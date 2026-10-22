// lib/src/lint/bloom_lint.dart
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;
import '../utils/project.dart';

class LintFinding {
  final String filePath;
  final int lineNumber;
  final String ruleName;
  final String message;
  final String snippet;

  LintFinding({
    required this.filePath,
    required this.lineNumber,
    required this.ruleName,
    required this.message,
    required this.snippet,
  });
}

class LintResult {
  final List<LintFinding> findings;
  final int scannedFilesCount;

  LintResult({required this.findings, required this.scannedFilesCount});

  bool get hasFindings => findings.isNotEmpty;
}

/// Bloom-specific lint rules for `bloom_js_native` projects, grounded in the
/// pitfalls documented in COOKBOOK.md Section 20.
class BloomLinter {
  final BloomProject project;

  BloomLinter(this.project);

  Future<LintResult> lint() async {
    final root = project.rootDir.path;
    final findings = <LintFinding>[];
    int scanned = 0;

    final packageConfig =
        File(p.join(root, '.dart_tool', 'package_config.json'));
    AnalysisContextCollection? collection;
    if (packageConfig.existsSync()) {
      try {
        collection = AnalysisContextCollection(includedPaths: [root]);
      } catch (_) {
        collection = null;
      }
    }

    for (final dirName in ['lib', 'test', 'bin']) {
      final dir = Directory(p.join(root, dirName));
      if (!dir.existsSync()) continue;

      for (final file in dir.listSync(recursive: true, followLinks: false)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        // Generated bindings from `bloom add npm:<pkg>` are not hand-authored;
        // skip them so lint never flags code developers didn't write.
        if (p.isWithin(p.join(root, 'lib', 'src', 'plugins'), file.path))
          continue;

        scanned++;
        final relPath = p.relative(file.path, from: root).replaceAll('\\', '/');
        final content = file.readAsStringSync();
        Map<int, bool>? resolvedSignals;
        if (collection != null) {
          try {
            final result = await collection
                .contextFor(file.path)
                .currentSession
                .getResolvedUnit(file.path);
            if (result is ResolvedUnitResult) {
              resolvedSignals = _resolvedSignalValueReads(result.unit);
            }
          } catch (_) {
            resolvedSignals = null;
          }
        }
        findings.addAll(lintDartSource(
          content,
          filePath: relPath,
          resolvedSignalReads: resolvedSignals,
        ));
      }
    }

    final indexHtml = File(p.join(root, 'web', 'index.html'));
    if (indexHtml.existsSync() && _isWebDomTarget()) {
      scanned++;
      final relPath =
          p.relative(indexHtml.path, from: root).replaceAll('\\', '/');
      final content = indexHtml.readAsStringSync();
      findings.addAll(lintHtmlSource(
        content,
        filePath: relPath,
        isWebDom: true,
        webDir: Directory(p.join(root, 'web')),
      ));
    }

    await collection?.dispose();

    return LintResult(findings: findings, scannedFilesCount: scanned);
  }

  bool _isWebDomTarget() {
    if (!project.bloomYamlFile.existsSync()) return false;
    final content = project.bloomYamlFile.readAsStringSync();
    return content.contains('target: web_dom') ||
        content.contains('target: "web_dom"');
  }

  /// Lints a Dart source string using analyzer parse-only AST traversal.
  static List<LintFinding> lintDartSource(String source,
      {String filePath = 'lib/main.dart',
      Map<int, bool>? resolvedSignalReads}) {
    final parseResult = parseString(content: source, throwIfDiagnostics: false);
    final visitor = _BloomLintVisitor(
      filePath: filePath,
      lineInfo: parseResult.lineInfo,
      source: source,
      resolvedSignalReads: resolvedSignalReads,
    );
    parseResult.unit.accept(visitor);
    return visitor.findings;
  }

