// lib/src/commands/symbols_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../symbolication/symbol_packager.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class SymbolsCommand extends Command<int> {
  @override
  final String name = 'symbols';

  @override
  final String description = 'Manage crash symbolication artifacts, dSYM, ProGuard mappings, and source maps.';

  SymbolsCommand() {
    addSubcommand(_PackageSymbolsCommand());
    addSubcommand(_UploadSymbolsCommand());
  }
}

class _PackageSymbolsCommand extends Command<int> {
  @override
  final String name = 'package';

  @override
  final String description = 'Discovers and packages ProGuard, dSYM, and web source maps into a symbol manifest.';

  _PackageSymbolsCommand() {
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
    final packager = BloomSymbolPackager(project: project);
    await packager.packageSymbols();
    return 0;
  }
}

class _UploadSymbolsCommand extends Command<int> {
  @override
  final String name = 'upload';

  @override
  final String description = 'Uploads symbol artifacts to the Bloom Observability Telemetry endpoint.';

  _UploadSymbolsCommand() {
    argParser
      ..addOption(
        'project-dir',
        help: 'Explicit path to the Bloom project directory.',
      )
      ..addOption(
        'endpoint',
        help: 'Telemetry symbol ingestion endpoint URL.',
        defaultsTo: 'https://telemetry.bloom.dev/symbols/upload',
      );
  }

  @override
  Future<int> run() async {
    final projectDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : Directory.current;
    final endpoint = argResults?['endpoint'] as String? ?? 'https://telemetry.bloom.dev/symbols/upload';

    final project = BloomProject.find(projectDir);
    if (project == null) {
      print(Ansi.error('✖ Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }
    final packager = BloomSymbolPackager(project: project);
    final manifestFile = await packager.packageSymbols();

    print(Ansi.boldText('🚀 Uploading symbol manifest to $endpoint...'));
    print('  Manifest: ${manifestFile.path} (${manifestFile.lengthSync()} bytes)');

    final manifestBytes = manifestFile.readAsBytesSync();
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(endpoint));
      req.headers.contentType = ContentType.json;
      req.headers.set('user-agent', 'Bloom-CLI/1.0');
      req.add(manifestBytes);
      final res = await req.close();
      if (res.statusCode >= 400) {
        print(Ansi.error('✖ Upload failed: HTTP ${res.statusCode}'));
        return 1;
      }
    } catch (e) {
      print(Ansi.error('✖ Upload failed: $e'));
      return 1;
    } finally {
      client.close();
    }

    print(Ansi.success('✔ Symbols uploaded successfully to Bloom Observability!'));
    return 0;
  }
}
