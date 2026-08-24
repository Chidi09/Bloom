// lib/src/templates/templates.dart
import '../utils/project.dart';

class BloomTemplates {
  /// Default `bloom.yaml` template
  static String bloomYaml({
    required String name,
    String version = '0.1.0',
    String description = 'A modern application built with Bloom',
    int androidMinSdk = 24,
    int androidTargetSdk = 34,
    String iosMinVersion = '15.0',
  }) {
    return '''# Bloom Application Manifest
# Schema versioning ensures backwards compatibility
schema: 1

name: $name
version: $version
description: "$description"

platforms:
  android:
    min_sdk: $androidMinSdk
    target_sdk: $androidTargetSdk
  ios:
    minimum_version: "$iosMinVersion"
  web:
    title: "$name"

features:
  routing: true
  state: true
  data: false
  native: false

environment:
  files:
    - .env
    - .env.local

plugins: []
''';
  }

  /// Default `.env` template
  static String dotEnv({required String name}) {
    return '''# Application Environment Variables
APP_NAME=$name
APP_ENV=development
API_URL=http://localhost:8080/api
LOG_LEVEL=debug
''';
  }

  /// Default `.env.example` template
  static String dotEnvExample() {
    return '''# Example Environment Configuration
APP_NAME=MyApp
APP_ENV=development
API_URL=https://api.example.com
LOG_LEVEL=info
''';
  }

  /// Default `analysis_options.yaml` template
  static String analysisOptions() {
    return '''include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    file_names: ignore
''';
  }

  /// Default `lib/main.dart`
  static String mainDart({required String projectName}) {
    return '''// lib/main.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';
import 'app/boot.dart';
import 'app/routes.g.dart';

Future<void> main() async {
  // Initialize Bloom runtime, environment, and dependency injection
  await Bloom.boot(
    bootstrapper: const AppBootstrapper(),
  );

  runApp(
    BloomApp(
      title: Bloom.config.name,
      routerConfig: appRouter,
    ),
  );
}
''';
  }

  /// Default `lib/app/boot.dart`
  static String bootDart() {
    return '''// lib/app/boot.dart
import 'package:bloom_framework/bloom.dart';

/// AppBootstrapper executes during the `Bloom.boot()` sequence
/// before the widget tree mounts. Use this to register DI services and initialize storage.
class AppBootstrapper extends BloomBootstrapper {
  const AppBootstrapper();

  @override
  Future<void> onBoot(BloomContainer container) async {
    logger.info('Initializing application dependencies...');

    // Example DI registration:
    // container.provideSingleton<AuthService>(() => AuthService());
  }
}
''';
  }

  /// Default `lib/routes/index.dart`
  static String indexRoute({required String projectName}) {
    return '''// lib/routes/index.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class IndexRoute extends BloomRoute {
  const IndexRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final count = signal(0);

    return Scaffold(
      appBar: AppBar(
        title: Text(Bloom.config.name),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BloomLogo(size: 72),
            const SizedBox(height: 16),
            Text(
              'Welcome to Bloom',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Environment: \${BloomEnv.get('APP_ENV', defaultValue: 'local')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 32),
            Watch((context) {
              return Text(
                'Clicks: \${count.value}',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => count.value++,
              icon: const Icon(Icons.add),
              label: const Text('Increment Signal'),
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

  /// Scaffolds a new page/route
  static String genericRoute({
    required String className,
    required String routePath,
  }) {
    return '''// lib/routes/$routePath.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class $className extends BloomRoute {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('$className'),
      ),
      body: const Center(
        child: Text('$className Screen'),
      ),
    );
  }
}
''';
  }

  /// Scaffolds a new BloomController
  static String controller({
    required String className,
    required String featureName,
  }) {
    return '''// lib/features/$featureName/controllers/\${featureName}_controller.dart
import 'package:bloom_framework/bloom.dart';

class $className extends BloomController {
  final count = signal(0);
  late final isEven = computed(() => count.value.isEven);

  void increment() => count.value++;
  void decrement() => count.value--;
  void reset() => count.value = 0;

  @override
  void onInit() {
    super.onInit();
    logger.info('$className initialized');
  }
}
''';
  }

  /// Scaffolds a new Model
  static String model({required String className}) {
    return '''// lib/models/\${className.toLowerCase()}.dart

class $className {
  final String id;
  final String title;
  final DateTime createdAt;

