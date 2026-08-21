import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../dev/live_reload_server.dart';
import '../dev/source_watcher.dart';
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

    // 3. Initial Fast Compile (-O0 for development)
    await _compile(entryFile, outputFile);

    // 4. Start Live Reload Dev Server with SSE and Auto-Injection
    final devServer = BloomLiveReloadServer(
      webDir: webDir,
      host: host,
      port: port,
      autoInjectScript: true,
    );
    await devServer.start();

    print(Ansi.step('\n⚡ Bloom JS Hot Live-Reload Server active on http://$host:$port'));
    print(Ansi.info('› Serving static assets from ${webDir.path}'));
    print(Ansi.info('› Live-Reload SSE channel listening on /_bloom_hr'));
    print(Ansi.boldText('› Watching for file changes in ${project.rootDir.path}/lib... (Ctrl+C to stop)\n'));

    // 5. Watch for Dart file changes and auto-recompile + broadcast reload
    final watchDir = Directory(p.join(project.rootDir.path, 'lib'));
    if (watchDir.existsSync()) {
      final watcher = BloomSourceWatcher(
        directories: [watchDir],
        debounceDuration: const Duration(milliseconds: 150),
      );

      watcher.onChange.listen((events) async {
        final changedName = p.basename(events.first.path);
        print(Ansi.info('\n🔄 File change detected: $changedName — Recompiling...'));
        final success = await _compile(entryFile, outputFile);
        if (success) {
          devServer.broadcastReload(reason: changedName);
          print(Ansi.success('⚡ [Hot Reload] Broadcasted live reload event to browser clients.'));
        }
      });
    }

    // Keep process active
    final completer = Completer<void>();
    ProcessSignal.sigint.watch().listen((_) async {
      print(Ansi.dimText('\nStopping Bloom JS dev server...'));
      await devServer.stop();
      completer.complete();
    });

    await completer.future;
    return 0;
  }

  Future<bool> _compile(File entryFile, File outputFile) async {
    final sw = Stopwatch()..start();
    final compileRes = await Process.run('dart', [
      'compile',
      'js',
      '-O0', // Fast development compile
      '-o',
      outputFile.path,
      entryFile.path,
    ]);
    sw.stop();

    if (compileRes.exitCode != 0) {
      print(Ansi.error('✖ Compilation failed:\n${compileRes.stderr}'));
      return false;
    } else {
      final sizeKb = (outputFile.lengthSync() / 1024).toStringAsFixed(1);
      print(Ansi.success('✓ Compiled main.js ($sizeKb kB) in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s'));
      return true;
    }
  }
}

/// `bloom js build` — production optimizer.
class JsBuildCommand extends Command<int> {
  @override
  final String name = 'build';

  @override
  final String description =
      'Compiles the Bloom JS application for production with -O4 tree-shaking and minification.';

  JsBuildCommand() {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory or JavaScript file.',
      )
      ..addOption(
        'entry',
        abbr: 'e',
        help: 'Custom entry point Dart file.',
      )
      ..addFlag(
        'analyze',
        defaultsTo: false,
        help: 'Analyze output bundle size breakdown.',
      );
  }

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory tree.'));
      return 1;
    }

    print(Ansi.step('🌸 Building Bloom JS Native Web Application for Production...\n'));

    // 1. Vendor NPM packages
    final assembler = NpmVendorAssembler(project);
    await assembler.assemble();

    // 2. Locate entry and output
    final webDir = Directory(p.join(project.rootDir.path, 'web')).existsSync()
        ? Directory(p.join(project.rootDir.path, 'web'))
        : Directory(p.join(project.rootDir.path, 'example'));

    final entryFile = argResults?['entry'] != null
        ? File(argResults!['entry'])
        : (File(p.join(project.rootDir.path, 'lib', 'main.dart')).existsSync()
            ? File(p.join(project.rootDir.path, 'lib', 'main.dart'))
            : File(p.join(project.rootDir.path, 'example', 'main.dart')));

    final outputFile = argResults?['output'] != null
        ? File(argResults!['output'])
        : File(p.join(webDir.path, 'main.js'));

    print(Ansi.info('› Entry  : ${entryFile.path}'));
    print(Ansi.info('› Output : ${outputFile.path}'));
    print(Ansi.info('› Mode   : -O4 Whole-Program Optimization & Tree-Shaking\n'));

    final sw = Stopwatch()..start();
    final compileRes = await Process.run('dart', [
      'compile',
      'js',
      '-O4',
      '-o',
      outputFile.path,
      entryFile.path,
    ]);
    sw.stop();

    if (compileRes.exitCode != 0) {
      print(Ansi.error('✖ Production compilation failed:\n${compileRes.stderr}'));
      return 1;
    }

    final sizeBytes = outputFile.lengthSync();
    final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);

    print(Ansi.success('✓ Production build succeeded in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s!'));
    print(Ansi.boldText('  • Output Bundle : ${outputFile.path} ($sizeKb kB)'));

    return 0;
  }
}

/// `bloom js vendor` — sync NPM packages.
class JsVendorCommand extends Command<int> {
  @override
  final String name = 'vendor';

  @override
  final String description = 'Downloads, bundles, and vendors NPM packages declared in bloom.yaml.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory tree.'));
      return 1;
    }

    final assembler = NpmVendorAssembler(project);
    await assembler.assemble();
    return 0;
  }
}
