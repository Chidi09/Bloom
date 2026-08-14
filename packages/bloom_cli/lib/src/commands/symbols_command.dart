// lib/src/commands/symbols_command.dart
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../symbolication/symbol_packager.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class SymbolsCommand extends Command<int> {
  @override
  final String name = 'symbols';

  @override
  final String description =
      'Manage crash symbolication artifacts, dSYM, ProGuard mappings, and source maps.';

  SymbolsCommand() {
    addSubcommand(_PackageSymbolsCommand());
    addSubcommand(_UploadSymbolsCommand());
  }
}

class _PackageSymbolsCommand extends Command<int> {
  @override
  final String name = 'package';

  @override
  final String description =
      'Discovers and packages ProGuard, dSYM, and web source maps into a symbol manifest.';

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
  final String description =
      'Uploads symbol artifacts to the Bloom Observability Telemetry endpoint.';

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
    final endpoint =
        argResults?['endpoint'] as String? ?? 'https://telemetry.bloom.dev/symbols/upload';

    final project = BloomProject.find(projectDir);
    if (project == null) {
      print(Ansi.error('✖ Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }
    final packager = BloomSymbolPackager(project: project);
    final manifestFile = await packager.packageSymbols();
    final manifestJson = manifestFile.readAsStringSync();
    final manifestMap = jsonDecode(manifestJson) as Map<String, dynamic>;

    final version = manifestMap['version']?.toString() ?? '1.0.0';
    final buildNumber = manifestMap['buildNumber']?.toString() ?? '1';
    final zipFile = packager.getSymbolsZipFile(version, buildNumber);

    print(Ansi.boldText('🚀 Uploading symbol manifest and package to $endpoint...'));
    print('  Manifest: ${manifestFile.path} (${manifestFile.lengthSync()} bytes)');
    if (zipFile.existsSync()) {
      print('  Package:  ${zipFile.path} (${zipFile.lengthSync()} bytes)');
    }

    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));
      request.headers['user-agent'] = 'Bloom-CLI/1.0';

      request.fields['appName'] = manifestMap['appName']?.toString() ?? '';
      request.fields['version'] = version;
      request.fields['buildNumber'] = buildNumber;
      request.fields['runtimeFingerprint'] = manifestMap['runtimeFingerprint']?.toString() ?? '';
      request.fields['manifest'] = manifestJson;

      if (zipFile.existsSync()) {
        final zipBytes = zipFile.readAsBytesSync();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          zipBytes,
          filename: '${version}_${buildNumber}_symbols.zip',
          contentType: MediaType('application', 'zip'),
        ));
      }

      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print(Ansi.success('✔ Symbols uploaded successfully to Bloom Observability!'));
        return 0;
      } else {
        print(Ansi.error('✖ Upload failed: HTTP ${response.statusCode} - ${response.body}'));
        return 1;
      }
    } catch (e) {
      print(Ansi.error('✖ Upload failed: $e'));
      return 1;
    } finally {
      client.close();
    }
  }
}
