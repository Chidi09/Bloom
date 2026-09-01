// lib/src/commands/deploy_command.dart
import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../deployment/deployment_target_detector.dart';
import '../deployment/docker_bundle_generator.dart';
import '../deployment/shorebird_config.dart';
import '../deployment/web_deploy_targets.dart';
import '../native/prebuild_engine.dart';
import '../templates/deployment_templates.dart';
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Supported mobile targets for OTA patching and binary releases.
const List<String> supportedMobileTargets = ['android', 'ios', 'aar', 'ios-framework'];

/// Supported web targets for hosting deployment.
const List<String> supportedWebTargets = ['web', 'web-container'];

/// All supported deployment target platforms.
const List<String> supportedTargets = [
  'android',
  'ios',
  'aar',
  'ios-framework',
  'web',
  'web-container',
];

/// Command that deploys web hosting configurations or OTA mobile patches using Shorebird.
///
/// Supports static web hosting targets (Netlify, Vercel, Nginx, Docker) and mobile
/// Over-The-Air code patches or base binary releases across Android and iOS.
/// Also provides subcommands: `bloom deploy init` and `bloom deploy docker`.
///
/// Example:
/// ```
/// bloom deploy --target web --host-format netlify --host-format vercel
/// bloom deploy --target android --flavor production --patch --channel production
/// bloom deploy init
/// bloom deploy docker --production-only
/// ```
class DeployCommand extends Command<int> {
  @override
  final String name = 'deploy';
  @override
  final String description =
      'Deploys web hosting configurations, OTA mobile patches/releases, or Docker lifecycle bundles.';

  DeployCommand() {
    _setupRootArgParser(argParser);
    _setupInitSubparser(argParser.addCommand('init'));
    _setupDockerSubparser(argParser.addCommand('docker'));
  }

  void _setupRootArgParser(ArgParser parser) {
    parser
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

  void _setupInitSubparser(ArgParser parser) {
    parser
      ..addOption(
        'target',
        abbr: 't',
        help: 'Override detected target platform (flutter, js_native, server, hybrid).',
        allowed: ['flutter', 'js_native', 'server', 'hybrid'],
      )
      ..addOption(
        'project-dir',
        help: 'Explicit path to the Bloom project directory.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing deployment configuration in bloom.yaml.',
        defaultsTo: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Preview deployment initialization changes without modifying files on disk.',
        defaultsTo: false,
      )
      ..addFlag(
        'non-interactive',
        abbr: 'y',
        aliases: ['yes'],
        help: 'Run in non-interactive mode without prompting.',
        defaultsTo: false,
      );
  }

  void _setupDockerSubparser(ArgParser parser) {
    parser
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target platform override (flutter, js_native, server, hybrid).',
        allowed: ['flutter', 'js_native', 'server', 'hybrid'],
      )
      ..addFlag(
        'production-only',
        help: 'Generate only production Dockerfile and omit Compose local development bundle.',
        defaultsTo: false,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Explicit output directory for generated deployment files (defaults to project root).',
      )
      ..addOption(
        'project-dir',
        help: 'Explicit path to the Bloom project directory.',
      )
      ..addFlag(
        'dry-run',
        help: 'Preview planned deployment files without writing them to disk.',
        defaultsTo: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing Docker and deployment files.',
        defaultsTo: false,
      )
      ..addFlag(
        'non-interactive',
        abbr: 'y',
        aliases: ['yes'],
        help: 'Run non-interactively in automated / CI pipelines.',
        defaultsTo: false,
      );
  }

  @override
  Future<int> run() async {
    final subcommand = argResults?.command;
    if (subcommand != null) {
      if (subcommand.name == 'init') {
        return _runInit(subcommand);
      } else if (subcommand.name == 'docker') {
        return _runDocker(subcommand);
      }
    }

    // Check rest arguments for init or docker fallback
    final rest = argResults?.rest ?? [];
    if (rest.isNotEmpty) {
      if (rest.first == 'init') {
        return _runInit(argResults!);
      } else if (rest.first == 'docker') {
        return _runDocker(argResults!);
      }
    }

    return _runRootDeploy();
  }

