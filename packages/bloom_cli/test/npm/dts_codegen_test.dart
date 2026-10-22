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
      expect(
          code,
          contains(
              "@JS('clsx')\nextension type Clsx(JSObject _) implements JSObject {"));

      // Best-effort guessed member inside the extension type (not top-level function)
      expect(code, contains("@JS('clsx')\n  external JSAny? clsx(["));

      // Generic callMethod escape hatch is available
      expect(code, contains('external JSAny? callMethod('));

      // The fictitious "Shadcn bridge" no longer appears
      expect(code, isNot(contains('Shadcn.render')));

      await tmp.parent.delete(recursive: true);
    });

    test(
        'falls back to a valid getter name when the JS global is not a valid identifier',
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
      expect(
          code,
          contains(
              "@JS('not a valid identifier')\nexternal ScopeWeirdPkg get scopeWeirdPkgGlobal;"));

      await tmp.parent.delete(recursive: true);
    });

    test('parses declare function and const declarations from .d.ts', () async {
      final dts = '''
export declare const cx: typeof clsx;
export declare function cva(base?: any, config?: any): (props?: any) => string;
''';
      final client = MockClient((req) async {
        if (req.url.toString() ==
            'https://esm.sh/class-variance-authority@0.7.1') {
          return http.Response('', 200, headers: {
            'x-typescript-types':
                'https://esm.sh/class-variance-authority@0.7.1/dist/index.d.ts',
          });
        }
        if (req.url.toString() ==
            'https://esm.sh/class-variance-authority@0.7.1/dist/index.d.ts') {
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

      expect(
          code,
          contains(
              "@JS('class_variance_authority')\nexternal ClassVarianceAuthority get class_variance_authority;"));
      expect(code, contains("@JS('cx')\n  external JSAny? cx(["));
      expect(
          code,
          contains(
              "@JS('cva')\n  external JSFunction cva([JSAny? base, JSAny? config]);"));

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
            'x-typescript-types':
                'https://esm.sh/tailwind-merge@3.6.0/dist/types.d.ts',
          });
        }
        if (req.url.toString() ==
            'https://esm.sh/tailwind-merge@3.6.0/dist/types.d.ts') {
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

      expect(
          code,
          contains(
              "@JS('tailwind_merge')\nexternal TailwindMerge get tailwind_merge;"));
      expect(
          code,
          contains(
              "@JS('createTailwindMerge')\n  external JSAny? createTailwindMerge(["));
      expect(
          code,
          contains(
              "@JS('extendTailwindMerge')\n  external JSAny? extendTailwindMerge(["));
      expect(code, contains("@JS('fromTheme')\n  external JSAny? fromTheme(["));
      expect(
          code,
          contains(
              "@JS('getDefaultConfig')\n  external JSAny? getDefaultConfig(["));
      expect(code,
          contains("@JS('mergeConfigs')\n  external JSAny? mergeConfigs(["));
      expect(code, contains("@JS('twJoin')\n  external JSAny? twJoin(["));
      expect(code, contains("@JS('twMerge')\n  external JSAny? twMerge(["));
      expect(
          code, contains("@JS('validators')\n  external JSAny? validators(["));

      // Aliased internal name and type exports should not appear as exported members
      expect(code, isNot(contains("@JS('validators_d')")));
      expect(code, isNot(contains("@JS('ClassNameValue')")));

      await tmp.parent.delete(recursive: true);
    });

    test(
        'follows barrel re-exports recursively and emits functions from re-exported files',
        () async {
      final barrelIndex = '''
export * from './animate';
export { inView } from './view';
''';
      final animateDts = '''
export declare function animate(element: string, keyframes: any, options?: any): Promise<any>;
''';
      final viewDts = '''
export declare function inView(element: string, onEnter: Function): Function;
''';

      final client = MockClient((req) async {
        final url = req.url.toString();
        if (url == 'https://esm.sh/motion@11.0.0') {
          return http.Response('', 200, headers: {
            'x-typescript-types':
                'https://esm.sh/motion@11.0.0/dist/index.d.ts',
          });
        }
        if (url == 'https://esm.sh/motion@11.0.0/dist/index.d.ts') {
          return http.Response(barrelIndex, 200);
        }
        if (url == 'https://esm.sh/motion@11.0.0/dist/animate.d.ts') {
          return http.Response(animateDts, 200);
        }
        if (url == 'https://esm.sh/motion@11.0.0/dist/view.d.ts') {
          return http.Response(viewDts, 200);
        }
        return http.Response('', 404);
      });

      final codegen = DtsCodegen(httpClient: client);
      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'motion',
        version: '11.0.0',
        outputPath: tmp.path,
        jsGlobalHint: 'motion',
      );
      final code = await tmp.readAsString();

      // Both animate and inView are discovered and emitted
      expect(
          code,
          contains(
              "@JS('animate')\n  external JSPromise<JSAny?> animate(String element, JSAny? keyframes, [JSAny? options]);"));
      expect(
          code,
          contains(
              "@JS('inView')\n  external JSFunction inView(String element, JSFunction onEnter);"));

      await tmp.parent.delete(recursive: true);
    });

    test(
        'maps parameter types and handles overloads by taking most parameters and making extras optional',
        () async {
      final dts = '''
export declare function configure(enabled: boolean, count: number, name: string): void;
export declare function calc(val: number): number;
export declare function calc(val: number, multiplier: number, offset?: number): number;
''';
      final client = MockClient((req) async {
        if (req.url.toString() == 'https://esm.sh/math-lib@1.0.0') {
          return http.Response('', 200, headers: {
            'x-typescript-types': 'https://esm.sh/math-lib@1.0.0/index.d.ts',
          });
        }
        if (req.url.toString() == 'https://esm.sh/math-lib@1.0.0/index.d.ts') {
          return http.Response(dts, 200);
        }
        return http.Response('', 404);
      });

      final codegen = DtsCodegen(httpClient: client);
      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'math-lib',
        version: '1.0.0',
        outputPath: tmp.path,
      );
      final code = await tmp.readAsString();

      // Primitives and void return
      expect(
          code,
          contains(
              "@JS('configure')\n  external void configure(bool enabled, num count, String name);"));
      // Overload with 3 parameters where parameters beyond shortest (length 1) become optional
      expect(
          code,
          contains(
              "@JS('calc')\n  external num calc(num val, [num? multiplier, num? offset]);"));

      await tmp.parent.delete(recursive: true);
    });

    test(
        'generates extension type with external factory and getters for primitive option objects',
        () async {
      final dts = '''
export interface AnimationOptions {
  duration?: number;
  delay?: number;
  ease?: string;
}
export interface ComplexOptions {
  callback: () => void;
}
export declare function animate(options?: AnimationOptions): void;
export declare function run(options?: ComplexOptions): void;
''';
      final client = MockClient((req) async {
        if (req.url.toString() == 'https://esm.sh/anim-pkg@1.0.0') {
          return http.Response('', 200, headers: {
            'x-typescript-types': 'https://esm.sh/anim-pkg@1.0.0/index.d.ts',
          });
        }
        if (req.url.toString() == 'https://esm.sh/anim-pkg@1.0.0/index.d.ts') {
          return http.Response(dts, 200);
        }
        return http.Response('', 404);
      });

      final codegen = DtsCodegen(httpClient: client);
      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'anim-pkg',
        version: '1.0.0',
        outputPath: tmp.path,
      );
      final code = await tmp.readAsString();

      // AnimationOptions has all primitive fields -> emits extension type
      expect(
          code,
          contains(
              "extension type AnimationOptions._(JSObject _) implements JSObject {"));
      expect(
          code,
          contains(
              "external factory AnimationOptions({num? duration, num? delay, String? ease});"));
      expect(code, contains("external num? get duration;"));
      expect(code, contains("external num? get delay;"));
      expect(code, contains("external String? get ease;"));
      expect(
          code,
          contains(
              "@JS('animate')\n  external void animate([AnimationOptions? options]);"));

      // ComplexOptions has non-primitive field -> keeps JSAny? and does not emit extension type
      expect(code, isNot(contains("extension type ComplexOptions")));
      expect(
          code, contains("@JS('run')\n  external void run([JSAny? options]);"));

      await tmp.parent.delete(recursive: true);
    });

    test(
        'falls back to ESM bundle text when declaration graph yields no exports',
        () async {
      // Mock client returns 404 for all .d.ts requests
      final client = MockClient((_) async => http.Response('', 404));
      final codegen = DtsCodegen(httpClient: client);

      // Create a temporary minified ESM bundle
      final bundleDir = await Directory.systemTemp.createTemp('bundle_test_');
      final bundleFile = File('${bundleDir.path}/bundle.js');
      await bundleFile
          .writeAsString('var a=1,b=2;export{a as animate,b as scroll};');

      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'motion-mini',
        version: '1.0.0',
        outputPath: tmp.path,
        bundlePath: bundleFile.path,
      );
      final code = await tmp.readAsString();

      expect(code,
          contains("/// Unknown signature from ESM bundle export `animate`."));
      expect(code, contains("@JS('animate')\n  external JSAny? animate(["));
      expect(code,
          contains("/// Unknown signature from ESM bundle export `scroll`."));
      expect(code, contains("@JS('scroll')\n  external JSAny? scroll(["));

      await bundleDir.delete(recursive: true);
      await tmp.parent.delete(recursive: true);
    });

    test(
        'prefers package metadata types entry over esm.sh x-typescript-types header',
        () async {
      final unpkgDts = '''
export declare function fromUnpkg(): string;
''';
      final esmHeaderDts = '''
export declare function fromEsmHeader(): string;
''';

      final client = MockClient((req) async {
        final url = req.url.toString();
        if (url == 'https://unpkg.com/meta-pkg@1.2.3/types/index.d.ts') {
          return http.Response(unpkgDts, 200);
        }
        if (url == 'https://esm.sh/meta-pkg@1.2.3') {
          return http.Response('', 200, headers: {
            'x-typescript-types':
                'https://esm.sh/meta-pkg@1.2.3/dist/index.d.ts',
          });
        }
        if (url == 'https://esm.sh/meta-pkg@1.2.3/dist/index.d.ts') {
          return http.Response(esmHeaderDts, 200);
        }
        return http.Response('', 404);
      });

      final codegen = DtsCodegen(httpClient: client);
      final tmp = await _tempFile();
      await codegen.generate(
        packageName: 'meta-pkg',
        version: '1.2.3',
        outputPath: tmp.path,
        typesEntry: './types/index.d.ts',
      );
      final code = await tmp.readAsString();

      // Should contain fromUnpkg, not fromEsmHeader
      expect(
          code, contains("@JS('fromUnpkg')\n  external String fromUnpkg();"));
      expect(code, isNot(contains('fromEsmHeader')));

      await tmp.parent.delete(recursive: true);
    });

    test('follows bare package exports and emits private declarations listed',
        () async {
      final client = MockClient((req) async {
        final url = Uri.decodeFull(req.url.toString());
        if (url == 'https://unpkg.com/root-pkg@1.0.0/index.d.ts') {
          return http.Response("export * from 'dep/dom';", 200);
        }
        if (url == 'https://unpkg.com/root-pkg@1.0.0/package.json') {
          return http.Response(
            '{"dependencies":{"dep":"^2.0.0"}}',
            200,
          );
        }
        if (url == 'https://unpkg.com/dep@^2.0.0/package.json') {
          return http.Response(
            '{"exports":{"./dom":{"types":"./dist/dom.d.ts",'
            '"default":"./dist/dom.mjs"}}}',
            200,
          );
        }
        if (url == 'https://unpkg.com/dep@^2.0.0/dist/dom.d.ts') {
          return http.Response('''
interface AnimOpts { duration?: number; }
declare function animate(el: string, opts?: AnimOpts): void;
declare function inView(element: string): void;
export { animate, inView };
export type { AnimOpts };
''', 200);
        }
        return http.Response('', 404);
      });

      final tmp = await _tempFile();
      await DtsCodegen(httpClient: client).generate(
        packageName: 'root-pkg',
        version: '1.0.0',
        outputPath: tmp.path,
        typesEntry: 'index.d.ts',
      );
      final code = await tmp.readAsString();

      expect(
        code,
        contains(
          "@JS('animate')\n  external void animate(String el, "
          '[AnimOpts? opts]);',
        ),
      );
      expect(
        code,
        contains("@JS('inView')\n  external void inView(String element);"),
      );
      expect(code, isNot(contains("@JS('AnimOpts')")));

      await tmp.parent.delete(recursive: true);
    });

    test('adds bundle exports when the declaration graph is sparse', () async {
      final client = MockClient((req) async {
        if (req.url.toString() == 'https://unpkg.com/sparse@1.0.0/index.d.ts') {
          return http.Response('export declare function animate(): void;', 200);
        }
        return http.Response('', 404);
      });
      final bundleDir = await Directory.systemTemp.createTemp('sparse_bundle_');
      final bundleFile = File('${bundleDir.path}/bundle.js');
      await bundleFile.writeAsString(
        'export{animate,scroll,stagger};',
      );
      final tmp = await _tempFile();

      await DtsCodegen(httpClient: client).generate(
        packageName: 'sparse',
        version: '1.0.0',
        outputPath: tmp.path,
        typesEntry: 'index.d.ts',
        bundlePath: bundleFile.path,
      );
      final code = await tmp.readAsString();

      expect(code, contains("@JS('animate')\n  external void animate();"));
      expect(
        code,
        contains("@JS('scroll')\n  external JSAny? scroll(["),
      );
      expect(code, contains("@JS('stagger')\n  external JSAny? stagger(["));

      await bundleDir.delete(recursive: true);
      await tmp.parent.delete(recursive: true);
    });

    test('parses nested callback and destructured parameters', () {
      const dts = '''
interface InViewOptions { amount?: number; }
export declare function inView(elementOrSelector: ElementOrSelector, onStart: (element: Element, entry: IntersectionObserverEntry) => void | ViewChangeHandler, { root, margin: rootMargin, amount }?: InViewOptions): VoidFunction;
export declare function scroll(onScroll: Function, { axis, source, container, ...options }?: ScrollOptions): VoidFunction;
''';
      final types = DtsCodegen.parseTypeDefinitions([dts]);
      final functions = DtsCodegen.parseDetailedFunctions([dts], types);

      expect(functions['inView']!.params, hasLength(3));
      expect(functions['inView']!.params[1].type, 'JSFunction');
      expect(functions['inView']!.params[2].isOptional, isTrue);
      expect(functions['scroll']!.params[1].dartName, 'options');
      expect(functions['scroll']!.params[1].isOptional, isTrue);
      expect(
        functions.values
            .expand((function) => function.params)
            .every((param) => !param.dartName.contains('__')),
        isTrue,
      );
    });

    test('merges callable const and repeated function overloads', () {
      const dts = '''
export declare const run: {
  (value: string, options?: Options): string;
  (value: number, keyframes: number[], options?: Options): number;
};
export declare function f(value: string): string;
export declare function f(value: number, extra: boolean = {}): number;
''';
      final types = DtsCodegen.parseTypeDefinitions([dts]);
      final functions = DtsCodegen.parseDetailedFunctions([dts], types);

      expect(functions['run']!.params, hasLength(3));
      expect(functions['run']!.params[0].type, 'JSAny?');
      expect(functions['run']!.params[1].isOptional, isTrue);
      expect(functions['run']!.returnType, 'JSAny?');
      expect(functions['f']!.params, hasLength(2));
      expect(functions['f']!.params[0].type, 'JSAny?');
      expect(functions['f']!.params[1].isOptional, isTrue);
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
