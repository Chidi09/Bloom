// lib/src/commands/doctor_command.dart
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../commands/audit_command.dart';
import '../deployment/deployment_doctor_check.dart';
import '../dev/mdns_discovery.dart';
import '../native/autolink_engine.dart';
import '../security/secret_scanner.dart';
import '../upgrade/breaking_change_analyzer.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

const _bloomCliVersion = '0.4.0';

/// Command that validates environment, toolchain, project configuration, and CI health.
///
/// Inspects Dart and Flutter SDKs, native mobile toolchains, mDNS network interfaces,
/// dependency CVEs, secret leaks, upgrade breaking-change compatibility, and Docker deployment readiness.
///
/// Example:
/// ```
/// bloom doctor
/// bloom doctor --ci
/// bloom doctor --upgrade
/// ```
class DoctorCommand extends Command<int> {
  @override
  final String name = 'doctor';
  @override
  final String description = 'Validates environment, toolchain, project configuration, and CI health.';

  DoctorCommand() {
    argParser.addFlag(
      'upgrade',
      help: 'Performs upgrade breaking-change compatibility analysis.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'ci',
      help: 'Runs strict CI continuous diagnostic verification and fails on any risk.',
      defaultsTo: false,
    );
    argParser.addOption(
      'project-dir',
      help: 'Explicit path to the Bloom project directory.',
    );
  }

  @override
  Future<int> run() async {
    final projectDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : Directory.current;

    final project = BloomProject.find(projectDir);

    // 1. Check if --upgrade flag was requested
    if (argResults?['upgrade'] == true) {
      if (project == null) {
        print(Ansi.error('✖ Not a valid Bloom project directory: ${projectDir.path}'));
        return 1;
      }
      final analyzer = BreakingChangeAnalyzer(project);
      final report = analyzer.analyze();
      return report.isCompatible ? 0 : 1;
    }

    // 2. Check if --ci flag was requested
    if (argResults?['ci'] == true) {
      return _runCiDoctor(project, projectDir);
    }

    // 3. Standard interactive developer health check
    print(Ansi.boldText('\n🩺 Bloom Diagnostic System Health Check\n'));

    bool allGood = true;

    // Dart SDK Check
    stdout.write('  Checking Dart SDK... ');
    final dartRes = await Process.run('dart', ['--version']);
    if (dartRes.exitCode == 0 || dartRes.stderr.toString().contains('Dart SDK version')) {
      final out = dartRes.stdout.toString().isNotEmpty
          ? dartRes.stdout.toString().trim()
          : dartRes.stderr.toString().trim();
      final firstLine = out.split('\n').first;
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('($firstLine)')}');
    } else {
      print('${Ansi.red}✖ Missing${Ansi.reset}');
      allGood = false;
    }

