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
      'Starts the Bloom JS Native development server with live reload.';

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
    print(Ansi.step('\n⚡ Starting Bloom JS Native Dev Server on http://localhost:$port\n'));

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
    print(Ansi.info('› Compiling ${p.basename(entryFile.path)} → main.js...'));
    final compileRes = await Process.run('dart', [
      'compile',
      'js',
      '-O1',
      '-o',
      outputFile.path,
      entryFile.path,
    ]);

    if (compileRes.exitCode != 0) {
      print(Ansi.error('Compilation failed:\n${compileRes.stderr}'));
    } else {
      print(Ansi.success('✓ Compilation successful.'));
    }

    print(Ansi.boldText('\nReady. Serving at http://localhost:$port (Press Ctrl+C to stop)\n'));
    return 0;
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
