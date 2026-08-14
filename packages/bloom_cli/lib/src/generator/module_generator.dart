// lib/src/generator/module_generator.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../templates/module_templates.dart';

class ModuleMethodParam {
  final String name;
  final String type;
  final bool isRequired;
  final String? defaultValue;

  const ModuleMethodParam({
    required this.name,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
  });
}

class ModuleMethodSpec {
  final String name;
  final String returnType;
  final List<ModuleMethodParam> parameters;
  final String thread;
  final bool isSync;

  const ModuleMethodSpec({
    required this.name,
    required this.returnType,
    this.parameters = const [],
    this.thread = 'ui',
    this.isSync = false,
  });
}

class ModuleConstantSpec {
  final String name;
  final String type;

  const ModuleConstantSpec({
    required this.name,
    required this.type,
  });
}

class ModuleStreamSpec {
  final String name;
  final String type;
  final bool isEvent;

  const ModuleStreamSpec({
    required this.name,
    required this.type,
    this.isEvent = false,
  });
}

class ModuleViewSpec {
  final String viewName;
  final String methodName;
  final List<ModuleMethodParam> props;

  const ModuleViewSpec({
    required this.viewName,
    required this.methodName,
    this.props = const [],
  });
}

class ModuleParsedDefinition {
  final String moduleName;
  final String version;
  final String description;
  final String definitionClassName;
  final List<ModuleConstantSpec> constants;
  final List<ModuleMethodSpec> methods;
  final List<ModuleStreamSpec> streams;
  final List<ModuleViewSpec> views;
  final List<String> lifecycleHooks;

  const ModuleParsedDefinition({
    required this.moduleName,
    required this.version,
    required this.description,
    required this.definitionClassName,
    this.constants = const [],
    this.methods = const [],
    this.streams = const [],
    this.views = const [],
    this.lifecycleHooks = const [],
  });
}

class BloomModuleCodeGenerator {
  /// Scans a module directory and generates .g.dart and native bridges.
  static bool generateForModule(Directory moduleDir) {
    final srcDir = Directory(p.join(moduleDir.path, 'lib', 'src'));
    if (!srcDir.existsSync()) return false;

    final moduleFiles = srcDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.module.dart'))
        .toList();

    if (moduleFiles.isEmpty) return false;

    for (final moduleFile in moduleFiles) {
      final content = moduleFile.readAsStringSync();
      final parsed = parseModuleDefinition(content, moduleFile);
      if (parsed == null) continue;

      // 1. Generate Dart bridge: lib/src/<name>.g.dart
      final baseName = p.basename(moduleFile.path).replaceAll('.module.dart', '');
      final dartBridgeCode = generateDartBridge(parsed, baseName);
      final dartBridgeFile = File(p.join(srcDir.path, '$baseName.g.dart'));
      dartBridgeFile.writeAsStringSync(dartBridgeCode);

      // 2. Generate Swift bridge: ios/Sources/<Name>Bridge.swift
      final iosDir = Directory(p.join(moduleDir.path, 'ios', 'Sources'));
      if (iosDir.existsSync()) {
        final swiftBridgeCode = generateSwiftBridge(parsed);
        File(p.join(iosDir.path, '${parsed.moduleName}Bridge.swift'))
            .writeAsStringSync(swiftBridgeCode);
      }

      // 3. Generate Kotlin bridge in android/src/main/kotlin/...
      final androidKotlinDir = Directory(p.join(moduleDir.path, 'android', 'src', 'main', 'kotlin'));
      if (androidKotlinDir.existsSync()) {
        final ktFiles = androidKotlinDir.listSync(recursive: true).whereType<File>().toList();
        Directory targetKtDir = androidKotlinDir;
        if (ktFiles.isNotEmpty) {
          targetKtDir = Directory(p.dirname(ktFiles.first.path));
        }
        final kotlinBridgeCode = generateKotlinBridge(parsed, targetKtDir.path);
        File(p.join(targetKtDir.path, '${parsed.moduleName}Bridge.kt'))
            .writeAsStringSync(kotlinBridgeCode);
      }
    }

    return true;
  }

