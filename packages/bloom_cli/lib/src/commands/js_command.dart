import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../dev/live_reload_server.dart';
import '../dev/source_watcher.dart';
import '../npm/npm_vendor_assembler.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';
import '../dev/server_supervisor.dart';

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
    addSubcommand(JsCreateCommand());
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

    // 6. Optional: Supervise a co-located Bloom server if bin/server.dart exists
    final serverEntry =
        File(p.join(project.rootDir.path, 'bin', 'server.dart'));
    BloomServerSupervisor? supervisor;
    if (serverEntry.existsSync()) {
      supervisor = BloomServerSupervisor(entryFile: serverEntry);
      await supervisor.start();
      supervisor.onOutput
          .listen((line) => print(Ansi.dimText('[server] $line')));
      print(Ansi.info('› Backend server supervisor active (bin/server.dart)'));

      final serverWatchDir =
          Directory(p.join(project.rootDir.path, 'lib'));
      if (serverWatchDir.existsSync()) {
        final serverWatcher = BloomSourceWatcher(
          directories: [serverWatchDir],
          debounceDuration: const Duration(milliseconds: 200),
        );
        serverWatcher.onChange.listen((events) async {
          final changed = p.basename(events.first.path);
          print(
              Ansi.info('\n🔄 Server source changed: $changed — Restarting...'));
          await supervisor!.restart(reason: changed);
          print(Ansi.success('⚡ Server restarted.'));
        });
      }
    }

    // Keep process active
    final completer = Completer<void>();
    ProcessSignal.sigint.watch().listen((_) async {
      print(Ansi.dimText('\nStopping Bloom JS dev server...'));
      await devServer.stop();
      await supervisor?.stop();
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

/// `bloom js create <name>` — scaffolds a new Bloom JS Native component
/// file with boilerplate, plus a matching test file.
class JsCreateCommand extends Command<int> {
  @override
  final String name = 'create';

  @override
  final String description =
      'Scaffold a new Bloom JS Native component with a matching test file.';

  @override
  String get invocation => 'bloom js create <ComponentName> [--page]';

  JsCreateCommand() {
    argParser.addFlag(
      'page',
      abbr: 'p',
      negatable: false,
      help:
          'Scaffold a route/page component (lib/pages/) with a BloomRoute '
          'registration snippet, instead of a plain component.',
    );
    argParser.addFlag(
      'guard',
      abbr: 'g',
      negatable: false,
      help: 'Scaffold a BloomRouteGuard (lib/guards/) instead of a '
          'plain component.',
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      print(Ansi.error('Usage: bloom js create <ComponentName>'));
      return 1;
    }

    final rawName = args.first;
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(rawName)) {
      print(Ansi.error(
          'Invalid component name: "$rawName". Must be alphanumeric, starting with a letter.'));
      return 1;
    }

    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error(
          'No Bloom project found. Run this command from inside a Bloom project directory (or an ancestor of one).'));
      return 1;
    }

    final isPage = (argResults!['page'] as bool?) ?? false;
    final isGuard = (argResults!['guard'] as bool?) ?? false;
    if (isPage && isGuard) {
      print(Ansi.error('Cannot combine --page and --guard.'));
      return 1;
    }

    final kind = isGuard ? 'guard' : (isPage ? 'page' : 'component');
    final subDir = isGuard ? 'guards' : (isPage ? 'pages' : 'components');

    final baseName = _pascalCase(rawName);
    final className = isGuard && !baseName.endsWith('Guard')
        ? '${baseName}Guard'
        : baseName;
    final fileBaseName = _snakeCase(className);

    final targetDir = Directory(p.join(project.rootDir.path, 'lib', subDir));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final targetFile = File(p.join(targetDir.path, '$fileBaseName.dart'));
    if (targetFile.existsSync()) {
      print(Ansi.error('${_capitalize(kind)} file already exists: ${targetFile.path}'));
      return 1;
    }

    targetFile.writeAsStringSync(switch (kind) {
      'page' => _pageTemplate(className, fileBaseName),
      'guard' => _guardTemplate(className),
      _ => _componentTemplate(className),
    });
    print(Ansi.success('Created $kind: ${targetFile.path}'));

    if (!isGuard) {
      final testDir = Directory(p.join(project.rootDir.path, 'test'));
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
      final testFile = File(p.join(testDir.path, '${fileBaseName}_test.dart'));
      if (!testFile.existsSync()) {
        testFile.writeAsStringSync(_componentTestTemplate(className, fileBaseName));
        print(Ansi.success('Created test: ${testFile.path}'));
      }
    }

    return 0;
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _pascalCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  String _snakeCase(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch.toUpperCase() == ch && ch.toLowerCase() != ch && i > 0) {
        buffer.write('_');
      }
      buffer.write(ch.toLowerCase());
    }
    return buffer.toString();
  }

  String _componentTemplate(String className) => '''
import 'package:bloom_js_native/bloom_js_native.dart';

/// $className component.
BloomNode $className() {
  return Div(
    className: '$className',
    children: [
      Text('$className'),
    ],
  );
}
''';

  String _pageTemplate(String className, String fileBaseName) => '''
import 'package:bloom_js_native/bloom_js_native.dart';

/// $className page.
///
/// Register this page as a route in your router setup, e.g.:
///
///   BloomRoute('/$fileBaseName', (params) => $className(params)),
///
/// Or with a data loader (React Router `loader`-style):
///
///   BloomRoute(
///     '/$fileBaseName',
///     null,
///     loader: (params) async => fetchSomething(params),
///     dataBuilder: (params, data) => $className(params),
///   ),
BloomNode $className(Map<String, String> params) {
  return Div(
    className: '$className',
    children: [
      Text('$className'),
    ],
  );
}
''';

  String _guardTemplate(String className) => '''
import 'package:bloom_js_native/bloom_js_native.dart';

/// $className route guard.
///
/// Register on a route via the `guards` list, e.g.:
///
///   BloomRoute('/admin', (params) => AdminPage(), guards: [$className()]),
class $className extends BloomRouteGuard {
  const $className();

  @override
  Future<GuardResult> canActivate(
      String location, Map<String, String> params) async {
    // TODO: implement your authorization check.
    return GuardResult.allow();
    // To deny and redirect instead:
    // return GuardResult.redirect('/login');
  }
}
''';

  String _componentTestTemplate(String className, String fileBaseName) => '''
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

// TODO: adjust this relative import to match your project's package name.
// import 'package:your_app/components/$fileBaseName.dart';

void main() {
  test('$className renders', () {
    // final renderer = renderForTest($className());
    // expect(renderer.getByText('$className'), isNotNull);
  });
}
''';
}
