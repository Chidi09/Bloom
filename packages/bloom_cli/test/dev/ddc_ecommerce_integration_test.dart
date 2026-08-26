import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:test/test.dart';

void main() {
  test('Full ecommerce app boots under DDC with NPM bindings and renders #app DOM', () async {
    final sdkBinDir = p.dirname(Platform.resolvedExecutable);
    final sdkRootDir = p.dirname(sdkBinDir);
    final snapshotsDir = p.join(sdkBinDir, 'snapshots');
    final aotSnapshot = File(p.join(snapshotsDir, 'dartdevc_aot.dart.snapshot'));
    final jitSnapshot = File(p.join(snapshotsDir, 'dartdevc.dart.snapshot'));

    final execSuffix = Platform.isWindows ? '.exe' : '';
    final String snapshotPath;
    final String runnerExecutable;
    if (aotSnapshot.existsSync()) {
      snapshotPath = aotSnapshot.path;
      runnerExecutable = p.join(sdkBinDir, 'dartaotruntime$execSuffix');
    } else {
      snapshotPath = jitSnapshot.path;
      runnerExecutable = p.join(sdkBinDir, 'dart$execSuffix');
    }

    // 1. Ensure dart_sdk.js exists
    final tempDir = Directory.systemTemp.createTempSync('bloom_ddc_test_');
    final dartSdkJs = File(p.join(tempDir.path, 'dart_sdk.js'));
    final ddcPlatformDill = File(p.join(sdkRootDir, 'lib', '_internal', 'ddc_platform.dill'));

    final sdkCompile = await Process.run(runnerExecutable, [
      snapshotPath,
      '--multi-root-scheme=org-dartlang-sdk',
      '--modules=amd',
      '--module-name=dart_sdk',
      '-o',
      dartSdkJs.path,
      ddcPlatformDill.path,
    ]);
    expect(sdkCompile.exitCode, equals(0), reason: 'Failed to compile dart_sdk.js: ${sdkCompile.stderr}');

    // 2. Compile bloom_js_ecommerce app
    final projectDir = Directory('/root/dev/Bloom/examples/bloom_js_ecommerce/web');
    final entryFile = File(p.join(projectDir.path, 'lib', 'main.dart'));
    final packageConfig = File(p.join(projectDir.path, '.dart_tool', 'package_config.json'));
    final appJs = File(p.join(tempDir.path, 'main.js'));

    final appCompile = await Process.run(runnerExecutable, [
      snapshotPath,
      '--packages=${packageConfig.path}',
      '--modules=amd',
      '--module-name=main',
      '-o',
      appJs.path,
      entryFile.path,
    ]);
    expect(appCompile.exitCode, equals(0), reason: 'Failed to compile app: ${appCompile.stderr}');

    // 3. Prepare index.html with DDC bootstrap
    final webDir = Directory(p.join(projectDir.path, 'web'));
    final indexFile = File(p.join(webDir.path, 'index.html'));
    var html = indexFile.readAsStringSync();

    final mainScriptRegex = RegExp(
        r'<script\s+[^>]*src=[\x22\x27]main\.js[\x22\x27][^>]*>\s*<\/script>',
        caseSensitive: false);
    html = html.replaceAll(mainScriptRegex, '');

    const ddcBootstrap = '''
<script type="module">
  const reqScript = document.createElement("script");
  reqScript.src = "/require.js";
  reqScript.onload = () => {
    require.config({
      baseUrl: "/",
      paths: {
        dart_sdk: "dart_sdk",
        main: "main"
      }
    });
    require(["dart_sdk", "main"], (dart_sdk, app) => {
      if (app) {
        for (const k of Object.keys(app)) {
          if (app[k] && typeof app[k].main === "function") {
            app[k].main();
            break;
          }
        }
      }
    });
  };
  document.body.appendChild(reqScript);
</script>
''';

    html = html.replaceFirst('</body>', '$ddcBootstrap\n</body>');

    // 4. Start local test server
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    server.listen((HttpRequest req) async {
      final pth = req.uri.path;
      if (pth == '/' || pth == '/index.html') {
        req.response.headers.contentType = ContentType.html;
        req.response.write(html);
        await req.response.close();
        return;
      }

      if (pth == '/require.js') {
        final f = File(p.join(sdkRootDir, 'lib', 'dev_compiler', 'amd', 'require.js'));
        req.response.headers.contentType = ContentType.parse('application/javascript');
        req.response.add(f.readAsBytesSync());
        await req.response.close();
        return;
      }

      if (pth == '/dart_sdk.js') {
        req.response.headers.contentType = ContentType.parse('application/javascript');
        req.response.add(dartSdkJs.readAsBytesSync());
        await req.response.close();
        return;
      }

      if (pth == '/main.js') {
        req.response.headers.contentType = ContentType.parse('application/javascript');
        req.response.add(appJs.readAsBytesSync());
        await req.response.close();
        return;
      }

      final file = File(p.join(webDir.path, pth.startsWith('/') ? pth.substring(1) : pth));
      if (file.existsSync()) {
        final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();
        if (ext == 'js') {
          req.response.headers.contentType = ContentType.parse('application/javascript');
        } else if (ext == 'css') {
          req.response.headers.contentType = ContentType.parse('text/css');
        }
        req.response.add(file.readAsBytesSync());
        await req.response.close();
        return;
      }

      req.response.statusCode = 404;
      await req.response.close();
    });

    Browser? browser;
    try {
      browser = await puppeteer.launch(
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
      );
      final page = await browser.newPage();
      await page.goto('http://127.0.0.1:$port', wait: Until.networkIdle);
      await Future.delayed(const Duration(seconds: 2));

      final appHtml = await page.evaluate(r'''
        document.getElementById('app') ? document.getElementById('app').innerHTML : ''
      ''') as String;

      expect(appHtml, contains('Bloom Store'));
      expect(appHtml, contains('Cart'));
      expect(appHtml, contains('Log in'));

      final globalsJson = await page.evaluate(r'''
        JSON.stringify({
          confetti: typeof window.canvas_confetti !== 'undefined',
          gsap: typeof window.gsap !== 'undefined',
          lucide: typeof window.lucide !== 'undefined',
          tanstack: typeof window.__bloomVirtualCore !== 'undefined'
        })
      ''') as String;

      final globals = jsonDecode(globalsJson) as Map<String, dynamic>;
      expect(globals['confetti'], isTrue);
      expect(globals['gsap'], isTrue);
      expect(globals['lucide'], isTrue);
      expect(globals['tanstack'], isTrue);
    } finally {
      await browser?.close();
      await server.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
