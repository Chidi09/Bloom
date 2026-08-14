// lib/src/commands/audit_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../security/license_checker.dart';
import '../security/vulnerability_db.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class AuditFinding {
  final String package;
  final String version;
  final PackageVulnerability vulnerability;

  AuditFinding({
    required this.package,
    required this.version,
    required this.vulnerability,
  });
}

class AuditReport {
  final List<AuditFinding> findings;
  final List<PackageLicenseResult> licenses;
  final int totalScannedPackages;

  AuditReport({
    required this.findings,
    required this.licenses,
    required this.totalScannedPackages,
  });

  bool get hasVulnerabilities => findings.isNotEmpty;
  int get criticalCount =>
      findings.where((f) => f.vulnerability.severity == VulnerabilitySeverity.critical).length;
  int get highCount =>
      findings.where((f) => f.vulnerability.severity == VulnerabilitySeverity.high).length;
}

class AuditCommand extends Command<int> {
  @override
  final String name = 'audit';

  @override
  final String description =
      'Scans Dart and native dependencies for known CVE vulnerabilities and license compliance risks.';

  final VulnerabilityDatabase? customDb;

  AuditCommand({this.customDb}) {
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
    if (project == null) {
      print(Ansi.error('✖ Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }

    final report = runAudit(project, db: customDb);

    print(Ansi.boldText('\n🛡️ Bloom Security Diagnostic\n'));

    if (report.findings.isNotEmpty) {
      print(Ansi.error('✖ Discovered ${report.findings.length} Vulnerability Advisory Finding(s):'));
      for (final finding in report.findings) {
        final v = finding.vulnerability;
        final severityStr = '[${v.severity.name.toUpperCase()}]';
        print('  • $severityStr ${v.cveId}: package "${finding.package}" (v${finding.version})');
        print('    Title: ${v.title}');
        print('    Remediation: Upgrade "${finding.package}" to >= ${v.fixedVersion}\n');
      }

      print(Ansi.error('✖ Security Audit Failed: ${report.criticalCount} Critical, ${report.highCount} High vulnerabilities detected.\n'));
      return 1;
    }

    final unknownLicenseCount =
        report.licenses.where((l) => l.riskLevel == LicenseRiskLevel.unknown).length;
    final copyleftCount = report.licenses
        .where((l) => l.riskLevel == LicenseRiskLevel.weakCopyleft || l.riskLevel == LicenseRiskLevel.strongCopyleft)
        .length;

    print(Ansi.success('✔ 0 Critical Vulnerabilities'));
    print(Ansi.success('✔ 0 High Severity CVEs'));
    print(Ansi.success('✔ ${unknownLicenseCount} package(s) with unknown license, ${copyleftCount} copyleft'));
    print(Ansi.success('✔ ${report.totalScannedPackages} package(s) scanned for CVEs\n'));

    return 0;
  }

  static AuditReport runAudit(BloomProject project, {VulnerabilityDatabase? db}) {
    final database = db ?? VulnerabilityDatabase();
    final lockFile = File(p.join(project.rootDir.path, 'pubspec.lock'));
    final findings = <AuditFinding>[];
    final licenses = <PackageLicenseResult>[];
    var scannedCount = 0;

    if (lockFile.existsSync()) {
      try {
        final yaml = loadYaml(lockFile.readAsStringSync());
        if (yaml is YamlMap && yaml['packages'] is YamlMap) {
          final pkgs = yaml['packages'] as YamlMap;
          for (final nameKey in pkgs.keys) {
            final pkgName = nameKey.toString();
            final pkgData = pkgs[nameKey];
            if (pkgData is YamlMap && pkgData['version'] != null) {
              final versionStr = pkgData['version'].toString();
              scannedCount++;

              final vulns = database.scanPackage(pkgName, versionStr);
              for (final vuln in vulns) {
                findings.add(AuditFinding(
                  package: pkgName,
                  version: versionStr,
                  vulnerability: vuln,
                ));
              }

              // pubspec.lock does not record licenses; the raw license text is
              // unavailable, so report as Unknown rather than fabricating 'MIT'.
              licenses.add(LicenseChecker.evaluate(pkgName, ''));
            }
          }
        }
      } catch (e, stack) {
        stderr.writeln('bloom audit: Failed to parse pubspec.lock: $e');
        stderr.writeln(stack);
      }
    }

    return AuditReport(
      findings: findings,
      licenses: licenses,
      totalScannedPackages: scannedCount,
    );
  }
}
