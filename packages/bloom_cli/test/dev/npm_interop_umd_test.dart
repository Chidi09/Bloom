import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:puppeteer/puppeteer.dart';
import 'package:test/test.dart';

void main() {
  test('NPM UMD module attached to window when require.js is loaded after module scripts', () async {
    const umdBundleContent = '''
(function (global, factory) {
    if (typeof define === "function" && define.amd) {
        define(["exports"], factory);
    } else if (typeof exports !== "undefined") {
        factory(exports);
    } else {
        var mod = { exports: {} };
        factory(mod.exports);
        global.myUmdLib = mod.exports;
    }
})(typeof globalThis !== "undefined" ? globalThis : typeof self !== "undefined" ? self : this, function (exports) {
    "use strict";
    Object.defineProperty(exports, "__esModule", { value: true });
    exports.hello = function() { return "hello from UMD!"; };
});
''';

    // Test Case 1: require.js in <head> before <script type="module"> (BROKEN for UMD)
    // Test Case 2: require.js after <script type="module"> (WORKING for UMD and DDC)

    for (final testCase in ['require_before_module', 'require_after_module']) {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((HttpRequest req) async {
        final p = req.uri.path;
        if (p == '/' || p == '/index.html') {
          req.response.headers.contentType = ContentType.html;

          final String html;
          if (testCase == 'require_before_module') {
            html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="/require.js"></script>
  <script type="importmap">
  {
    "imports": {
      "my-umd-lib": "/vendor/my-umd.js"
    }
  }
  </script>
  <script type="module">
    import * as ns from "my-umd-lib";
    window.myUmdLib = ns.hello ? ns : (window.myUmdLib || ns);
  </script>
</head>
<body>
  <div id="app"></div>
</body>
</html>
''';
          } else {
            html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script type="importmap">
  {
    "imports": {
      "my-umd-lib": "/vendor/my-umd.js"
    }
  }
  </script>
  <script type="module">
    import * as ns from "my-umd-lib";
    window.myUmdLib = ns.hello ? ns : (window.myUmdLib || ns);
  </script>
</head>
<body>
  <div id="app"></div>
  <script type="module">
    const script = document.createElement('script');
    script.src = '/require.js';
    script.onload = () => {
      window.__require_loaded = true;
    };
    document.body.appendChild(script);
  </script>
</body>
</html>
''';
          }

          req.response.write(html);
          await req.response.close();
          return;
        }

        if (p == '/require.js') {
          final sdkBinDir = File(Platform.resolvedExecutable).parent.path;
          final sdkRootDir = Directory(sdkBinDir).parent.path;
          final f = File('$sdkRootDir/lib/dev_compiler/amd/require.js');
          req.response.headers.contentType = ContentType.parse('application/javascript');
          req.response.add(f.readAsBytesSync());
          await req.response.close();
          return;
        }

        if (p == '/vendor/my-umd.js') {
          req.response.headers.contentType = ContentType.parse('application/javascript');
          req.response.write(umdBundleContent);
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
        await Future.delayed(const Duration(milliseconds: 500));

        final resJson = await page.evaluate(r'''
          (() => {
            const lib = window.myUmdLib;
            return JSON.stringify({
              exists: typeof lib !== 'undefined',
              hasHello: !!(lib && typeof lib.hello === 'function'),
              callResult: (lib && typeof lib.hello === 'function') ? lib.hello() : null
            });
          })()
        ''');

        final res = jsonDecode(resJson as String) as Map<String, dynamic>;
        print('  Test case "$testCase" result: $res');

        if (testCase == 'require_before_module') {
          // When require.js is loaded BEFORE the module script,
          // UMD detects define.amd and defines an AMD module instead of attaching to window.
          // Hence window.myUmdLib.hello does NOT exist.
          expect(res['hasHello'], isFalse,
              reason: 'UMD packages break if require.js loads before importmap modules');
        } else {
          // When require.js is loaded AFTER the module script,
          // window.myUmdLib is populated and working!
          expect(res['hasHello'], isTrue,
              reason: 'UMD packages work when require.js loads after importmap modules');
          expect(res['callResult'], equals('hello from UMD!'));
        }
      } finally {
        await browser?.close();
        await server.close();
      }
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
