// lib/src/security/secret_scanner.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

class SecretFinding {
  final String filePath;
  final int lineNumber;
  final String ruleName;
  final String snippet;
  final String maskedSecret;

  SecretFinding({
    required this.filePath,
    required this.lineNumber,
    required this.ruleName,
    required this.snippet,
    required this.maskedSecret,
  });
}

class SecretScanResult {
  final List<SecretFinding> findings;
  final int scannedFilesCount;

  SecretScanResult({
    required this.findings,
    required this.scannedFilesCount,
  });

  bool get hasSecrets => findings.isNotEmpty;
}

class SecretPattern {
  final String name;
  final RegExp regex;

  const SecretPattern(this.name, this.regex);
}

/// Scans source code and configuration files for exposed secrets, tokens, and private keys.
class SecretScanner {
  final BloomProject project;

  static final List<SecretPattern> patterns = [
    SecretPattern('AWS Access Key ID', RegExp(r'\b(AKIA[0-9A-Z]{16})\b')),
    SecretPattern(
      'AWS Secret Access Key',
      RegExp(r'''aws(.{0,20})?(secret|key).{0,5}['"][0-9a-zA-Z\/+]{40}['"]''', caseSensitive: false),
    ),
    SecretPattern('Private Key Header', RegExp(r'-----BEGIN (?:RSA|EC|OPENSSH|DSA|PGP)? PRIVATE KEY-----')),
    SecretPattern('OpenAI / SaaS API Key', RegExp(r'\b(sk-[a-zA-Z0-9]{20,})\b')),
    SecretPattern('GitHub Personal Access Token', RegExp(r'\b(ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36})\b')),
    SecretPattern(
      'Hardcoded API Key / Secret Token',
      RegExp(r'''(api[_-]?key|secret[_-]?key|auth[_-]?token|bearer[_-]?token)\s*[:=]\s*['"][a-zA-Z0-9_\-\.]{16,}['"]''', caseSensitive: false),
    ),
    SecretPattern('JWT Token', RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}')),
  ];

  SecretScanner(this.project);

  /// Scans the project directory and returns all identified secret findings.
  SecretScanResult scan() {
    print(Ansi.boldText('\n🔑 Scanning codebase for hardcoded secrets, private keys, and API tokens...'));

    final filesToScan = _discoverFiles(project.rootDir);
    final findings = <SecretFinding>[];

    for (final file in filesToScan) {
      try {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final pattern in patterns) {
            final match = pattern.regex.firstMatch(line);
            if (match != null) {
              final rawSecret = match.group(0) ?? '';
              final masked = _mask(rawSecret);
              final relPath = p.relative(file.path, from: project.rootDir.path).replaceAll('\\', '/');

              findings.add(SecretFinding(
                filePath: relPath,
                lineNumber: i + 1,
                ruleName: pattern.name,
                snippet: line.trim(),
                maskedSecret: masked,
              ));
            }
          }
        }
      } on FileSystemException {
        // Skip unreadable files
      }
    }

    if (findings.isNotEmpty) {
      print(Ansi.error('\n✖ Exposed Secrets Detected! Found ${findings.length} secret finding(s):'));
      for (final f in findings) {
        print('  • [${f.ruleName}] at ${f.filePath}:${f.lineNumber}');
        print('    Line: ${f.snippet.length > 80 ? '${f.snippet.substring(0, 80)}...' : f.snippet}');
      }
      print('');
    } else {
      print(Ansi.success('✔ Clean! 0 hardcoded secrets or exposed private keys found across ${filesToScan.length} file(s).\n'));
    }

    return SecretScanResult(
      findings: findings,
      scannedFilesCount: filesToScan.length,
    );
  }

  List<File> _discoverFiles(Directory dir) {
    final list = <File>[];
    const excludedDirs = {
      '.git',
      '.dart_tool',
      'build',
      'node_modules',
      '.bloom',
      '.idea',
      '.vscode',
    };

    final entities = dir.listSync(recursive: true, followLinks: false);
    for (final e in entities) {
      if (e is File) {
        final rel = p.relative(e.path, from: dir.path);
        final parts = rel.split(p.separator);
        if (parts.any((part) => excludedDirs.contains(part))) {
          continue;
        }
        // Exclude common binary image/archive formats
        final ext = p.extension(e.path).toLowerCase();
        if (ext == '.png' ||
            ext == '.jpg' ||
            ext == '.jpeg' ||
            ext == '.webp' ||
            ext == '.zip' ||
            ext == '.so' ||
            ext == '.dylib' ||
            ext == '.dll') {
          continue;
        }
        list.add(e);
      }
    }
    return list..sort((a, b) => a.path.compareTo(b.path)); // Deterministic order
  }

  String _mask(String value) {
    if (value.length <= 6) return '******';
    final prefix = value.substring(0, 4);
    return '$prefix${'*' * (value.length - 4)}';
  }
}
