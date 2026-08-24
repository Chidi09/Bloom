// lib/src/commands/generate_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../generator/module_generator.dart';
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Parent command that generates routes, pages, controllers, models, services, environments, and module bridges.
///
/// Manages code generation across all architectural layers of a Bloom application.
///
/// Example:
/// ```
/// bloom generate page users/[id]
/// bloom generate controller Auth --feature auth
/// bloom generate model User
/// bloom generate service Api
/// bloom generate router
/// bloom generate env
/// bloom generate api items
/// ```
class GenerateCommand extends Command<int> {
  @override
  final String name = 'generate';
  @override
  final String description = 'Generates deterministic routes, pages, controllers, models, services, environments, and native module bridges.';

  GenerateCommand() {
    addSubcommand(_GeneratePageCommand());
    addSubcommand(_GenerateRouteCommand());
    addSubcommand(_GenerateControllerCommand());
    addSubcommand(_GenerateModelCommand());
    addSubcommand(_GenerateServiceCommand());
    addSubcommand(_GenerateRouterCommand());
    addSubcommand(_GenerateEnvCommand());
    addSubcommand(_GenerateModuleCommand());
    addSubcommand(_GenerateApiCommand());
  }
}

class _GenerateEnvCommand extends Command<int> {
  @override
  final String name = 'env';
  @override
  final String description = 'Generates standard .env and .env.example environment templates.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final envFile = File(p.join(project.rootDir.path, '.env'));
    final envExampleFile = File(p.join(project.rootDir.path, '.env.example'));

    if (!envFile.existsSync()) {
      envFile.writeAsStringSync(BloomTemplates.dotEnv(name: project.projectName));
      print(Ansi.success('Generated .env file.'));
    } else {
      print(Ansi.info('.env file already exists.'));
    }

    if (!envExampleFile.existsSync()) {
      envExampleFile.writeAsStringSync(BloomTemplates.dotEnvExample());
      print(Ansi.success('Generated .env.example file.'));
    } else {
      print(Ansi.info('.env.example file already exists.'));
    }

    return 0;
  }
}

class _GeneratePageCommand extends Command<int> {
  @override
  final String name = 'page';
  @override
  final String description = 'Generates a new filesystem route page.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a page name or path (e.g., "users" or "users/[id]").'));
      return 1;
    }

    final pagePath = rest.first.trim();
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found. Run this command inside a Bloom project directory.'));
      return 1;
    }

    // Determine target file path
    String relativeFilePath = pagePath;
    if (!relativeFilePath.endsWith('.dart')) {
      if (relativeFilePath.endsWith('/')) {
        relativeFilePath = '${relativeFilePath}index.dart';
      } else {
        relativeFilePath = '$relativeFilePath.dart';
      }
    }

    final targetFile = File(p.join(project.rootDir.path, 'lib', 'routes', relativeFilePath));
    if (targetFile.existsSync()) {
      print(Ansi.error('Route file already exists: ${targetFile.path}'));
      return 1;
    }

    targetFile.createSync(recursive: true);

    // Derive class name
    final clean = p.withoutExtension(relativeFilePath).replaceAll(RegExp(r'[[\]()]'), '');
    final className = clean.split(RegExp(r'[/_\-]')).map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join() + 'Route';

    targetFile.writeAsStringSync(
      BloomTemplates.genericRoute(
        className: className,
        routePath: p.withoutExtension(relativeFilePath),
      ),
    );

    print(Ansi.success('Created route: ${targetFile.path}'));

    // Automatically regenerate routes.g.dart
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);

    print(Ansi.success('Updated router configuration: ${routerFile.path}'));
    return 0;
  }
}

class _GenerateRouteCommand extends _GeneratePageCommand {
  @override
  final String name = 'route';
  @override
  final String description = 'Alias for `bloom generate page`.';
}

class _GenerateControllerCommand extends Command<int> {
  @override
  final String name = 'controller';
  @override
  final String description = 'Generates a state controller.';

  _GenerateControllerCommand() {
    argParser.addOption(
      'feature',
      abbr: 'f',
      help: 'Feature folder to place the controller in.',
    );
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a controller name (e.g., "CounterController" or "Auth").'));
      return 1;
    }

    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    var rawName = rest.first.trim();
    if (!rawName.endsWith('Controller')) {
      rawName = '${rawName}Controller';
    }
    final className = '${rawName[0].toUpperCase()}${rawName.substring(1)}';
    final feature = argResults?['feature'] as String? ?? className.replaceAll('Controller', '').toLowerCase();

    final targetFile = File(
      p.join(project.rootDir.path, 'lib', 'features', feature, 'controllers', '${feature}_controller.dart'),
    );
    targetFile.createSync(recursive: true);
    targetFile.writeAsStringSync(
      BloomTemplates.controller(className: className, featureName: feature),
    );

    print(Ansi.success('Created controller: ${targetFile.path}'));
    return 0;
  }
}