  /// Parses @BloomModule definition file into structured definition AST.
  static ModuleParsedDefinition? parseModuleDefinition(String content, File sourceFile) {
    // 1. Extract @BloomModule metadata (supports multi-line, single/double quotes, trailing commas)
    final moduleMatch = RegExp(
      r'@BloomModule\s*\(\s*name:\s*[\x27\x22]([^\x27\x22]+)[\x27\x22](?:[\s\S]*?version:\s*[\x27\x22]([^\x27\x22]+)[\x27\x22])?(?:[\s\S]*?description:\s*[\x27\x22]([^\x27\x22]+)[\x27\x22])?',
    ).firstMatch(content);

    final moduleName = moduleMatch?.group(1) ??
        BloomModuleTemplates.toPascalCase(p.basename(sourceFile.path).replaceAll('.module.dart', ''));
    final version = moduleMatch?.group(2) ?? '1.0.0';
    final description = moduleMatch?.group(3) ?? '';

    // 2. Extract class name
    final classMatch = RegExp(r'abstract\s+class\s+([A-Za-z0-9_]+)').firstMatch(content);
    final defClassName = classMatch?.group(1) ?? '${moduleName}Definition';

    // 3. Extract Constants
    final constants = <ModuleConstantSpec>[];
    final constantMatches = RegExp(
      r'@BloomConstant\(\)\s*([\s\S]+?)\s+get\s+([A-Za-z0-9_]+);',
    ).allMatches(content);
    for (final m in constantMatches) {
      constants.add(ModuleConstantSpec(type: m.group(1)!.trim(), name: m.group(2)!.trim()));
    }

    // 4. Extract Async Functions
    final methods = <ModuleMethodSpec>[];
    final asyncFuncMatches = RegExp(
      r'@BloomAsyncFunction\((?:[\s\S]*?thread:\s*NativeThread\.([A-Za-z0-9_]+))?[\s\S]*?\)\s*Future<([\s\S]+?)>\s+([A-Za-z0-9_]+)\s*\(([\s\S]*?)\);',
    ).allMatches(content);

    for (final m in asyncFuncMatches) {
      final thread = m.group(1) ?? 'ui';
      final returnType = m.group(2)!.trim();
      final methodName = m.group(3)!.trim();
      final rawParams = m.group(4)?.trim() ?? '';

      final params = _parseParams(rawParams);
      methods.add(ModuleMethodSpec(
        name: methodName,
        returnType: returnType,
        parameters: params,
        thread: thread,
        isSync: false,
      ));
    }

    // 5. Extract Sync Functions
    final syncFuncMatches = RegExp(
      r'@BloomSyncFunction\(\)\s*([\s\S]+?)\s+([A-Za-z0-9_]+)\s*\(([\s\S]*?)\);',
    ).allMatches(content);

    for (final m in syncFuncMatches) {
      final returnType = m.group(1)!.trim();
      final methodName = m.group(2)!.trim();
      final rawParams = m.group(3)?.trim() ?? '';

      final params = _parseParams(rawParams);
      methods.add(ModuleMethodSpec(
        name: methodName,
        returnType: returnType,
        parameters: params,
        thread: 'ui',
        isSync: true,
      ));
    }

    // 6. Extract Streams & Events
    final streams = <ModuleStreamSpec>[];
    final eventMatches = RegExp(
      r'@BloomEvent\(\)\s*Stream<([\s\S]+?)>\s+get\s+([A-Za-z0-9_]+);',
    ).allMatches(content);
    for (final m in eventMatches) {
      streams.add(ModuleStreamSpec(type: m.group(1)!.trim(), name: m.group(2)!.trim(), isEvent: true));
    }

    final streamMatches = RegExp(
      r'@BloomStream\(\)\s*Stream<([\s\S]+?)>\s+get\s+([A-Za-z0-9_]+);',
    ).allMatches(content);
    for (final m in streamMatches) {
      streams.add(ModuleStreamSpec(type: m.group(1)!.trim(), name: m.group(2)!.trim(), isEvent: false));
    }

    // 7. Extract Views
    final views = <ModuleViewSpec>[];
    final viewMatches = RegExp(
      r"@BloomView\(\s*name:\s*[\x27\x22]([^\x27\x22]+)[\x27\x22]\)\s*(?:void|Widget)\s+([A-Za-z0-9_]+)\s*\(([\s\S]*?)\);",
    ).allMatches(content);
    for (final m in viewMatches) {
      final viewName = m.group(1)!.trim();
      final methodName = m.group(2)!.trim();
      final rawParams = m.group(3)?.trim() ?? '';
      views.add(ModuleViewSpec(
        viewName: viewName,
        methodName: methodName,
        props: _parseParams(rawParams),
      ));
    }

    // 8. Lifecycle Hooks
    final lifecycleHooks = <String>[];
    final hookMatches = RegExp(
      r'@BloomLifecycleHook\(\)\s*void\s+([A-Za-z0-9_]+)\s*\(\);',
    ).allMatches(content);
    for (final m in hookMatches) {
      lifecycleHooks.add(m.group(1)!);
    }

    return ModuleParsedDefinition(
      moduleName: moduleName,
      version: version,
      description: description,
      definitionClassName: defClassName,
      constants: constants,
      methods: methods,
      streams: streams,
      views: views,
      lifecycleHooks: lifecycleHooks,
    );
  }

