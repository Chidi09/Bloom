import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../npm/npm_vendor_assembler.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Top-level command `bloom js` for Bloom JS Native web apps.
class JsCommand extends Command<int> {
  @override
  final String name = 'js';

  @override
  final String description =
      'Build, develop, and vendor Bloom JS Native fine-grained web applications.';

  JsCommand() {
    addSubcommand(JsDevCommand());
    addSubcommand(JsBuildCommand());
    addSubcommand(JsVendorCommand());
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}

/// `bloom js dev` — starts hot live-reloading dev server.
class JsDevCommand extends Command<int> {
  @override
  final String name = 'dev';

  @override
  final String description =
      'Starts the native Bloom JS dev server with live reload and automatic compilation.';

  JsDevCommand() {
    argParser
      ..addOption(
        'port',
        abbr: 'p',
        defaultsTo: '8080',
        help: 'Port to bind development server.',
      )
      ..addOption(
        'entry',
        abbr: 'e',
        help: 'Custom entry point Dart file.',
      )
      ..addOption(
        'host',
        defaultsTo: '0.0.0.0',
        help: 'Host interface to bind.',
      );
  }

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory tree.'));
      return 1;
    }

    final port = int.tryParse(argResults?['port'] ?? '8080') ?? 8080;
    final host = argResults?['host'] ?? '0.0.0.0';

    // 1. Sync NPM vendors
    final assembler = NpmVendorAssembler(project);
    await assembler.assemble();

    // 2. Locate entry and web root
    final webDir = Directory(p.join(project.rootDir.path, 'web')).existsSync()
        ? Directory(p.join(project.rootDir.path, 'web'))
        : Directory(p.join(project.rootDir.path, 'example'));

    final entryFile = argResults?['entry'] != null
        ? File(argResults!['entry'])
        : (File(p.join(project.rootDir.path, 'lib', 'main.dart')).existsSync()
            ? File(p.join(project.rootDir.path, 'lib', 'main.dart'))
            : File(p.join(project.rootDir.path, 'example', 'main.dart')));

    final outputFile = File(p.join(webDir.path, 'main.js'));

    // 3. Initial Compile
    await _compile(entryFile, outputFile);

    // 4. Start Native Pure-Dart Static & SPA Server
    final server = await HttpServer.bind(host, port);
    print(Ansi.step('\n⚡ Bloom JS Native Dev Server active on http://$host:$port'));
    print(Ansi.info('› Serving static assets from ${webDir.path}'));
    print(Ansi.boldText('› Watching for file changes in ${project.rootDir.path}/lib... (Ctrl+C to stop)\n'));

