// lib/src/commands/security_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../security/secret_scanner.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class SecurityCommand extends Command<int> {
  @override
  final String name = 'security';

  @override
  final String description = 'Security diagnostic, secret scanning, and token leak prevention.';

  SecurityCommand() {
    addSubcommand(_ScanSecurityCommand());
  }
}

class _ScanSecurityCommand extends Command<int> {
  @override
  final String name = 'scan';

  @override
  final String description =
      'Scans the workspace for exposed secrets, private keys, and API tokens.';

  _ScanSecurityCommand() {
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

    final scanner = SecretScanner(project);
    final result = scanner.scan();

    if (result.hasSecrets) {
      return 1;
    }
    return 0;
  }
}