  /// Lints web/index.html content for non-SSR/non-Dart stylesheet/style tags.
  static List<LintFinding> lintHtmlSource(
    String source, {
    String filePath = 'web/index.html',
    bool isWebDom = true,
    Directory? webDir,
  }) {
    if (!isWebDom) return [];
    final findings = <LintFinding>[];
    final sanitized = source.replaceAllMapped(
      RegExp(r'<!--.*?-->|<script\b[^>]*>.*?</script\s*>',
          caseSensitive: false, dotAll: true),
      (match) => match.group(0)!.replaceAll(RegExp(r'[^\n]'), ' '),
    );
    final lines = sanitized.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'<style\b', caseSensitive: false).hasMatch(line)) {
        findings.add(LintFinding(
          filePath: filePath,
          lineNumber: i + 1,
          ruleName: 'hand_authored_style_in_index_html',
          message:
              'web/index.html should stay near-empty (meta tags, SEO content, and the main.js '
              'script only). Design tokens belong in lib/design/tokens.dart injected via '
              'Style(), and fonts should be wired with `bloom fonts optimize` + '
              'fontStylesheetLink() — see COOKBOOK.md Section 19, or move the CSS into a file under web/ and link it with <link rel="stylesheet">.',
          snippet: line.trim(),
        ));
      }
      final linkPattern = RegExp(r'<link\b[^>]*>', caseSensitive: false);
      for (final link in linkPattern.allMatches(line)) {
        final tag = link.group(0)!;
        if (!RegExp(r'\brel\s*=\s*["\x27]stylesheet["\x27]',
                caseSensitive: false)
            .hasMatch(tag)) continue;
        final hrefMatch = RegExp(r'\bhref\s*=\s*["\x27]([^"\x27]*)["\x27]',
                caseSensitive: false)
            .firstMatch(tag);
        if (hrefMatch == null || webDir == null) continue;
        final href = hrefMatch.group(1)!;
        if (RegExp(r'^(https?:)?//', caseSensitive: false).hasMatch(href)) {
          continue;
        }
        final localPath = href.split(RegExp(r'[?#]')).first;
        final target = File(p.normalize(p.join(webDir.path,
            localPath.startsWith('/') ? localPath.substring(1) : localPath)));
        if (p.isWithin(webDir.path, target.path) && target.existsSync()) {
          continue;
        }
        findings.add(LintFinding(
          filePath: filePath,
          lineNumber: i + 1,
          ruleName: 'missing_stylesheet',
          message: "Stylesheet '$href' not found under web/.",
          snippet: line.trim(),
        ));
      }
    }

    return findings;
  }

  static Map<int, bool> _resolvedSignalValueReads(CompilationUnit unit) {
    final reads = <int, bool>{};
    unit.accept(_ResolvedSignalReadCollector(reads));
    return reads;
  }
}

class _ResolvedSignalReadCollector extends RecursiveAstVisitor<void> {
  final Map<int, bool> reads;

  _ResolvedSignalReadCollector(this.reads);

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'value') {
      reads[node.offset] = _isSignalsCoreReadonlySignal(node.prefix.staticType);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'value') {
      reads[node.offset] =
          _isSignalsCoreReadonlySignal(node.realTarget.staticType);
    }
    super.visitPropertyAccess(node);
  }

  bool _isSignalsCoreReadonlySignal(DartType? type) {
    if (type is! InterfaceType) return false;
    for (final candidate in [type, ...type.allSupertypes]) {
      // The element model is mid-migration in analyzer 7 (element3 is still
      // experimental), so use the stable-but-deprecated accessors.
      // ignore: deprecated_member_use
      final element = candidate.element;
      if (element.name == 'ReadonlySignal' &&
          // ignore: deprecated_member_use
          element.library.source.uri
              .toString()
              .startsWith('package:signals_core/')) {
        return true;
      }
    }
    return false;
  }
}

