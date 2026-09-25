// lib/src/dev/signal_key_injector.dart
import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:crypto/crypto.dart';

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

class _SignalImport {
  final String? prefix;

  const _SignalImport(this.prefix);
}

class _DeclaredNameVisitor extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    names.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    names.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    names.add(node.name.lexeme);
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    names.add(node.name.lexeme);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    names.add(node.name.lexeme);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final name = node.name;
    if (name != null) names.add(name.lexeme);
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    names.add(node.name.lexeme);
    super.visitFunctionTypedFormalParameter(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    names.add(node.name.lexeme);
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    names.add(node.name.lexeme);
    super.visitSuperFormalParameter(node);
  }
}

class _SignalBearingClassVisitor extends RecursiveAstVisitor<void> {
  final List<_SignalImport> signalImports;
  final Set<String> declaredNames;
  final Set<String> classes = {};
  final Map<String, Set<String>> _parents = {};
  String? _currentClass;

  _SignalBearingClassVisitor(this.signalImports, this.declaredNames);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previousClass = _currentClass;
    final className = node.name.lexeme;
    _currentClass = className;
    _parents[className] = {
      if (node.extendsClause != null)
        node.extendsClause!.superclass.name2.lexeme,
      ...?node.withClause?.mixinTypes.map((type) => type.name2.lexeme),
    };
    super.visitClassDeclaration(node);
    _currentClass = previousClass;
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final previousClass = _currentClass;
    _currentClass = node.name.lexeme;
    super.visitMixinDeclaration(node);
    _currentClass = previousClass;
  }

  Set<String> get statefulClasses {
    final result = Set<String>.of(classes);
    var changed = true;
    while (changed) {
      changed = false;
      for (final entry in _parents.entries) {
        if (!result.contains(entry.key) && entry.value.any(result.contains)) {
          result.add(entry.key);
          changed = true;
        }
      }
    }
    return result;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_currentClass != null && node.methodName.name == 'signal') {
      for (final import in signalImports) {
        final target = node.target;
        if ((import.prefix == null &&
                target == null &&
                !declaredNames.contains('signal')) ||
            (import.prefix != null &&
                !declaredNames.contains(import.prefix) &&
                target is SimpleIdentifier &&
                target.name == import.prefix)) {
          classes.add(_currentClass!);
          break;
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _SignalKeyVisitor extends RecursiveAstVisitor<void> {
  final String fileRelativePath;
  final String source;
  final List<_SignalCallReplacement> replacements = [];
  final Map<String, int> _declarationSignalCount = {};
  final Set<String> declaredNames;
  final Map<String, int> _forEachScopeSignatureCount = {};
  final Map<String, int> _declarationLiveCount = {};
  final Map<String, int> _declarationShowCount = {};
  final Map<String, int> _declarationMemoCount = {};
  final Map<String, int> _declarationSuspenseCount = {};
  final Map<String, int> _declarationErrorBoundaryCount = {};
  final Map<String, int> _declarationMountCount = {};
  final Map<String, int> _declarationEffectCount = {};
  final Map<String, int> _declarationLazyCount = {};
  final Map<String, int> _declarationCustomElementCount = {};
  final Map<String, int> _declarationStatefulInstanceCount = {};
  _SignalKeyVisitor({
    required this.fileRelativePath,
    required this.source,
    required this.signalImports,
    required this.componentImports,
    required this.forEachImports,
    required this.liveImports,
    required this.showImports,
    required this.memoImports,
    required this.suspenseImports,
    required this.errorBoundaryImports,
    required this.mountImports,
    required this.effectImports,
    required this.lazyImports,
    required this.customElementDefinitionImports,
    required this.batchImports,
    required this.untrackedImports,
    required this.hmrScopeImports,
    required this.signalBearingClasses,
    required this.declaredNames,
  });

  final List<_SignalImport> signalImports;
  final List<_SignalImport> componentImports;
  final List<_SignalImport> forEachImports;
  final List<_SignalImport> liveImports;
  final List<_SignalImport> showImports;
  final List<_SignalImport> memoImports;
  final List<_SignalImport> suspenseImports;
  final List<_SignalImport> errorBoundaryImports;
  final List<_SignalImport> mountImports;
  final List<_SignalImport> effectImports;
  final List<_SignalImport> lazyImports;
  final List<_SignalImport> customElementDefinitionImports;
  final List<_SignalImport> batchImports;
  final List<_SignalImport> untrackedImports;
  final List<_SignalImport> hmrScopeImports;
  final Set<String> signalBearingClasses;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _injectStatefulInstanceScope(node);
    _injectForEachScope(node);
    _injectLiveScope(node);
    _injectShowScope(node);
    _injectMemoScope(node);
    _injectSuspenseScope(node);
    _injectErrorBoundaryScope(node);
    _injectMountScope(node);
    super.visitInstanceCreationExpression(node);
  }

  void _injectStatefulInstanceScope(InstanceCreationExpression node) {
    if (node.isConst || hmrScopeImports.isEmpty) return;
    final typeName = node.constructorName.type.name2.lexeme;
    if (!signalBearingClasses.contains(typeName) &&
        !_isDirectVariableInitializer(node)) {
      return;
    }
    _injectStatefulScope(node, typeName);
  }

  void _injectStatefulFactoryCallScope(MethodInvocation node) {
    if (hmrScopeImports.isEmpty) return;
    final callTarget = node.target;
    final namedConstructorType = switch (callTarget) {
      SimpleIdentifier(name: final name) when _isUppercaseIdentifier(name) =>
        name,
      PrefixedIdentifier(identifier: SimpleIdentifier(name: final name))
          when _isUppercaseIdentifier(name) =>
        name,
      PropertyAccess(propertyName: SimpleIdentifier(name: final name))
          when _isUppercaseIdentifier(name) =>
        name,
      _ => null,
    };
    final typeName = namedConstructorType ?? node.methodName.name;
    final constructorVariable = _isDirectVariableInitializer(node) &&
        (namedConstructorType != null ||
            (callTarget == null && _isUppercaseIdentifier(typeName)) ||
            (callTarget is SimpleIdentifier &&
                _isUppercaseIdentifier(typeName)));
    if (!signalBearingClasses.contains(typeName) && !constructorVariable) {
      return;
    }
    _injectStatefulScope(node, typeName);
  }

  bool _isDirectVariableInitializer(AstNode node) =>
      node.parent is VariableDeclaration &&
      (node.parent as VariableDeclaration).initializer == node;

  bool _isUppercaseIdentifier(String name) =>
      name.isNotEmpty &&
      name.codeUnitAt(0) >= 0x41 &&
      name.codeUnitAt(0) <= 0x5a;

  void _injectStatefulScope(AstNode node, String typeName) {
    if (!signalBearingClasses.contains(typeName) &&
        !_isDirectVariableInitializer(node)) {
      return;
    }
    if (_isInsideUnkeyedForEachBuilder(node) ||
        !_hasStableStatefulInstanceParent(node)) {
      return;
    }

    _SignalImport? helperImport;
    for (final candidate in hmrScopeImports) {
      if (candidate.prefix != null
          ? !declaredNames.contains(candidate.prefix)
          : !declaredNames.contains('bloomHmrScope')) {
        helperImport = candidate;
        break;
      }
    }
    if (helperImport == null) return;

    final declaration = _resolveEnclosingDeclarationName(node);
    final variable = _isDirectVariableInitializer(node)
        ? node.parent as VariableDeclaration
        : null;
    final stableOwner =
        variable == null ? declaration : '$declaration#${variable.name.lexeme}';
    final countKey = '$stableOwner#$typeName';
    final ordinal = _declarationStatefulInstanceCount.update(
      countKey,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = variable == null
        ? '$fileRelativePath#$stableOwner#$typeName#$ordinal'
        : '$fileRelativePath#$stableOwner#$typeName';
    final escapedId = scopeId.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final helper = helperImport.prefix == null
        ? 'bloomHmrScope'
        : '${helperImport.prefix}.bloomHmrScope';
    replacements.add(_SignalCallReplacement(
      offset: node.offset,
      end: node.offset,
      text: "$helper('$escapedId', () => (",
    ));
    replacements.add(_SignalCallReplacement(
      offset: node.end,
      end: node.end,
      text: '))',
    ));
  }

  bool _hasStableStatefulInstanceParent(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ForStatement ||
          current is WhileStatement ||
          current is DoStatement) {
        return false;
      }
      if (current is FunctionExpression) {
        final declaration = current.parent;
        if (declaration is FunctionDeclaration) {
          return declaration.name.lexeme == 'main';
        }
        if (declaration is MethodDeclaration) {
          return declaration.name.lexeme == 'build' &&
              declaration.returnType?.toSource().split('.').last == 'BloomNode';
        }
        return _isKeyedForEachBuilderFunction(current) ||
            _isLiveBuilderFunction(current) ||
            _isShowWhenFunction(current) ||
            _isMemoCallbackFunction(current) ||
            _isSuspenseCallbackFunction(current) ||
            _isErrorBoundaryBuilderFunction(current) ||
            _isMountLifecycleFunction(current) ||
            _isLazyLoaderFunction(current) ||
            _isCustomElementDefinitionBuilder(current);
      }
      if (current is FunctionDeclaration) {
        return current.name.lexeme == 'main';
      }
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build' &&
            current.returnType?.toSource().split('.').last == 'BloomNode';
      }
      if (current is FieldDeclaration) return false;
      if (current is ConstructorDeclaration) return false;
      current = current.parent;
    }
    // A top-level initializer runs once per module evaluation and has a
    // stable identity across DDC remounts.
    return true;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _injectStatefulFactoryCallScope(node);
    if (node.methodName.name == 'ForEach' &&
        _isImportedBloomForEachMethod(node)) {
      _injectForEachScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'Live' && _isImportedBloomLiveMethod(node)) {
      _injectLiveScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'Show' && _isImportedBloomShowMethod(node)) {
      _injectShowScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'Memo' && _isImportedBloomMemoMethod(node)) {
      _injectMemoScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'Suspense' &&
        _isImportedBloomSuspenseMethod(node)) {
      _injectSuspenseScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'ErrorBoundary' &&
        _isImportedBloomErrorBoundaryMethod(node)) {
      _injectErrorBoundaryScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'Mount' && _isImportedBloomMountMethod(node)) {
      _injectMountScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'effect' &&
        _isImportedBloomEffectMethod(node)) {
      _injectEffectScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'lazy' && _isImportedBloomLazyMethod(node)) {
      _injectLazyScopeArguments(node.argumentList, node);
    }
    if (node.methodName.name == 'defineCustomElement' &&
        _isImportedBloomCustomElementDefinitionMethod(node)) {
      _injectCustomElementDefinitionScopeArguments(node.argumentList, node);
    }
    _checkAndInject(node);
    super.visitMethodInvocation(node);
  }

  void _injectForEachScope(InstanceCreationExpression node) {
    if (node.constructorName.type.name2.lexeme != 'ForEach' ||
        !_isImportedBloomForEach(node)) {
      return;
    }
    _injectForEachScopeArguments(node.argumentList, node);
  }

  void _injectLiveScope(InstanceCreationExpression node) {
    if (node.constructorName.type.name2.lexeme != 'Live' ||
        !_isImportedBloomLive(node)) {
      return;
    }
    _injectLiveScopeArguments(node.argumentList, node);
  }

  void _injectShowScope(InstanceCreationExpression node) {
    if (node.constructorName.type.name2.lexeme != 'Show' ||
        !_isImportedBloomShow(node)) {
      return;
    }
    _injectShowScopeArguments(node.argumentList, node);
  }

  void _injectShowScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    final positional = argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.isEmpty || positional.first is! FunctionExpression) return;
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationShowCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#Show#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectMemoScope(InstanceCreationExpression node) {
    if (node.constructorName.type.name2.lexeme != 'Memo' ||
        !_isImportedBloomMemo(node)) {
      return;
    }
    _injectMemoScopeArguments(node.argumentList, node);
  }

  void _injectSuspenseScope(InstanceCreationExpression node) {
    if (node.constructorName.type.name2.lexeme != 'Suspense' ||
        !_isImportedBloomSuspense(node)) {
      return;
    }
    _injectSuspenseScopeArguments(node.argumentList, node);
  }

  void _injectErrorBoundaryScope(InstanceCreationExpression node) {
    if (node.constructorName.type.name2.lexeme != 'ErrorBoundary' ||
        !_isImportedBloomErrorBoundary(node)) {
      return;
    }
    _injectErrorBoundaryScopeArguments(node.argumentList, node);
  }

  void _injectMountScope(InstanceCreationExpression node) {
    if (node.constructorName.type.name2.lexeme != 'Mount' ||
        !_isImportedBloomMount(node)) {
      return;
    }
    _injectMountScopeArguments(node.argumentList, node);
  }

  void _injectMountScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    if (!argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        const {'onMount', 'onUnmount'}.contains(argument.name.label.name))) {
      return;
    }
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationMountCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#Mount#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectEffectScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    final positional = argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.isEmpty || positional.first is! FunctionExpression) return;
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationEffectCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#effect#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectLazyScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    final positional = argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.isEmpty || positional.first is! FunctionExpression) return;
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationLazyCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#lazy#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectCustomElementDefinitionScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    final positional = argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.length < 2 || positional[1] is! FunctionExpression) return;
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationCustomElementCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#customElement#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectErrorBoundaryScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    if (!argumentList.arguments.any((argument) =>
        argument is NamedExpression && argument.name.label.name == 'builder')) {
      return;
    }
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationErrorBoundaryCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#ErrorBoundary#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectSuspenseScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    if (!argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        const {'resource', 'builder'}.contains(argument.name.label.name))) {
      return;
    }
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationSuspenseCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#Suspense#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectMemoScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    final positional = argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.length < 2) return;
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationMemoCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#Memo#$ordinal';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  void _injectLiveScopeArguments(
      ArgumentList argumentList, AstNode invocation) {
    if (_isInsideUnkeyedForEachBuilder(invocation)) return;
    final args = argumentList.arguments;
    if (args.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    final declaration = _resolveEnclosingDeclarationName(invocation);
    final ordinal = _declarationLiveCount.update(
      declaration,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId = '$fileRelativePath#$declaration#Live#$ordinal';
    _insertNamedArgument(
        argumentList, "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'");
  }

  void _injectForEachScopeArguments(
    ArgumentList argumentList,
    AstNode invocation,
  ) {
    if (argumentList.arguments.any((argument) =>
        argument is NamedExpression &&
        argument.name.label.name == 'hotReloadScopeId')) {
      return;
    }
    final hasKey = argumentList.arguments.any((argument) =>
        argument is NamedExpression && argument.name.label.name == 'key');
    if (!hasKey) return;

    final declaration = _resolveEnclosingDeclarationName(invocation);
    final positional = argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.length < 2) return;
    final keySource = argumentList.arguments
        .whereType<NamedExpression>()
        .firstWhere((argument) => argument.name.label.name == 'key')
        .expression
        .toSource();
    final signature = sha256
        .convert(utf8.encode(
            '$fileRelativePath#$declaration#${positional.first.toSource()}#$keySource'))
        .toString();
    final duplicateIndex = _forEachScopeSignatureCount.update(
      signature,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    final scopeId =
        '$fileRelativePath#$declaration#ForEach#$signature#$duplicateIndex';
    _insertNamedArgument(
      argumentList,
      "hotReloadScopeId: '${scopeId.replaceAll("'", r"\'")}'",
    );
  }

  bool _isImportedBloomForEach(InstanceCreationExpression node) {
    final typeSource = node.constructorName.type.toSource();
    final genericStart = typeSource.indexOf('<');
    final qualifiedName =
        genericStart < 0 ? typeSource : typeSource.substring(0, genericStart);
    final dot = qualifiedName.lastIndexOf('.');
    final prefix = dot < 0 ? null : qualifiedName.substring(0, dot);
    return _isImportedBloomForEachPrefix(prefix);
  }

  bool _isImportedBloomLive(InstanceCreationExpression node) {
    final typeSource = node.constructorName.type.toSource();
    final genericStart = typeSource.indexOf('<');
    final qualifiedName =
        genericStart < 0 ? typeSource : typeSource.substring(0, genericStart);
    final dot = qualifiedName.lastIndexOf('.');
    final prefix = dot < 0 ? null : qualifiedName.substring(0, dot);
    if (prefix == null && declaredNames.contains('Live')) return false;
    return liveImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomShow(InstanceCreationExpression node) {
    final typeSource = node.constructorName.type.toSource();
    final genericStart = typeSource.indexOf('<');
    final qualifiedName =
        genericStart < 0 ? typeSource : typeSource.substring(0, genericStart);
    final dot = qualifiedName.lastIndexOf('.');
    final prefix = dot < 0 ? null : qualifiedName.substring(0, dot);
    if (prefix == null && declaredNames.contains('Show')) return false;
    return showImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomShowMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('Show')) return false;
    return showImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomLiveMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('Live')) return false;
    return liveImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomMemo(InstanceCreationExpression node) {
    final typeSource = node.constructorName.type.toSource();
    final genericStart = typeSource.indexOf('<');
    final qualifiedName =
        genericStart < 0 ? typeSource : typeSource.substring(0, genericStart);
    final dot = qualifiedName.lastIndexOf('.');
    final prefix = dot < 0 ? null : qualifiedName.substring(0, dot);
    if (prefix == null && declaredNames.contains('Memo')) return false;
    return memoImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomMemoMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('Memo')) return false;
    return memoImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomSuspense(InstanceCreationExpression node) {
    final typeSource = node.constructorName.type.toSource();
    final genericStart = typeSource.indexOf('<');
    final qualifiedName =
        genericStart < 0 ? typeSource : typeSource.substring(0, genericStart);
    final dot = qualifiedName.lastIndexOf('.');
    final prefix = dot < 0 ? null : qualifiedName.substring(0, dot);
    if (prefix == null && declaredNames.contains('Suspense')) return false;
    return suspenseImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomSuspenseMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('Suspense')) return false;
    return suspenseImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomErrorBoundary(InstanceCreationExpression node) {
    final typeSource = node.constructorName.type.toSource();
    final genericStart = typeSource.indexOf('<');
    final qualifiedName =
        genericStart < 0 ? typeSource : typeSource.substring(0, genericStart);
    final dot = qualifiedName.lastIndexOf('.');
    final prefix = dot < 0 ? null : qualifiedName.substring(0, dot);
    if (prefix == null && declaredNames.contains('ErrorBoundary')) {
      return false;
    }
    return errorBoundaryImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomErrorBoundaryMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('ErrorBoundary')) return false;
    return errorBoundaryImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomMount(InstanceCreationExpression node) {
    final typeSource = node.constructorName.type.toSource();
    final genericStart = typeSource.indexOf('<');
    final qualifiedName =
        genericStart < 0 ? typeSource : typeSource.substring(0, genericStart);
    final dot = qualifiedName.lastIndexOf('.');
    final prefix = dot < 0 ? null : qualifiedName.substring(0, dot);
    if (prefix == null && declaredNames.contains('Mount')) return false;
    return mountImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomMountMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('Mount')) return false;
    return mountImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomEffectMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('effect')) return false;
    return effectImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomLazyMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('lazy')) return false;
    return lazyImports.any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomCustomElementDefinitionMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains('defineCustomElement')) {
      return false;
    }
    return customElementDefinitionImports
        .any((import) => import.prefix == prefix);
  }

  bool _isImportedBloomForEachMethod(MethodInvocation node) {
    final target = node.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    return _isImportedBloomForEachPrefix(prefix);
  }

  bool _isImportedBloomForEachPrefix(String? prefix) {
    if (prefix == null && declaredNames.contains('ForEach')) return false;
    return forEachImports.any((import) => import.prefix == prefix);
  }

  void _insertNamedArgument(ArgumentList argumentList, String argument) {
    final args = argumentList.arguments;
    if (args.isEmpty) {
      final offset = argumentList.leftParenthesis.end;
      replacements.add(_SignalCallReplacement(
        offset: offset,
        end: offset,
        text: argument,
      ));
      return;
    }

    final last = args.last;
    final between =
        source.substring(last.end, argumentList.rightParenthesis.offset);
    final commaIndex = between.indexOf(',');
    if (commaIndex >= 0) {
      final offset = last.end + commaIndex;
      replacements.add(_SignalCallReplacement(
        offset: offset,
        end: offset + 1,
        text: ', $argument,',
      ));
    } else {
      final offset = argumentList.rightParenthesis.offset;
      replacements.add(_SignalCallReplacement(
        offset: offset,
        end: offset,
        text: ', $argument',
      ));
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkAndWrapComponentMethod(node);
    super.visitMethodDeclaration(node);
  }

  void _checkAndWrapComponentMethod(MethodDeclaration node) {
    if (node.name.lexeme != 'build' ||
        node.returnType?.toSource().split('.').last != 'BloomNode' ||
        node.body.isAsynchronous ||
        node.body.isGenerator ||
        componentImports.isEmpty) {
      return;
    }

    final componentClass = _findEnclosingClassName(node);
    if (componentClass == null) return;
    _SignalImport? imported;
    for (final candidate in componentImports) {
      if (candidate.prefix != null ||
          !declaredNames.contains('bloomHmrComponent')) {
        imported = candidate;
        break;
      }
    }
    if (imported == null) return;
    final call = imported.prefix == null
        ? 'bloomHmrComponent'
        : '${imported.prefix}.bloomHmrComponent';
    final key = '$fileRelativePath#$componentClass.${node.name.lexeme}';
    final escapedKey = key.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final body = node.body;
    final replacement = switch (body) {
      BlockFunctionBody(:final block) =>
        '{ return $call(\'$escapedKey\', () {${source.substring(block.leftBracket.end, block.rightBracket.offset)}\n}); }',
      ExpressionFunctionBody(:final expression) =>
        '=> $call(\'$escapedKey\', () => (${source.substring(expression.offset, expression.end)}))',
      _ => null,
    };
    if (replacement == null) return;
    replacements.add(_SignalCallReplacement(
      offset: body.offset,
      end: body.end,
      text: replacement,
    ));
  }

  void _checkAndInject(MethodInvocation node) {
    if (node.methodName.name != 'signal') return;
    _SignalImport? matchingImport;
    for (final import in signalImports) {
      final prefix = import.prefix;
      final importedName = prefix ?? 'signal';
      // Without resolved ASTs, a same-named declaration anywhere in this
      // compilation unit could shadow the import at this call site. Skip
      // auto-keying rather than changing an unrelated function call.
      if (declaredNames.contains(importedName)) continue;
      if ((prefix == null && node.target == null) ||
          (prefix != null &&
              node.target is SimpleIdentifier &&
              (node.target as SimpleIdentifier).name == prefix)) {
        matchingImport = import;
        break;
      }
    }
    if (matchingImport == null) return;

    // 1. If key: named argument already exists, explicit developer key wins
    final args = node.argumentList.arguments;
    for (final arg in args) {
      if (arg is NamedExpression && arg.name.label.name == 'key') {
        return;
      }
    }

    // Anonymous builders can execute once per list item or on every reactive
    // update. Only keyed ForEach builders receive a runtime item scope; other
    // closures still require an explicit item-specific key.
    AstNode? ancestor = node.parent;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          ancestor.parent is! FunctionDeclaration &&
          !_isInsideKeyedForEachBuilder(ancestor) &&
          !_isInsideLiveBuilder(ancestor) &&
          !_isInsideShowWhen(ancestor) &&
          !_isInsideMemoCallback(ancestor) &&
          !_isInsideSuspenseCallback(ancestor) &&
          !_isInsideErrorBoundaryBuilder(ancestor) &&
          !_isInsideMountLifecycle(ancestor) &&
          !_isInsideEventHandler(ancestor) &&
          !_isInsideEffectCallback(ancestor) &&
          !_isInsideLazyLoader(ancestor) &&
          !_isInsideCustomElementDefinition(ancestor) &&
          !_isInsideSynchronousSignalCallback(ancestor) &&
          !_isInsideKeyedForEachItems(ancestor)) {
        return;
      }
      ancestor = ancestor.parent;
    }

    // 2. Resolve the enclosing named declaration.
    final enclosingName = _resolveEnclosingDeclarationName(node);

    // 3. Compute ordinal scoped ONLY to this enclosing declaration
    final ordinal = _declarationSignalCount.update(
      enclosingName,
      (count) => count + 1,
      ifAbsent: () => 0,
    );

    // 4. Construct stable key
    final keyString = '$fileRelativePath#$enclosingName#$ordinal';
    final escapedKey = keyString.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

    // 5. Record source replacement
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

  bool _isInsideKeyedForEachBuilder(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isKeyedForEachBuilderFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isInsideUnkeyedForEachBuilder(AstNode node) {
    AstNode? ancestor = node;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isForEachBuilderFunction(ancestor) &&
          !_isKeyedForEachBuilderFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isInsideEventHandler(FunctionExpression function) {
    AstNode? current = function;
    while (current != null) {
      if (current is FunctionExpression && _isEventHandlerFunction(current)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isEventHandlerFunction(FunctionExpression function) {
    final parent = function.parent;
    if (parent is NamedExpression) {
      final name = parent.name.label.name;
      if (name.startsWith('on') && name.length > 2) return true;
      if (const {'on', 'events'}.contains(name) &&
          parent.parent is ArgumentList) {
        return true;
      }
    }
    if (parent is MapLiteralEntry && parent.value == function) {
      final map = parent.parent;
      final namedOn = map?.parent;
      return namedOn is NamedExpression &&
          const {'on', 'events'}.contains(namedOn.name.label.name) &&
          namedOn.parent is ArgumentList;
    }
    return false;
  }

  bool _isForEachBuilderFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! ArgumentList) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! ArgumentList) return false;
    final positional = ancestor.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.length < 2 ||
        function.offset < positional[1].offset ||
        function.end > positional[1].end) {
      return false;
    }
    final invocation = ancestor.parent;
    return invocation is InstanceCreationExpression
        ? invocation.constructorName.type.name2.lexeme == 'ForEach' &&
            _isImportedBloomForEach(invocation)
        : invocation is MethodInvocation &&
            invocation.methodName.name == 'ForEach' &&
            _isImportedBloomForEachMethod(invocation);
  }

  bool _isInsideLiveBuilder(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression && _isLiveBuilderFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isInsideShowWhen(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression && _isShowWhenFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isShowWhenFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! ArgumentList) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! ArgumentList) return false;
    final positional = ancestor.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.isEmpty ||
        function.offset < positional.first.offset ||
        function.end > positional.first.end) {
      return false;
    }
    final invocation = ancestor.parent;
    return switch (invocation) {
      InstanceCreationExpression() =>
        invocation.constructorName.type.name2.lexeme == 'Show' &&
            _isImportedBloomShow(invocation),
      MethodInvocation() => invocation.methodName.name == 'Show' &&
          _isImportedBloomShowMethod(invocation),
      _ => false,
    };
  }

  bool _isLiveBuilderFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! ArgumentList) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! ArgumentList) return false;
    final positional = ancestor.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.isEmpty ||
        function.offset < positional.first.offset ||
        function.end > positional.first.end) {
      return false;
    }
    final invocation = ancestor.parent;
    return switch (invocation) {
      InstanceCreationExpression() =>
        invocation.constructorName.type.name2.lexeme == 'Live' &&
            _isImportedBloomLive(invocation),
      MethodInvocation() => invocation.methodName.name == 'Live' &&
          _isImportedBloomLiveMethod(invocation),
      _ => false,
    };
  }

  bool _isInsideMemoCallback(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression && _isMemoCallbackFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isInsideSuspenseCallback(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isSuspenseCallbackFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isInsideLazyLoader(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression && _isLazyLoaderFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isInsideCustomElementDefinition(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isCustomElementDefinitionBuilder(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isInsideSynchronousSignalCallback(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isSynchronousSignalCallback(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isSynchronousSignalCallback(FunctionExpression function) {
    final args = function.parent;
    if (args is! ArgumentList ||
        args.arguments.isEmpty ||
        args.arguments.first != function) {
      return false;
    }
    final invocation = args.parent;
    if (invocation is! MethodInvocation) return false;
    return switch (invocation.methodName.name) {
      'batch' => _isImportedSignalCallbackMethod(invocation, batchImports,
          methodName: 'batch'),
      'untracked' => _isImportedSignalCallbackMethod(
          invocation, untrackedImports,
          methodName: 'untracked'),
      _ => false,
    };
  }

  bool _isImportedSignalCallbackMethod(
    MethodInvocation invocation,
    List<_SignalImport> imports, {
    required String methodName,
  }) {
    if (invocation.methodName.name != methodName) return false;
    final target = invocation.target;
    if (target != null && target is! SimpleIdentifier) return false;
    final prefix = target is SimpleIdentifier ? target.name : null;
    if (prefix == null && declaredNames.contains(methodName)) return false;
    return imports.any((import) => import.prefix == prefix);
  }

  bool _isCustomElementDefinitionBuilder(FunctionExpression function) {
    final args = function.parent;
    if (args is! ArgumentList) return false;
    final positional = args.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.length < 2 || positional[1] != function) return false;
    final invocation = args.parent;
    return invocation is MethodInvocation &&
        invocation.methodName.name == 'defineCustomElement' &&
        _isImportedBloomCustomElementDefinitionMethod(invocation);
  }

  bool _isLazyLoaderFunction(FunctionExpression function) {
    final args = function.parent;
    if (args is! ArgumentList ||
        args.arguments.isEmpty ||
        args.arguments.first != function) return false;
    final invocation = args.parent;
    return invocation is MethodInvocation &&
        invocation.methodName.name == 'lazy' &&
        _isImportedBloomLazyMethod(invocation);
  }

  bool _isSuspenseCallbackFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! NamedExpression) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! NamedExpression ||
        !const {'resource', 'builder', 'errorBuilder'}
            .contains(ancestor.name.label.name)) {
      return false;
    }
    final invocation = ancestor.parent?.parent;
    return switch (invocation) {
      InstanceCreationExpression() =>
        invocation.constructorName.type.name2.lexeme == 'Suspense' &&
            _isImportedBloomSuspense(invocation),
      MethodInvocation() => invocation.methodName.name == 'Suspense' &&
          _isImportedBloomSuspenseMethod(invocation),
      _ => false,
    };
  }

  bool _isInsideErrorBoundaryBuilder(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isErrorBoundaryBuilderFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isErrorBoundaryBuilderFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! NamedExpression) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! NamedExpression ||
        !const {'builder', 'fallback'}.contains(ancestor.name.label.name)) {
      return false;
    }
    final invocation = ancestor.parent?.parent;
    return switch (invocation) {
      InstanceCreationExpression() =>
        invocation.constructorName.type.name2.lexeme == 'ErrorBoundary' &&
            _isImportedBloomErrorBoundary(invocation),
      MethodInvocation() => invocation.methodName.name == 'ErrorBoundary' &&
          _isImportedBloomErrorBoundaryMethod(invocation),
      _ => false,
    };
  }

  bool _isInsideMountLifecycle(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isMountLifecycleFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isMountLifecycleFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! NamedExpression) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! NamedExpression ||
        !const {'onMount', 'onUnmount'}.contains(ancestor.name.label.name)) {
      return false;
    }
    final invocation = ancestor.parent?.parent;
    return switch (invocation) {
      InstanceCreationExpression() =>
        invocation.constructorName.type.name2.lexeme == 'Mount' &&
            _isImportedBloomMount(invocation),
      MethodInvocation() => invocation.methodName.name == 'Mount' &&
          _isImportedBloomMountMethod(invocation),
      _ => false,
    };
  }

  bool _isInsideEffectCallback(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isEffectCallbackFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isEffectCallbackFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! ArgumentList) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! ArgumentList) return false;
    final positional = ancestor.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.isEmpty ||
        function.offset < positional.first.offset ||
        function.end > positional.first.end) {
      return false;
    }
    final invocation = ancestor.parent;
    return invocation is MethodInvocation &&
        invocation.methodName.name == 'effect' &&
        _isImportedBloomEffectMethod(invocation);
  }

  bool _isMemoCallbackFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! ArgumentList) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! ArgumentList) return false;
    final positional = ancestor.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.length < 2 ||
        !positional.take(2).any((argument) =>
            function.offset >= argument.offset &&
            function.end <= argument.end)) {
      return false;
    }
    final invocation = ancestor.parent;
    return switch (invocation) {
      InstanceCreationExpression() =>
        invocation.constructorName.type.name2.lexeme == 'Memo' &&
            _isImportedBloomMemo(invocation),
      MethodInvocation() => invocation.methodName.name == 'Memo' &&
          _isImportedBloomMemoMethod(invocation),
      _ => false,
    };
  }

  bool _isInsideKeyedForEachItems(FunctionExpression function) {
    AstNode? ancestor = function;
    while (ancestor != null) {
      if (ancestor is FunctionExpression &&
          _isKeyedForEachItemsFunction(ancestor)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  bool _isKeyedForEachItemsFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! ArgumentList) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! ArgumentList) return false;
    final positional = ancestor.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.isEmpty ||
        function.offset < positional.first.offset ||
        function.end > positional.first.end) {
      return false;
    }
    final invocation = ancestor.parent;
    final isBloomForEach = invocation is InstanceCreationExpression
        ? invocation.constructorName.type.name2.lexeme == 'ForEach' &&
            _isImportedBloomForEach(invocation)
        : invocation is MethodInvocation &&
            invocation.methodName.name == 'ForEach' &&
            _isImportedBloomForEachMethod(invocation);
    return isBloomForEach &&
        ancestor.arguments.any((argument) =>
            argument is NamedExpression && argument.name.label.name == 'key');
  }

  bool _isKeyedForEachBuilderFunction(FunctionExpression function) {
    AstNode? ancestor = function.parent;
    while (ancestor != null && ancestor is! ArgumentList) {
      ancestor = ancestor.parent;
    }
    final argumentList = ancestor;
    if (argumentList is! ArgumentList) return false;
    final positional = argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .toList(growable: false);
    if (positional.length < 2 ||
        function.offset < positional[1].offset ||
        function.end > positional[1].end) {
      return false;
    }
    final invocation = argumentList.parent;
    final isBloomForEach = invocation is InstanceCreationExpression
        ? invocation.constructorName.type.name2.lexeme == 'ForEach' &&
            _isImportedBloomForEach(invocation)
        : invocation is MethodInvocation &&
            invocation.methodName.name == 'ForEach' &&
            _isImportedBloomForEachMethod(invocation);
    if (!isBloomForEach) {
      return false;
    }
    return argumentList.arguments.any((argument) =>
        argument is NamedExpression && argument.name.label.name == 'key');
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
      if (current is ExtensionDeclaration)
        return current.name?.lexeme ?? 'extension';
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
  static String injectKeys(String source,
      {String relativePath = 'lib/main.dart'}) {
    final parseResult = parseString(content: source, throwIfDiagnostics: false);
    if (parseResult.errors.isNotEmpty) {
      return source;
    }

    final signalImports = <_SignalImport>[];
    final hmrScopeImports = <_SignalImport>[];
    final effectImports = <_SignalImport>[];
    final lazyImports = <_SignalImport>[];
    final customElementDefinitionImports = <_SignalImport>[];
    final batchImports = <_SignalImport>[];
    final untrackedImports = <_SignalImport>[];
    for (final directive in parseResult.unit.directives) {
      if (directive is! ImportDirective) continue;
      final uri = directive.uri.stringValue;
      if (uri != 'package:bloom_js_native/bloom_js_native.dart' &&
          uri != 'package:bloom_js_native/src/signals.dart') {
        continue;
      }
      var exportsSignal = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'signal')) {
          exportsSignal = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'signal')) {
          exportsSignal = false;
        }
      }
      if (exportsSignal) {
        signalImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsHmrScope = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames
                .any((name) => name.name == 'bloomHmrScope')) {
          exportsHmrScope = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames
                .any((name) => name.name == 'bloomHmrScope')) {
          exportsHmrScope = false;
        }
      }
      if (exportsHmrScope) {
        hmrScopeImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsEffect = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'effect')) {
          exportsEffect = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'effect')) {
          exportsEffect = false;
        }
      }
      if (exportsEffect) {
        effectImports.add(_SignalImport(directive.prefix?.name));
      }

      for (final methodName in const ['batch', 'untracked']) {
        var exportsMethod = true;
        for (final combinator in directive.combinators) {
          if (combinator is ShowCombinator &&
              !combinator.shownNames.any((name) => name.name == methodName)) {
            exportsMethod = false;
          }
          if (combinator is HideCombinator &&
              combinator.hiddenNames.any((name) => name.name == methodName)) {
            exportsMethod = false;
          }
        }
        if (!exportsMethod) continue;
        final import = _SignalImport(directive.prefix?.name);
        if (methodName == 'batch') {
          batchImports.add(import);
        } else {
          untrackedImports.add(import);
        }
      }
    }

    for (final directive in parseResult.unit.directives) {
      if (directive is! ImportDirective) continue;
      final uri = directive.uri.stringValue;
      if (uri != 'package:bloom_js_native/bloom_js_native.dart' &&
          uri != 'package:bloom_js_native/src/lazy.dart') continue;
      var exportsLazy = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'lazy')) {
          exportsLazy = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'lazy')) {
          exportsLazy = false;
        }
      }
      if (exportsLazy) lazyImports.add(_SignalImport(directive.prefix?.name));
    }

    for (final directive in parseResult.unit.directives) {
      if (directive is! ImportDirective) continue;
      final uri = directive.uri.stringValue;
      if (uri != 'package:bloom_js_native/browser.dart' &&
          uri != 'package:bloom_js_native/src/web_components.dart') {
        continue;
      }
      var exportsDefinition = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames
                .any((name) => name.name == 'defineCustomElement')) {
          exportsDefinition = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames
                .any((name) => name.name == 'defineCustomElement')) {
          exportsDefinition = false;
        }
      }
      if (exportsDefinition) {
        customElementDefinitionImports
            .add(_SignalImport(directive.prefix?.name));
      }
    }

    final componentImports = <_SignalImport>[];
    final forEachImports = <_SignalImport>[];
    final liveImports = <_SignalImport>[];
    final showImports = <_SignalImport>[];
    final memoImports = <_SignalImport>[];
    final suspenseImports = <_SignalImport>[];
    final errorBoundaryImports = <_SignalImport>[];
    final mountImports = <_SignalImport>[];
    for (final directive in parseResult.unit.directives) {
      if (directive is! ImportDirective) continue;
      final uri = directive.uri.stringValue;
      if (uri != 'package:bloom_js_native/bloom_js_native.dart' &&
          uri != 'package:bloom_js_native/src/framework.dart') {
        continue;
      }
      var exportsComponentBoundary = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames
                .any((name) => name.name == 'bloomHmrComponent')) {
          exportsComponentBoundary = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames
                .any((name) => name.name == 'bloomHmrComponent')) {
          exportsComponentBoundary = false;
        }
      }
      if (exportsComponentBoundary) {
        componentImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsForEach = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'ForEach')) {
          exportsForEach = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'ForEach')) {
          exportsForEach = false;
        }
      }
      if (exportsForEach) {
        forEachImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsLive = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'Live')) {
          exportsLive = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'Live')) {
          exportsLive = false;
        }
      }
      if (exportsLive) {
        liveImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsShow = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'Show')) {
          exportsShow = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'Show')) {
          exportsShow = false;
        }
      }
      if (exportsShow) {
        showImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsMemo = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'Memo')) {
          exportsMemo = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'Memo')) {
          exportsMemo = false;
        }
      }
      if (exportsMemo) {
        memoImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsSuspense = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'Suspense')) {
          exportsSuspense = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'Suspense')) {
          exportsSuspense = false;
        }
      }
      if (exportsSuspense) {
        suspenseImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsErrorBoundary = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames
                .any((name) => name.name == 'ErrorBoundary')) {
          exportsErrorBoundary = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames
                .any((name) => name.name == 'ErrorBoundary')) {
          exportsErrorBoundary = false;
        }
      }
      if (exportsErrorBoundary) {
        errorBoundaryImports.add(_SignalImport(directive.prefix?.name));
      }

      var exportsMount = true;
      for (final combinator in directive.combinators) {
        if (combinator is ShowCombinator &&
            !combinator.shownNames.any((name) => name.name == 'Mount')) {
          exportsMount = false;
        }
        if (combinator is HideCombinator &&
            combinator.hiddenNames.any((name) => name.name == 'Mount')) {
          exportsMount = false;
        }
      }
      if (exportsMount) {
        mountImports.add(_SignalImport(directive.prefix?.name));
      }
    }

    if (signalImports.isEmpty &&
        hmrScopeImports.isEmpty &&
        effectImports.isEmpty &&
        componentImports.isEmpty &&
        forEachImports.isEmpty &&
        liveImports.isEmpty &&
        showImports.isEmpty &&
        memoImports.isEmpty &&
        suspenseImports.isEmpty &&
        errorBoundaryImports.isEmpty &&
        mountImports.isEmpty &&
        lazyImports.isEmpty &&
        customElementDefinitionImports.isEmpty &&
        batchImports.isEmpty &&
        untrackedImports.isEmpty) {
      return source;
    }

    final declaredNames = _DeclaredNameVisitor();
    parseResult.unit.accept(declaredNames);
    final signalBearingClassesVisitor = _SignalBearingClassVisitor(
      signalImports,
      declaredNames.names,
    )..visitCompilationUnit(parseResult.unit);

    final visitor = _SignalKeyVisitor(
      fileRelativePath: relativePath.replaceAll(r'\', '/'),
      source: source,
      signalImports: signalImports,
      effectImports: effectImports,
      componentImports: componentImports,
      forEachImports: forEachImports,
      liveImports: liveImports,
      showImports: showImports,
      memoImports: memoImports,
      suspenseImports: suspenseImports,
      errorBoundaryImports: errorBoundaryImports,
      mountImports: mountImports,
      lazyImports: lazyImports,
      customElementDefinitionImports: customElementDefinitionImports,
      batchImports: batchImports,
      untrackedImports: untrackedImports,
      hmrScopeImports: hmrScopeImports,
      signalBearingClasses: signalBearingClassesVisitor.statefulClasses,
      declaredNames: declaredNames.names,
    );
    parseResult.unit.accept(visitor);

    if (visitor.replacements.isEmpty) {
      return source;
    }

    // Apply replacements in reverse offset order so earlier offsets remain valid
    visitor.replacements.sort((a, b) => b.offset.compareTo(a.offset));
    var rewritten = source;
    for (final r in visitor.replacements) {
      rewritten = rewritten.substring(0, r.offset) +
          r.text +
          rewritten.substring(r.end);
    }
    return rewritten;
  }
}
