import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Represents an exported member parsed from TypeScript definitions.
class DtsExportedFunction {
  final String name;
  final List<DtsParam> params;
  final String returnType;

  const DtsExportedFunction({
    required this.name,
    this.params = const [],
    this.returnType = 'JSAny?',
  });
}

class DtsParam {
  final String rawName;
  final String dartName;
  final String type;
  final bool isOptional;

  const DtsParam({
    required this.rawName,
    required this.dartName,
    required this.type,
    required this.isOptional,
  });
}

class DtsTypeDefinition {
  final String name;
  final Map<String, String> properties; // propName -> tsType

  const DtsTypeDefinition({
    required this.name,
    required this.properties,
  });

  bool get isAllPrimitives {
    if (properties.isEmpty) return false;
    for (final t in properties.values) {
      final clean = t
          .trim()
          .replaceAll(RegExp(r'\s*\|\s*undefined'), '')
          .replaceAll(RegExp(r'\s*\|\s*null'), '');
      if (clean != 'string' && clean != 'number' && clean != 'boolean') {
        return false;
      }
    }
    return true;
  }
}

class DtsCodegen {
  final http.Client _client;
  DtsCodegen({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  /// Fetches TypeScript definitions (.d.ts) and generates a Dart 3.5+ @JS() extension type binding file.
  Future<void> generate({
    required String packageName,
    required String version,
    required String outputPath,
    String? jsGlobalHint,
    String? typesEntry,
    String? bundlePath,
  }) async {
    String? dtsContent;
    String? rootDtsUrl;

    // 1. Try package metadata types entry via unpkg, then esm.sh
    if (typesEntry != null && typesEntry.isNotEmpty) {
      final cleanTypes =
          typesEntry.startsWith('./') ? typesEntry.substring(2) : typesEntry;
      final unpkgUrl = 'https://unpkg.com/$packageName@$version/$cleanTypes';
      try {
        final resp = await _client.get(Uri.parse(unpkgUrl));
        if (resp.statusCode == 200 && resp.body.isNotEmpty) {
          dtsContent = resp.body;
          rootDtsUrl = unpkgUrl;
        }
      } catch (_) {}

      if (dtsContent == null || dtsContent.isEmpty) {
        final esmDirectUrl = 'https://esm.sh/$packageName@$version/$cleanTypes';
        try {
          final resp = await _client.get(Uri.parse(esmDirectUrl));
          if (resp.statusCode == 200 && resp.body.isNotEmpty) {
            dtsContent = resp.body;
            rootDtsUrl = esmDirectUrl;
          }
        } catch (_) {}
      }
    }

    // 2. Ask esm.sh for the TypeScript types header
    if (dtsContent == null || dtsContent.isEmpty) {
      try {
        final esmUrl = 'https://esm.sh/$packageName@$version';
        final resp = await _client.get(Uri.parse(esmUrl));
        final dtsUrl = resp.headers['x-typescript-types'];
        if (dtsUrl != null) {
          final dtsResp = await _client.get(Uri.parse(dtsUrl));
          if (dtsResp.statusCode == 200 && dtsResp.body.isNotEmpty) {
            dtsContent = dtsResp.body;
            rootDtsUrl = dtsUrl;
          }
        }
      } catch (_) {}
    }

    // 3. Fall back to DefinitelyTyped (@types/*)
    if (dtsContent == null || dtsContent.isEmpty) {
      try {
        final atPkg = packageName.startsWith('@')
            ? packageName.replaceAll('@', '').replaceAll('/', '__')
            : packageName;
        final dtUrl = 'https://esm.sh/@types/$atPkg/index.d.ts';
        final dtResp = await _client.get(Uri.parse(dtUrl));
        if (dtResp.statusCode == 200 && dtResp.body.isNotEmpty) {
          dtsContent = dtResp.body;
          rootDtsUrl = dtUrl;
        }
      } catch (_) {}
    }

    // Traverse re-export graph if rootDtsUrl and dtsContent are present
    final graphContents = <String>[];
    if (dtsContent != null && dtsContent.isNotEmpty) {
      graphContents.add(dtsContent);
      if (rootDtsUrl != null) {
        final visited = <String>{rootDtsUrl};
        final manifests = <String, Map<String, dynamic>>{};
        await _fetchReexports(
          rootDtsUrl,
          dtsContent,
          graphContents,
          visited,
          manifests,
          packageName,
          version,
          0,
        );
      }
    }

    // Read bundle content for ESM fallback if available
    String? bundleContent;
    if (bundlePath != null) {
      try {
        final bFile = File(bundlePath);
        if (await bFile.exists()) {
          bundleContent = await bFile.readAsString();
        }
      } catch (_) {}
    }

    final dartCode = _emitWithGraph(
      packageName: packageName,
      version: version,
      graphContents: graphContents,
      bundleContent: bundleContent,
      jsGlobalHint: jsGlobalHint,
    );

    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsString(dartCode);
  }

  /// Recursively fetches re-exported .d.ts files up to max depth 10.
  Future<void> _fetchReexports(
    String currentUrl,
    String content,
    List<String> collectedContents,
    Set<String> visitedUrls,
    Map<String, Map<String, dynamic>> manifests,
    String packageName,
    String version,
    int depth,
  ) async {
    if (depth >= 10) return;

    final reexportSpecifiers = _extractReexportSpecifiers(content);
    for (final spec in reexportSpecifiers) {
      final resolvedCandidates = spec.startsWith('.')
          ? _resolveSpecifierUrls(currentUrl, spec)
          : await _resolvePackageSpecifier(
              spec,
              packageName,
              version,
              manifests,
            );
      for (final candidateUrl in resolvedCandidates) {
        if (visitedUrls.contains(candidateUrl)) continue;
        visitedUrls.add(candidateUrl);
        try {
          final resp = await _client.get(Uri.parse(candidateUrl));
          if (resp.statusCode == 200 && resp.body.isNotEmpty) {
            collectedContents.add(resp.body);
            final package = _packageForUrl(candidateUrl, packageName, version);
            await _fetchReexports(
              candidateUrl,
              resp.body,
              collectedContents,
              visitedUrls,
              manifests,
              package.$1,
              package.$2,
              depth + 1,
            );
            break; // resolved this specifier
          }
        } catch (_) {}
      }
    }
  }

  Future<List<String>> _resolvePackageSpecifier(
    String specifier,
    String currentPackage,
    String currentVersion,
    Map<String, Map<String, dynamic>> manifests,
  ) async {
    final parts = _splitPackageSpecifier(specifier);
    if (parts == null) return [];
    final dependency = parts.$1;
    final subpath = parts.$2;
    final currentManifest = await _packageManifest(
      currentPackage,
      currentVersion,
      manifests,
    );
    final dependencies = currentManifest?['dependencies'];
    final peers = currentManifest?['peerDependencies'];
    final range =
        dependencies is Map ? dependencies[dependency]?.toString() : null;
    final peerRange = peers is Map ? peers[dependency]?.toString() : null;
    final dependencyRange = range ?? peerRange;
    if (dependencyRange == null) return [];

    final manifest = await _packageManifest(
      dependency,
      dependencyRange,
      manifests,
    );
    if (manifest == null) return [];
    final entry = _typesExport(manifest['exports'], subpath) ??
        (subpath.isEmpty
            ? (manifest['types'] ?? manifest['typings'])?.toString()
            : null);
    if (entry == null || entry.isEmpty) return [];
    final cleanEntry = entry.startsWith('./') ? entry.substring(2) : entry;
    return ['https://unpkg.com/$dependency@$dependencyRange/$cleanEntry'];
  }

  Future<Map<String, dynamic>?> _packageManifest(
    String package,
    String version,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    final key = '$package@$version';
    if (cache.containsKey(key)) return cache[key];
    try {
      final response = await _client.get(Uri.parse(
        'https://unpkg.com/$package@$version/package.json',
      ));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        cache[key] = decoded;
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  static (String, String)? _splitPackageSpecifier(String specifier) {
    final pieces = specifier.split('/');
    final packageEnd = specifier.startsWith('@') ? 2 : 1;
    if (pieces.length < packageEnd) return null;
    final package = pieces.take(packageEnd).join('/');
    final subpath = pieces.skip(packageEnd).join('/');
    return (package, subpath);
  }

  static String? _typesExport(dynamic exports, String subpath) {
    if (exports is! Map) return null;
    final key = subpath.isEmpty ? '.' : './$subpath';
    dynamic value = exports.containsKey(key) ? exports[key] : null;
    if (value == null &&
        subpath.isEmpty &&
        !exports.keys.any(
          (key) => key.toString().startsWith('.'),
        )) {
      value = exports;
    }
    return _typesCondition(value);
  }

  static String? _typesCondition(dynamic value) {
    if (value is String) return value.endsWith('.d.ts') ? value : null;
    if (value is! Map) return null;
    final types = _typesCondition(value['types']);
    if (types != null) return types;
    for (final condition in ['import', 'default']) {
      final result = _typesCondition(value[condition]);
      if (result != null) return result;
    }
    return null;
  }

  static (String, String) _packageForUrl(
    String url,
    String fallbackPackage,
    String fallbackVersion,
  ) {
    final match = RegExp(r'https://unpkg\.com/(@[^/]+/[^@/]+|[^/@]+)@([^/]+)/')
        .firstMatch(url);
    return match == null
        ? (fallbackPackage, fallbackVersion)
        : (match.group(1)!, match.group(2)!);
  }

  static List<String> _resolveSpecifierUrls(
      String currentUrl, String specifier) {
    // Current directory URL ending with /
    final lastSlash = currentUrl.lastIndexOf('/');
    final baseDirUrl = lastSlash >= 0
        ? currentUrl.substring(0, lastSlash + 1)
        : '$currentUrl/';
    final baseUri = Uri.parse(baseDirUrl);

    final candidates = <String>[];
    if (specifier.endsWith('.d.ts')) {
      candidates.add(baseUri.resolve(specifier).toString());
    } else {
      candidates.add(baseUri.resolve('$specifier.d.ts').toString());
      candidates.add(baseUri.resolve('$specifier/index.d.ts').toString());
    }
    return candidates;
  }

  static List<String> _extractReexportSpecifiers(String dts) {
    final specifiers = <String>[];
    // export * from '...'
    final starRegex = RegExp(r'''export\s*\*\s*from\s*['"]([^'"]+)['"]''');
    for (final m in starRegex.allMatches(dts)) {
      specifiers.add(m.group(1)!);
    }
    // export { ... } from '...'
    final namedRegex =
        RegExp(r'''export\s*(?!type\b)\{[^}]*\}\s*from\s*['"]([^'"]+)['"]''');
    for (final m in namedRegex.allMatches(dts)) {
      specifiers.add(m.group(1)!);
    }
    return specifiers;
  }

  /// Parses TypeScript definition (.d.ts) content for exported member names.
  static Set<String> parseExports(String dts) {
    final exports = LinkedHashSet<String>();

    // 1. export declare function / export function
    final funcRegex = RegExp(
      r'export\s+(?:declare\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)',
      multiLine: true,
    );
    for (final match in funcRegex.allMatches(dts)) {
      exports.add(match.group(1)!);
    }

    // 2. export declare const/let/var / export const/let/var
    final constRegex = RegExp(
      r'export\s+(?:declare\s+)?(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)',
      multiLine: true,
    );
    for (final match in constRegex.allMatches(dts)) {
      exports.add(match.group(1)!);
    }

    // 3. export declare class / export class
    final classRegex = RegExp(
      r'export\s+(?:declare\s+)?class\s+([A-Za-z_$][A-Za-z0-9_$]*)',
      multiLine: true,
    );
    for (final match in classRegex.allMatches(dts)) {
      exports.add(match.group(1)!);
    }

    // 4. export default <name> or export default function <name>
    final defaultRegex = RegExp(
      r'export\s+default\s+(?:function\s+)?([A-Za-z_$][A-Za-z0-9_$]*)?',
      multiLine: true,
    );
    for (final match in defaultRegex.allMatches(dts)) {
      final name = match.group(1);
      if (name != null && name.isNotEmpty && name != 'function') {
        exports.add(name);
      }
      exports.add('default');
    }

    // 5. Barrel re-exports: export { a, b as c, ... }
    final barrelRegex = RegExp(
      r'export\s*(?!type\b)\{\s*([^}]+)\s*\}',
      multiLine: true,
    );
    for (final match in barrelRegex.allMatches(dts)) {
      final block = match.group(1)!;
      final items = block.split(',');
      for (final item in items) {
        final clean = item.trim();
        if (clean.isEmpty) continue;
        if (clean.startsWith('type ')) {
          continue;
        }
        if (clean.contains(RegExp(r'\s+as\s+'))) {
          final parts = clean.split(RegExp(r'\s+as\s+'));
          if (parts.length == 2) {
            final alias = parts[1].trim();
            if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(alias)) {
              exports.add(alias);
            }
          }
        } else {
          if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(clean)) {
            exports.add(clean);
          }
        }
      }
    }

    return exports;
  }

  static Map<String, String> _parseLocalExportAliases(String dts) {
    final aliases = <String, String>{};
    final listRegex = RegExp(
      r'export\s*(?!type\b)\{\s*([^}]+)\s*\}(?!\s*from)',
      multiLine: true,
    );
    for (final match in listRegex.allMatches(dts)) {
      for (final item in match.group(1)!.split(',')) {
        final clean = item.trim();
        if (clean.isEmpty || clean.startsWith('type ')) continue;
        final parts = clean.split(RegExp(r'\s+as\s+'));
        if (parts.length == 2 &&
            RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(parts[0]) &&
            RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(parts[1])) {
          aliases[parts[1]] = parts[0];
        }
      }
    }
    return aliases;
  }

  /// Extracts export names from ESM bundle text.
  static Set<String> parseEsmBundleExports(String bundleText) {
    final exports = LinkedHashSet<String>();

    // 1. export { a as b, c }
    final exportBlockRegex = RegExp(r'export\s*\{([^}]+)\}', multiLine: true);
    for (final match in exportBlockRegex.allMatches(bundleText)) {
      final block = match.group(1)!;
      for (final item in block.split(',')) {
        final clean = item.trim();
        if (clean.isEmpty) continue;
        if (clean.contains(RegExp(r'\s+as\s+'))) {
          final parts = clean.split(RegExp(r'\s+as\s+'));
          if (parts.length == 2) {
            final alias = parts[1].trim();
            if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(alias)) {
              exports.add(alias);
            }
          }
        } else {
          if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(clean)) {
            exports.add(clean);
          }
        }
      }
    }

    // 2. export function x
    final funcRegex = RegExp(r'export\s+function\s+([A-Za-z_$][A-Za-z0-9_$]*)',
        multiLine: true);
    for (final match in funcRegex.allMatches(bundleText)) {
      exports.add(match.group(1)!);
    }

    // 3. export const/let/var x
    final constRegex = RegExp(
        r'export\s+(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)',
        multiLine: true);
    for (final match in constRegex.allMatches(bundleText)) {
      exports.add(match.group(1)!);
    }

    // 4. export class X
    final classRegex =
        RegExp(r'export\s+class\s+([A-Za-z_$][A-Za-z0-9_$]*)', multiLine: true);
    for (final match in classRegex.allMatches(bundleText)) {
      exports.add(match.group(1)!);
    }

    return exports;
  }

