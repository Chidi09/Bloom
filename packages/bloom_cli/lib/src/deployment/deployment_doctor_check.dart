// lib/src/deployment/deployment_doctor_check.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'deployment_target_detector.dart';

class DeploymentDoctorItem {
  final String title;
  final bool isHealthy;
  final bool isWarning;
  final String details;
  final String? fixHint;

  const DeploymentDoctorItem({
    required this.title,
    required this.isHealthy,
    this.isWarning = false,
    required this.details,
    this.fixHint,
  });
}

class DeploymentDoctorReport {
  final List<DeploymentDoctorItem> items;
  final bool isPassed;
  final BloomTargetDetectionResult? detectionResult;

  const DeploymentDoctorReport({
    required this.items,
    required this.isPassed,
    this.detectionResult,
  });
}

/// Validates Docker toolchain, target prerequisites, and environment security.
class DeploymentDoctorChecker {
  const DeploymentDoctorChecker();

  Future<DeploymentDoctorReport> check({
    BloomProject? project,
    bool strictCi = false,
  }) async {
    final items = <DeploymentDoctorItem>[];
    var isPassed = true;

    // 1. Docker CLI Check
    try {
      final dockerRes = await Process.run('docker', ['--version']);
      if (dockerRes.exitCode == 0) {
        final versionLine =
            dockerRes.stdout.toString().trim().split('\n').first;
        items.add(DeploymentDoctorItem(
          title: 'Docker Engine CLI',
          isHealthy: true,
          details: versionLine,
        ));
      } else {
        if (strictCi) isPassed = false;
        items.add(DeploymentDoctorItem(
          title: 'Docker Engine CLI',
          isHealthy: false,
          isWarning: !strictCi,
          details: 'Docker CLI not found on PATH.',
          fixHint: 'Install Docker from https://docs.docker.com/get-docker/',
        ));
      }
    } catch (_) {
      if (strictCi) isPassed = false;
      items.add(DeploymentDoctorItem(
        title: 'Docker Engine CLI',
        isHealthy: false,
        isWarning: !strictCi,
        details: 'Docker CLI not available or not installed.',
        fixHint: 'Install Docker from https://docs.docker.com/get-docker/',
      ));
    }

    // 2. Docker Compose Check
    try {
      var composeRes = await Process.run('docker', ['compose', 'version']);
      if (composeRes.exitCode != 0) {
        composeRes = await Process.run('docker-compose', ['--version']);
      }
      if (composeRes.exitCode == 0) {
        final versionLine =
            composeRes.stdout.toString().trim().split('\n').first;
        items.add(DeploymentDoctorItem(
          title: 'Docker Compose',
          isHealthy: true,
          details: versionLine,
        ));
      } else {
        items.add(const DeploymentDoctorItem(
          title: 'Docker Compose',
          isHealthy: false,
          isWarning: true,
          details: 'Compose plugin not detected.',
          fixHint:
              'Install Compose via docker-compose-plugin or docker-compose binary.',
        ));
      }
    } catch (_) {
      items.add(const DeploymentDoctorItem(
        title: 'Docker Compose',
        isHealthy: false,
        isWarning: true,
        details: 'Compose plugin not detected.',
        fixHint:
            'Install Compose via docker-compose-plugin or docker-compose binary.',
      ));
    }

    BloomTargetDetectionResult? detection;

    // 3. Project-specific checks
    if (project != null) {
      final detector = const BloomDeploymentTargetDetector();
      detection = detector.detect(project);

      items.add(DeploymentDoctorItem(
        title: 'Application Target',
        isHealthy: true,
        details: '${detection.target.displayName} (${detection.target.id})',
      ));

      // Check Target Prerequisites
      if (detection.target == BloomDeploymentTarget.server) {
        final serverFile =
            File(p.join(project.rootDir.path, 'bin', 'server.dart'));
        if (serverFile.existsSync()) {
          items.add(const DeploymentDoctorItem(
            title: 'Server Entrypoint',
            isHealthy: true,
            details: 'bin/server.dart present',
          ));
        } else {
          isPassed = false;
          items.add(const DeploymentDoctorItem(
            title: 'Server Entrypoint',
            isHealthy: false,
            details:
                'Missing required bin/server.dart entrypoint for server deployment.',
            fixHint: 'Run "bloom server create" or create bin/server.dart.',
          ));
        }
      }

      // Check .dockerignore for secret leak protection
      final dockerignoreFile =
          File(p.join(project.rootDir.path, '.dockerignore'));
      if (dockerignoreFile.existsSync()) {
        final content = dockerignoreFile.readAsStringSync();
        final ignoresEnv =
            content.contains('.env') || content.contains('.env*');
        if (ignoresEnv) {
          items.add(const DeploymentDoctorItem(
            title: 'Docker Secret Protection',
            isHealthy: true,
            details:
                '.dockerignore properly excludes .env secrets from container builds',
          ));
        } else {
          if (strictCi) isPassed = false;
          items.add(DeploymentDoctorItem(
            title: 'Docker Secret Protection',
            isHealthy: false,
            isWarning: !strictCi,
            details:
                '.dockerignore does not explicitly exclude .env files! Secrets may leak into Docker image layers.',
            fixHint:
                'Add .env to .dockerignore or run "bloom deploy docker" to generate a secure .dockerignore.',
          ));
        }
      } else {
        items.add(const DeploymentDoctorItem(
          title: 'Docker Configuration',
          isHealthy: false,
          isWarning: true,
          details: 'No .dockerignore found in project root.',
          fixHint:
              'Run "bloom deploy docker" to generate production container files.',
        ));
      }

      // Check environment templates
      final envExample = File(p.join(project.rootDir.path, '.env.example'));
      if (envExample.existsSync()) {
        items.add(const DeploymentDoctorItem(
          title: 'Environment Template',
          isHealthy: true,
          details: '.env.example template present',
        ));
      } else {
        items.add(const DeploymentDoctorItem(
          title: 'Environment Template',
          isHealthy: false,
          isWarning: true,
          details: '.env.example template is missing.',
          fixHint: 'Run "bloom deploy init" to scaffold .env.example.',
        ));
      }

      // Check ports
      final config = project.loadBloomConfig();
      final portVal = config['port'] ?? Platform.environment['PORT'] ?? '8080';
      final port = int.tryParse(portVal.toString());
      if (port != null && port >= 1 && port <= 65535) {
        items.add(DeploymentDoctorItem(
          title: 'Port Configuration',
          isHealthy: true,
          details: 'Port $port configured and valid',
        ));
      } else {
        items.add(DeploymentDoctorItem(
          title: 'Port Configuration',
          isHealthy: false,
          isWarning: true,
          details: 'Invalid port value "$portVal".',
          fixHint: 'Configure a valid TCP port between 1 and 65535.',
        ));
      }
    }

    return DeploymentDoctorReport(
      items: items,
      isPassed: isPassed,
      detectionResult: detection,
    );
  }

  void printReport(DeploymentDoctorReport report) {
    print(Ansi.boldText('\n🐳 Container & Deployment Lifecycle Checks\n'));
    for (final item in report.items) {
      stdout.write('  Checking ${item.title}... ');
      if (item.isHealthy) {
        print(
            '${Ansi.green}✔ OK${Ansi.reset} ${Ansi.dimText("(${item.details})")}');
      } else if (item.isWarning) {
        print(
            '${Ansi.yellow}⚠ Warning${Ansi.reset} ${Ansi.dimText("(${item.details})")}');
        if (item.fixHint != null) {
          print('    ${Ansi.dimText("› ${item.fixHint}")}');
        }
      } else {
        print(
            '${Ansi.red}✖ Failed${Ansi.reset} ${Ansi.dimText("(${item.details})")}');
        if (item.fixHint != null) {
          print('    ${Ansi.cyan}› Fix: ${item.fixHint}${Ansi.reset}');
        }
      }
    }
  }
}
