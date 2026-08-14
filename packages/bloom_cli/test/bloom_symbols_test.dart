// test/bloom_symbols_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/commands/symbols_command.dart';
import '../lib/src/symbolication/symbol_packager.dart';
import '../lib/src/utils/project.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_symbols_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 13: BloomSymbolPackager & Symbolication Manifest', () {
    test('Discovers Android ProGuard, iOS dSYM, and Web source maps, generates runtimeFingerprint, and creates zip bundle', () async {
      final appDir = Directory(p.join(tempDir.path, 'symbol_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: symbol_app
version: 1.5.0
build_number: "42"
''');

      // 1. Mock Android mapping.txt
      final mappingDir = Directory(p.join(appDir.path, 'android', 'app', 'build', 'outputs', 'mapping', 'release'))
        ..createSync(recursive: true);
      File(p.join(mappingDir.path, 'mapping.txt')).writeAsStringSync('com.example.App -> a.b.c:\n');

      // 2. Mock iOS dSYM bundle with multiple files to verify path binding and sorting
      final dsymDir = Directory(p.join(appDir.path, 'build', 'ios', 'Runner.app.dSYM', 'Contents', 'Resources', 'DWARF'))
        ..createSync(recursive: true);
      File(p.join(dsymDir.path, 'Runner')).writeAsStringSync('DWARF_BINARY_MOCK_DATA');
      File(p.join(appDir.path, 'build', 'ios', 'Runner.app.dSYM', 'Contents', 'Info.plist'))
        ..writeAsStringSync('<plist></plist>');

      // 3. Mock Web source map
      final webDir = Directory(p.join(appDir.path, 'build', 'web'))..createSync(recursive: true);
      File(p.join(webDir.path, 'main.dart.js.map')).writeAsStringSync('{"version":3,"sources":[]}');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final packager = BloomSymbolPackager(project: project);
      final symbols = packager.discoverSymbols();

      expect(symbols.length, 3);
      expect(symbols.any((s) => s.platform == 'android' && s.type == 'proguard'), isTrue);
      expect(symbols.any((s) => s.platform == 'ios' && s.type == 'dsym'), isTrue);
      expect(symbols.any((s) => s.platform == 'web' && s.type == 'sourcemap'), isTrue);

      final dsymArtifact = symbols.firstWhere((s) => s.type == 'dsym');
      expect(dsymArtifact.sha256Hash.isNotEmpty, isTrue);

      final manifestFile = await packager.packageSymbols();
      expect(manifestFile.existsSync(), isTrue);

      final manifestJson = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(manifestJson['appName'], 'symbol_app');
      expect(manifestJson['version'], '1.5.0');
      expect(manifestJson['buildNumber'], '42');
      expect(manifestJson['runtimeFingerprint'], isNotEmpty);
      expect((manifestJson['artifacts'] as List).length, 3);

      // Check zip archive was created and contains manifest and artifacts
      final zipFile = packager.getSymbolsZipFile('1.5.0', '42');
      expect(zipFile.existsSync(), isTrue);
      final zipBytes = zipFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      expect(archive.files.any((f) => f.name == 'manifest.json'), isTrue);
      expect(archive.files.any((f) => f.name.contains('mapping.txt')), isTrue);
    });
  });

  group('Phase 13: CLI SymbolsCommand Execution', () {
    test('bloom symbols package and bloom symbols upload execute cleanly with multipart payload', () async {
      final appDir = Directory(p.join(tempDir.path, 'cli_symbols_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: cli_symbols_app\nversion: 1.0.0\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(SymbolsCommand());

      final packageExit = await runner.run([
        'symbols',
        'package',
        '--project-dir=${appDir.path}',
      ]);
      expect(packageExit, 0);

      // Start local mock telemetry server for upload testing
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      late String receivedContentType;
      late String receivedUserAgent;
      late List<int> allBytes;

      server.listen((HttpRequest req) async {
        receivedUserAgent = req.headers.value('user-agent') ?? '';
        receivedContentType = req.headers.contentType.toString();
        allBytes = await req.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
        req.response.statusCode = 200;
        req.response.write('{"status": "ok"}');
        await req.response.close();
      });

      final uploadExit = await runner.run([
        'symbols',
        'upload',
        '--project-dir=${appDir.path}',
        '--endpoint=http://${server.address.host}:${server.port}/upload',
      ]);
      expect(uploadExit, 0);
      expect(receivedUserAgent, 'Bloom-CLI/1.0');
      expect(receivedContentType, contains('multipart/form-data'));
      final decodedBody = utf8.decode(allBytes, allowMalformed: true);
      expect(decodedBody, contains('cli_symbols_app'));
      expect(decodedBody, contains('runtimeFingerprint'));

      await server.close();
    });

    test('bloom symbols upload returns error code 1 on 4xx/5xx HTTP rejection', () async {
      final appDir = Directory(p.join(tempDir.path, 'cli_symbols_err'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: cli_symbols_err\nversion: 1.0.0\n');

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(SymbolsCommand());

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest req) async {
        await req.drain<void>();
        req.response.statusCode = 500;
        req.response.write('{"error": "Internal server error"}');
        await req.response.close();
      });

      final uploadExit = await runner.run([
        'symbols',
        'upload',
        '--project-dir=${appDir.path}',
        '--endpoint=http://${server.address.host}:${server.port}/upload',
      ]);
      expect(uploadExit, 1);

      await server.close();
    });
  });
}
