import 'dart:io';
import 'dart:isolate';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloom_cli/src/upgrade/ui_symbols.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('bloomUiSymbols matches public top-level names exported by ui.dart',
      () async {
    // Resolve from this package's lib/ rather than the working directory,
    // which other tests in the same run change.
    final lib =
        await Isolate.resolvePackageUri(Uri.parse('package:bloom_cli/'));
    final entry = File(p.join(p.fromUri(lib!), '..', '..', 'bloom_js_native',
        'lib', 'src', 'ui.dart'));
    if (!entry.existsSync()) {
      markTestSkipped('The bloom_js_native monorepo package is not available.');
      return;
    }
    final source = entry.readAsStringSync();
    final exportedFiles = RegExp(r"export\s+'([^']+)'")
        .allMatches(source)
        .map((match) => File(p.join(entry.parent.path, match.group(1)!)))
        .toList();
    final names = <String>{};
    for (final file in exportedFiles) {
      final unit = parseString(
        content: file.readAsStringSync(),
        throwIfDiagnostics: false,
      ).unit;
      for (final declaration in unit.declarations) {
        final name = switch (declaration) {
          ClassDeclaration() => declaration.name.lexeme,
          EnumDeclaration() => declaration.name.lexeme,
          MixinDeclaration() => declaration.name.lexeme,
          // ignore: experimental_member_use
          ExtensionTypeDeclaration() => declaration.name.lexeme,
          GenericTypeAlias() => declaration.name.lexeme,
          FunctionDeclaration() => declaration.name.lexeme,
          TopLevelVariableDeclaration() => null,
          ExtensionDeclaration() => declaration.name?.lexeme,
          _ => null,
        };
        if (name != null && !name.startsWith('_')) names.add(name);
        if (declaration is TopLevelVariableDeclaration) {
          for (final variable in declaration.variables.variables) {
            final variableName = variable.name.lexeme;
            if (!variableName.startsWith('_')) names.add(variableName);
          }
        }
      }
    }
    expect(names, bloomUiSymbols);
  });
}
