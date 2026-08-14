// lib/src/commands/doctor_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../dev/mdns_discovery.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class DoctorCommand extends Command<int> {
  @override
  final String name = 'doctor';
  @override
  final String description = 'Validates environment, toolchain, and project configuration.';

  @override
  Future<int> run() async {
    print(Ansi.boldText('\n🩺 Bloom Diagnostic System Health Check\n'));

    bool allGood = true;

    // 1. Dart SDK Check
    stdout.write('  Checking Dart SDK... ');
    final dartRes = await Process.run('dart', ['--version']);
    if (dartRes.exitCode == 0 || dartRes.stderr.toString().contains('Dart SDK version')) {
      final out = dartRes.stdout.toString().isNotEmpty
          ? dartRes.stdout.toString().trim()
          : dartRes.stderr.toString().trim();
      final firstLine = out.split('\n').first;
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dim}($firstLine)${Ansi.reset}');
    } else {
      print('${Ansi.red}✖ Missing${Ansi.reset}');
      allGood = false;
    }

    // 2. Flutter SDK Check
    stdout.write('  Checking Flutter SDK... ');
    final flutterRes = await Process.run('flutter', ['--version']);
    if (flutterRes.exitCode == 0) {
      final out = flutterRes.stdout.toString().trim();
      final firstLine = out.split('\n').first;
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dim}($firstLine)${Ansi.reset}');
    } else {
      print('${Ansi.red}✖ Missing${Ansi.reset}');
      allGood = false;
    }

    // 3. Android SDK / Java Check
    stdout.write('  Checking Android Toolchain / Java... ');
    final javaRes = await Process.run('java', ['-version']);
    final androidHome = Platform.environment['ANDROID_HOME'] ?? Platform.environment['ANDROID_SDK_ROOT'];
    if (javaRes.exitCode == 0) {
      final sdkStatus = androidHome != null ? 'SDK: $androidHome' : 'Java present';
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dim}($sdkStatus)${Ansi.reset}');
    } else {
      print('${Ansi.yellow}⚠ JDK not found (Required for Android builds)${Ansi.reset}');
    }

    // 4. iOS / macOS Toolchain (if running on macOS)
    if (Platform.isMacOS) {
      stdout.write('  Checking Xcode & CocoaPods... ');
      final xcodeRes = await Process.run('xcode-select', ['-p']);
      if (xcodeRes.exitCode == 0) {
        print('${Ansi.green}✔ OK${Ansi.reset}');
      } else {
        print('${Ansi.yellow}⚠ Xcode command line tools not found${Ansi.reset}');
      }
    }

    // 5. Shorebird OTA CLI Check
    stdout.write('  Checking Shorebird CLI (OTA)... ');
    try {
      final shorebirdRes = await Process.run('shorebird', ['--version']);
      if (shorebirdRes.exitCode == 0) {
        final versionLine = shorebirdRes.stdout.toString().trim().split('\n').first;
        print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dim}($versionLine)${Ansi.reset}');
      } else {
        print('${Ansi.dim}ℹ Optional (run curl -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash)${Ansi.reset}');
      }
    } catch (_) {
      print('${Ansi.dim}ℹ Optional (run curl -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash)${Ansi.reset}');
    }

    // 6. Network Interface & Bloom Discovery Check
    stdout.write('  Checking Local Network Interfaces... ');
    final localIpResult = await MdnsDiscovery.getLocalIp();
    if (localIpResult.isLoopback) {
      print('${Ansi.yellow}⚠ Loopback only (${localIpResult.ip})${Ansi.reset}');
    } else {
      print('${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dim}(LAN IP: ${localIpResult.ip})${Ansi.reset}');
    }

    // 7. Project-level diagnostic (if executed inside a Bloom app)
    final project = BloomProject.find();
    if (project != null) {
      print(Ansi.boldText('\n📁 Project Configuration (${project.projectName})'));
      
      // bloom.yaml
      if (project.bloomYamlFile.existsSync()) {
        final config = project.loadBloomConfig();
        print('  ${Ansi.green}✔ bloom.yaml valid${Ansi.reset} ${Ansi.dim}(schema: ${config['schema'] ?? 1})${Ansi.reset}');
      } else {
        print('  ${Ansi.red}✖ bloom.yaml missing${Ansi.reset}');
        allGood = false;
      }

      // .env
      final envFile = File('${project.rootDir.path}/.env');
      if (envFile.existsSync()) {
        print('  ${Ansi.green}✔ .env file present${Ansi.reset}');
      } else {
        print('  ${Ansi.yellow}⚠ .env file missing (run `bloom generate env`)${Ansi.reset}');
      }

      // routes
      final routes = project.scanRoutes();
      print('  ${Ansi.green}✔ ${routes.length} filesystem route(s) discovered${Ansi.reset}');
      for (final r in routes) {
        print('    ${Ansi.dim}• ${r.routePath} -> ${r.componentClassName} (${r.relativeFilePath})${Ansi.reset}');
      }
    } else {
      print('\n${Ansi.dim}(Not inside a Bloom project directory)${Ansi.reset}');
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
}
