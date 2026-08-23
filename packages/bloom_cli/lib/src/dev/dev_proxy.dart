// lib/src/dev/dev_proxy.dart
import 'dart:async';
import 'dart:io';

/// Configuration rule for forwarding dev server requests to an upstream target.
///
/// Enables seamless Backend-for-Frontend (BFF) development by allowing the client
/// web application to call backend services on the same origin (avoiding browser CORS
/// restrictions) while forwarding traffic to local servers or third-party APIs.
class BloomDevProxyRule {
  /// The local URL path prefix that triggers this proxy rule (e.g. `'/api'` or `'/gh'`).
  final String pathPrefix;

  /// The upstream destination URI (e.g. `Uri.parse('http://127.0.0.1:8090')`).
  final Uri targetUri;

  /// Whether to remove [pathPrefix] from the request path before forwarding upstream.
  final bool stripPrefix;

  /// Creates a [BloomDevProxyRule] with path prefix, upstream URI, and optional prefix stripping.
  const BloomDevProxyRule({
    required this.pathPrefix,
    required this.targetUri,
    this.stripPrefix = false,
  });

  /// Parses a [BloomDevProxyRule] from a YAML configuration entry.
  ///
  /// Expects [key] as the path prefix and [value] as a map containing a required `target`
  /// string and optional `strip_prefix` boolean. Throws [FormatException] if `target` is
  /// missing or malformed.
  factory BloomDevProxyRule.fromYaml(String key, dynamic value) {
    if (value is! Map) {
      throw FormatException(
        'Proxy configuration for "$key" must be a map with a "target" URL string.',
      );
    }
    final rawTarget = value['target'];
    if (rawTarget == null || rawTarget.toString().trim().isEmpty) {
      throw FormatException(
        'Proxy configuration for "$key" is missing required "target" URL.',
      );
    }
    final targetStr = rawTarget.toString().trim();
    final uri = Uri.tryParse(targetStr);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException(
        'Proxy configuration for "$key" has invalid "target" URL: "$targetStr".',
      );
    }

    final strip = value['strip_prefix'] == true || value['stripPrefix'] == true;
    final normalizedKey = key.startsWith('/') ? key : '/$key';

    return BloomDevProxyRule(
      pathPrefix: normalizedKey,
      targetUri: uri,
      stripPrefix: strip,
    );
  }

  /// Checks whether [requestPath] matches this rule's [pathPrefix].
  ///
  /// Matches exact prefix or path segments (e.g. `/api` matches `/api`, `/api/`, and `/api/v1`).
  bool matches(String requestPath) {
    final prefix = pathPrefix.endsWith('/') && pathPrefix.length > 1
        ? pathPrefix.substring(0, pathPrefix.length - 1)
        : pathPrefix;

    if (prefix == '/' || prefix.isEmpty) return true;
    return requestPath == prefix || requestPath.startsWith('$prefix/');
  }

  /// Resolves the final upstream target [Uri] for an incoming request path and query string.
  Uri resolveTargetUri(Uri requestUri) {
    final reqPath = requestUri.path;
    final prefix = pathPrefix.endsWith('/') && pathPrefix.length > 1
        ? pathPrefix.substring(0, pathPrefix.length - 1)
        : pathPrefix;

    String effectiveSubPath;
    if (stripPrefix) {
      if (reqPath == prefix) {
        effectiveSubPath = '';
      } else if (reqPath.startsWith('$prefix/')) {
        effectiveSubPath = reqPath.substring(prefix.length);
      } else {
        effectiveSubPath = reqPath;
      }
    } else {
      effectiveSubPath = reqPath;
    }

    // Combine upstream target base path with effective subpath
    final basePath = targetUri.path.endsWith('/') && targetUri.path.length > 1
        ? targetUri.path.substring(0, targetUri.path.length - 1)
        : (targetUri.path == '/' ? '' : targetUri.path);

    final String finalPath;
    if (effectiveSubPath.startsWith('/')) {
      finalPath = '$basePath$effectiveSubPath';
    } else if (effectiveSubPath.isEmpty) {
      finalPath = basePath.isEmpty ? '/' : basePath;
    } else {
      finalPath = '$basePath/$effectiveSubPath';
    }

    // Preserve query parameters: request query parameters take priority,
    // falling back to target URI query parameters if none in request.
    final query = requestUri.hasQuery
        ? requestUri.query
        : (targetUri.hasQuery ? targetUri.query : null);

    return targetUri.replace(
      path: finalPath.isEmpty ? '/' : finalPath,
      query: query,
    );
  }
}

