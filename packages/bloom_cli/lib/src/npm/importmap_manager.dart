import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class ImportMapManager {
  final String projectRoot;

  ImportMapManager(this.projectRoot);

  File get _indexHtml => File(p.join(projectRoot, 'web', 'index.html'));

  /// Adds or updates an entry in the <script type="importmap"> block in web/index.html.
  Future<void> addEntry({
    required String packageName,
    required String vendorPath,
  }) async {
    final file = _indexHtml;
    if (!await file.exists()) {
      return;
    }

    String html = await file.readAsString();
    final importMapRegex = RegExp(
      r'<script\s+type=["\x27]importmap["\x27]>([\s\S]*?)<\/script>',
      caseSensitive: false,
    );

    Map<String, dynamic> currentMap = {'imports': <String, dynamic>{}};
    final existingMatch = importMapRegex.firstMatch(html);

    if (existingMatch != null) {
      try {
        final content = existingMatch.group(1)!.trim();
        if (content.isNotEmpty) {
          currentMap = jsonDecode(content) as Map<String, dynamic>;
        }
      } catch (_) {
        currentMap = {'imports': <String, dynamic>{}};
      }
    }

    final imports = (currentMap['imports'] is Map)
        ? Map<String, dynamic>.from(currentMap['imports'] as Map)
        : <String, dynamic>{};

    imports[packageName] = '/$vendorPath';
    currentMap['imports'] = imports;

    final newImportMapJson = const JsonEncoder.withIndent('  ').convert(currentMap);
    final newScriptTag = '<script type="importmap">\n$newImportMapJson\n</script>';

    if (existingMatch != null) {
      html = html.replaceFirst(importMapRegex, newScriptTag);
    } else {
      if (html.contains('</head>')) {
        html = html.replaceFirst('</head>', '  $newScriptTag\n</head>');
      } else {
        html = '$newScriptTag\n$html';
      }
    }

    await file.writeAsString(html);
  }

  /// Removes an entry from the <script type="importmap"> block in web/index.html.
  Future<void> removeEntry({required String packageName}) async {
    final file = _indexHtml;
    if (!await file.exists()) return;

    String html = await file.readAsString();
    final importMapRegex = RegExp(
      r'<script\s+type=["\x27]importmap["\x27]>([\s\S]*?)<\/script>',
      caseSensitive: false,
    );

    final existingMatch = importMapRegex.firstMatch(html);
    if (existingMatch == null) return;

    Map<String, dynamic> currentMap = {'imports': <String, dynamic>{}};
    try {
      final content = existingMatch.group(1)!.trim();
      if (content.isNotEmpty) {
        currentMap = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {
      return;
    }

    final imports = (currentMap['imports'] is Map)
        ? Map<String, dynamic>.from(currentMap['imports'] as Map)
        : <String, dynamic>{};

    imports.remove(packageName);
    currentMap['imports'] = imports;

    final newJson = const JsonEncoder.withIndent('  ').convert(currentMap);
    final newScriptTag = '<script type="importmap">\n$newJson\n</script>';

    html = html.replaceFirst(importMapRegex, newScriptTag);
    await file.writeAsString(html);
  }
}