  /// Parses interface and type declarations from DTS files.
  static Map<String, DtsTypeDefinition> parseTypeDefinitions(
      List<String> dtsList) {
    final typeDefs = <String, DtsTypeDefinition>{};

    for (final dts in dtsList) {
      // interface Name { ... }
      final interfaceRegex = RegExp(
        r'(?:export\s+)?(?:declare\s+)?interface\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:<[^>]*>)?\s*\{([^}]*)\}',
        multiLine: true,
      );
      for (final m in interfaceRegex.allMatches(dts)) {
        final name = m.group(1)!;
        final body = m.group(2)!;
        final props = _parseProperties(body);
        typeDefs[name] = DtsTypeDefinition(name: name, properties: props);
      }

      // type Name = { ... }
      final typeAliasRegex = RegExp(
        r'(?:export\s+)?(?:declare\s+)?type\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:<[^>]*>)?\s*=\s*\{([^}]*)\}',
        multiLine: true,
      );
      for (final m in typeAliasRegex.allMatches(dts)) {
        final name = m.group(1)!;
        final body = m.group(2)!;
        final props = _parseProperties(body);
        typeDefs[name] = DtsTypeDefinition(name: name, properties: props);
      }
    }

    return typeDefs;
  }

  static Map<String, String> _parseProperties(String body) {
    final props = <String, String>{};
    final lines = body.split(RegExp(r'[;\n]'));
    for (final line in lines) {
      final clean = line.trim();
      if (clean.isEmpty || clean.startsWith('//') || clean.startsWith('/*'))
        continue;
      // prop?: type or prop: type
      final colonIdx = clean.indexOf(':');
      if (colonIdx > 0) {
        var propName = clean.substring(0, colonIdx).trim();
        if (propName.endsWith('?')) {
          propName = propName.substring(0, propName.length - 1).trim();
        }
        var propType = clean.substring(colonIdx + 1).trim();
        if (propType.endsWith(';')) {
          propType = propType.substring(0, propType.length - 1).trim();
        }
        if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(propName)) {
          props[propName] = propType;
        }
      }
    }
    return props;
  }

  /// Parses functions with detailed signatures from DTS files.
  /// Handles overloads by choosing the overload with the most parameters,
  /// making all parameters beyond the shortest signature optional.
  static Map<String, DtsExportedFunction> parseDetailedFunctions(
    List<String> dtsList,
    Map<String, DtsTypeDefinition> typeDefs,
  ) {
    // Map function name -> list of parsed overloads
    final overloadMap = <String, List<_RawFunctionSig>>{};

    // Match: export [declare] function name(params): returnType;
    // Also match: declare function name(params): returnType;
    for (final dts in dtsList) {
      final funcRegex = RegExp(
        r'(?:export\s+)?(?:declare\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:<[^>]*>)?\s*\(',
        dotAll: true,
      );
      for (final m in funcRegex.allMatches(dts)) {
        final open = dts.indexOf('(', m.start);
        final close = _matchingDelimiter(dts, open, '(', ')');
        if (close < 0) continue;
        final colon = dts.indexOf(':', close);
        final end = dts.indexOf(';', close);
        if (colon < 0 || end < 0 || colon > end) continue;
        final name = m.group(1)!;
        final rawParams = dts.substring(open + 1, close);
        final rawReturn = dts.substring(colon + 1, end).trim();
        final parsedParams = _parseParamList(rawParams, typeDefs);
        overloadMap.putIfAbsent(name, () => []).add(_RawFunctionSig(
              params: parsedParams,
              returnType: _mapTsTypeToDart(rawReturn, typeDefs),
            ));
      }

      final constRegex = RegExp(
        r'(?:export\s+)?(?:declare\s+)?const\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*:\s*\{',
        dotAll: true,
      );
      for (final m in constRegex.allMatches(dts)) {
        final open = dts.indexOf('{', m.start);
        final close = _matchingDelimiter(dts, open, '{', '}');
        if (close < 0) continue;
        final body = dts.substring(open + 1, close);
        final signatures =
            RegExp(r'\(.*?\)\s*:\s*[^;]+;', dotAll: true).allMatches(body);
        final name = m.group(1)!;
        for (final signature in signatures) {
          final text = signature.group(0)!;
          final paren = text.indexOf('(');
          final endParen = _matchingDelimiter(text, paren, '(', ')');
          if (endParen < 0) continue;
          final rawParams = text.substring(paren + 1, endParen);
          final rawReturn = text
              .substring(text.indexOf(':', endParen) + 1)
              .replaceFirst(RegExp(r';\s*$'), '')
              .trim();
          overloadMap.putIfAbsent(name, () => []).add(_RawFunctionSig(
                params: _parseParamList(rawParams, typeDefs),
                returnType: _mapTsTypeToDart(rawReturn, typeDefs),
              ));
        }
      }
    }

    final result = <String, DtsExportedFunction>{};

    for (final entry in overloadMap.entries) {
      final name = entry.key;
      final overloads = entry.value;
      if (overloads.isEmpty) continue;

      if (overloads.length == 1) {
        result[name] = DtsExportedFunction(
          name: name,
          params: overloads.first.params,
          returnType: overloads.first.returnType,
        );
      } else {
        // Pick the overload with the most parameters
        int maxLen = -1;
        _RawFunctionSig bestSig = overloads.first;

        for (final sig in overloads) {
          if (sig.params.length > maxLen) {
            maxLen = sig.params.length;
            bestSig = sig;
          }
        }

        // Merge each position across overloads.
        final resolvedParams = <DtsParam>[];
        for (var i = 0; i < bestSig.params.length; i++) {
          final p = bestSig.params[i];
          final positionParams = overloads
              .where((sig) => i < sig.params.length)
              .map((sig) => sig.params[i])
              .toList();
          final types = positionParams.map((param) => param.type).toSet();
          final isOpt = positionParams.length != overloads.length ||
              positionParams.any((param) => param.isOptional);
          resolvedParams.add(DtsParam(
            rawName: p.rawName,
            dartName: p.dartName,
            type: types.length == 1 ? types.first : 'JSAny?',
            isOptional: isOpt,
          ));
        }

        result[name] = DtsExportedFunction(
          name: name,
          params: resolvedParams,
          returnType: overloads.map((sig) => sig.returnType).toSet().length == 1
              ? bestSig.returnType
              : 'JSAny?',
        );
      }
    }

    return result;
  }

  static List<DtsParam> _parseParamList(
      String rawParams, Map<String, DtsTypeDefinition> typeDefs) {
    if (rawParams.trim().isEmpty) return [];

    final params = <DtsParam>[];
    // Split by commas taking nesting into account
    final tokens = _splitParams(rawParams);
    final seenNames = <String>{};

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i].trim();
      if (token.isEmpty) continue;

      // rest param: ...args: any[]
      final isRest = token.startsWith('...');
      var cleanToken = isRest ? token.substring(3).trim() : token;

      var namePart = cleanToken;
      var typePart = 'any';

      // Only top-level ':' and '=' count: destructuring patterns contain
      // renames (`{ margin: rootMargin }`) and function types contain `=>`.
      final colonIdx = _topLevelIndexOf(cleanToken, ':');
      if (colonIdx >= 0) {
        namePart = cleanToken.substring(0, colonIdx).trim();
        typePart = cleanToken.substring(colonIdx + 1).trim();
      }
      final defaultIdx = _topLevelIndexOf(namePart, '=');
      if (defaultIdx >= 0) {
        namePart = namePart.substring(0, defaultIdx).trim();
      }

      final isOptional = namePart.endsWith('?') || defaultIdx >= 0;
      if (namePart.startsWith('{') || namePart.startsWith('[')) {
        namePart = 'options';
        var n = 2;
        while (seenNames.contains(_toDartParamName(namePart, i))) {
          namePart = 'options${n++}';
        }
      }
      if (namePart.endsWith('?')) {
        namePart = namePart.substring(0, namePart.length - 1).trim();
      }

      var sanitizedName = _toDartParamName(namePart, i);
      if (seenNames.contains(sanitizedName)) {
        sanitizedName = '${sanitizedName}_$i';
      }
      seenNames.add(sanitizedName);

      final dartType =
          isRest ? 'JSArray<JSAny?>' : _mapTsTypeToDart(typePart, typeDefs);

      params.add(DtsParam(
        rawName: namePart,
        dartName: sanitizedName,
        type: dartType,
        isOptional: isOptional,
      ));
    }

    return params;
  }

  /// Index of [char] outside any (), {}, [] or <> nesting, or -1. The `>` of
  /// an arrow (`=>`) is not a closing bracket, and the `=` of `=>` is skipped.
  static int _topLevelIndexOf(String raw, String char) {
    var depth = 0;
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '(' || c == '{' || c == '[' || c == '<') {
        depth++;
      } else if (c == ')' || c == '}' || c == ']') {
        depth--;
      } else if (c == '>' && (i == 0 || raw[i - 1] != '=')) {
        depth--;
      } else if (c == char && depth == 0) {
        if (c == '=' && i + 1 < raw.length && raw[i + 1] == '>') continue;
        return i;
      }
    }
    return -1;
  }

  static List<String> _splitParams(String raw) {
    final result = <String>[];
    var depth = 0;
    var current = StringBuffer();

    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == '(' || char == '{' || char == '[' || char == '<') {
        depth++;
        current.write(char);
      } else if (char == ')' || char == '}' || char == ']') {
        depth--;
        current.write(char);
      } else if (char == '>' && (i == 0 || raw[i - 1] != '=')) {
        depth--;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) {
      result.add(current.toString());
    }
    return result;
  }

  static int _matchingDelimiter(
    String source,
    int start,
    String opening,
    String closing,
  ) {
    if (start < 0 || start >= source.length) return -1;
    var depth = 0;
    for (var i = start; i < source.length; i++) {
      if (source[i] == opening) depth++;
      if (source[i] == closing && --depth == 0) return i;
    }
    return -1;
  }

  static String _mapTsTypeToDart(
      String tsType, Map<String, DtsTypeDefinition> typeDefs) {
    final clean = tsType.trim();

    // Check if clean matches an option object interface/type with all primitives
    final stripped = clean
        .replaceAll(RegExp(r'\s*\|\s*undefined'), '')
        .replaceAll(RegExp(r'\s*\|\s*null'), '');
    if (typeDefs.containsKey(stripped)) {
      final def = typeDefs[stripped]!;
      if (def.isAllPrimitives) {
        return def.name;
      }
    }

    if (clean == 'void') return 'void';
    if (clean == 'string') return 'String';
    if (clean == 'number') return 'num';
    if (clean == 'boolean') return 'bool';

    // Promise<...>
    if (clean.startsWith('Promise<') || clean == 'Promise') {
      return 'JSPromise<JSAny?>';
    }

    // Function types: (...) => ..., Function
    if (clean.contains('=>') || clean == 'Function') {
      return 'JSFunction';
    }

    // Array types: ...[] or Array<...>
    if (clean.endsWith('[]') || clean.startsWith('Array<')) {
      return 'JSArray<JSAny?>';
    }

    return 'JSAny?';
  }

  static String _emitWithGraph({
    required String packageName,
    required String version,
    required List<String> graphContents,
    String? bundleContent,
    String? jsGlobalHint,
  }) {
    final className = _toPascalCase(packageName);
    final jsGlobal = jsGlobalHint ?? _inferGlobal(packageName);

    final getterName = _isValidDartIdentifier(jsGlobal)
        ? jsGlobal
        : '${_toCamelCase(className)}Global';

    // 1. Collect all exported names across the DTS graph
    final allDtsExports = LinkedHashSet<String>();
    for (final dts in graphContents) {
      allDtsExports.addAll(parseExports(dts));
    }

    // 2. Parse type definitions (interfaces and types)
    final typeDefs = parseTypeDefinitions(graphContents);

    // 3. Parse detailed functions
    final detailedFunctions = parseDetailedFunctions(graphContents, typeDefs);

    // 4. Track option extension types to emit
    final optionTypesToEmit = LinkedHashMap<String, DtsTypeDefinition>();

    // Determine fallback mode if allDtsExports is empty
    Set<String>? esmBundleExports;
    if (bundleContent != null && bundleContent.isNotEmpty) {
      final esmExports = parseEsmBundleExports(bundleContent);
      if (esmExports.isNotEmpty) {
        esmBundleExports = esmExports;
      }
    }
    final localAliases = <String, String>{};
    for (final dts in graphContents) {
      localAliases.addAll(_parseLocalExportAliases(dts));
    }

    final buffer = StringBuffer();
    buffer.writeln('// AUTO-GENERATED by `bloom add $packageName`');
    buffer.writeln('// NPM package  : $packageName@$version');
    buffer.writeln('// JS global    : $jsGlobal');
    buffer.writeln(
        '// DO NOT EDIT  — run `bloom add $packageName` to regenerate.');
    buffer.writeln('//');
    buffer.writeln(
        '// ignore_for_file: non_constant_identifier_names, avoid_js_interop_library_on_non_web_platforms, unused_import');
    buffer.writeln();
    buffer.writeln("import 'dart:js_interop';");
    buffer.writeln("import 'package:web/web.dart' as web;");
    buffer.writeln();
    buffer.writeln(
        '/// Dart 3.5+ JS Interop binding for the `$packageName` NPM package.');
    buffer.writeln('///');
    buffer.writeln(
        '/// This file was auto-generated from the package\'s TypeScript declarations');
    buffer.writeln(
        '/// ${graphContents.isNotEmpty ? 'fetched from esm.sh / DefinitelyTyped / package source.' : '(no .d.ts found — dynamic proxy emitted).'}');
    buffer.writeln('///');
    buffer.writeln(
        '/// The package namespace is bridged onto `window.$jsGlobal` via the bootstrap');
    buffer.writeln(
        '/// script in `web/index.html`. Access members through the top-level [$getterName] getter.');
    buffer.writeln('///');
    buffer.writeln('/// Usage:');
    buffer.writeln('///   $getterName.<member>(...)');
    buffer.writeln('@JS(\'$jsGlobal\')');
    buffer.writeln('external $className get $getterName;');
    buffer.writeln();
    buffer.writeln('@JS(\'$jsGlobal\')');
    buffer
        .writeln('extension type $className(JSObject _) implements JSObject {');

    if (allDtsExports.isNotEmpty) {
      for (final exp in allDtsExports) {
        final dartMemberName = _toDartMemberName(exp);
        final detailedFunc =
            detailedFunctions[exp] ?? detailedFunctions[localAliases[exp]];

        if (detailedFunc != null) {
          // Check if any param uses an option type
          for (final p in detailedFunc.params) {
            if (typeDefs.containsKey(p.type) &&
                typeDefs[p.type]!.isAllPrimitives) {
              optionTypesToEmit[p.type] = typeDefs[p.type]!;
            }
          }

          buffer.writeln('  @JS(\'$exp\')');
          _emitFunctionSignature(buffer, dartMemberName, detailedFunc);
        } else {
          // Const, class, or function without detailed parse
          buffer.writeln('  @JS(\'$exp\')');
          buffer.writeln('  external JSAny? $dartMemberName([');
          buffer.writeln('    JSAny? a0,');
          buffer.writeln('    JSAny? a1,');
          buffer.writeln('    JSAny? a2,');
          buffer.writeln('    JSAny? a3,');
          buffer.writeln('    JSAny? a4,');
          buffer.writeln('    JSAny? a5,');
          buffer.writeln('  ]);');
        }
      }
      if (allDtsExports.length < 3 && esmBundleExports != null) {
        for (final exp in esmBundleExports) {
          if (allDtsExports.contains(exp)) continue;
          final dartMemberName = _toDartMemberName(exp);
          buffer.writeln(
              '  /// Unknown signature from ESM bundle export `$exp`.');
          buffer.writeln('  @JS(\'$exp\')');
          buffer.writeln('  external JSAny? $dartMemberName([');
          buffer.writeln('    JSAny? a0,');
          buffer.writeln('    JSAny? a1,');
          buffer.writeln('    JSAny? a2,');
          buffer.writeln('    JSAny? a3,');
          buffer.writeln('    JSAny? a4,');
          buffer.writeln('    JSAny? a5,');
          buffer.writeln('  ]);');
        }
      }
    } else if (esmBundleExports != null && esmBundleExports.isNotEmpty) {
      // Last-resort fallback with real ESM bundle names
      for (final exp in esmBundleExports) {
        final dartMemberName = _toDartMemberName(exp);
        buffer
            .writeln('  /// Unknown signature from ESM bundle export `$exp`.');
        buffer.writeln('  @JS(\'$exp\')');
        buffer.writeln('  external JSAny? $dartMemberName([');
        buffer.writeln('    JSAny? a0,');
        buffer.writeln('    JSAny? a1,');
        buffer.writeln('    JSAny? a2,');
        buffer.writeln('    JSAny? a3,');
        buffer.writeln('    JSAny? a4,');
        buffer.writeln('    JSAny? a5,');
        buffer.writeln('  ]);');
      }
    } else {
      // Fallback: no .d.ts and no ESM exports found
      final fallbackProp = _toCamelCase(className);
      final fallbackDartName = _toDartMemberName(fallbackProp);
      buffer.writeln(
          '  /// Fallback member guess (no .d.ts found or no parseable exports).');
      buffer.writeln(
          '  /// Note: this member name is unverified and may not match runtime exports.');
      buffer.writeln('  @JS(\'$fallbackProp\')');
      buffer.writeln('  external JSAny? $fallbackDartName([');
      buffer.writeln('    JSAny? a0,');
      buffer.writeln('    JSAny? a1,');
      buffer.writeln('    JSAny? a2,');
      buffer.writeln('    JSAny? a3,');
      buffer.writeln('    JSAny? a4,');
      buffer.writeln('    JSAny? a5,');
      buffer.writeln('  ]);');
    }

    buffer.writeln(
        '  /// Call a named method on the JS object form of this package.');
    buffer.writeln(
        '  /// Note: this member maps to a literal JS property named `callMethod` on the');
    buffer.writeln(
        '  /// target object, not a dynamic-dispatch-by-name call. It only works if the');
    buffer.writeln(
        '  /// target object happens to define a method literally named `callMethod`.');
    buffer.writeln(
        '  external JSAny? callMethod(String method, [JSArray<JSAny?>? args]);');
    buffer.writeln('}');
    buffer.writeln();

    // Emit option object extension types
    for (final def in optionTypesToEmit.values) {
      _emitOptionExtensionType(buffer, def);
    }

    return buffer.toString();
  }

  static void _emitFunctionSignature(
      StringBuffer buffer, String dartMemberName, DtsExportedFunction func) {
    final ret = func.returnType;
    final params = func.params;

    if (params.isEmpty) {
      buffer.writeln('  external $ret $dartMemberName();');
      return;
    }

    final requiredParams = <DtsParam>[];
    final optionalParams = <DtsParam>[];

    for (final p in params) {
      if (p.isOptional || optionalParams.isNotEmpty) {
        optionalParams.add(p);
      } else {
        requiredParams.add(p);
      }
    }

    buffer.write('  external $ret $dartMemberName(');
    final parts = <String>[];
    for (final p in requiredParams) {
      parts.add('${p.type} ${p.dartName}');
    }
    if (optionalParams.isNotEmpty) {
      final optParts = <String>[];
      for (final p in optionalParams) {
        final optType =
            (p.type.endsWith('?') || p.type == 'void') ? p.type : '${p.type}?';
        optParts.add('$optType ${p.dartName}');
      }
      parts.add('[${optParts.join(', ')}]');
    }

    buffer.write(parts.join(', '));
    buffer.writeln(');');
  }

  static void _emitOptionExtensionType(
      StringBuffer buffer, DtsTypeDefinition def) {
    buffer.writeln(
        'extension type ${def.name}._(JSObject _) implements JSObject {');
    // external factory Name({type? prop, ...});
    final factoryParams = <String>[];
    for (final entry in def.properties.entries) {
      final propName = entry.key;
      final tsType = entry.value;
      final dartType = _mapPrimitiveToDart(tsType);
      final dartParamName = _toDartMemberName(propName);
      factoryParams.add('$dartType? $dartParamName');
    }

    if (factoryParams.isNotEmpty) {
      buffer.writeln(
          '  external factory ${def.name}({${factoryParams.join(', ')}});');
    } else {
      buffer.writeln('  external factory ${def.name}();');
    }

    // Getters
    for (final entry in def.properties.entries) {
      final propName = entry.key;
      final tsType = entry.value;
      final dartType = _mapPrimitiveToDart(tsType);
      final dartMemberName = _toDartMemberName(propName);
      if (dartMemberName != propName) {
        buffer.writeln('  @JS(\'$propName\')');
      }
      buffer.writeln('  external $dartType? get $dartMemberName;');
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  static String _mapPrimitiveToDart(String tsType) {
    final clean = tsType
        .trim()
        .replaceAll(RegExp(r'\s*\|\s*undefined'), '')
        .replaceAll(RegExp(r'\s*\|\s*null'), '');
    if (clean == 'string') return 'String';
    if (clean == 'number') return 'num';
    if (clean == 'boolean') return 'bool';
    return 'JSAny';
  }

  static const _reservedKeywords = {
    'assert',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'if',
    'in',
    'is',
    'new',
    'null',
    'rethrow',
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with',
    'async',
    'hide',
    'of',
    'on',
    'show',
    'sync',
    'await',
    'yield',
  };

  static bool _isValidDartIdentifier(String s) {
    if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(s)) return false;
    return !_reservedKeywords.contains(s);
  }

  static String _toDartMemberName(String exp) {
    if (_reservedKeywords.contains(exp)) {
      return '${exp}_';
    }
    if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(exp)) {
      return exp;
    }
    return 'prop_${exp.replaceAll(RegExp(r'[^A-Za-z0-9_$]'), '_')}';
  }

  static String _toDartParamName(String param, int index) {
    var clean = param.replaceAll(RegExp(r'[^A-Za-z0-9_$]'), '_');
    if (clean.isEmpty || !RegExp(r'^[A-Za-z_$]').hasMatch(clean)) {
      clean = 'arg$index';
    }
    if (_reservedKeywords.contains(clean)) {
      return '${clean}_';
    }
    return clean;
  }

  static String _toCamelCase(String pascal) =>
      pascal.isEmpty ? pascal : pascal[0].toLowerCase() + pascal.substring(1);

  static String _toPascalCase(String input) {
    final clean =
        input.replaceAll('@', '').replaceAll('/', '_').replaceAll('-', '_');
    return clean
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join();
  }

  static String _inferGlobal(String pkg) {
    return pkg.replaceAll('@', '').replaceAll('/', '_').replaceAll('-', '_');
  }
}

class _RawFunctionSig {
  final List<DtsParam> params;
  final String returnType;

  _RawFunctionSig({
    required this.params,
    required this.returnType,
  });
}