class _GenerateModelCommand extends Command<int> {
  @override
  final String name = 'model';
  @override
  final String description = 'Generates a data model.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a model name (e.g., "User" or "Product").'));
      return 1;
    }

    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final rawName = rest.first.trim();
    final className = '${rawName[0].toUpperCase()}${rawName.substring(1)}';
    final fileName = '${rawName.toLowerCase()}.dart';

    final targetFile = File(p.join(project.rootDir.path, 'lib', 'models', fileName));
    targetFile.createSync(recursive: true);
    targetFile.writeAsStringSync(BloomTemplates.model(className: className));

    print(Ansi.success('Created model: ${targetFile.path}'));
    return 0;
  }
}

class _GenerateServiceCommand extends Command<int> {
  @override
  final String name = 'service';
  @override
  final String description = 'Generates a service or repository.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a service name (e.g., "ApiService" or "AuthService").'));
      return 1;
    }

    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final rawName = rest.first.trim();
    final className = '${rawName[0].toUpperCase()}${rawName.substring(1)}';
    final fileName = '${rawName.toLowerCase()}.dart';

    final targetFile = File(p.join(project.rootDir.path, 'lib', 'services', fileName));
    targetFile.createSync(recursive: true);
    targetFile.writeAsStringSync(BloomTemplates.service(className: className));

    print(Ansi.success('Created service: ${targetFile.path}'));
    return 0;
  }
}

class _GenerateRouterCommand extends Command<int> {
  @override
  final String name = 'router';
  @override
  final String description = 'Rescans lib/routes/ and regenerates lib/app/routes.g.dart.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);

    print(Ansi.success('Successfully scanned ${routes.length} route(s) and regenerated ${routerFile.path}'));
    return 0;
  }
}

class _GenerateModuleCommand extends Command<int> {
  @override
  final String name = 'module';
  @override
  final String description = 'Compiles @BloomModule DSL definitions into typed Dart, Swift, and Kotlin bridge interfaces.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    final targetPath = rest.isNotEmpty ? rest.first : Directory.current.path;
    final dir = Directory(targetPath);

    if (!dir.existsSync()) {
      print(Ansi.error('Directory not found: $targetPath'));
      return 1;
    }

    print(Ansi.boldText('\n⚙  Running Bloom Module Code Generator on "${dir.path}"...\n'));
    final success = BloomModuleCodeGenerator.generateForModule(dir);

    if (success) {
      print(Ansi.success('Successfully compiled @BloomModule DSL into typed Dart, Swift, and Kotlin bridge bindings!'));
      return 0;
    } else {
      print(Ansi.warn('No .module.dart DSL files found in ${dir.path}/lib/src'));
      return 1;
    }
  }
}

class _GenerateApiCommand extends Command<int> {
  @override
  final String name = 'api';
  @override
  final String description = 'Generates a backend REST API route handler under lib/routes/api/.';

  _GenerateApiCommand() {
    argParser.addOption('project-dir', help: 'Explicit path to the Bloom project directory.');
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify an API route name or path (e.g., "users" or "users/[id]").'));
      return 1;
    }

    final apiPath = rest.first.trim();
    final explicitDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : null;

    final project = BloomProject.find(explicitDir);
    if (project == null) {
      print(Ansi.error('No Bloom project found. Run this command inside a Bloom project directory.'));
      return 1;
    }

    String relativeFilePath = apiPath;
    if (!relativeFilePath.endsWith('.dart')) {
      if (relativeFilePath.endsWith('/')) {
        relativeFilePath = '${relativeFilePath}index.dart';
      } else {
        relativeFilePath = '$relativeFilePath.dart';
      }
    }

    final targetFile = File(p.join(project.rootDir.path, 'lib', 'routes', 'api', relativeFilePath));
    if (targetFile.existsSync()) {
      print(Ansi.error('API route file already exists: ${targetFile.path}'));
      return 1;
    }

    targetFile.createSync(recursive: true);
    final endpointName = p.basenameWithoutExtension(relativeFilePath);

    final content = '''
// lib/routes/api/$relativeFilePath
import 'package:bloom_framework/bloom_server.dart';

/// GET /api/${apiPath.replaceAll(RegExp(r'/?index(\.dart)?$'), '')}
Future<BloomResponse> get(BloomRequest request) async {
  final id = request.params['id'];
  return BloomResponse.json({
    'status': 'ok',
    'endpoint': '$endpointName',
    if (id != null) 'id': id,
    'timestamp': DateTime.now().toIso8601String(),
  });
}

/// POST /api/${apiPath.replaceAll(RegExp(r'/?index(\.dart)?$'), '')}
Future<BloomResponse> post(BloomRequest request) async {
  final body = request.json();
  return BloomResponse.json({
    'message': 'Created successfully',
    'data': body,
  }, statusCode: 201);
}

/// DELETE /api/${apiPath.replaceAll(RegExp(r'/?index(\.dart)?$'), '')}
Future<BloomResponse> delete(BloomRequest request) async {
  return BloomResponse.noContent();
}
''';

    targetFile.writeAsStringSync(content.trim());
    print(Ansi.success('Generated API route handler at ${targetFile.path}'));
    return 0;
  }
}