class _BloomLintVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;
  final String source;
  final Map<int, bool>? resolvedSignalReads;
  final Set<String> _signalIdentifiers = {};
  final List<LintFinding> findings = [];

  final List<bool> _functionUiStack = [];
  int _exemptedDepth = 0;

  bool get _isInsideUiFunction =>
      _functionUiStack.isNotEmpty && _functionUiStack.last;

  static const Set<String> _inPlaceMutationMethods = {
    'add',
    'addAll',
    'remove',
    'removeAt',
    'removeLast',
    'removeWhere',
    'insert',
    'clear',
    'sort',
    'shuffle',
    'retainWhere',
  };

  static const Set<String> _eventParamNames = {
    'e',
    'ev',
    'evt',
    'event',
  };

  static const Set<String> _fullyExemptedCalls = {
    'Live',
    'LiveNode',
    'ForEach',
    'ForEachNode',
    'Memo',
    'MemoNode',
    'effect',
    'addEffect',
    'computed',
    'addEventListener',
    'subscribe',
  };

  static const Set<String> _knownUiNodeTypes = {
    'BloomNode',
    'ElNode',
    'TextNode',
    'FragmentNode',
    'LiveNode',
    'ShowNode',
    'ForEachNode',
    'MemoNode',
    'StyleNode',
    'RawHtmlNode',
    'AnimatedNode',
    'MountNode',
    'RefNode',
    'ContextProviderNode',
    'ErrorBoundaryNode',
    'PortalNode',
    'SuspenseNode',
    'Div',
    'Span',
    'Button',
    'Input',
    'Form',
    'H1',
    'H2',
    'H3',
    'H4',
    'H5',
    'H6',
    'P',
    'Ul',
    'Ol',
    'Li',
    'A',
    'Nav',
    'Header',
    'Footer',
    'Section',
    'Main',
    'Aside',
    'Article',
    'Table',
    'Thead',
    'Tbody',
    'Tr',
    'Th',
    'Td',
    'Label',
    'Select',
    'Option',
    'Textarea',
    'Img',
    'Svg',
    'Path',
    'Fragment',
    'Text',
    'Live',
    'Show',
    'ForEach',
    'Memo',
    'Raw',
    'Style',
    'Mount',
  };

  _BloomLintVisitor({
    required this.filePath,
    required this.lineInfo,
    required this.source,
    required this.resolvedSignalReads,
  }) {
    parseString(content: source, throwIfDiagnostics: false)
        .unit
        .accept(_SignalDeclarationCollector(_signalIdentifiers));
  }

  String _getSnippet(AstNode node) {
    final lineNumber = lineInfo.getLocation(node.offset).lineNumber;
    final lineStarts = lineInfo.lineStarts;
    final lineStart = lineStarts[lineNumber - 1];
    final lineEnd = lineNumber < lineStarts.length
        ? lineStarts[lineNumber] - 1
        : source.length;
    return source.substring(lineStart, lineEnd).trim();
  }

  bool _isUiTypeName(String typeName) {
    final clean = typeName.replaceAll('?', '').trim();
    if (_knownUiNodeTypes.contains(clean)) return true;
    if (clean.contains('BloomNode') || clean.contains('ElNode')) return true;
    if (clean.endsWith('Node')) return true;
    return false;
  }

  bool _expressionIsUiNode(Expression expr) {
    if (expr is InstanceCreationExpression) {
      return _isUiTypeName(expr.constructorName.type.name2.lexeme);
    }
    if (expr is MethodInvocation) {
      return _isUiTypeName(expr.methodName.name);
    }
    return false;
  }

  bool _bodyReturnsUiNode(FunctionBody body) {
    if (body is ExpressionFunctionBody) {
      return _expressionIsUiNode(body.expression);
    }
    if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        if (statement is ReturnStatement && statement.expression != null) {
          if (_expressionIsUiNode(statement.expression!)) return true;
        }
      }
    }
    return false;
  }

  bool _isUiDeclaration({
    TypeAnnotation? returnType,
    required FunctionBody body,
  }) {
    if (returnType != null) {
      return _isUiTypeName(returnType.toSource());
    }
    return _bodyReturnsUiNode(body);
  }

  bool _isNonSignalReceiver(AstNode node, String receiverName) {
    if (_eventParamNames.contains(receiverName)) return true;
    if (_isEnclosingEventParam(node, receiverName)) return true;
    return !_signalIdentifiers.contains(receiverName);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final isUi = _isUiDeclaration(
      returnType: node.returnType,
      body: node.functionExpression.body,
    );
    _functionUiStack.add(isUi);
    super.visitFunctionDeclaration(node);
    _functionUiStack.removeLast();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final isUi = _isUiDeclaration(
      returnType: node.returnType,
      body: node.body,
    );
    _functionUiStack.add(isUi);
    super.visitMethodDeclaration(node);
    _functionUiStack.removeLast();
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) {
      final isUi = _bodyReturnsUiNode(node.body);
      _functionUiStack.add(isUi);
      super.visitFunctionExpression(node);
      _functionUiStack.removeLast();
    } else {
      super.visitFunctionExpression(node);
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent;
    TypeAnnotation? type;
    if (parent is VariableDeclarationList) {
      type = parent.type;
    }
    final isUi = (type != null && _isUiTypeName(type.toSource())) ||
        (node.initializer != null && _expressionIsUiNode(node.initializer!));
    if (isUi) {
      _functionUiStack.add(true);
      super.visitVariableDeclaration(node);
      _functionUiStack.removeLast();
    } else {
      super.visitVariableDeclaration(node);
    }
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if (name == 'className') {
      _checkConflictingClasses(node.expression);
    }
    final isEventHandler = (name.startsWith('on') &&
            name.length > 2 &&
            name[2].toUpperCase() == name[2]) ||
        name == 'on' ||
        name == 'onMount' ||
        name == 'onUnmount' ||
        name == 'onDispose' ||
        name == 'onInit' ||
        name == 'key';
    if (isEventHandler) {
      _exemptedDepth++;
      super.visitNamedExpression(node);
      _exemptedDepth--;
    } else {
      super.visitNamedExpression(node);
    }
  }

  // 1. nullable_event_force_unwrap
  @override
  void visitPostfixExpression(PostfixExpression node) {
    super.visitPostfixExpression(node);

    if (node.operator.lexeme != '!') return;

    final operand = node.operand;
    String? propName;
    String? receiverName;

    if (operand is PropertyAccess) {
      propName = operand.propertyName.name;
      final target = operand.realTarget;
      if (target is SimpleIdentifier) {
        receiverName = target.name;
      }
    } else if (operand is PrefixedIdentifier) {
      propName = operand.identifier.name;
      receiverName = operand.prefix.name;
    }

    if (propName != 'value' && propName != 'checked') return;
    if (receiverName == null) return;

    // Parse-only syntactic heuristic for BloomEvent receivers (type resolution unavailable without package_config).
    if (_isEnclosingEventParam(node, receiverName)) {
      findings.add(LintFinding(
        filePath: filePath,
        lineNumber: lineInfo.getLocation(node.offset).lineNumber,
        ruleName: 'nullable_event_force_unwrap',
        message:
            'BloomEvent.value and BloomEvent.checked are both nullable (String?/bool?) — '
            'force-unwrapping with `!` will throw at runtime on events where the field is '
            'legitimately null (e.g. non-input targets). Use `e.value ?? ""` or a null check.',
        snippet: _getSnippet(node),
      ));
    }
  }

  bool _isEnclosingEventParam(AstNode node, String name) {
    AstNode? current = node.parent;
    while (current != null) {
      FormalParameterList? params;
      if (current is FunctionExpression) {
        params = current.parameters;
      } else if (current is MethodDeclaration) {
        params = current.parameters;
      } else if (current is FunctionDeclaration) {
        params = current.functionExpression.parameters;
      }

      if (params != null) {
        for (final p in params.parameters) {
          final paramName = p.name?.lexeme;
          if (paramName == name) {
            // Check type annotation if present
            if (p is SimpleFormalParameter && p.type != null) {
              final typeStr = p.type!.toSource();
              if (typeStr.contains('BloomEvent')) return true;
              return false;
            }
            if (p is DefaultFormalParameter) {
              final normal = p.parameter;
              if (normal is SimpleFormalParameter && normal.type != null) {
                final typeStr = normal.type!.toSource();
                if (typeStr.contains('BloomEvent')) return true;
                return false;
              }
            }
            // If untyped, match conventional event parameter names
            if (_eventParamNames.contains(name)) {
              return true;
            }
            return false;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  void _visitShowArguments(ArgumentList argumentList) {
    for (var i = 0; i < argumentList.arguments.length; i++) {
      final arg = argumentList.arguments[i];
      if (i == 0 && arg is! NamedExpression) {
        _exemptedDepth++;
        arg.accept(this);
        _exemptedDepth--;
      } else if (arg is NamedExpression && arg.name.label.name == 'when') {
        _exemptedDepth++;
        arg.accept(this);
        _exemptedDepth--;
      } else {
        arg.accept(this);
      }
    }
  }

  // 2. foreach_missing_key
  // 4. live_never_reads_signal
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    if (_fullyExemptedCalls.contains(typeName)) {
      _exemptedDepth++;
      super.visitInstanceCreationExpression(node);
      _exemptedDepth--;
    } else if (typeName == 'Show' || typeName == 'ShowNode') {
      node.constructorName.accept(this);
      _visitShowArguments(node.argumentList);
    } else {
      super.visitInstanceCreationExpression(node);
    }

    _checkForEachAndLive(
      typeName: typeName,
      argumentList: node.argumentList,
      anchor: node,
    );
  }

  void _checkForEachAndLive({
    required String typeName,
    required ArgumentList argumentList,
    required AstNode anchor,
  }) {
    if (typeName == 'ForEach') {
      final hasKey = argumentList.arguments.any(
        (a) => a is NamedExpression && a.name.label.name == 'key',
      );
      if (!hasKey) {
        findings.add(LintFinding(
          filePath: filePath,
          lineNumber: lineInfo.getLocation(anchor.offset).lineNumber,
          ruleName: 'foreach_missing_key',
          message:
              'ForEach<T>(...) without a `key:` extractor rebuilds every item on updates, '
              'losing focus, form input state, and local effects. '
              'Pass `key: (item) => item.id` or similar.',
          snippet: _getSnippet(anchor),
        ));
      }
    }

    if (typeName == 'Live') {
      FunctionExpression? builder;
      for (final arg in argumentList.arguments) {
        if (arg is FunctionExpression) {
          builder = arg;
          break;
        } else if (arg is NamedExpression &&
            arg.expression is FunctionExpression) {
          builder = arg.expression as FunctionExpression;
          break;
        }
      }

      if (builder != null) {
        final signalChecker = _SignalValueReadChecker();
        builder.body.accept(signalChecker);
        if (!signalChecker.hasSignalValueRead) {
          findings.add(LintFinding(
            filePath: filePath,
            lineNumber: lineInfo.getLocation(anchor.offset).lineNumber,
            ruleName: 'live_never_reads_signal',
            message:
                "Live(...) builder never reads any signal's .value property — "
                'Live creates a reactive subscription only when signals are accessed inside its builder. '
                "If this subtree is static, remove Live(...); if dynamic, access a signal's .value.",
            snippet: _getSnippet(anchor),
          ));
        }
      }
    }
  }

  // 3. browser_import_in_test & forbidden_browser_import_in_shared_code
  @override
  void visitImportDirective(ImportDirective node) {
    super.visitImportDirective(node);

    final uri = node.uri.stringValue;
    if (uri == null || !uri.endsWith('bloom_js_native/browser.dart')) return;

    final isTestFile = filePath.startsWith('test/') ||
        filePath.startsWith('test\\') ||
        p.split(filePath).contains('test');

    if (isTestFile) {
      findings.add(LintFinding(
        filePath: filePath,
        lineNumber: lineInfo.getLocation(node.offset).lineNumber,
        ruleName: 'browser_import_in_test',
        message:
            "Importing 'package:bloom_js_native/browser.dart' in a test file requires a real DOM "
            '(dart test --platform chrome) and will fail under the default VM test runner. '
            "Import 'package:bloom_js_native/bloom_js_native.dart' (the SSR-safe core) instead "
            'unless this test is deliberately browser-only.',
        snippet: _getSnippet(node),
      ));
    }

    final normalizedPath = filePath.replaceAll('\\', '/');
    final isAllowed =
        normalizedPath == 'lib/main.dart' || normalizedPath.startsWith('web/');
    if (!isAllowed) {
      findings.add(LintFinding(
        filePath: filePath,
        lineNumber: lineInfo.getLocation(node.offset).lineNumber,
        ruleName: 'forbidden_browser_import_in_shared_code',
        message:
            "Importing 'package:bloom_js_native/browser.dart' requires a real browser DOM "
            'and is only permitted in the browser entry point (lib/main.dart) or files under web/. '
            'Shared components, SSR routes, and library code must import '
            "'package:bloom_js_native/bloom_js_native.dart' (the SSR-safe core) instead.",
        snippet: _getSnippet(node),
      ));
    }
  }

  // 5. inplace_signal_collection_mutation
  //
  // Also handles rules 2/4 (foreach_missing_key, live_never_reads_signal):
  // parse-only mode (no resolved element model) cannot tell a generic
  // function call apart from an implicit-`new` constructor call — analyzer
  // parses `ForEach<T>(...)`/`Live(...)` as MethodInvocation, not
  // InstanceCreationExpression, unless resolution is available. Both node
  // shapes must be checked so those rules actually fire on real Bloom code.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (node.target == null && _fullyExemptedCalls.contains(methodName)) {
      _exemptedDepth++;
      super.visitMethodInvocation(node);
      _exemptedDepth--;
    } else if (node.target == null &&
        (methodName == 'Show' || methodName == 'ShowNode')) {
      node.methodName.accept(this);
      node.typeArguments?.accept(this);
      _visitShowArguments(node.argumentList);
    } else {
      super.visitMethodInvocation(node);
    }

    if (node.target == null) {
      _checkForEachAndLive(
        typeName: methodName,
        argumentList: node.argumentList,
        anchor: node,
      );
    }

    if (!_inPlaceMutationMethods.contains(methodName)) return;

    final target = node.target;
    var targetHasValueProp = false;

    if (target is PropertyAccess) {
      targetHasValueProp = target.propertyName.name == 'value';
    } else if (target is PrefixedIdentifier) {
      targetHasValueProp = target.identifier.name == 'value';
    }

    if (targetHasValueProp) {
      findings.add(LintFinding(
        filePath: filePath,
        lineNumber: lineInfo.getLocation(node.offset).lineNumber,
        ruleName: 'inplace_signal_collection_mutation',
        message:
            "Mutating a signal's collection in place (e.g. `signal.value.add(...)`) does not notify "
            'subscribers because the identity of .value did not change. '
            'Reassign .value instead: `signal.value = [...signal.value, item]`.',
        snippet: _getSnippet(node),
      ));
    }
  }

  // 8. untracked_signal_read
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);

    if (node.identifier.name != 'value') return;
    _checkUntrackedSignalRead(node, receiverName: node.prefix.name);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    super.visitPropertyAccess(node);

    if (node.propertyName.name != 'value') return;
    final target = node.realTarget;
    final receiverName = target is SimpleIdentifier ? target.name : null;
    _checkUntrackedSignalRead(node, receiverName: receiverName);
  }

  void _checkUntrackedSignalRead(AstNode node, {String? receiverName}) {
    if (!_isInsideUiFunction) return;
    if (_exemptedDepth > 0) return;

    if (resolvedSignalReads != null) {
      if (resolvedSignalReads![node.offset] != true) return;
    } else if (receiverName == null ||
        !_signalIdentifiers.contains(receiverName)) {
      return;
    }

    // Ignore pure assignments to .value (e.g. `signal.value = x`)
    final parent = node.parent;
    if (parent is AssignmentExpression &&
        parent.leftHandSide == node &&
        parent.operator.lexeme == '=') {
      return;
    }

    if (resolvedSignalReads == null &&
        receiverName != null &&
        _isNonSignalReceiver(node, receiverName)) {
      return;
    }

    findings.add(LintFinding(
      filePath: filePath,
      lineNumber: lineInfo.getLocation(node.offset).lineNumber,
      ruleName: 'untracked_signal_read',
      message:
          "Reading a signal's `.value` directly inside a UI-building function outside "
          'Live(...), Show(...), ForEach(...), lazy(...), effect(...), or computed(...) captures a '
          'one-time snapshot rather than creating a reactive subscription — the UI will '
          'not update when the signal changes. Wrap dynamic UI reads in Live(() => ...) '
          '(see COOKBOOK.md Section 20).',
      snippet: _getSnippet(node),
    ));
  }

  void _checkConflictingClasses(Expression expression) {
    final literals = <SimpleStringLiteral>[];
    if (expression is SimpleStringLiteral) {
      literals.add(expression);
    } else if (expression is MethodInvocation &&
        (expression.methodName.name == 'cn' ||
            expression.methodName.name == 'cx') &&
        expression.argumentList.arguments.isNotEmpty &&
        expression.argumentList.arguments.first is ListLiteral) {
      final list = expression.argumentList.arguments.first as ListLiteral;
      for (final element in list.elements) {
        if (element is SimpleStringLiteral) literals.add(element);
      }
    }
    final seen = <String, String>{};
    for (final literal in literals) {
      for (final token in literal.value.split(RegExp(r'\s+'))) {
        final pieces = token.split(':');
        final utility = pieces.removeLast();
        final group = _tailwindConflictGroup[utility];
        if (group == null) continue;
        final key = '${pieces.join(':')}|$group';
        final previous = seen[key];
        if (previous != null && previous != utility) {
          findings.add(LintFinding(
            filePath: filePath,
            lineNumber: lineInfo.getLocation(literal.offset).lineNumber,
            ruleName: 'conflicting_classes',
            message:
                "'$previous' and '$utility' conflict; the one defined later in Tailwind's CSS wins regardless of order. Remove one or use a responsive/state prefix.",
            snippet: _getSnippet(literal),
          ));
        }
        seen[key] = utility;
      }
    }
  }
}

