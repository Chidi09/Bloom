// lib/src/deployment/host_config_generator.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../dev/dev_proxy.dart';
import 'web_deploy_targets.dart';

/// Generates host-native static web server and reverse-proxy deployment configurations.
///
/// ### Architectural Contract
/// - Translates declarative [BloomDevProxyRule] entries defined in `bloom.yaml` into host-native
///   routing/proxying configurations for Netlify (`_redirects`), Vercel (`vercel.json`),
///   Nginx (`nginx.conf`), and Docker containers (`Dockerfile`, `docker-compose.yml`).
/// - Guarantees that client-side SPA routing and Backend-For-Frontend (BFF) reverse proxying work
///   consistently in production environments without requiring custom server code.
/// - All generation methods are pure, deterministic, and side-effect free.
class BloomHostConfigGenerator {
  const BloomHostConfigGenerator();

  /// Generates Netlify `_redirects` configuration with proxy rewrites and SPA fallback.
  ///
  /// ### CORS Prevention Rationale
  /// Uses HTTP status `200` (proxy rewrite) rather than `301` or `302` redirects.
  /// A `301`/`302` redirect instructs the user's browser to make a direct external HTTP request
  /// to the upstream target origin, which immediately triggers browser Cross-Origin Resource
  /// Sharing (CORS) blocks and exposes the internal upstream service URL. An HTTP `200` rewrite
  /// proxies the request on Netlify's edge CDN, preserving the client application's origin.
  String generateNetlifyRedirects(List<BloomDevProxyRule> rules) {
    final buffer = StringBuffer();

    for (final rule in rules) {
      final prefix = _normalizePrefix(rule.pathPrefix);
      final target = _normalizeTargetUri(rule.targetUri);

      if (rule.stripPrefix) {
        // Strip prefix: the splat parameter maps directly onto the target root path
        buffer.writeln('$prefix/*  $target/:splat  200');
      } else {
        // Preserve prefix: the prefix is preserved when forwarding to the upstream target
        buffer.writeln('$prefix/*  $target$prefix/:splat  200');
      }
    }

    // SPA catch-all fallback rewrite for client-side routing
    buffer.writeln('/*  /index.html  200');
    return buffer.toString();
  }

  /// Generates Vercel `vercel.json` configuration with edge proxy rewrites and SPA fallback.
  ///
  /// Uses `"rewrites"` instead of `"redirects"` to proxy requests server-side at the CDN edge
  /// without browser redirects or CORS issues.
  String generateVercelJson(List<BloomDevProxyRule> rules) {
    final rewrites = <Map<String, String>>[];

    for (final rule in rules) {
      final prefix = _normalizePrefix(rule.pathPrefix);
      final target = _normalizeTargetUri(rule.targetUri);

      final destination = rule.stripPrefix
          ? '$target/:path*'
          : '$target$prefix/:path*';

      rewrites.add({
        'source': '$prefix/:path*',
        'destination': destination,
      });
    }

    // SPA catch-all fallback rewrite for client-side routing
    rewrites.add({
      'source': '/(.*)',
      'destination': '/index.html',
    });

    return const JsonEncoder.withIndent('  ').convert({
      'rewrites': rewrites,
    });
  }

