import 'dart:io';

import 'package:bloom_cli/src/npm/dts_codegen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DtsCodegen', () {
    test('emits a callable top-level binding alongside the extension type',
        () async {
      // clsx has no reachable .d.ts in this fake client, exercising the
      // no-dts fallback path -- the callable binding must still appear,
      // since that path is the one real npm.add hits whenever esm.sh is
      // unreachable or the package ships no types.
      final client = MockClient((_) async => http.Response('', 404));
      final codegen = DtsCodegen(httpClient: client);

      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'clsx',
        version: '2.1.1',
        outputPath: tmp.path,
        jsGlobalHint: 'clsx',
      );
      final code = await tmp.readAsString();

      // The callable form: clsx's default export is a bare function, so a
      // Dart caller must be able to invoke it directly without a method name.
      expect(code, contains("@JS('clsx')"));
      expect(code, contains('external JSAny? clsx(['));

      // The object form stays available for packages that do export methods.
      expect(code, contains('extension type Clsx(JSObject _)'));
      expect(code, contains('external JSAny? callMethod('));

      // The fictitious "Shadcn bridge" no longer appears -- no such bridge
      // exists anywhere in the framework.
      expect(code, isNot(contains('Shadcn.render')));

      await tmp.parent.delete(recursive: true);
    });

    test('falls back to a wrapper name when the JS global is not a valid identifier',
        () async {
      final client = MockClient((_) async => http.Response('', 404));
      final codegen = DtsCodegen(httpClient: client);

      final tmp = await _tempFile();
      await codegen.generate(
        packageName: '@scope/weird-pkg',
        version: '1.0.0',
        outputPath: tmp.path,
        jsGlobalHint: 'not a valid identifier',
      );
      final code = await tmp.readAsString();

      // The raw global still appears only inside the @JS annotation string,
      // never as the emitted Dart function name.
      expect(code, contains("external JSAny? scopeWeirdPkgCall(["));

      await tmp.parent.delete(recursive: true);
    });
  });
}

Future<_TempFileHandle> _tempFile() async {
  final dir = await Directory.systemTemp.createTemp('dts_codegen_test_');
  return _TempFileHandle(File('${dir.path}/out.dart'));
}

class _TempFileHandle {
  final File file;
  _TempFileHandle(this.file);
  String get path => file.path;
  Directory get parent => file.parent;
  Future<String> readAsString() => file.readAsString();
}
