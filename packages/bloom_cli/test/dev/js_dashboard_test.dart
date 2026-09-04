// test/dev/js_dashboard_test.dart
import 'dart:async';
import 'dart:io';

import 'package:bloom_cli/src/dev/dev_proxy.dart';
import 'package:bloom_cli/src/dev/js_dashboard.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<String> _render(void Function() body) async {
  final lines = <String>[];
  runZoned(
    () => body(),
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        lines.add(line);
      },
    ),
  );
  return lines.join('\n');
}

void main() {
  late Directory projectDir;
  late BloomProject project;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('bloom_js_dash_');
    Directory(p.join(projectDir.path, 'lib', 'routes')).createSync(
        recursive: true);
    File(p.join(projectDir.path, 'lib', 'routes', 'index.dart'))
        .writeAsStringSync('void indexRoute() {}');
    File(p.join(projectDir.path, 'lib', 'routes', 'about.dart'))
        .writeAsStringSync('void aboutRoute() {}');
    project = BloomProject.fromDirectory(projectDir);
  });

  tearDown(() async {
    projectDir.deleteSync(recursive: true);
  });

  JsDevDashboard makeDash({bool ddc = true}) {
    return JsDevDashboard(
      project: project,
      displayHost: 'localhost',
      port: 8080,
      isDdcMode: ddc,
      proxyRules: [
        BloomDevProxyRule(
          pathPrefix: '/api',
          targetUri: Uri.parse('http://127.0.0.1:8090'),
        ),
      ],
      webDirPath: p.join(projectDir.path, 'web'),
      watchDirPath: p.join(projectDir.path, 'lib'),
    );
  }

  test('startup panel shows project, url, mode, proxy and routes', () async {
    final out = await _render(() {
      makeDash().renderStartup();
    });

    expect(out, contains(project.projectName));
    expect(out, contains('http://localhost:8080'));
    expect(out, contains('DDC fast dev-loop'));
    expect(out, contains('Proxy (1):'));
    expect(out, contains('/api'));
    expect(out, contains('Routes (2):'));
    expect(out, contains('/'));
    expect(out, contains('/about'));
  });

  test('startup panel reports dart2js mode when not DDC', () async {
    final out = await _render(() {
      makeDash(ddc: false).renderStartup();
    });
    expect(out, contains('dart2js -O0'));
    expect(out, isNot(contains('DDC fast dev-loop')));
  });

  test('live build status increments compiles and prints counts', () async {
    final dash = makeDash();
    final out = await _render(() {
      dash.onBuildStart('main.dart');
      dash.onBuildFinished(true, note: 'Hot Remount');
      dash.onBuildFinished(true, note: 'Hot Reload');
    });

    expect(out, contains('compiling main.dart'));
    expect(out, contains('Hot Remount'));
    expect(out, contains('(2 builds, 0 errors)'));
    expect(dash.compiles, 2);
    expect(dash.errors, 0);
  });

  test('failed build increments errors and prints a failure line', () async {
    final dash = makeDash();
    final out = await _render(() {
      dash.onBuildStart('main.dart');
      dash.onBuildFinished(false, errorText: 'lib/main.dart:12: missing ;');
    });

    expect(out, contains('build failed'));
    expect(out, contains('(0 builds, 1 errors)'));
    expect(out, contains('missing ;'));
    expect(dash.errors, 1);
  });
}