  /// Generates an Nginx server configuration block with reverse proxying and SPA fallback.
  ///
  /// ### Nginx Trailing-Slash Proxy Behavior
  /// In Nginx `proxy_pass`, the presence or absence of a trailing slash dictates URI rewriting:
  /// - When `proxy_pass` contains a trailing slash (e.g. `proxy_pass http://upstream/;`), Nginx
  ///   strips the matched `location` prefix from the normalized URI before forwarding.
  /// - When `proxy_pass` omits the trailing slash (e.g. `proxy_pass http://upstream;`), Nginx
  ///   passes the full original request URI (including the prefix) unchanged to the upstream server.
  String generateNginxConf(
    List<BloomDevProxyRule> rules, {
    required String root,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('server {');
    buffer.writeln('  listen 8080;');
    buffer.writeln('  server_name localhost;');
    buffer.writeln('  root $root;');
    buffer.writeln('  index index.html;');
    buffer.writeln();

    for (final rule in rules) {
      final prefix = _normalizePrefix(rule.pathPrefix);
      final upstreamHost = rule.targetUri.host;
      final target = _normalizeTargetUri(rule.targetUri);

      // Trailing slash controls prefix stripping in Nginx
      final proxyPassUrl = rule.stripPrefix ? '$target/' : target;

      buffer.writeln('  location $prefix/ {');
      buffer.writeln('    proxy_pass $proxyPassUrl;');
      buffer.writeln('    proxy_http_version 1.1;');
      if (rule.targetUri.scheme == 'https') {
        // Without this, nginx omits the TLS SNI extension when connecting to an
        // HTTPS upstream, so any name-based virtual host answers with the wrong
        // certificate (or refuses the handshake outright).
        buffer.writeln('    proxy_ssl_server_name on;');
      }
      buffer.writeln('    proxy_set_header Host $upstreamHost;');
      buffer.writeln('    proxy_set_header X-Real-IP \$remote_addr;');
      buffer.writeln('    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;');
      buffer.writeln('    proxy_set_header X-Forwarded-Proto \$scheme;');
      // nginx defaults to a 4k/8k header buffer, which real upstreams routinely
      // exceed -- GitHub alone sends enough Set-Cookie and CSP headers to blow
      // past it, and nginx answers 502 with "upstream sent too big header"
      // rather than anything that points at the true cause. Verified against
      // github.com: the default buffers 502, these values succeed.
      buffer.writeln('    proxy_buffer_size 16k;');
      buffer.writeln('    proxy_buffers 8 16k;');
      buffer.writeln('    proxy_busy_buffers_size 32k;');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln('  location / {');
    buffer.writeln('    try_files \$uri \$uri/ /index.html;');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates a multi-stage Dockerfile for containerized deployment.
  ///
  /// ### Container Optimization Rationale
  /// For server deployments (`includeServer: true`), compiles a standalone binary via
  /// `dart compile exe` and runs inside a minimal `FROM scratch` container. Copying only
  /// `/runtime/` and the compiled executable produces a minimal container attack surface and
  /// a tiny final image with no Dart SDK or build toolchain.
  /// For static deployments (`includeServer: false`), builds the distribution and serves it via
  /// `nginx:alpine` with the generated Nginx reverse proxy configuration.
  String generateDockerfile({
    required String appName,
    bool includeServer = false,
    String staticSourceDir = 'build/web',
  }) {
    if (includeServer) {
      return '''
# Multi-stage Dockerfile for Bloom Full-Stack Application (SSR / Server)
# Stage 1: Build standalone self-contained server executable
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Minimal runtime image using scratch
# Using `dart compile exe` combined with `FROM scratch` produces a minimal production
# container image with zero extraneous dependencies and no Dart SDK in the final layer.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/build/web /app/build/web

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
'''.trimLeft();
    } else {
      return '''
# Dockerfile for Bloom Static Web Application
#
# Single-stage by design. The web bundle is produced ahead of this build by
# `bloom js build` (or `bloom build web --static`), so there is nothing left for
# a Dart build stage to compile -- one would only add the SDK to the build
# context and copy a directory that the CLI has already emitted.
#
# Build from the project root so $staticSourceDir resolves:
#   docker build -f $staticSourceDir/Dockerfile -t $appName .
FROM nginx:alpine

COPY $staticSourceDir /usr/share/nginx/html
COPY $staticSourceDir/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
'''.trimLeft();
    }
  }

  /// Generates a minimal docker-compose configuration file.
  String generateDockerCompose({required String appName}) {
    return '''
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    image: $appName:latest
    container_name: $appName
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
'''.trimLeft();
  }

  /// Writes host configuration files for all requested [formats] to [outputDir].
  List<File> writeAll({
    required Directory outputDir,
    required List<BloomDevProxyRule> rules,
    required String appName,
    required Set<BloomWebHostFormat> formats,
    String nginxRoot = '/usr/share/nginx/html',
    bool includeServer = false,
    String staticSourceDir = 'build/web',
  }) {
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final written = <File>[];

    if (formats.contains(BloomWebHostFormat.netlify)) {
      final file = File(p.join(outputDir.path, '_redirects'));
      file.writeAsStringSync(generateNetlifyRedirects(rules));
      written.add(file);
    }

    if (formats.contains(BloomWebHostFormat.vercel)) {
      final file = File(p.join(outputDir.path, 'vercel.json'));
      file.writeAsStringSync(generateVercelJson(rules));
      written.add(file);
    }

    if (formats.contains(BloomWebHostFormat.nginx)) {
      final file = File(p.join(outputDir.path, 'nginx.conf'));
      file.writeAsStringSync(generateNginxConf(rules, root: nginxRoot));
      written.add(file);
    }

    if (formats.contains(BloomWebHostFormat.docker)) {
      final dockerfile = File(p.join(outputDir.path, 'Dockerfile'));
      dockerfile.writeAsStringSync(
        generateDockerfile(
          appName: appName,
          includeServer: includeServer,
          staticSourceDir: staticSourceDir,
        ),
      );
      written.add(dockerfile);

      final compose = File(p.join(outputDir.path, 'docker-compose.yml'));
      compose.writeAsStringSync(generateDockerCompose(appName: appName));
      written.add(compose);
    }

    return written;
  }

  static String _normalizePrefix(String prefix) {
    var p = prefix.trim();
    if (!p.startsWith('/')) p = '/$p';
    if (p.endsWith('/') && p.length > 1) p = p.substring(0, p.length - 1);
    return p;
  }

  static String _normalizeTargetUri(Uri targetUri) {
    var s = targetUri.toString().trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }
}