  /// Splits a comma-separated list of parameters respecting generic brackets, braces, and parentheses.
  static List<String> _splitTopLevel(String input, [String delimiter = ',']) {
    final results = <String>[];
    var depthParen = 0;
    var depthBracket = 0;
    var depthBrace = 0;
    var depthAngle = 0;
    var current = StringBuffer();

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '(') depthParen++;
      else if (ch == ')') depthParen = depthParen > 0 ? depthParen - 1 : 0;
      else if (ch == '[') depthBracket++;
      else if (ch == ']') depthBracket = depthBracket > 0 ? depthBracket - 1 : 0;
      else if (ch == '{') depthBrace++;
      else if (ch == '}') depthBrace = depthBrace > 0 ? depthBrace - 1 : 0;
      else if (ch == '<') depthAngle++;
      else if (ch == '>') depthAngle = depthAngle > 0 ? depthAngle - 1 : 0;

      if (ch == delimiter && depthParen == 0 && depthBracket == 0 && depthBrace == 0 && depthAngle == 0) {
        final item = current.toString().trim();
        if (item.isNotEmpty) results.add(item);
        current.clear();
      } else {
        current.write(ch);
      }
    }
    final item = current.toString().trim();
    if (item.isNotEmpty) results.add(item);
    return results;
  }

  static List<ModuleMethodParam> _parseParams(String rawParams) {
    if (rawParams.isEmpty) return [];
    final params = <ModuleMethodParam>[];
    final cleaned = rawParams.replaceAll('{', '').replaceAll('}', '').trim();
    final parts = _splitTopLevel(cleaned, ',');

    for (var p in parts) {
      p = p.trim();
      if (p.isEmpty) continue;

      final isRequired = p.startsWith('required ');
      if (isRequired) {
        p = p.replaceFirst('required ', '').trim();
      }

      String? defaultValue;
      if (p.contains('=')) {
        final defParts = _splitTopLevel(p, '=');
        p = defParts[0].trim();
        if (defParts.length > 1) {
          defaultValue = defParts[1].trim();
        }
      }

      final lastSpace = p.lastIndexOf(' ');
      if (lastSpace != -1) {
        final type = p.substring(0, lastSpace).trim();
        final name = p.substring(lastSpace + 1).trim();
        params.add(ModuleMethodParam(
          name: name,
          type: type,
          isRequired: isRequired,
          defaultValue: defaultValue,
        ));
      }
    }
    return params;
  }

  /// Emits typed Dart bridge (lib/src/<name>.g.dart).
  static String generateDartBridge(ModuleParsedDefinition def, String baseFileName) {
    final buffer = StringBuffer();
    final className = def.moduleName;

    buffer.writeln('// AUTO-GENERATED BY BLOOM MODULE GENERATOR. DO NOT EDIT.');
    buffer.writeln('// Generated from $baseFileName.module.dart');
    buffer.writeln('// ignore_for_file: unused_import, unnecessary_cast, unused_element');
    buffer.writeln();
    buffer.writeln("import 'dart:async';");
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'package:flutter/services.dart';");
    buffer.writeln("import 'package:bloom_framework/bloom.dart';");
    buffer.writeln("import '$baseFileName.module.dart';");
    buffer.writeln();
    buffer.writeln('/// Strongly-typed platform bridge implementing [${def.definitionClassName}].');
    buffer.writeln('abstract class Bloom${className}Bridge extends BloomNativeModule implements ${def.definitionClassName} {');
    buffer.writeln('  Bloom${className}Bridge() : super(name: \'$className\', version: \'${def.version}\');');
    buffer.writeln();

    // Constants
    for (final c in def.constants) {
      buffer.writeln('  @override');
      if (c.type == 'String' || c.type == 'String?') {
        buffer.writeln('  ${c.type} get ${c.name} => getProperty<String>(\'${c.name}\') ?? \'\';');
      } else if (c.type == 'int' || c.type == 'int?') {
        buffer.writeln('  ${c.type} get ${c.name} => getProperty<int>(\'${c.name}\') ?? 0;');
      } else if (c.type == 'double' || c.type == 'double?') {
        buffer.writeln('  ${c.type} get ${c.name} => getProperty<double>(\'${c.name}\') ?? 0.0;');
      } else if (c.type == 'bool' || c.type == 'bool?') {
        buffer.writeln('  ${c.type} get ${c.name} => getProperty<bool>(\'${c.name}\') ?? false;');
      } else if (c.type.startsWith('List<')) {
        buffer.writeln('  ${c.type} get ${c.name} => (getProperty<List<dynamic>>(\'${c.name}\') ?? const []).cast();');
      } else if (c.type.startsWith('Map<')) {
        buffer.writeln('  ${c.type} get ${c.name} => (getProperty<Map<dynamic, dynamic>>(\'${c.name}\') ?? const {}).cast();');
      } else {
        buffer.writeln('  ${c.type} get ${c.name} => getProperty<${c.type}>(\'${c.name}\') as ${c.type};');
      }
      buffer.writeln();
    }

    // Async Methods
    for (final m in def.methods.where((m) => !m.isSync)) {
      buffer.writeln('  @override');
      final paramsSig = m.parameters.isEmpty
          ? ''
          : '{' +
              m.parameters
                  .map((p) =>
                      '${p.isRequired ? "required " : ""}${p.type} ${p.name}${p.defaultValue != null ? " = ${p.defaultValue}" : ""}')
                  .join(', ') +
              '}';

      buffer.writeln('  Future<${m.returnType}> ${m.name}($paramsSig) async {');
      buffer.writeln('    final payload = <String, dynamic>{');
      for (final p in m.parameters) {
        if (p.type == 'DateTime' || p.type == 'DateTime?') {
          buffer.writeln("      '${p.name}': ${p.name}?.toIso8601String(),");
        } else {
          buffer.writeln("      '${p.name}': ${p.name},");
        }
      }
      buffer.writeln('    };');
      buffer.writeln();

      final threadEnum = 'NativeThread.${m.thread}';
      if (m.returnType == 'void' || m.returnType == 'Null') {
        buffer.writeln("    await invokeAsync<dynamic>('${m.name}', payload, $threadEnum);");
      } else if (m.returnType == 'Map<String, dynamic>') {
        buffer.writeln("    final result = await invokeAsync<Map<dynamic, dynamic>>('${m.name}', payload, $threadEnum);");
        buffer.writeln('    return result != null ? Map<String, dynamic>.from(result) : <String, dynamic>{};');
      } else if (m.returnType == 'List<String>') {
        buffer.writeln("    final result = await invokeAsync<List<dynamic>>('${m.name}', payload, $threadEnum);");
        buffer.writeln('    return result != null ? List<String>.from(result) : <String>[];');
      } else {
        buffer.writeln("    final result = await invokeAsync<${m.returnType}>('${m.name}', payload, $threadEnum);");
        buffer.writeln('    return result as ${m.returnType};');
      }
      buffer.writeln('  }');
      buffer.writeln();
    }

    // Sync Methods
    for (final m in def.methods.where((m) => m.isSync)) {
      buffer.writeln('  @override');
      final paramsSig = m.parameters.isEmpty
          ? ''
          : '{' +
              m.parameters
                  .map((p) =>
                      '${p.isRequired ? "required " : ""}${p.type} ${p.name}${p.defaultValue != null ? " = ${p.defaultValue}" : ""}')
                  .join(', ') +
              '}';
      buffer.writeln('  ${m.returnType} ${m.name}($paramsSig) {');
      buffer.writeln('    return getProperty<${m.returnType}>(\'${m.name}\') as ${m.returnType};');
      buffer.writeln('  }');
      buffer.writeln();
    }

    // Streams & Events
    for (final s in def.streams) {
      buffer.writeln('  @override');
      buffer.writeln('  Stream<${s.type}> get ${s.name} => subscribeStream<${s.type}>(\'${s.name}\');');
      buffer.writeln();
    }

    // Views
    for (final v in def.views) {
      buffer.writeln('  @override');
      final paramsSig = v.props.isEmpty
          ? ''
          : '{' +
              v.props
                  .map((p) =>
                      '${p.isRequired ? "required " : ""}${p.type} ${p.name}${p.defaultValue != null ? " = ${p.defaultValue}" : ""}')
                  .join(', ') +
              '}';
      buffer.writeln('  void ${v.methodName}($paramsSig) {}');
      buffer.writeln();
    }

    // Lifecycle Hooks
    for (final hook in def.lifecycleHooks) {
      buffer.writeln('  @override');
      buffer.writeln('  void $hook() {}');
      buffer.writeln();
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  /// Emits Swift bridge protocol and method dispatcher.
  static String generateSwiftBridge(ModuleParsedDefinition def) {
    final buffer = StringBuffer();
    final name = def.moduleName;

    buffer.writeln('// AUTO-GENERATED BY BLOOM MODULE GENERATOR. DO NOT EDIT.');
    buffer.writeln('import Foundation');
    buffer.writeln('import Flutter');
    buffer.writeln();
    buffer.writeln('/// Swift protocol for $name Module native operations.');
    buffer.writeln('public protocol ${name}ModuleBridge: AnyObject {');
    for (final c in def.constants) {
      buffer.writeln('    var ${c.name}: String { get }');
    }
    for (final m in def.methods) {
      final swiftParams = m.parameters.map((p) => '${p.name}: ${p.type == "String" ? "String" : "Any?"}').join(', ');
      buffer.writeln('    func ${m.name}($swiftParams) async throws -> Any?');
    }
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('/// Method channel dispatcher mapping incoming Flutter method calls to [${name}ModuleBridge].');
    buffer.writeln('public class ${name}ModuleDispatcher: NSObject, FlutterStreamHandler {');
    buffer.writeln('    private weak var bridge: ${name}ModuleBridge?');
    buffer.writeln('    private var eventSink: FlutterEventSink?');
    buffer.writeln();
    buffer.writeln('    public init(bridge: ${name}ModuleBridge) {');
    buffer.writeln('        self.bridge = bridge');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {');
    buffer.writeln('        Task {');
    buffer.writeln('            do {');
    buffer.writeln('                let args = call.arguments as? [String: Any] ?? [:]');
    buffer.writeln('                switch call.method {');
    for (final m in def.methods) {
      buffer.writeln('                case "${m.name}":');
      final swiftArgs = m.parameters.map((p) => '${p.name}: args["${p.name}"] as? ${p.type == "String" ? "String" : "Any"}').join(', ');
      buffer.writeln('                    if let res = try await bridge?.${m.name}($swiftArgs) {');
      buffer.writeln('                        result(res)');
      buffer.writeln('                    } else {');
      buffer.writeln('                        result(nil)');
      buffer.writeln('                    }');
    }
    buffer.writeln('                default:');
    buffer.writeln('                    result(FlutterMethodNotImplemented)');
    buffer.writeln('                }');
    buffer.writeln('            } catch {');
    buffer.writeln('                result(FlutterError(code: "OPERATION_FAILED", message: error.localizedDescription, details: nil))');
    buffer.writeln('            }');
    buffer.writeln('        }');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {');
    buffer.writeln('        self.eventSink = events');
    buffer.writeln('        return nil');
    buffer.writeln('    }');
    buffer.writeln('    public func onCancel(withArguments arguments: Any?) -> FlutterError? {');
    buffer.writeln('        self.eventSink = nil');
    buffer.writeln('        return nil');
    buffer.writeln('    }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Emits Kotlin bridge interface and dispatcher.
  static String generateKotlinBridge(ModuleParsedDefinition def, String ktDirPath) {
    final buffer = StringBuffer();
    final name = def.moduleName;

    // Derive package from android/src/main/kotlin directory structure
    String pkgName = 'dev.bloom.modules.${def.moduleName.toLowerCase()}';
    final kotlinIdx = ktDirPath.indexOf('src/main/kotlin/');
    if (kotlinIdx != -1) {
      final sub = ktDirPath.substring(kotlinIdx + 'src/main/kotlin/'.length);
      pkgName = sub.replaceAll('/', '.').replaceAll('\\', '.');
    }

    buffer.writeln('// AUTO-GENERATED BY BLOOM MODULE GENERATOR. DO NOT EDIT.');
    buffer.writeln('package $pkgName');
    buffer.writeln();
    buffer.writeln('import io.flutter.plugin.common.MethodCall');
    buffer.writeln('import io.flutter.plugin.common.MethodChannel');
    buffer.writeln('import io.flutter.plugin.common.EventChannel');
    buffer.writeln('import kotlinx.coroutines.CoroutineScope');
    buffer.writeln('import kotlinx.coroutines.Dispatchers');
    buffer.writeln('import kotlinx.coroutines.launch');
    buffer.writeln();
    buffer.writeln('/// Kotlin interface for $name Module native operations.');
    buffer.writeln('interface ${name}ModuleBridge {');
    for (final c in def.constants) {
      buffer.writeln('    val ${c.name}: String');
    }
    for (final m in def.methods) {
      final ktParams = m.parameters.map((p) => '${p.name}: Any?').join(', ');
      buffer.writeln('    suspend fun ${m.name}($ktParams): Any?');
    }
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('/// Method channel dispatcher mapping incoming Flutter method calls to [${name}ModuleBridge].');
    buffer.writeln('class ${name}ModuleDispatcher(');
    buffer.writeln('    private val bridge: ${name}ModuleBridge,');
    buffer.writeln('    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main)');
    buffer.writeln(') : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {');
    buffer.writeln('    private var eventSink: EventChannel.EventSink? = null');
    buffer.writeln();
    buffer.writeln('    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {');
    buffer.writeln('        val args = call.arguments as? Map<String, Any?> ?: emptyMap()');
    buffer.writeln('        scope.launch {');
    buffer.writeln('            try {');
    buffer.writeln('                when (call.method) {');
    for (final m in def.methods) {
      buffer.writeln('                    "${m.name}" -> {');
      final ktArgs = m.parameters.map((p) => 'args["${p.name}"]').join(', ');
      buffer.writeln('                        val res = bridge.${m.name}($ktArgs)');
      buffer.writeln('                        result.success(res)');
      buffer.writeln('                    }');
    }
    buffer.writeln('                    else -> result.notImplemented()');
    buffer.writeln('                }');
    buffer.writeln('            } catch (e: Exception) {');
    buffer.writeln('                result.error("OPERATION_FAILED", e.message, null)');
    buffer.writeln('            }');
    buffer.writeln('        }');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {');
    buffer.writeln('        this.eventSink = events');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    override fun onCancel(arguments: Any?) {');
    buffer.writeln('        this.eventSink = null');
    buffer.writeln('    }');
    buffer.writeln('}');

    return buffer.toString();
  }
}