  Future<int> _runInit(ArgResults args) async {
    final explicitDir =
        args.options.contains('project-dir') && args['project-dir'] != null
            ? Directory(args['project-dir'] as String)
            : null;

    final project = BloomProject.find(explicitDir);
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory or parent directories.'));
      return 1;
    }

    final targetOverride = args.options.contains('target') ? args['target'] as String? : null;
    final isForce = args.options.contains('force') ? args['force'] as bool? ?? false : false;
    final isDryRun = args.options.contains('dry-run') ? args['dry-run'] as bool? ?? false : false;
    final isNonInteractive = args.options.contains('non-interactive') ? args['non-interactive'] as bool? ?? false : false;

    if (isNonInteractive) {
      print(Ansi.dimText('Running deployment initialization non-interactively in automated / CI mode.'));
    }

    print(Ansi.boldText('\n🔍 Bloom Deployment Target Auto-Detection\n'));

    final detector = const BloomDeploymentTargetDetector();
    final result = detector.detect(project, explicitTarget: targetOverride);

    print('${Ansi.cyan}› Target Detected: ${Ansi.boldText(result.target.displayName)} (${result.target.id})${Ansi.reset}');
    print('${Ansi.cyan}› Description:     ${Ansi.dimText(result.target.description)}${Ansi.reset}');
    print('${Ansi.cyan}› App Name:        ${Ansi.boldText(result.appName)}${Ansi.reset}');
    if (result.services.isNotEmpty) {
      print('${Ansi.cyan}› Services:        ${Ansi.boldText(result.services.join(', '))}${Ansi.reset}');
    }
    if (result.defaultPorts.isNotEmpty) {
      final portsStr = result.defaultPorts.entries.map((e) => '${e.key}:${e.value}').join(', ');
      print('${Ansi.cyan}› Default Ports:   ${Ansi.boldText(portsStr)}${Ansi.reset}');
    }

    print('\n${Ansi.boldText('Evidence & Indicators:')}');
    for (final reason in result.reasons) {
      print('  • $reason');
    }

    if (isDryRun) {
      print(Ansi.step('\nPlanned deployment initialization changes (Dry Run):'));
      final yamlFile = project.bloomYamlFile;
      if (yamlFile.existsSync()) {
        final content = yamlFile.readAsStringSync();
        if (!content.contains('deployment:') || isForce) {
          print(Ansi.info('  • Update ${yamlFile.path} (target: ${result.target.id})'));
        } else {
          print(Ansi.dimText('  - ${yamlFile.path} (already configured, skipped)'));
        }
      }
      final envExample = File(p.join(project.rootDir.path, '.env.example'));
      if (!envExample.existsSync() || isForce) {
        print(Ansi.info('  • Create ${envExample.path} (.env.example template)'));
      } else {
        print(Ansi.dimText('  - ${envExample.path} (already exists, skipped)'));
      }
      print(Ansi.success('\n✔ Dry run complete. 0 files written or modified on disk.\n'));
      return 0;
    }

    // Update bloom.yaml if needed
    final yamlFile = project.bloomYamlFile;
    if (yamlFile.existsSync()) {
      var content = yamlFile.readAsStringSync();
      if (!content.contains('deployment:') || isForce) {
        if (!content.contains('deployment:')) {
          content = '$content\ndeployment:\n  target: ${result.target.id}\n';
        } else if (isForce) {
          content = content.replaceAll(
            RegExp(r'deployment:\s*\n\s*target:\s*[a-zA-Z0-9_\-]+'),
            'deployment:\n  target: ${result.target.id}',
          );
        }
        yamlFile.writeAsStringSync(content);
        print(Ansi.success('\n✔ Updated bloom.yaml with deployment target: ${result.target.id}'));
      } else {
        print(Ansi.info('\nbloom.yaml already contains deployment configuration. Use --force to overwrite.'));
      }
    }

    // Ensure .env.example exists
    final envExample = File(p.join(project.rootDir.path, '.env.example'));
    if (!envExample.existsSync() || isForce) {
      envExample.writeAsStringSync(
        BloomDeploymentTemplates.envExample(
          target: result.target,
          appName: result.appName,
        ),
      );
      print(Ansi.success('✔ Generated .env.example environment template (Zero secrets embedded).'));
    }

