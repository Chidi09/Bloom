// lib/src/commands/dev_command.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class DevCommand extends Command<int> {
  @override
  final String name = 'dev';
  @override
  final String description = 'Starts the interactive development server with hot reload and diagnostics.';

  DevCommand() {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Target device ID to run the application on.',
      )
      ..addFlag(
        'wireless',
        abbr: 'w',
        help: 'Enable wireless network discovery and pairing.',
        defaultsTo: false,
      );
  }

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found in current directory or parent directories.'));
      return 1;
    }

    final targetDevice = argResults?['device'] as String?;

    printBloomBanner();
    print('${Ansi.cyan}${Ansi.bold}🌸 Starting Bloom Development Engine for "${project.projectName}"...${Ansi.reset}\n');

    // 1. Ensure routes are freshly synced
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);
    print(Ansi.step('Synchronized ${routes.length} filesystem route(s).'));

    // 2. Launch flutter run process
    final flutterArgs = ['run'];
    if (targetDevice != null) {
      flutterArgs.addAll(['-d', targetDevice]);
    }

    print(Ansi.step('Launching runtime orchestrator...\n'));

    final process = await Process.start(
      'flutter',
      flutterArgs,
      workingDirectory: project.rootDir.path,
      mode: ProcessStartMode.normal,
    );

    // Stream process stdout with clean filtering
    final stdoutSub = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains('Flutter run key commands') || line.contains('An Observatory debugger')) {
        // Suppress noisy internal flutter banner in favor of Bloom dashboard
        return;
      }
      if (line.contains('Performing hot reload') || line.contains('Reloaded')) {
        print('${Ansi.green}⚡ $line${Ansi.reset}');
      } else if (line.contains('Performing hot restart') || line.contains('Restarted')) {
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
          } else if (char == 'd') {
            process.stdin.writeln('d'); // Toggle devices
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