    // 5. Watch for Dart file changes and auto-recompile
    final watchDir = Directory(p.join(project.rootDir.path, 'lib'));
    if (watchDir.existsSync()) {
      Timer? debounce;
      watchDir.watch(recursive: true).listen((event) {
        if (event.path.endsWith('.dart')) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 300), () async {
            print(Ansi.info('\n🔄 File change detected: ${p.basename(event.path)} — Recompiling...'));
            await _compile(entryFile, outputFile);
          });
        }
      });
    }

    // 6. Handle HTTP Requests
    await for (final request in server) {
      _handleRequest(request, webDir);
    }

    return 0;
  }

  Future<void> _compile(File entryFile, File outputFile) async {
    final sw = Stopwatch()..start();
    final compileRes = await Process.run('dart', [
      'compile',
      'js',
      '-O1',
      '-o',
      outputFile.path,
      entryFile.path,
    ]);
    sw.stop();

    if (compileRes.exitCode != 0) {
      print(Ansi.error('✖ Compilation failed:\n${compileRes.stderr}'));
    } else {
      final sizeKb = (outputFile.lengthSync() / 1024).toStringAsFixed(1);
      print(Ansi.success('✓ Compiled main.js ($sizeKb kB) in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s'));
    }
  }

  void _handleRequest(HttpRequest req, Directory webDir) async {
    try {
      var reqPath = req.uri.path;
      if (reqPath.startsWith('/')) reqPath = reqPath.substring(1);
      if (reqPath.isEmpty) reqPath = 'index.html';

      var targetPath = p.canonicalize(p.join(webDir.path, reqPath));

      if (p.isWithin(webDir.path, targetPath) || targetPath == p.canonicalize(webDir.path)) {
        var targetFile = File(targetPath);
        if (targetFile.existsSync() && !FileSystemEntity.isDirectorySync(targetFile.path)) {
          final bytes = targetFile.readAsBytesSync();
          final ext = targetFile.path.split('.').last.toLowerCase();
          req.response.headers.set(HttpHeaders.contentTypeHeader, _getContentType(ext));
          req.response.headers.set('Cache-Control', 'no-cache');
          req.response.add(bytes);
          await req.response.close();
          return;
        }

        // SPA Fallback to index.html
        final indexFile = File(p.join(webDir.path, 'index.html'));
        if (indexFile.existsSync()) {
          final bytes = indexFile.readAsBytesSync();
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
          req.response.headers.set('Cache-Control', 'no-cache');
          req.response.add(bytes);
          await req.response.close();
          return;
        }
      }

      req.response.statusCode = HttpStatus.notFound;
      req.response.write('404 Not Found');
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  String _getContentType(String ext) {
    switch (ext) {
      case 'html': return 'text/html; charset=utf-8';
      case 'js': return 'application/javascript; charset=utf-8';
      case 'css': return 'text/css; charset=utf-8';
      case 'json': return 'application/json; charset=utf-8';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'svg': return 'image/svg+xml';
      case 'ico': return 'image/x-icon';
      case 'wasm': return 'application/wasm';
      default: return 'application/octet-stream';
    }
  }
}

/// `bloom js build` — compiles optimized production JS bundle.
class JsBuildCommand extends Command<int> {
  @override
  final String name = 'build';

  @override
  final String description =
      'Compiles an optimized production JavaScript bundle with optional budget analysis.';

  JsBuildCommand() {
    argParser
      ..addFlag(
        'analyze',
        abbr: 'a',
        defaultsTo: false,
        help: 'Generates detailed bytes-per-dependency and gzip budget report.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output JavaScript file path.',
      );
  }

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory tree.'));
      return 1;
    }

    final entryFile = File(p.join(project.rootDir.path, 'lib', 'main.dart')).existsSync()
        ? File(p.join(project.rootDir.path, 'lib', 'main.dart'))
        : File(p.join(project.rootDir.path, 'example', 'main.dart'));

    final webDir = Directory(p.join(project.rootDir.path, 'web')).existsSync()
        ? Directory(p.join(project.rootDir.path, 'web'))
        : Directory(p.join(project.rootDir.path, 'example'));

    final targetOutput = argResults?['output'] != null
        ? File(argResults!['output'])
        : File(p.join(webDir.path, 'main.js'));

    print(Ansi.step('\n🏗  Compiling Bloom JS Native production bundle (O4)...\n'));

    // Vendor sync
    final assembler = NpmVendorAssembler(project);
    await assembler.assemble();

    final stopwatch = Stopwatch()..start();
    final res = await Process.run('dart', [
      'compile',
      'js',
      '-O4',
      '-o',
      targetOutput.path,
      entryFile.path,
    ]);
    stopwatch.stop();

    if (res.exitCode != 0) {
      print(Ansi.error('Build failed:\n${res.stderr}'));
      return 1;
    }

    final sizeBytes = targetOutput.existsSync() ? targetOutput.lengthSync() : 0;
    final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);
    final gzipEstimateKb = (sizeBytes * 0.25 / 1024).toStringAsFixed(1);

    print(Ansi.success('✓ Build completed in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s: ${targetOutput.path} ($sizeKb kB)'));

    if (argResults?['analyze'] == true) {
      print('\n' + Ansi.boldText('📊 Bloom JS Native — Bundle Analysis Report'));
      print('┌────────────────────────────────────────┬──────────────┬──────────────┐');
      print('│ Asset                                  │ Raw Size     │ Gzip (est)   │');
      print('├────────────────────────────────────────┼──────────────┼──────────────┤');
      print('│ ${p.basename(targetOutput.path).padRight(38)} │ ${(sizeKb + ' kB').padRight(12)} │ ${(gzipEstimateKb + ' kB').padRight(12)} │');

      // Check vendor directory
      final vendorDir = Directory(p.join(webDir.path, 'vendor'));
      if (vendorDir.existsSync()) {
        for (final file in vendorDir.listSync().whereType<File>()) {
          if (file.path.endsWith('.js')) {
            final vBytes = file.lengthSync();
            final vKb = (vBytes / 1024).toStringAsFixed(1);
            final vGzipKb = (vBytes * 0.28 / 1024).toStringAsFixed(1);
            print('│ ${('vendor/' + p.basename(file.path)).padRight(38)} │ ${(vKb + ' kB').padRight(12)} │ ${(vGzipKb + ' kB').padRight(12)} │');
          }
        }
      }
      print('└────────────────────────────────────────┴──────────────┴──────────────┘\n');
    }

    return 0;
  }
}

/// `bloom js vendor` — snapshots NPM dependencies via Bun or ESM CDN.
class JsVendorCommand extends Command<int> {
  @override
  final String name = 'vendor';

  @override
  final String description =
      'Syncs and snapshots NPM dependencies into web/vendor/ using Bun or ESM CDN.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory tree.'));
      return 1;
    }

    final assembler = NpmVendorAssembler(project);
    await assembler.assemble(preferBun: true);
    return 0;
  }
}
