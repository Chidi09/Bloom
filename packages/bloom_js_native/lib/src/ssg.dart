import 'dart:io';
import 'attribute_safety.dart';
import 'framework.dart';
import 'html.dart';
import 'npm.dart';
import 'ui/font_link.dart';

/// Summary of static site generation execution.
class SsgResult {
  /// All files written to the output directory during static site generation.
  final List<String> writtenFiles;

  /// Total number of HTML route pages generated.
  final int pageCount;

  /// Creates an [SsgResult] descriptor.
  const SsgResult({
    required this.writtenFiles,
    required this.pageCount,
  });
}

/// Generates a static site into [outDir] from the supplied [pages] map and [webDir] assets.
///
/// Example `bin/ssg.dart` usage:
/// ```dart
/// import 'package:bloom_js_native/bloom_js_native.dart';
/// import 'package:bloom_js_native/ssg.dart';
///
/// void main() async {
///   final result = await generateStaticSite(
///     pages: {
///       '/': () => Div(text: 'Home page'),
///       '/about': () => Div(text: 'About page'),
///     },
///     title: 'My Bloom App',
///     stylesheets: ['/css/reset.css', '/css/design-system.css'],
///     titleFor: (path) => path == '/about' ? 'About Us' : 'Home',
///   );
///   print('Rendered ${result.pageCount} pages (${result.writtenFiles.length} files total).');
/// }
/// ```
Future<SsgResult> generateStaticSite({
  required Map<String, BloomNode Function()> pages,
  String outDir = 'dist',
  String webDir = 'web',
  String? title,
  String Function(String path)? titleFor,
  List<BloomNode> head = const [],

  /// Stylesheets shared by every generated page.
  List<String> stylesheets = const [],
  String lang = 'en',
  String appElementId = 'app',
  String mainScript = 'main.js',
  bool includeNpm = true,
  String bloomYamlPath = 'bloom.yaml',
}) async {
  final outputDirectory = Directory(outDir);
  final webDirectory = Directory(webDir);

  // 1. Require webDir/main.js to exist
  final webMainJs = File(_joinPaths([webDirectory.path, 'main.js']));
  if (!webMainJs.existsSync()) {
    throw StateError('Run `bloom js build` first');
  }

  // 2. Delete and recreate outDir
  if (outputDirectory.existsSync()) {
    outputDirectory.deleteSync(recursive: true);
  }
  outputDirectory.createSync(recursive: true);

  final writtenFiles = <String>[];

  // 3. Copy every file under webDir except index.html and *.deps into outDir (keep relative paths)
  if (webDirectory.existsSync()) {
    for (final entity
        in webDirectory.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relPath = _relativePath(entity.path, webDirectory.path);
        final baseName = _baseName(entity.path);
        if (relPath == 'index.html' || baseName.endsWith('.deps')) {
          continue;
        }
        final destFile = File(_joinPaths([outputDirectory.path, relPath]));
        destFile.parent.createSync(recursive: true);
        entity.copySync(destFile.path);
        writtenFiles.add(destFile.path);
      }
    }
  }

  // 4. Copy fonts to the URL path fontStylesheetLink expects, if the generated fonts directory exists
  final sampleFontNode = fontStylesheetLink();
  String expectedFontPath = '/generated/fonts/fonts.g.css';
  if (sampleFontNode is ElNode && sampleFontNode.attrs != null) {
    expectedFontPath = sampleFontNode.attrs!['href'] ?? expectedFontPath;
  }
  final cleanFontRelPath = expectedFontPath.startsWith('/')
      ? expectedFontPath.substring(1)
      : expectedFontPath;
  final expectedFontDirRel = _dirName(cleanFontRelPath);

  final candidateFontDirs = [
    Directory(_joinPaths(['lib', 'generated', 'fonts'])),
    Directory(_joinPaths(['web', 'generated', 'fonts'])),
    Directory(_joinPaths(['generated', 'fonts'])),
  ];
  for (final cDir in candidateFontDirs) {
    if (cDir.existsSync()) {
      final destFontDir =
          Directory(_joinPaths([outputDirectory.path, expectedFontDirRel]));
      destFontDir.createSync(recursive: true);
      for (final fontEntity
          in cDir.listSync(recursive: true, followLinks: false)) {
        if (fontEntity is File) {
          final rel = _relativePath(fontEntity.path, cDir.path);
          final target = File(_joinPaths([destFontDir.path, rel]));
          target.parent.createSync(recursive: true);
          fontEntity.copySync(target.path);
          if (!writtenFiles.contains(target.path)) {
            writtenFiles.add(target.path);
          }
        }
      }
      break;
    }
  }

  // 5. Build npm head nodes if enabled
  final npmHeadNodes = <BloomNode>[];
  if (includeNpm) {
    final bloomYamlFile = File(bloomYamlPath);
    if (bloomYamlFile.existsSync()) {
      final yamlContent = bloomYamlFile.readAsStringSync();
      final registry = NpmRegistry.fromBloomYaml(yamlContent);
      npmHeadNodes.addAll(registry.headNodes());
    }
  }

  // 6. Main script node
  final cleanScriptSrc =
      mainScript.startsWith('/') ? mainScript : '/$mainScript';
  validateBloomAttribute('src', cleanScriptSrc);
  final mainScriptNode = El(
    'script',
    attrs: {
      'src': cleanScriptSrc,
      'defer': '',
    },
  );

  // 7. Render each page
  int pageCount = 0;
  for (final entry in pages.entries) {
    final routePath = entry.key;
    final pageBuilder = entry.value;

    final pageTitle = titleFor?.call(routePath) ?? title;
    final pageBody = Div(
      attrs: {'id': appElementId},
      children: [pageBuilder()],
    );

    final combinedHead = <BloomNode>[
      ...head,
      ...npmHeadNodes,
      mainScriptNode,
    ];

    final html = renderToDocument(
      pageBody,
      lang: lang,
      title: pageTitle,
      head: combinedHead,
      stylesheets: stylesheets,
    );

    final String destRelPath;
    if (routePath == '/' || routePath.isEmpty) {
      destRelPath = 'index.html';
    } else {
      final normalizedRoute =
          routePath.startsWith('/') ? routePath.substring(1) : routePath;
      if (normalizedRoute.endsWith('.html')) {
        destRelPath = normalizedRoute;
      } else {
        destRelPath = _joinPaths([normalizedRoute, 'index.html']);
      }
    }

    final destHtmlFile = File(_joinPaths([outputDirectory.path, destRelPath]));
    destHtmlFile.parent.createSync(recursive: true);
    destHtmlFile.writeAsStringSync(html);
    writtenFiles.add(destHtmlFile.path);
    pageCount++;
  }

  return SsgResult(
    writtenFiles: writtenFiles,
    pageCount: pageCount,
  );
}

String _joinPaths(List<String> parts) {
  final filtered = parts
      .map((p) => p.replaceAll('\\', '/'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (filtered.isEmpty) return '';
  final buffer = StringBuffer(filtered.first);
  for (var i = 1; i < filtered.length; i++) {
    final curr = filtered[i];
    final prevEnds = buffer.toString().endsWith('/');
    final currStarts = curr.startsWith('/');
    if (prevEnds && currStarts) {
      buffer.write(curr.substring(1));
    } else if (!prevEnds && !currStarts) {
      buffer.write('/$curr');
    } else {
      buffer.write(curr);
    }
  }
  return buffer.toString();
}

String _relativePath(String path, String from) {
  final normalizedPath = path.replaceAll('\\', '/');
  final normalizedFrom =
      from.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  if (normalizedPath.startsWith('$normalizedFrom/')) {
    return normalizedPath.substring(normalizedFrom.length + 1);
  }
  return normalizedPath;
}

String _baseName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

String _dirName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(0, index) : '.';
}
