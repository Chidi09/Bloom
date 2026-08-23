// lib/src/commands/typegen_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../generator/route_typegen.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class TypegenCommand extends Command<int> {
  @override
  final String name = 'typegen';

  @override
  final String description =
      "Generates typed, compile-checked route-builder functions from your app's registered routes.";

  TypegenCommand() {
    argParser
      ..addOption(
        'entry',
        help: 'The Dart file containing the BloomRoute(...) list.',
        defaultsTo: 'lib/main.dart',
      )
      ..addOption(
        'out',
        help: 'Output path for the generated route builders.',
        defaultsTo: 'lib/generated/routes.g.dart',
      )
      ..addOption(
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
      print(
        Ansi.error(
          'Not a valid Bloom project directory: ${projectDir.path}',
        ),
      );
      return 1;
    }

    final entryOption =
        argResults?['entry'] as String? ?? 'lib/main.dart';
    final outOption =
        argResults?['out'] as String? ?? 'lib/generated/routes.g.dart';

    final entryFile = p.isAbsolute(entryOption)
        ? File(entryOption)
        : File(p.join(project.rootDir.path, entryOption));

    if (!entryFile.existsSync()) {
      print(
        Ansi.error(
          'Entry file not found: ${entryFile.path}. Specify --entry to point to your route definition file.',
        ),
      );
      return 1;
    }

    final warnings = <String>[];
    final source = entryFile.readAsStringSync();
    final primaryRoutes = RouteTypegen.parseSource(
      source,
      onWarning: (w) => warnings.add(w),
    );

    var allRoutes = primaryRoutes;

    // Secondary scan: check if filesystem routes exist in lib/routes/
    final routesDir = Directory(p.join(project.rootDir.path, 'lib', 'routes'));
    if (routesDir.existsSync()) {
      final discovered = project.scanRoutes();
      if (discovered.isNotEmpty) {
        final secondary = RouteTypegen.fromDiscoveredRoutes(discovered);
        allRoutes = RouteTypegen.mergeRoutes(
          primaryRoutes,
          secondary,
          onWarning: (w) => warnings.add(w),
        );
      }
    }

    if (allRoutes.isEmpty) {
      final entryDisplay = p.isAbsolute(entryOption)
          ? p.relative(entryFile.path, from: project.rootDir.path)
          : entryOption;
      print(
        Ansi.info(
          'No BloomRoute(...) declarations found in $entryDisplay. Nothing to generate.',
        ),
      );
      return 0;
    }

    final entryDisplay = p.isAbsolute(entryOption)
        ? p.relative(entryFile.path, from: project.rootDir.path)
        : entryOption;

    final result = RouteTypegen.generate(
      routes: allRoutes,
      entryPath: entryDisplay,
      onWarning: (w) => warnings.add(w),
    );

    final outFile = p.isAbsolute(outOption)
        ? File(outOption)
        : File(p.join(project.rootDir.path, outOption));

    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(result.code);

    final staticCount = result.symbols.where((s) => s.isConst).length;
    final paramCount = result.symbols
        .where((s) => !s.isConst && !s.route.hasWildcard)
        .length;
    final wildcardCount =
        result.symbols.where((s) => s.route.hasWildcard).length;

    final outDisplay = p.isAbsolute(outOption)
        ? p.relative(outFile.path, from: project.rootDir.path)
        : outOption;

    for (final w in warnings) {
      print(Ansi.warn(w));
    }

    print(
      Ansi.success(
        'Generated ${result.symbols.length} route helper(s) -> $outDisplay',
      ),
    );
    print('');
    print(
      Ansi.boldText(
        'Discovered routes (${allRoutes.length} total: $staticCount static, $paramCount parameterized, $wildcardCount wildcard):',
      ),
    );
    for (final sym in result.symbols) {
      print(
        '  ${Ansi.step(sym.identifier)} ${Ansi.dimText('->')} ${sym.route.path}',
      );
    }

    return 0;
  }
}