    // Flutter SDK Check
    stdout.write('  Checking Flutter SDK... ');
    final flutterRes = await Process.run('flutter', ['--version']);
    if (flutterRes.exitCode == 0) {
      final out = flutterRes.stdout.toString().trim();
      final firstLine = out.split('\n').first;
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('($firstLine)')}');
    } else {
      print('${Ansi.red}✖ Missing${Ansi.reset}');
      allGood = false;
    }

    // Android SDK / Java Check
    stdout.write('  Checking Android Toolchain / Java... ');
    final javaRes = await Process.run('java', ['-version']);
    final androidHome = Platform.environment['ANDROID_HOME'] ?? Platform.environment['ANDROID_SDK_ROOT'];
    if (javaRes.exitCode == 0) {
      final sdkStatus = androidHome != null ? 'SDK: $androidHome' : 'Java present';
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('($sdkStatus)')}');
    } else {
      print('${Ansi.yellow}⚠ JDK not found (Required for Android builds)${Ansi.reset}');
    }

    // iOS / macOS Toolchain
    if (Platform.isMacOS) {
      stdout.write('  Checking Xcode & CocoaPods... ');
      final xcodeRes = await Process.run('xcode-select', ['-p']);
      if (xcodeRes.exitCode == 0) {
        print('${Ansi.green}✔ OK${Ansi.reset}');
      } else {
        print('${Ansi.yellow}⚠ Xcode command line tools not found${Ansi.reset}');
      }
    }

    // Shorebird OTA CLI Check
    stdout.write('  Checking Shorebird CLI (OTA)... ');
    try {
      final shorebirdRes = await Process.run('shorebird', ['--version']);
      if (shorebirdRes.exitCode == 0) {
        final versionLine = shorebirdRes.stdout.toString().trim().split('\n').first;
        print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('($versionLine)')}');
      } else {
        print('${Ansi.dimText('ℹ Optional (run curl -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash)')}');
      }
    } catch (_) {
      print('${Ansi.dimText('ℹ Optional (run curl -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash)')}');
    }

    // Network Interface & Bloom Discovery Check
    stdout.write('  Checking Local Network Interfaces... ');
    final localIpResult = await MdnsDiscovery.getLocalIp();
    if (localIpResult.isLoopback) {
      print('${Ansi.yellow}⚠ Loopback only (${localIpResult.ip})${Ansi.reset}');
    } else {
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('(LAN IP: ${localIpResult.ip})')}');
    }

    // Container & Deployment Lifecycle Checks
    final deploymentChecker = const DeploymentDoctorChecker();
    final deployReport = await deploymentChecker.check(project: project);
    deploymentChecker.printReport(deployReport);
    if (!deployReport.isPassed) {
      allGood = false;
    }

    // System Information
    print(Ansi.boldText('\n💻 System Information\n'));

    stdout.write('  Checking Operating System... ');
    print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('(${Platform.operatingSystem}, ${Platform.operatingSystemVersion})')}');

    stdout.write('  Checking CPU Cores... ');
    print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('(${Platform.numberOfProcessors} cores)')}');

    stdout.write('  Checking Process Memory... ');
    final rssMb = (ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(1);
    print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('(current CLI process RSS: ${rssMb} MB)')}');

    stdout.write('  Checking Dart Executable... ');
    print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText('(${Platform.resolvedExecutable})')}');

    // Version Check
    print(Ansi.boldText('\n📦 Version Check\n'));
    await _checkBloomCliVersion();

    // Project-level diagnostic
    if (project != null) {
      print(Ansi.boldText('\n📁 Project Configuration (${project.projectName})'));

      if (project.bloomYamlFile.existsSync()) {
        final config = project.loadBloomConfig();
        print('  ${Ansi.green}✔ bloom.yaml valid${Ansi.reset} ${Ansi.dimText('(schema: ${config['schema'] ?? 1})')}');
      } else {
        print('  ${Ansi.red}✖ bloom.yaml missing${Ansi.reset}');
        allGood = false;
      }

      final envFile = File('${project.rootDir.path}/.env');
      if (envFile.existsSync()) {
        print('  ${Ansi.green}✔ .env file present${Ansi.reset}');
      } else {
        print('  ${Ansi.yellow}⚠ .env file missing (create a .env file in project root)${Ansi.reset}');
      }

      final routes = project.scanRoutes();
      print('  ${Ansi.green}✔ ${routes.length} filesystem route(s) discovered${Ansi.reset}');
      for (final r in routes) {
        print('    ${Ansi.dimText('• ${r.routePath} -> ${r.componentClassName} (${r.relativeFilePath})')}');
      }
    } else {
      print('\n${Ansi.dimText('(Not inside a Bloom project directory)')}');
    }

    print('');
    if (allGood) {
      print(Ansi.success('Environment is healthy and ready for Bloom development!\n'));
      return 0;
    } else {
      print(Ansi.warn('Some checks did not pass. Please resolve above items.\n'));
      return 1;
    }
  }

  Future<void> _checkBloomCliVersion() async {
    stdout.write('  Checking bloom_cli version... ');
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      try {
        final request = await client
            .getUrl(Uri.parse('https://pub.dev/api/packages/bloom_cli'))
            .timeout(const Duration(seconds: 3));
        final response = await request.close().timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final body = await response
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 3));
          final data = jsonDecode(body);
          if (data is Map<String, dynamic>) {
            final latest = data['latest'];
            if (latest is Map<String, dynamic>) {
              final latestVersion = latest['version'] as String?;
              if (latestVersion != null && latestVersion.isNotEmpty) {
                if (latestVersion == _bloomCliVersion) {
                  print('${Ansi.green}✔ Up to date${Ansi.reset} ${Ansi.dimText('(v$_bloomCliVersion)')}');
                } else {
                  print('${Ansi.yellow}⚠ Update available${Ansi.reset} ${Ansi.dimText('(installed v$_bloomCliVersion, latest v$latestVersion)')}');
                }
                return;
              }
            }
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
    print(Ansi.dimText('ℹ Unable to check for updates (offline or not published) (installed v$_bloomCliVersion)'));
  }

  Future<int> _runCiDoctor(BloomProject? project, Directory projectDir) async {
    print(Ansi.boldText('\n🤖 Bloom Continuous CI Health Agent\n'));

    if (project == null) {
      print(Ansi.error('✖ CI Check Failed: Not inside a valid Bloom project (${projectDir.path})\n'));
      return 1;
    }

    var ciFailed = false;

    // 1. Validate bloom.yaml
    if (!project.bloomYamlFile.existsSync()) {
      print(Ansi.error('✖ [CONFIG] Missing required bloom.yaml configuration file.'));
      ciFailed = true;
    } else {
      print(Ansi.success('✔ [CONFIG] Valid bloom.yaml configuration'));
    }

    // 2. Run Dependency Security Audit
    final auditReport = AuditCommand.runAudit(project);
    if (auditReport.hasVulnerabilities) {
      print(Ansi.error('✖ [SECURITY] Discovered ${auditReport.findings.length} vulnerable dependency advisory/advisories!'));
      ciFailed = true;
    } else {
      print(Ansi.success('✔ [SECURITY] Dependency audit clean (0 CVEs)'));
    }

    // 3. Run Secret Scanner
    final secretScanner = SecretScanner(project);
    final secretResult = secretScanner.scan();
    if (secretResult.hasSecrets) {
      print(Ansi.error('✖ [SECRETS] Exposed secret tokens or private keys detected in codebase!'));
      ciFailed = true;
    } else {
      print(Ansi.success('✔ [SECRETS] 0 exposed secret tokens found'));
    }

    // 4. Run Autolink & Duplicate Conflict Check
    try {
      final autolink = AutolinkEngine(project);
      autolink.discoverAllRequirements();
      final modules = autolink.detectConflicts();
      if (modules.isEmpty) {
        print(Ansi.success('✔ [AUTOLINK] Native module autolink verified with no version conflicts'));
      } else {
        for (final c in modules) {
          print(Ansi.error(
              '✖ [AUTOLINK] Duplicate native module "${c.moduleName}" with conflicting versions: ${c.conflictingVersions.join(', ')}'));
        }
        ciFailed = true;
      }
    } catch (e) {
      print(Ansi.error('✖ [AUTOLINK] Native module autolink failure: $e'));
      ciFailed = true;
    }

    // 5. Run Deployment Lifecycle Checks
    final deploymentChecker = const DeploymentDoctorChecker();
    final deployReport = await deploymentChecker.check(project: project, strictCi: true);
    if (!deployReport.isPassed) {
      for (final item in deployReport.items.where((i) => !i.isHealthy && !i.isWarning)) {
        print(Ansi.error('✖ [DEPLOY] ${item.title}: ${item.details}'));
        if (item.fixHint != null) {
          print('    ${Ansi.dimText(item.fixHint!)}');
        }
      }
      ciFailed = true;
    } else {
      print(Ansi.success('✔ [DEPLOY] Deployment configuration & container checks passed'));
    }

    print('');
    if (ciFailed) {
      print(Ansi.error('✖ Continuous CI Verification Failed! Please address above diagnostic errors.\n'));
      return 1;
    }

    print(Ansi.success('✔ Continuous CI Health Check Passed: 100% Healthy & Production-Ready!\n'));
    return 0;
  }
}