    print(Ansi.boldText('\nNext Steps:'));
    print('  1. Generate Docker production bundle: ${Ansi.cyan}bloom deploy docker${Ansi.reset}');
    print('  2. Verify deployment toolchains:      ${Ansi.cyan}bloom doctor${Ansi.reset}\n');

    return 0;
  }

  Future<int> _runDocker(ArgResults args) async {
    final explicitDir =
        args.options.contains('project-dir') && args['project-dir'] != null
            ? Directory(args['project-dir'] as String)
            : null;

    final project = BloomProject.find(explicitDir);
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory or parent directories.'));
      return 1;
    }

    final targetOverride = args.options.contains('target') ? args['target'] as String? : null;
    final isProductionOnly = args.options.contains('production-only') ? args['production-only'] as bool? ?? false : false;
    final isDryRun = args.options.contains('dry-run') ? args['dry-run'] as bool? ?? false : false;
    final isForce = args.options.contains('force') ? args['force'] as bool? ?? false : false;
    final isNonInteractive = args.options.contains('non-interactive') ? args['non-interactive'] as bool? ?? false : false;
    final explicitOutput = args.options.contains('output') ? args['output'] as String? : null;
    final outputDir = explicitOutput != null ? Directory(explicitOutput) : project.rootDir;

    if (isNonInteractive) {
      print(Ansi.dimText('Running Docker generation non-interactively in automated / CI mode.'));
    }

    final detector = const BloomDeploymentTargetDetector();
    final result = detector.detect(project, explicitTarget: targetOverride);

    final generator = const BloomDockerGenerator();
    final bundle = generator.generate(
      project: project,
      target: result.target,
      productionOnly: isProductionOnly,
      hasSsr: result.hasSsr,
      dbDialect: result.databaseDialect,
    );

    print(Ansi.boldText('\n🐳 Bloom Docker Deployment Generator\n'));
    print('${Ansi.cyan}› Target:          ${Ansi.boldText(result.target.displayName)} (${result.target.id})${Ansi.reset}');
    print('${Ansi.cyan}› Output Mode:     ${Ansi.boldText(isProductionOnly ? "Production Only (Compose omitted)" : "Full Local Dev + Production Bundle")}${Ansi.reset}');
    print('${Ansi.cyan}› Target Directory:${Ansi.boldText(outputDir.path)}${Ansi.reset}');
    print('${Ansi.cyan}› Artifacts:       ${Ansi.boldText(bundle.files.keys.join(', '))}${Ansi.reset}\n');

    if (isDryRun) {
      print(Ansi.step('Planned deployment files to generate (Dry Run):'));
      for (final entry in bundle.files.entries) {
        final filePath = p.join(outputDir.path, entry.key);
        print(Ansi.info('  • $filePath (${entry.value.length} bytes)'));
      }
      print(Ansi.success('\n✔ Dry run complete. 0 files written to disk.'));
      return 0;
    }

    // Write files to disk
    final writtenFiles = generator.writeBundle(
      bundle: bundle,
      targetDir: outputDir,
      overwrite: isForce,
    );

    if (writtenFiles.isEmpty && bundle.files.isNotEmpty) {
      print(Ansi.warn('Files already exist in target directory. Re-run with --force to overwrite.'));
      for (final key in bundle.files.keys) {
        print(Ansi.dimText('  - ${p.join(outputDir.path, key)} (skipped)'));
      }
      return 0;
    }

    print(Ansi.step('Generated deployment artifacts:'));
    for (final file in writtenFiles) {
      print(Ansi.success('  ✔ ${file.path}'));
    }

    print(Ansi.success('\n✔ Docker deployment bundle generated successfully!'));
    print('  Build image:    ${Ansi.cyan}docker build -t ${project.projectName}:latest .${Ansi.reset}');
    if (!isProductionOnly) {
      print('  Run local dev:  ${Ansi.cyan}docker compose up --build${Ansi.reset}');
    }
    print('  Verify health:  ${Ansi.cyan}bloom doctor${Ansi.reset}\n');

    return 0;
  }

  Future<int> _runRootDeploy() async {
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