  const $className({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory $className.fromJson(Map<String, dynamic> json) {
    return $className(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
''';
  }

  /// Scaffolds a new Service
  static String service({required String className}) {
    return '''// lib/services/\${className.toLowerCase()}.dart
import 'package:bloom_framework/bloom.dart';

class $className {
  Future<void> initialize() async {
    logger.info('$className initialized');
  }
}
''';
  }

  /// Generates `lib/app/routes.g.dart` from discovered routes
  static String generatedRouter({
    required String projectName,
    required List<DiscoveredRoute> routes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by Bloom CLI');
    buffer.writeln('// ignore_for_file: depend_on_referenced_packages, unused_import, file_names');
    buffer.writeln('');
    buffer.writeln("import 'package:bloom_framework/bloom.dart';");
    buffer.writeln('');

    // Imports for all routes
    for (final r in routes) {
      buffer.writeln("import '../routes/${r.relativeFilePath}';");
    }
    buffer.writeln('');

    buffer.writeln('final GoRouter appRouter = BloomRouter.create(');
    buffer.writeln("  initialLocation: '/',");
    buffer.writeln('  routes: [');

    for (final r in routes) {
      buffer.writeln('    GoRoute(');
      buffer.writeln("      path: '${r.routePath}',");
      buffer.writeln('      builder: (context, state) {');
      buffer.writeln('        return const ${r.componentClassName}();');
      buffer.writeln('      },');
      buffer.writeln('    ),');
    }

    buffer.writeln('  ],');
    buffer.writeln(');');

    return buffer.toString();
  }

  /// Default `test/widget_test.dart`
  static String widgetTest({required String projectName}) {
    return '''// test/widget_test.dart
import 'package:bloom_framework/bloom_testing.dart';
import 'package:$projectName/routes/index.dart';

void main() {
  testWidgets('Index route mounts and shows welcome message', (WidgetTester tester) async {
    await tester.pumpBloomApp(
      home: const IndexRoute(),
    );

    expect(find.text('Welcome to Bloom'), findsOneWidget);
  });
}
''';
  }

  /// `bloom.yaml` for a Flutter-free Bloom JS Native project.
  static String jsNativeBloomYaml({
    required String name,
    String version = '0.1.0',
    String description = 'A modern application built with Bloom JS Native',
  }) {
    return '''# Bloom Application Manifest
schema: 1

name: $name
version: $version
description: "$description"
type: js_native

web:
  title: "$name"
  entry: lib/main.dart
  out: web/main.js

features:
  routing: false
  state: true
  data: false
  native: false
''';
  }

  /// `pubspec.yaml` for a Flutter-free Bloom JS Native project. No `flutter:`
  /// SDK dependency — `bloom js dev`/`bloom js build` compile with
  /// `dart compile js`, not the Flutter toolchain.
  static String jsNativePubspec({
    required String name,
    required String description,
    required String bloomJsNativeVersion,
  }) {
    return '''name: $name
description: "$description"
publish_to: 'none'
version: 0.1.0

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  bloom_js_native: ^$bloomJsNativeVersion

dev_dependencies:
  test: ^1.25.0
  lints: ^4.0.0
''';
  }

  /// `web/index.html` for a Bloom JS Native project. Loads the compiled
  /// `main.js` produced by `bloom js dev` / `bloom js build`.
  static String jsNativeIndexHtml({required String name}) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$name</title>
</head>
<body>
  <div id="app"></div>
  <!-- Compiled by `bloom js dev` / `bloom js build` from lib/main.dart -->
  <script src="main.js" defer></script>
</body>
</html>
''';
  }

  /// `lib/main.dart` for a Bloom JS Native project. Imports `browser.dart`
  /// (not the bare `bloom_js_native.dart` entry point) since `mount()` is
  /// browser-only — a common mistake that fails with
  /// "Error: Method not found: 'mount'." if omitted.
  static String jsNativeMainDart({required String projectName}) {
    return '''import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  final count = signal(0);

  final app = Div(
    className: 'app',
    children: [
      H1(text: 'Welcome to $projectName'),
      Live(() => P(text: 'Count: \${count.value}')),
      Button(
        text: 'Increment',
        onClick: (_) => count.value++,
      ),
    ],
  );

  mount(app, '#app');
}
''';
  }

  /// `test/smoke_test.dart` for a Bloom JS Native project — a plain `dart
  /// test` unit test against the SSR-safe core, not a browser test.
  static String jsNativeSmokeTest({required String projectName}) {
    return '''import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  test('count signal starts at 0 and increments', () {
    final count = signal(0);
    expect(count.value, 0);
    count.value++;
    expect(count.value, 1);
  });
}
''';
  }

  /// `.gitignore` for a Bloom JS Native project.
  static String jsNativeGitignore() {
    return '''.dart_tool/
.packages
pubspec.lock
web/main.js
web/main.js.map
web/main.js.deps
web/vendor/
web/importmap.json
''';
  }
}