/// Reverse proxy engine for Bloom development servers.
///
/// Streams requests and responses between the dev server and configured upstream targets,
/// managing hop-by-hop headers, proxy forwarding headers (`x-forwarded-*`), and error boundaries.
class BloomDevProxy {
  final HttpClient _client;

  /// Hop-by-hop headers that must not be forwarded across proxy hops per RFC 7230.
  static const Set<String> _hopByHopHeaders = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
    'host',
  };

  /// Creates a [BloomDevProxy] with an optional custom [HttpClient].
  BloomDevProxy({HttpClient? client})
      : _client = client ?? (HttpClient()..autoUncompress = false);

  /// Forwards an incoming dev server [HttpRequest] to the upstream target defined by [rule].
  ///
  /// Streams the request body to the upstream server, copies response status and headers,
  /// and streams the response bytes back to the client. Returns HTTP 502 on upstream failure.
  Future<void> forward(HttpRequest req, BloomDevProxyRule rule) async {
    final upstreamUri = rule.resolveTargetUri(req.uri);

    try {
      final upstreamReq = await _client.openUrl(req.method, upstreamUri);

      // 1. Forward request headers (excluding hop-by-hop headers)
      req.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (_hopByHopHeaders.contains(lower)) return;
        for (final val in values) {
          upstreamReq.headers.add(name, val);
        }
      });

      // 2. Set proxy forwarding headers
      final clientIp = req.connectionInfo?.remoteAddress.address ?? '127.0.0.1';
      final existingXff = req.headers.value('x-forwarded-for');
      upstreamReq.headers.set(
        'x-forwarded-for',
        existingXff != null ? '$existingXff, $clientIp' : clientIp,
      );

      final originalHost = req.headers.value(HttpHeaders.hostHeader) ?? req.uri.host;
      if (originalHost.isNotEmpty) {
        upstreamReq.headers.set('x-forwarded-host', originalHost);
      }

      final existingProto = req.headers.value('x-forwarded-proto');
      final proto = existingProto ??
          (req.connectionInfo?.remoteAddress.isLoopback == false && req.certificate != null
              ? 'https'
              : 'http');
      upstreamReq.headers.set('x-forwarded-proto', proto);

      // 3. Stream request body to upstream
      await upstreamReq.addStream(req);
      final upstreamRes = await upstreamReq.close();

      // 4. Set response status code and forward response headers
      req.response.statusCode = upstreamRes.statusCode;
      upstreamRes.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (_hopByHopHeaders.contains(lower)) return;
        for (final val in values) {
          req.response.headers.add(name, val);
        }
      });

      req.response.bufferOutput = false;

      // 5. Stream response body back to browser client
      await req.response.addStream(upstreamRes);
      await req.response.close();
    } catch (e) {
      stderr.writeln(
        '[BloomDevProxy] ✖ Failed to proxy ${req.method} ${req.uri.path} -> $upstreamUri: $e',
      );

      try {
        req.response.statusCode = HttpStatus.badGateway;
        req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/plain; charset=utf-8');
        req.response.write(
          '502 Bad Gateway: Upstream connection failed to $upstreamUri\n\n$e',
        );
        await req.response.close();
      } catch (_) {}
    }
  }

  /// Closes the internal [HttpClient] connection pool.
  Future<void> close({bool force = false}) async {
    _client.close(force: force);
  }
}
