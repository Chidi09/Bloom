// lib/src/commands/deploy_command.dart
import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../deployment/shorebird_config.dart';
import '../deployment/web_deploy_targets.dart';
import '../native/prebuild_engine.dart';
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

const List<String> supportedMobileTargets = ['android', 'ios', 'aar', 'ios-framework'];
const List<String> supportedWebTargets = ['web', 'web-container'];
const List<String> supportedTargets = [
  'android',
  'ios',
  'aar',
  'ios-framework',
  'web',
  'web-container',
];

class DeployCommand extends Command<int> {
  @override
  final String name = 'deploy';
  @override
  final String description =
      'Deploys web hosting configurations or Over-The-Air (OTA) mobile patches/releases using Shorebird.';

  DeployCommand() {
    argParser
      ..addOption(
        'channel',
        abbr: 'c',
        help: 'Target deployment release channel (e.g. production, staging, preview).',
        defaultsTo: 'production',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target platform to release or patch (${supportedTargets.join(', ')}).',
        defaultsTo: 'android',
      )
      ..addOption(
        'flavor',
        abbr: 'f',
        help: 'Build flavor to deploy (e.g. development, staging, production).',
      )
      ..addMultiOption(
        'host-format',
        help: 'Host configuration formats to generate for web targets (netlify, vercel, nginx, docker).',
        allowed: ['netlify', 'vercel', 'nginx', 'docker'],
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Explicit output directory for generated web deployment configuration files.',
      )
      ..addOption(
        'app-id',
        help: 'Explicit Shorebird App ID override.',
      )
      ..addFlag(
        'patch',
        help: 'Deploy an Over-The-Air (OTA) code patch to an existing release.',
        defaultsTo: true,
      )
      ..addFlag(
        'release',
        help: 'Build and publish a full base binary release.',
        defaultsTo: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Validate configuration and output planned deployment commands without executing them.',
        defaultsTo: false,
      )
      ..addFlag(
        'prebuild',
        help: 'Run native prebuild synchronization before deployment.',
        defaultsTo: true,
      );
  }

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory or parent directories.'));
      return 1;
    }

    final channel = (argResults?['channel'] as String? ?? 'production').trim();
    final target = (argResults?['target'] as String? ?? 'android').trim().toLowerCase();
    final flavor = argResults?['flavor'] as String?;
    final overrideAppId = argResults?['app-id'] as String?;
    final isRelease = argResults?['release'] as bool? ?? false;
    final isPatch = argResults?['patch'] as bool? ?? true;
    final isDryRun = argResults?['dry-run'] as bool? ?? false;
    final runPrebuild = argResults?['prebuild'] as bool? ?? true;

    // 1. Target Validation
    if (!supportedTargets.contains(target)) {
      print(Ansi.error('Invalid target "$target". Supported targets: ${supportedTargets.join(', ')}'));
      return 1;
    }

    // 2. Flavor Validation
    final config = project.loadBloomConfig();
    if (flavor != null) {
      final flavors = config['flavors'];
      if (flavors is! Map || !flavors.containsKey(flavor)) {
        print(Ansi.error('Flavor "$flavor" is not defined under flavors in bloom.yaml.'));
        return 1;
      }
    }

    // 3. Web Deployment Branch (dispatched before mobile/Shorebird steps)
    if (supportedWebTargets.contains(target)) {
      final webTarget = target == 'web'
          ? BloomWebDeployTarget.static_
          : BloomWebDeployTarget.container;

      final rawFormats = (argResults?['host-format'] as List<String>?) ?? [];
      final Set<BloomWebHostFormat> formats;
      if (rawFormats.isNotEmpty) {
        formats = rawFormats
            .map((f) => BloomWebHostFormat.values.firstWhere((v) => v.name == f))
            .toSet();
      } else {
        formats = webTarget == BloomWebDeployTarget.static_
            ? {BloomWebHostFormat.netlify}
            : {BloomWebHostFormat.docker, BloomWebHostFormat.nginx};
      }

      final explicitOutput = argResults?['output'] as String?;
      final outputDir = explicitOutput != null ? Directory(explicitOutput) : null;

      final deployer = const BloomWebDeployer();
      return await deployer.run(
        project: project,
        target: webTarget,
        flavor: flavor,
        dryRun: isDryRun,
        formats: formats,
        outputDir: outputDir,
      );
    }

    // 4. Mobile Validation
    if (channel.isEmpty) {
      print(Ansi.error('Deployment release channel cannot be empty.'));
      return 1;
    }

    if (!isRelease && !isPatch) {
      print(Ansi.error('Must specify either --patch or --release mode for deployment.'));
      return 1;
    }

    printBloomBanner();
    print('${Ansi.boldText('🚀 Bloom OTA Deployment Engine (Shorebird)')}\n');

    // 2. Sync routes
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);

    // 3. Prebuild native manifests if requested
    if (runPrebuild) {
      final prebuildEngine = PrebuildEngine(project);
      final syncSuccess = await prebuildEngine.run();
      if (!syncSuccess) {
        print(Ansi.error('Prebuild synchronization failed. Fix errors and retry.'));
        return 1;
      }
    }

    // 4. Synchronize shorebird.yaml
    final synchronizer = ShorebirdSynchronizer(project);
    final shorebirdFile = synchronizer.sync(activeFlavor: flavor, overrideAppId: overrideAppId);
    if (!shorebirdFile.existsSync() || shorebirdFile.readAsStringSync().trim().isEmpty) {
      print(Ansi.error('Failed to generate valid shorebird.yaml.'));
      return 1;
    }

    // 5. Assemble Shorebird execution arguments
    final shorebirdArgs = <String>[];
    if (isRelease) {
      shorebirdArgs.addAll(['release', target]);
    } else {
      shorebirdArgs.addAll(['patch', target, '--channel', channel]);
    }

    if (flavor != null) {
      shorebirdArgs.addAll(['--flavor', flavor]);
      shorebirdArgs.add('--dart-define=BLOOM_FLAVOR=$flavor');
    }

    print('\n${Ansi.cyan}› Target:  ${Ansi.boldText(target)}${Ansi.reset}');
    print('${Ansi.cyan}› Mode:    ${Ansi.boldText(isRelease ? "Full Base Release" : "OTA Code-Push Patch")}${Ansi.reset}');
    print('${Ansi.cyan}› Channel: ${Ansi.boldText(channel)}${Ansi.reset}');
    if (flavor != null) {
      print('${Ansi.cyan}› Flavor:  ${Ansi.boldText(flavor)}${Ansi.reset}');
    }

    final commandStr = 'shorebird ${shorebirdArgs.join(' ')}';
    print('\n${Ansi.boldText('Command:')} $commandStr\n');

    if (isDryRun) {
      print(Ansi.success('✔ Dry run complete. Deployment configuration and execution plan validated.'));
      return 0;
    }

    // 6. Check if shorebird is installed
    final hasShorebird = await _checkShorebirdInstalled();
    if (!hasShorebird) {
      print(Ansi.error('✖ Shorebird CLI is not installed or not available on PATH.'));
      print(Ansi.info('To install Shorebird, run:'));
      print('  curl --proto "=https" --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash\n');
      return 1; // Explicit failure exit code on missing tool in non-dry-run
    }

    print(Ansi.step('Executing Shorebird deployment...'));
    final process = await Process.start(
      'shorebird',
      shorebirdArgs,
      workingDirectory: project.rootDir.path,
      mode: ProcessStartMode.inheritStdio,
    );

    return await process.exitCode;
  }

  Future<bool> _checkShorebirdInstalled() async {
    try {
      final result = await Process.run('shorebird', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
