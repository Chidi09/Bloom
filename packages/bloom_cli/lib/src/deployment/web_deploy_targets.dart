// lib/src/deployment/web_deploy_targets.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../dev/dev_proxy.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'host_config_generator.dart';
import 'proxy_config_loader.dart';

/// Supported static and container host configuration formats.
enum BloomWebHostFormat {
  netlify,
  vercel,
  nginx,
  docker,
}

/// The deployable web targets Bloom supports.
enum BloomWebDeployTarget {
  static_,
  container;

  /// CLI flag value for this deployment target (e.g. `'web'`, `'web-container'`).
  String get cliName {
    switch (this) {
      case BloomWebDeployTarget.static_:
        return 'web';
      case BloomWebDeployTarget.container:
        return 'web-container';
    }
  }

  /// Human-readable summary of the target platform and output characteristics.
  String get description {
    switch (this) {
      case BloomWebDeployTarget.static_:
        return 'Prebuilt static bundle for CDN/static host deployment (Netlify, Vercel, Nginx).';
      case BloomWebDeployTarget.container:
        return 'Self-hosted container image with built-in runtime and reverse-proxying.';
    }
  }

  /// Resolves a [BloomWebDeployTarget] from its [cliName].
  static BloomWebDeployTarget? fromCliName(String name) {
    for (final target in BloomWebDeployTarget.values) {
      if (target.cliName == name) return target;
    }
    return null;
  }
}

/// Orchestrates web deployment configuration generation for Bloom projects.
///
/// ### Architectural Contract
/// - Bridges project configuration (`bloom.yaml`) and proxy rules into target host
///   artifacts without modifying application code.
/// - In dry-run mode (`dryRun: true`), outputs the execution plan and target file paths
///   with strict zero-side-effect guarantees (no directories or files created).
/// - Gracefully handles empty proxy definitions by generating valid SPA fallback rules.
class BloomWebDeployer {
  const BloomWebDeployer();

  /// Executes the web deployment workflow.
  Future<int> run({
    required BloomProject project,
    required BloomWebDeployTarget target,
    String? flavor,
    required bool dryRun,
    required Set<BloomWebHostFormat> formats,
    Directory? outputDir,
  }) async {
    // 1. Load config and parse proxy rules
    final config = project.loadBloomConfig();
    final List<BloomDevProxyRule> rules;
    try {
      rules = loadProxyRules(config);
    } catch (e) {
      final message = e is FormatException ? e.message : e.toString();
      print(Ansi.error('Invalid proxy configuration: $message'));
      return 1;
    }

    // 2. Determine web output directory
    final defaultWebDir = Directory(
      p.join(project.rootDir.path, 'build', 'web'),
    );
    final effectiveOutputDir = outputDir ?? defaultWebDir;

    // 3. Print deployment plan
    print('${Ansi.boldText('🌸 Bloom Web Deployment Plan')}\n');
    print('${Ansi.cyan}› Target:     ${Ansi.boldText(target.cliName)} (${target.description})${Ansi.reset}');
    if (flavor != null) {
      print('${Ansi.cyan}› Flavor:     ${Ansi.boldText(flavor)}${Ansi.reset}');
    }
    print('${Ansi.cyan}› Proxy Rules: ${Ansi.boldText(rules.length.toString())}${Ansi.reset}');
    print('${Ansi.cyan}› Formats:    ${Ansi.boldText(formats.map((f) => f.name).join(', '))}${Ansi.reset}');
    print('${Ansi.cyan}› Output Dir: ${Ansi.boldText(effectiveOutputDir.path)}${Ansi.reset}\n');

    if (rules.isEmpty) {
      print(Ansi.info('No "proxy" configuration found in bloom.yaml. Emitting default SPA fallback rules.'));
    }

    // 4. Dry-run early return
    if (dryRun) {
      print(Ansi.step('Planned deployment files to write:'));
      if (formats.contains(BloomWebHostFormat.netlify)) {
        print(Ansi.info('  • ${p.join(effectiveOutputDir.path, '_redirects')}'));
      }
      if (formats.contains(BloomWebHostFormat.vercel)) {
        print(Ansi.info('  • ${p.join(effectiveOutputDir.path, 'vercel.json')}'));
      }
      if (formats.contains(BloomWebHostFormat.nginx)) {
        print(Ansi.info('  • ${p.join(effectiveOutputDir.path, 'nginx.conf')}'));
      }
      if (formats.contains(BloomWebHostFormat.docker)) {
        print(Ansi.info('  • ${p.join(effectiveOutputDir.path, 'Dockerfile')}'));
        print(Ansi.info('  • ${p.join(effectiveOutputDir.path, 'docker-compose.yml')}'));
      }
      print(Ansi.success('\n✔ Dry run complete. Deployment plan validated with zero side-effects.'));
      return 0;
    }

    // 5. Generate and write configuration files
    try {
      final generator = const BloomHostConfigGenerator();
      final writtenFiles = generator.writeAll(
        outputDir: effectiveOutputDir,
        rules: rules,
        appName: project.projectName,
        formats: formats,
        // A container target does not imply a server to compile. The server
        // Dockerfile runs `dart compile exe bin/server.dart`, so emitting it for
        // a static SPA produces a Dockerfile that cannot build. Gate it on the
        // entrypoint actually existing.
        includeServer: target == BloomWebDeployTarget.container &&
            File(p.join(project.rootDir.path, 'bin', 'server.dart')).existsSync(),
        // The web bundle directory, not effectiveOutputDir: `--output` only
        // says where to put the generated config, and may point anywhere on
        // disk. Docker cannot COPY from outside its build context, so a path
        // that escapes the project root would produce an unbuildable image.
        staticSourceDir: p.relative(
          defaultWebDir.path,
          from: project.rootDir.path,
        ),
      );

      print(Ansi.step('Generated host configuration files:'));
      for (final file in writtenFiles) {
        print(Ansi.success('  • ${file.path}'));
      }
      print(Ansi.success('\n✔ Web deployment configuration generated successfully.'));
      return 0;
    } catch (e) {
      print(Ansi.error('✖ Failed to write web deployment configuration:\n$e'));
      return 1;
    }
  }
}
