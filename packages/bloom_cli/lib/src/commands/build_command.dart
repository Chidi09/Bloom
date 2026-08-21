import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../provenance/provenance_generator.dart';
import '../npm/npm_vendor_assembler.dart';
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';
import '../web/ssg_engine.dart';
import '../web/ssr_engine.dart';

class BuildCommand extends Command<int> {
  @override
  final String name = 'build';
  @override
  final String description = 'Compiles production artifacts with Bloom environment injection and flavor profiles.';

  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment,
    bool runInShell,
    ProcessStartMode mode,
  }) processRunner;

  BuildCommand({
    this.processRunner = _defaultProcessRunner,
  }) {
    argParser
      ..addFlag(
        'release',
        help: 'Build a release version of the application.',
        defaultsTo: true,
      )
      ..addFlag(
        'profile',
        help: 'Build a performance profiling version of the application.',
        defaultsTo: false,
      )
      ..addOption(
        'flavor',
        abbr: 'f',
        help: 'Build flavor to use (defined in bloom.yaml).',
      )
      ..addFlag(
        'static',
        help: 'Build static pre-rendered HTML site (SSG) with sitemap and PWA assets.',
        defaultsTo: false,
      )
      ..addFlag(
        'server',
        help: 'Build full-stack Server-Side Rendering (SSR) bundle with API routes.',
        defaultsTo: false,
      )
      ..addOption(
        'env-file',
        help: 'Explicit environment file to inject during build.',
      )
      ..addOption(
        'project-dir',
        help: 'Explicit path to the Bloom project directory.',
      );
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a build target (e.g. "apk", "appbundle", "ipa", "web", "linux", "windows", "macos").'));
      return 1;
    }

    final target = rest.first.toLowerCase();
    final explicitDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : null;

    final project = BloomProject.find(explicitDir);
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final flavor = argResults?['flavor'] as String?;
    final explicitEnv = argResults?['env-file'] as String?;
    final isStatic = argResults?['static'] == true;
    final isServer = argResults?['server'] == true;

    print(Ansi.boldText('\n🏗  Building Bloom target: ${Ansi.cyan}$target${Ansi.reset}${flavor != null ? ' [Flavor: $flavor]' : ''}\n'));

    // 1. Sync routes first
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);

    // 2. Handle Provenance, Web SSG, and SSR targets
    if (target == 'provenance') {
      final provenanceGen = ProvenanceGenerator(project);
      provenanceGen.generateProvenance();
      return 0;
    }

    if (target == 'web' || target == 'web_dom') {
      final assembler = NpmVendorAssembler(project);
      await assembler.assemble();
    }

    if (target == 'web_dom') {
      print(Ansi.step('Compiling Pure Dart Web application (AOT JS)...'));
      final dartBuildResult = await processRunner(
        'dart',
        ['compile', 'js', '-O2', '-o', 'web/main.dart.js', 'lib/main.dart'],
        workingDirectory: project.rootDir.path,
      );
      if (dartBuildResult.exitCode != 0) {
        print(Ansi.error('dart compile js failed:\n${dartBuildResult.stdout}\n${dartBuildResult.stderr}'));
        return 1;
      }
      print('\n${Ansi.success('Pure Dart web application compiled successfully!')}\n');
      return 0;
    }

    if (target == 'web' && (isStatic || isServer)) {
      print(Ansi.step('Compiling Flutter web application...'));
      final flutterBuildResult = await processRunner(
        'flutter',
        ['build', 'web', '--release'],
        workingDirectory: project.rootDir.path,
      );
      if (flutterBuildResult.exitCode != 0) {
        print(Ansi.error('flutter build web failed:\n${flutterBuildResult.stdout}\n${flutterBuildResult.stderr}'));
        return 1;
      }

      final ssg = BloomSsgEngine(project: project);
      await ssg.generate();

      if (isServer) {
        final ssr = BloomSsrEngine(project: project);
        await ssr.generate();
      }
      ProvenanceGenerator(project).generateProvenance();
      return 0;
    }

    // 3. Determine environment file injection
    String? envToInject = explicitEnv;
    if (envToInject == null && flavor != null) {
      final config = project.loadBloomConfig();
      if (config['flavors'] is Map && config['flavors'][flavor] is Map) {
        final flavorConfig = config['flavors'][flavor] as Map;
        envToInject = flavorConfig['env_file']?.toString() ?? flavorConfig['envFile']?.toString();
      }
      envToInject ??= '.env.$flavor';
    }

    // 4. Assemble flutter build arguments
    final buildArgs = ['build', target];

    if (argResults?['profile'] == true) {
      buildArgs.add('--profile');
    } else if (argResults?['release'] == true) {
      buildArgs.add('--release');
    }

    if (flavor != null) {
      buildArgs.addAll(['--flavor', flavor]);
      buildArgs.add('--dart-define=BLOOM_FLAVOR=$flavor');
    }

    if (envToInject != null) {
      final envFile = File(p.join(project.rootDir.path, envToInject));
      if (envFile.existsSync()) {
        buildArgs.add('--dart-define-from-file=$envToInject');
        print(Ansi.step('Injecting environment definition: $envToInject'));
      }
    }

    final proc = await Process.start(
      'flutter',
      buildArgs,
      workingDirectory: project.rootDir.path,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await proc.exitCode;
    if (exitCode == 0) {
      print('\n${Ansi.success('Build completed successfully for $target!')}\n');
    } else {
      print('\n${Ansi.error('Build failed with exit code $exitCode')}\n');
    }
    return exitCode;
  }
}

Future<ProcessResult> _defaultProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  ProcessStartMode mode = ProcessStartMode.normal,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
  );
}
