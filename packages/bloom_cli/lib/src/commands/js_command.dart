import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../deployment/host_config_generator.dart';
import '../deployment/proxy_config_loader.dart';
import '../deployment/web_deploy_targets.dart';
import '../dev/css_hot_swap.dart';
import '../dev/ddc_dev_compiler.dart';
import '../dev/dev_proxy.dart';
import '../dev/live_reload_server.dart';
import '../dev/source_watcher.dart';
import '../npm/npm_vendor_assembler.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';
import '../dev/server_supervisor.dart';

/// Top-level command `bloom js` for Bloom JS Native web apps.
///
/// Manages fine-grained reactive web applications through subcommands: `dev`, `build`, `vendor`, and `create`.
///
/// Example:
/// ```
/// bloom js dev
/// bloom js build
/// bloom js vendor
/// bloom js create CounterButton
/// ```
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

/// Subcommand `bloom js dev` that starts the native Bloom JS dev server with live reload and automatic compilation.
///
/// Example:
/// ```
/// bloom js dev --port 3000 --host 0.0.0.0
/// bloom js dev --entry lib/custom_entry.dart
/// ```
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
      )
      ..addFlag(
        'experimental-ddc',
        defaultsTo: false,
        help:
            'Enable experimental fast DDC (Dart Dev Compiler) compilation for development.',
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

    // Check experimental DDC option
    final useDdcRequested =
        (argResults?['experimental-ddc'] as bool?) ?? false;
    DdcToolchain? ddcToolchain;
    DdcDevCompiler? ddcCompiler;
    bool isDdcActive = false;

    if (useDdcRequested) {
      ddcToolchain = DdcToolchain.discover(projectRoot: project.rootDir);
      if (!ddcToolchain.isAvailable) {
        print(Ansi.warn(
            '⚠ Experimental DDC toolchain snapshots not found in Dart SDK (${ddcToolchain.snapshotPath ?? "unknown"}). Falling back to dart2js -O0.'));
      } else {
        isDdcActive = true;
        print(Ansi.step(
            '⚡ Using experimental DDC (Dart Dev Compiler) fast dev-loop.'));
        await ddcToolchain.ensureSdkArtifacts(
          onProgress: (msg) => print(Ansi.info('› $msg')),
        );
        final packageConfig = File(p.join(
            project.rootDir.path, '.dart_tool', 'package_config.json'));
        ddcCompiler = DdcDevCompiler(
          toolchain: ddcToolchain,
          entryFile: entryFile,
          outputFile: outputFile,
          packageConfigFile:
              packageConfig.existsSync() ? packageConfig : null,
          moduleName: 'main',
        );
      }
    }

    // 3. Parse dev proxy configuration from bloom.yaml
    final config = project.loadBloomConfig();
    final List<BloomDevProxyRule> proxyRules;
    try {
      proxyRules = List.of(loadProxyRules(config));
    } catch (e) {
      final message = e is FormatException ? e.message : e.toString();
      print(Ansi.error(message));
      return 1;
    }

    // 4. Optional: Supervise a co-located Bloom server if bin/server.dart exists
    final serverEntry =
        File(p.join(project.rootDir.path, 'bin', 'server.dart'));
    BloomServerSupervisor? supervisor;
    const defaultServerPort = 8090;

    if (serverEntry.existsSync()) {
      // Automatically register default /api proxy if not explicitly configured
      final hasApiRule = proxyRules.any((r) => r.matches('/api'));
      if (!hasApiRule) {
        proxyRules.add(BloomDevProxyRule(
          pathPrefix: '/api',
          targetUri: Uri.parse('http://127.0.0.1:$defaultServerPort'),
          stripPrefix: false,
        ));
      }

      supervisor = BloomServerSupervisor(
        entryFile: serverEntry,
        port: defaultServerPort,
      );
      await supervisor.start();
      supervisor.onOutput
          .listen((line) => print(Ansi.dimText('[server] $line')));
      print(Ansi.info('› Backend server supervisor active on http://127.0.0.1:$defaultServerPort (bin/server.dart)'));

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

    // Pre-populate cached source baseline for CSS hot-swap detection
    final watchDir = Directory(p.join(project.rootDir.path, 'lib'));
    final Map<String, String> lastSource = {};
    if (watchDir.existsSync()) {
      for (final file in watchDir.listSync(recursive: true, followLinks: false)) {
        if (file is File && file.path.endsWith('.dart')) {
          try {
            lastSource[file.path] = file.readAsStringSync();
          } catch (_) {}
        }
      }
    }

    // 5. Initial Fast Compile
    if (isDdcActive && ddcCompiler != null) {
      await _compileDdc(ddcCompiler);
    } else {
      await _compile(entryFile, outputFile);
    }

    // 6. Start Live Reload Dev Server with SSE and Auto-Injection
    final devServer = BloomLiveReloadServer(
      webDir: webDir,
      host: host,
      port: port,
      autoInjectScript: true,
      proxyRules: proxyRules,
      isDdcMode: isDdcActive,
      ddcCacheDir: ddcToolchain?.cacheDir,
    );
    await devServer.start();

    print(Ansi.step('\n⚡ Bloom JS Hot Live-Reload Server active on http://$host:$port'));
    print(Ansi.info('› Serving static assets from ${webDir.path}'));
    print(Ansi.info('› Live-Reload SSE channel listening on /_bloom_hr'));
    if (proxyRules.isNotEmpty) {
      for (final rule in proxyRules) {
        final stripNote = rule.stripPrefix ? ' (strip prefix)' : '';
        print(Ansi.info('› Proxy: ${rule.pathPrefix} ➔ ${rule.targetUri}$stripNote'));
      }
    }
    print(Ansi.boldText('› Watching for file changes in ${project.rootDir.path}/lib... (Ctrl+C to stop)\n'));

    // 7. Watch for Dart file changes and auto-recompile + broadcast reload
    if (watchDir.existsSync()) {
      final watcher = BloomSourceWatcher(
        directories: [watchDir],
        debounceDuration: const Duration(milliseconds: 150),
      );

      watcher.onChange.listen((events) async {
        if (events.length == 1) {
          final event = events.first;
          final changedPath = event.path;
          final changedFile = File(changedPath);
          if (changedPath.endsWith('.dart') && changedFile.existsSync()) {
            final oldContent = lastSource[changedPath];
            if (oldContent != null) {
              String? newContent;
              try {
                newContent = await changedFile.readAsString();
              } catch (_) {}

              if (newContent != null) {
                final change = detectCssOnlyChange(oldContent, newContent);
                if (change != null) {
                  devServer.broadcastCssPatch(
                    oldCss: change.oldCss,
                    newCss: change.newCss,
                  );
                  print(Ansi.success('⚡ [CSS Hot Swap] Patched stylesheet without recompiling.'));
                  lastSource[changedPath] = newContent;
                  return;
                }
              }
            }
          }
        }

        final changedName = p.basename(events.first.path);
        print(Ansi.info('\n🔄 File change detected: $changedName — Recompiling...'));
        // Tell the browser a rebuild started BEFORE compiling, not after: the
        // compile takes seconds, and until this event existed the page gave no
        // feedback at all in the meantime.
        devServer.broadcastCompiling(reason: changedName);
        final bool success;
        if (isDdcActive && ddcCompiler != null) {
          success = await _compileDdc(ddcCompiler, devServer: devServer);
        } else {
          success = await _compile(entryFile, outputFile, devServer: devServer);
        }
        if (success) {
          if (isDdcActive) {
            devServer.broadcastHotRemount(reason: changedName);
            print(Ansi.success('⚡ [Hot Remount] Broadcasted fast remount event to browser clients.'));
          } else {
            devServer.broadcastReload(reason: changedName);
            print(Ansi.success('⚡ [Hot Reload] Broadcasted live reload event to browser clients.'));
          }
        }

        // Update cached source for every changed file in the event batch
        for (final event in events) {
          if (event.path.endsWith('.dart')) {
            final file = File(event.path);
            if (file.existsSync()) {
              try {
                lastSource[event.path] = file.readAsStringSync();
              } catch (_) {}
            } else {
              lastSource.remove(event.path);
            }
          }
        }
      });
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

  /// Compiles [entryFile] to [outputFile] using DDC.
  Future<bool> _compileDdc(
    DdcDevCompiler compiler, {
    BloomLiveReloadServer? devServer,
  }) async {
    final result = await compiler.compile(devServer: devServer);
    if (!result.success) {
      print(Ansi.error('✖ Compilation failed:\n${result.error}'));
      return false;
    } else {
      final sizeKb = result.outputSizeKb.toStringAsFixed(1);
      final secs = (result.duration.inMilliseconds / 1000).toStringAsFixed(2);
      print(Ansi.success(
          '✓ Compiled main.js ($sizeKb kB) via DDC in ${secs}s'));
      return true;
    }
  }

  /// Compiles [entryFile] to [outputFile].
  ///
  /// When [devServer] is supplied, a failed compile is pushed to the browser as
  /// a build error rather than only being printed to this terminal -- otherwise
  /// the page keeps showing the last good build with no indication that the most
  /// recent save never made it in.
  Future<bool> _compile(
    File entryFile,
    File outputFile, {
    BloomLiveReloadServer? devServer,
  }) async {
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
      devServer?.broadcastError('${compileRes.stderr}'.trim());
      return false;
    } else {
      final sizeKb = (outputFile.lengthSync() / 1024).toStringAsFixed(1);
      print(Ansi.success('✓ Compiled main.js ($sizeKb kB) in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s'));
      return true;
    }
  }
}

/// Subcommand `bloom js build` that compiles the Bloom JS application for production with -O4 tree-shaking and minification.
///
/// Example:
/// ```
/// bloom js build
/// bloom js build --output build/web/app.js --entry lib/main.dart
/// ```
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

    // Host configuration generation for production static hosting
    final config = project.loadBloomConfig();
    final proxyRules = loadProxyRules(config);
    if (proxyRules.isNotEmpty) {
      final generator = const BloomHostConfigGenerator();
      final written = generator.writeAll(
        outputDir: webDir,
        rules: proxyRules,
        appName: project.projectName,
        formats: {BloomWebHostFormat.netlify},
      );
      for (final file in written) {
        print(Ansi.info('› Generated host configuration: ${p.basename(file.path)}'));
      }
    }

    return 0;
  }
}

/// Subcommand `bloom js vendor` that downloads, bundles, and vendors NPM packages declared in bloom.yaml.
///
/// Example:
/// ```
/// bloom js vendor
/// ```
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

/// Subcommand `bloom js create` that scaffolds a new Bloom JS Native component, page, or route guard with a test.
///
/// Example:
/// ```
/// bloom js create Counter
/// bloom js create Profile --page
/// bloom js create Auth --guard
/// ```
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