const Map<String, String> _tailwindConflictGroup = {
  'block': 'display',
  'inline-block': 'display',
  'inline': 'display',
  'flex': 'display',
  'inline-flex': 'display',
  'grid': 'display',
  'inline-grid': 'display',
  'hidden': 'display',
  'contents': 'display',
  'table': 'display',
  'static': 'position',
  'fixed': 'position',
  'absolute': 'position',
  'relative': 'position',
  'sticky': 'position',
  'visible': 'visibility',
  'invisible': 'visibility',
  'collapse': 'visibility',
  'flex-row': 'flex-direction',
  'flex-row-reverse': 'flex-direction',
  'flex-col': 'flex-direction',
  'flex-col-reverse': 'flex-direction',
  'text-left': 'text-align',
  'text-center': 'text-align',
  'text-right': 'text-align',
  'text-justify': 'text-align',
  'text-start': 'text-align',
  'text-end': 'text-align',
  'font-thin': 'font-weight',
  'font-extralight': 'font-weight',
  'font-light': 'font-weight',
  'font-normal': 'font-weight',
  'font-medium': 'font-weight',
  'font-semibold': 'font-weight',
  'font-bold': 'font-weight',
  'font-extrabold': 'font-weight',
  'font-black': 'font-weight',
};

class _SignalDeclarationCollector extends RecursiveAstVisitor<void> {
  final Set<String> names;

  _SignalDeclarationCollector(this.names);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final declarationList = node.parent;
    if (declarationList is VariableDeclarationList) {
      final declaredType = declarationList.type?.toSource() ?? '';
      final initializer = node.initializer;
      final signalInitializer = initializer is MethodInvocation &&
          {'signal', 'computed', 'readonly'}
              .contains(initializer.methodName.name);
      if (_isSignalType(declaredType) || signalInitializer) {
        names.add(node.name.lexeme);
      }
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    if (_isSignalType(node.type?.toSource() ?? '') && node.name != null) {
      names.add(node.name!.lexeme);
    }
    super.visitSimpleFormalParameter(node);
  }

  bool _isSignalType(String type) =>
      RegExp(r'\b(Signal|Computed|ReadonlySignal)\s*<').hasMatch(type);
}

class _SignalValueReadChecker extends RecursiveAstVisitor<void> {
  bool hasSignalValueRead = false;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'value') {
      hasSignalValueRead = true;
      return;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'value') {
      hasSignalValueRead = true;
      return;
    }
    super.visitPrefixedIdentifier(node);
  }
}
