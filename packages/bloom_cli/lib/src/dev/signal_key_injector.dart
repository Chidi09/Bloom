// lib/src/dev/signal_key_injector.dart
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class _SignalCallReplacement {
  final int offset;
  final int end;
  final String text;

  const _SignalCallReplacement({
    required this.offset,
    required this.end,
    required this.text,
  });
}

class _SignalKeyVisitor extends RecursiveAstVisitor<void> {
  final String fileRelativePath;
  final String source;
  final List<_SignalCallReplacement> replacements = [];
  final Map<String, int> _declarationSignalCount = {};

  _SignalKeyVisitor({
    required this.fileRelativePath,
    required this.source,
  });

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _checkAndInject(node);
    super.visitMethodInvocation(node);
  }

  void _checkAndInject(MethodInvocation node) {
    if (node.methodName.name != 'signal') return;
    if (node.target != null) return;

    // 1. If key: named argument already exists, explicit developer key wins
    final args = node.argumentList.arguments;
    for (final arg in args) {
      if (arg is NamedExpression && arg.name.label.name == 'key') {
        return;
      }
    }

    // 2. If inside an anonymous closure / builder (e.g. Live(() => ...)), skip
    if (_isInsideAnonymousClosure(node)) {
      return;
    }

    // 3. Resolve enclosing declaration name
    final enclosingName = _resolveEnclosingDeclarationName(node);

    // 4. Compute ordinal scoped ONLY to this enclosing declaration
    final ordinal = _declarationSignalCount.update(
      enclosingName,
      (count) => count + 1,
      ifAbsent: () => 0,
    );

    // 5. Construct stable key
    final keyString = '$fileRelativePath#$enclosingName#$ordinal';
    final escapedKey = keyString.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

    // 6. Record source replacement
    if (args.isEmpty) {
      final offset = node.argumentList.leftParenthesis.end;
      replacements.add(_SignalCallReplacement(
        offset: offset,
        end: offset,
        text: "key: '$escapedKey'",
      ));
    } else {
      final lastArg = args.last;
      final between = source.substring(
        lastArg.end,
        node.argumentList.rightParenthesis.offset,
      );
      final commaIndex = between.indexOf(',');
      if (commaIndex != -1) {
        final offset = lastArg.end + commaIndex;
        replacements.add(_SignalCallReplacement(
          offset: offset,
          end: offset + 1,
          text: ", key: '$escapedKey',",
        ));
      } else {
        replacements.add(_SignalCallReplacement(
          offset: lastArg.end,
          end: lastArg.end,
          text: ", key: '$escapedKey'",
        ));
      }
    }
  }

  bool _isInsideAnonymousClosure(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionDeclaration) {
        return false;
      }
      if (current is MethodDeclaration ||
          current is ConstructorDeclaration ||
          current is FieldDeclaration ||
          current is TopLevelVariableDeclaration) {
        return false;
      }
      if (current is FunctionExpression) {
        if (current.parent is! FunctionDeclaration) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  String _resolveEnclosingDeclarationName(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        final varName = current.name.lexeme;
        final parent = current.parent;
        final grandParent = parent?.parent;
        if (grandParent is FieldDeclaration) {
          final className = _findEnclosingClassName(grandParent);
          return className != null ? '$className.$varName' : varName;
        } else if (grandParent is TopLevelVariableDeclaration) {
          return varName;
        }
      }
      if (current is MethodDeclaration) {
        final className = _findEnclosingClassName(current);
        final methodName = current.name.lexeme;
        return className != null ? '$className.$methodName' : methodName;
      }
      if (current is ConstructorDeclaration) {
        final className = _findEnclosingClassName(current);
        final ctorName = current.name?.lexeme ?? 'new';
        return className != null ? '$className.$ctorName' : ctorName;
      }
      if (current is FunctionDeclaration) {
        return current.name.lexeme;
      }
      if (current is ClassDeclaration) {
        return current.name.lexeme;
      }
      current = current.parent;
    }
    return 'top-level';
  }

  String? _findEnclosingClassName(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) return current.name.lexeme;
      if (current is MixinDeclaration) return current.name.lexeme;
      if (current is ExtensionDeclaration) return current.name?.lexeme ?? 'extension';
      if (current is EnumDeclaration) return current.name.lexeme;
      current = current.parent;
    }
    return null;
  }
}

/// AST transformation pass injecting stable compile-time keys into `signal(...)` calls.
///
/// Runs strictly ahead of DDC dev compilation to support state-preserving hot reload.
class SignalKeyInjector {
  /// Injects stable keys into `signal(...)` calls within [source].
  ///
  /// Returns the rewritten source text with `key: '...'` injected where applicable.
  /// If [source] contains syntax errors or no injectable `signal(...)` calls, returns
  /// the unmodified [source].
  static String injectKeys(String source, {String relativePath = 'lib/main.dart'}) {
    final parseResult = parseString(content: source, throwIfDiagnostics: false);
    if (parseResult.errors.isNotEmpty) {
      return source;
    }

    final visitor = _SignalKeyVisitor(
      fileRelativePath: relativePath.replaceAll(r'\', '/'),
      source: source,
    );
    parseResult.unit.accept(visitor);

    if (visitor.replacements.isEmpty) {
      return source;
    }

    // Apply replacements in reverse offset order so earlier offsets remain valid
    visitor.replacements.sort((a, b) => b.offset.compareTo(a.offset));
    var rewritten = source;
    for (final r in visitor.replacements) {
      rewritten = rewritten.substring(0, r.offset) + r.text + rewritten.substring(r.end);
    }
    return rewritten;
  }
}
