import 'dart:io';

import 'package:bloom_cli/src/npm/dts_codegen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DtsCodegen', () {
    test('emits fallback member and top-level getter when no .d.ts is found',
        () async {
      // clsx has no reachable .d.ts in this fake client, exercising the
      // no-dts fallback path.
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

      // Top-level global getter to obtain the namespace object instance
      expect(code, contains("@JS('clsx')\nexternal Clsx get clsx;"));

      // Extension type bound to the global
      expect(code, contains("@JS('clsx')\nextension type Clsx(JSObject _) implements JSObject {"));

      // Best-effort guessed member inside the extension type (not top-level function)
      expect(code, contains("@JS('clsx')\n  external JSAny? clsx(["));

      // Generic callMethod escape hatch is available
      expect(code, contains('external JSAny? callMethod('));

      // The fictitious "Shadcn bridge" no longer appears
      expect(code, isNot(contains('Shadcn.render')));

      await tmp.parent.delete(recursive: true);
    });

    test('falls back to a valid getter name when the JS global is not a valid identifier',
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

      // The raw global still appears inside the @JS annotation string,
      // and the Dart getter name falls back to a valid identifier.
      expect(code, contains("@JS('not a valid identifier')\nexternal ScopeWeirdPkg get scopeWeirdPkgGlobal;"));

      await tmp.parent.delete(recursive: true);
    });

    test('parses declare function and const declarations from .d.ts', () async {
      final dts = '''
export declare const cx: typeof clsx;
export declare function cva(base?: any, config?: any): (props?: any) => string;
''';
      final client = MockClient((req) async {
        if (req.url.toString() == 'https://esm.sh/class-variance-authority@0.7.1') {
          return http.Response('', 200, headers: {
            'x-typescript-types': 'https://esm.sh/class-variance-authority@0.7.1/dist/index.d.ts',
          });
        }
        if (req.url.toString() == 'https://esm.sh/class-variance-authority@0.7.1/dist/index.d.ts') {
          return http.Response(dts, 200);
        }
        return http.Response('', 404);
      });

      final codegen = DtsCodegen(httpClient: client);
      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'class-variance-authority',
        version: '0.7.1',
        outputPath: tmp.path,
        jsGlobalHint: 'class_variance_authority',
      );
      final code = await tmp.readAsString();

      expect(code, contains("@JS('class_variance_authority')\nexternal ClassVarianceAuthority get class_variance_authority;"));
      expect(code, contains("@JS('cx')\n  external JSAny? cx(["));
      expect(code, contains("@JS('cva')\n  external JSAny? cva(["));

      await tmp.parent.delete(recursive: true);
    });

    test('parses barrel re-exports of the form export { a, b as c }', () async {
      final dts = '''
declare const twMerge: (...classLists: any[]) => string;
declare const validators_d_isAny: () => boolean;
export { createTailwindMerge, extendTailwindMerge, fromTheme, getDefaultConfig, mergeConfigs, twJoin, twMerge, validators_d as validators };
export type { ClassNameValue, Config };
''';
      final client = MockClient((req) async {
        if (req.url.toString() == 'https://esm.sh/tailwind-merge@3.6.0') {
          return http.Response('', 200, headers: {
            'x-typescript-types': 'https://esm.sh/tailwind-merge@3.6.0/dist/types.d.ts',
          });
        }
        if (req.url.toString() == 'https://esm.sh/tailwind-merge@3.6.0/dist/types.d.ts') {
          return http.Response(dts, 200);
        }
        return http.Response('', 404);
      });

      final codegen = DtsCodegen(httpClient: client);
      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'tailwind-merge',
        version: '3.6.0',
        outputPath: tmp.path,
        jsGlobalHint: 'tailwind_merge',
      );
      final code = await tmp.readAsString();

      expect(code, contains("@JS('tailwind_merge')\nexternal TailwindMerge get tailwind_merge;"));
      expect(code, contains("@JS('createTailwindMerge')\n  external JSAny? createTailwindMerge(["));
      expect(code, contains("@JS('extendTailwindMerge')\n  external JSAny? extendTailwindMerge(["));
      expect(code, contains("@JS('fromTheme')\n  external JSAny? fromTheme(["));
      expect(code, contains("@JS('getDefaultConfig')\n  external JSAny? getDefaultConfig(["));
      expect(code, contains("@JS('mergeConfigs')\n  external JSAny? mergeConfigs(["));
      expect(code, contains("@JS('twJoin')\n  external JSAny? twJoin(["));
      expect(code, contains("@JS('twMerge')\n  external JSAny? twMerge(["));
      expect(code, contains("@JS('validators')\n  external JSAny? validators(["));

      // Aliased internal name and type exports should not appear as exported members
      expect(code, isNot(contains("@JS('validators_d')")));
      expect(code, isNot(contains("@JS('ClassNameValue')")));

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

