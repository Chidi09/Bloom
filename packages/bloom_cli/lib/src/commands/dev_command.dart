// lib/src/commands/dev_command.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../dev/dashboard.dart';
import '../dev/dev_server.dart';
import '../npm/npm_vendor_assembler.dart';
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class DevCommand extends Command<int> {
  @override
  final String name = 'dev';
  @override
  final String description = 'Starts the interactive development server with hot reload, QR pairing, and diagnostics.';

  DevCommand() {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Target device ID to run the application on.',
      )
      ..addOption(
        'flavor',
        abbr: 'f',
        help: 'Build flavor profile to run (e.g. development, staging, production).',
      )
      ..addOption(
        'port',
        abbr: 'p',
        help: 'Development server HTTP port.',
        defaultsTo: '8080',
      )
      ..addFlag(
        'wireless',
        abbr: 'w',
        help: 'Enable wireless ADB network discovery and pairing.',
        defaultsTo: false,
      )
      ..addFlag(
        'discovery',
        help: 'Broadcast development server presence over local network UDP beacons.',
        defaultsTo: true,
      );
  }

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory or parent directories.'));
      return 1;
    }

    var targetDevice = argResults?['device'] as String?;
    final flavor = argResults?['flavor'] as String?;
    final wireless = argResults?['wireless'] as bool? ?? false;
    final enableDiscovery = argResults?['discovery'] as bool? ?? true;
    final port = int.tryParse(argResults?['port']?.toString() ?? '8080') ?? 8080;

    printBloomBanner();

    // 1. Ensure routes are freshly synced
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);

    // 1b. Assemble NPM vendor packages for web projects
    final config = project.loadBloomConfig();
    if (config['target'] == 'web_dom' || config['target'] == 'web' ||
        (config['platforms'] is Map && (config['platforms'] as Map).containsKey('web'))) {
      final assembler = NpmVendorAssembler(project);
      await assembler.assemble();
    }

    // 2. Start DevServer & Discovery Broadcaster
    final devServer = BloomDevServer(
      project,
      preferredPort: port,
      enableDiscovery: enableDiscovery,
    );
    await devServer.start();

    // 3. Render Dashboard
    final dashboard = DevDashboard(
      project: project,
      devServer: devServer,
      flavor: flavor,
    );
    dashboard.render();

    // 4. Wireless ADB device discovery with robust line parser
    if (wireless && targetDevice == null) {
      try {
        final adbResult = await Process.run('adb', ['devices', '-l']);
        if (adbResult.exitCode == 0) {
          final lines = (adbResult.stdout as String).split('\n');
          final adbRegex = RegExp(r'^([^\s]+)\s+device\b');
          for (final line in lines) {
            final match = adbRegex.firstMatch(line.trim());
            if (match != null) {
              final candidate = match.group(1)!;
              if (candidate.contains(':5555') || candidate.contains('.')) {
                targetDevice = candidate;
                print(Ansi.success('📱 Connected to wireless target device: $targetDevice'));
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    // 5. Assemble flutter run arguments
    final flutterArgs = ['run'];
    if (targetDevice != null) {
      flutterArgs.addAll(['-d', targetDevice]);
    }
    if (flavor != null) {
      flutterArgs.addAll(['--flavor', flavor]);
      flutterArgs.add('--dart-define=BLOOM_FLAVOR=$flavor');
      final config = project.loadBloomConfig();
      if (config['flavors'] is Map && config['flavors'][flavor] is Map) {
        final flavorConfig = config['flavors'][flavor] as Map;
        final envFile = flavorConfig['env_file']?.toString() ?? flavorConfig['envFile']?.toString() ?? '.env.$flavor';
        if (File(p.join(project.rootDir.path, envFile)).existsSync()) {
          flutterArgs.add('--dart-define-from-file=$envFile');
        }
      }
    }

    print(Ansi.step('Launching Flutter runtime orchestrator...\n'));

    final process = await Process.start(
      'flutter',
      flutterArgs,
      workingDirectory: project.rootDir.path,
      mode: ProcessStartMode.normal,
    );

    // Stream process stdout with clean filtering
    final stdoutSub = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains('Flutter run key commands') || line.contains('An Observatory debugger')) {
        return;
      }
      if (line.contains('Performing hot reload') || line.contains('Reloaded')) {
        devServer.recordHotReload();
        print('${Ansi.green}⚡ $line${Ansi.reset}');
      } else if (line.contains('Performing hot restart') || line.contains('Restarted')) {
        devServer.recordHotRestart();
        print('${Ansi.magenta}🔄 $line${Ansi.reset}');
      } else if (line.toLowerCase().contains('error') || line.toLowerCase().contains('exception')) {
        print('${Ansi.red}$line${Ansi.reset}');
      } else {
        print(line);
      }
    });

    // Stream process stderr
    final stderrSub = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains('Woah! You appear to be trying to run flutter as root')) return;
      print('${Ansi.red}$line${Ansi.reset}');
    });

    // Terminal keyboard interactions
    StreamSubscription? stdinSub;
    try {
      if (stdin.hasTerminal) {
        stdin.echoMode = false;
        stdin.lineMode = false;

        stdinSub = stdin.listen((bytes) {
          final char = String.fromCharCodes(bytes);
          if (char == 'r') {
            process.stdin.writeln('r'); // Hot reload
          } else if (char == 'R') {
            process.stdin.writeln('R'); // Hot restart
          } else if (char == 'o' || char == 'v') {
            process.stdin.writeln('v'); // Open DevTools
          } else if (char == 'w') {
            dashboard.showQrCode = !dashboard.showQrCode;
            dashboard.render();
          } else if (char == 'd') {
            dashboard.printDevices();
          } else if (char == 'c') {
            print('\x1B[2J\x1B[0;0H'); // Clear terminal
            dashboard.render();
          } else if (char == 'q' || char == '\x03') {
            process.stdin.writeln('q'); // Quit
          } else {
            process.stdin.write(char);
          }
        });
      }
    } catch (_) {}

    final exitCode = await process.exitCode;

    await stdoutSub.cancel();
    await stderrSub.cancel();
    await stdinSub?.cancel();
    await devServer.stop();

    if (stdin.hasTerminal) {
      try {
        stdin.lineMode = true;
        stdin.echoMode = true;
      } catch (_) {}
    }

    print('\n${Ansi.info('Bloom development session ended.')}\n');
    return exitCode;
  }
}
