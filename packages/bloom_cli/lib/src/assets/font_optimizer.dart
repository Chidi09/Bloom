// lib/src/assets/font_optimizer.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../utils/project.dart';

/// Allowed font weights for Google Fonts requests.
///
/// This allowlist acts as a guard against unbounded or malformed inputs,
/// ensuring only standard CSS font weights are requested and processed.
const List<String> kAllowedFontWeights = [
  '100',
  '200',
  '300',
  '400',
  '500',
  '600',
  '700',
  '800',
  '900',
];

/// Modern desktop browser User-Agent header string.
///
/// Google Fonts serves modern WOFF2 font files only when requested with a
/// modern browser User-Agent. Legacy or absent User-Agent headers may receive
/// older TTF/WOFF/EOT formats.
const String kModernBrowserUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Result summary returned by [BloomFontOptimizer.optimize].
class BloomFontOptimizeResult {
  /// Font family names that were requested for optimization.
  final List<String> families;

  /// Absolute file paths of all downloaded `.woff2` files and the generated CSS file.
  final List<String> filesWritten;

  /// Absolute path to the generated `fonts.g.css` stylesheet, or empty string if none written.
  final String cssPath;

  /// Warning messages captured during processing (e.g. non-200 responses, network failures).
  final List<String> warnings;

  const BloomFontOptimizeResult({
    required this.families,
    required this.filesWritten,
    required this.cssPath,
    this.warnings = const [],
  });
}

/// Build-time font optimization engine for Bloom applications.
///
/// Downloads Google Fonts font files (`.woff2`) at build time to self-host them
/// directly from the application's domain. This eliminates render-blocking
/// third-party network roundtrips to `fonts.googleapis.com` / `fonts.gstatic.com`.
///
/// ### CLS Mitigation & Scope Note
/// To mitigate Cumulative Layout Shift (CLS) when webfonts swap in, this optimizer
/// generates a fallback `@font-face` definition using system fonts with `size-adjust`.
///
/// **Scope & Approximation**: Exact per-font Capsize-style metric calculation
/// (adjusting `ascent-override`, `descent-override`, `line-gap-override`, and
/// font-specific `size-adjust` percentages) requires an extensive database of
/// font glyph bounding boxes and metrics. Bloom intentionally uses a generic,
/// honest baseline (`100%` size-adjust on standard system fallbacks like Arial)
/// unless explicit overrides are passed via [sizeAdjustOverrides].
class BloomFontOptimizer {
  final BloomProject project;
  final http.Client _client;
  final bool _ownsClient;

  BloomFontOptimizer({
    required this.project,
    http.Client? httpClient,
  })  : _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  /// Converts a font family name to a kebab-cased filesystem-safe string.
  static String toKebabCase(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Downloads specified Google Fonts [families] and [weights], writing `.woff2` files
  /// to `<project>/lib/generated/fonts/` and generating `fonts.g.css`.
  ///
  /// - [families]: List of Google Font family names (e.g. `['Inter', 'JetBrains Mono']`).
  /// - [weights]: List of CSS font weight strings (defaults to `['400', '700']`).
  /// - [subset]: Character subset (defaults to `'latin'`).
  /// - [sizeAdjustOverrides]: Optional map of family names to explicit `size-adjust`
  ///   percentages (e.g. `{'Inter': 107.0}`). When not supplied for a family, defaults
  ///   to `100.0` (honest baseline no-op).
  ///
  /// Throws [ArgumentError] if [families] is empty or if any weight is not in [kAllowedFontWeights].
  Future<BloomFontOptimizeResult> optimize({
    required List<String> families,
    List<String> weights = const ['400', '700'],
    String subset = 'latin',
    Map<String, double>? sizeAdjustOverrides,
  }) async {
    if (families.isEmpty) {
      throw ArgumentError('Font families list must not be empty.');
    }

    for (final weight in weights) {
      if (!kAllowedFontWeights.contains(weight)) {
        throw ArgumentError(
          'Weight "$weight" is not an allowed font weight. Allowed weights: $kAllowedFontWeights',
        );
      }
    }

    final sortedWeights = weights.toSet().toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    final fontsDir = Directory(
      p.join(project.rootDir.path, 'lib', 'generated', 'fonts'),
    );

    final filesWritten = <String>[];
    final warnings = <String>[];
    final processedFamilies = <String>[];
    final downloadedRules = <String, List<({String weight, String filename})>>{};

    try {
      if (!fontsDir.existsSync()) {
        fontsDir.createSync(recursive: true);
      }

      for (final family in families) {
        processedFamilies.add(family);
        final kebabFamily = toKebabCase(family);

        try {
          final uri = Uri.parse(
            'https://fonts.googleapis.com/css2?family=${Uri.encodeComponent(family)}:wght@${sortedWeights.join(';')}&display=swap',
          );

          final cssResponse = await _client.get(
            uri,
            headers: {'User-Agent': kModernBrowserUserAgent},
          );

          if (cssResponse.statusCode != 200) {
            warnings.add(
              'Google Fonts API returned HTTP ${cssResponse.statusCode} for family "$family".',
            );
            continue;
          }

          final cssContent = cssResponse.body;
          final downloadedForFamily = <({String weight, String filename})>[];

          // Parse @font-face blocks to associate weights with woff2 URLs
          final fontFaceRegex = RegExp(r'@font-face\s*\{([^}]+)\}', multiLine: true);
          final fontFaceMatches = fontFaceRegex.allMatches(cssContent);

          final downloadedWeights = <String>{};

          for (final match in fontFaceMatches) {
            final block = match.group(1) ?? '';
            final weightMatch = RegExp(r'font-weight:\s*(\d+)').firstMatch(block);
            final weight = weightMatch?.group(1) ??
                (sortedWeights.length == 1 ? sortedWeights.first : '400');

            if (downloadedWeights.contains(weight)) {
              continue;
            }

            final urlMatch = RegExp(r'url\(([^)]+\.woff2)\)').firstMatch(block);

            if (urlMatch != null) {
              var fontUrl = urlMatch.group(1)!.trim();
              if ((fontUrl.startsWith("'") && fontUrl.endsWith("'")) ||
                  (fontUrl.startsWith('"') && fontUrl.endsWith('"'))) {
                fontUrl = fontUrl.substring(1, fontUrl.length - 1).trim();
              }
              final filename = '$kebabFamily-$weight.woff2';
              final targetFile = File(p.join(fontsDir.path, filename));

              try {
                final fontResponse = await _client.get(Uri.parse(fontUrl));
                if (fontResponse.statusCode == 200) {
                  await targetFile.writeAsBytes(fontResponse.bodyBytes);
                  filesWritten.add(targetFile.path);
                  downloadedWeights.add(weight);
                  downloadedForFamily.add((weight: weight, filename: filename));
                } else {
                  warnings.add(
                    'Failed to download font file for "$family" weight $weight: HTTP ${fontResponse.statusCode}',
                  );
                }
              } catch (e) {
                warnings.add('Failed to download font file for "$family" weight $weight: $e');
              }
            }
          }

          // Fallback: if block parsing did not catch woff2 URLs, try global regex search
          if (downloadedForFamily.isEmpty) {
            final globalUrlRegex = RegExp(r'url\(([^)]+\.woff2)\)');
            final globalMatches = globalUrlRegex.allMatches(cssContent).toList();

            for (var i = 0; i < globalMatches.length && i < sortedWeights.length; i++) {
              final weight = sortedWeights[i];
              var fontUrl = globalMatches[i].group(1)!.trim();
              if ((fontUrl.startsWith("'") && fontUrl.endsWith("'")) ||
                  (fontUrl.startsWith('"') && fontUrl.endsWith('"'))) {
                fontUrl = fontUrl.substring(1, fontUrl.length - 1).trim();
              }
              final filename = '$kebabFamily-$weight.woff2';
              final targetFile = File(p.join(fontsDir.path, filename));

              try {
                final fontResponse = await _client.get(Uri.parse(fontUrl));
                if (fontResponse.statusCode == 200) {
                  await targetFile.writeAsBytes(fontResponse.bodyBytes);
                  filesWritten.add(targetFile.path);
                  downloadedForFamily.add((weight: weight, filename: filename));
                }
              } catch (e) {
                warnings.add('Failed to download font file for "$family" weight $weight: $e');
              }
            }
          }

          if (downloadedForFamily.isEmpty) {
            warnings.add('No woff2 font files found or downloaded for family "$family".');
          } else {
            downloadedRules[family] = downloadedForFamily;
          }
        } catch (e) {
          warnings.add('Failed to optimize font family "$family": $e');
        }
      }

      var cssPath = '';
      if (downloadedRules.isNotEmpty) {
        final cssBuffer = StringBuffer();
        cssBuffer.writeln('/* Generated by Bloom Font Optimizer. Do not edit manually. */');

        for (final entry in downloadedRules.entries) {
          final family = entry.key;
          final rules = entry.value;

          for (final rule in rules) {
            cssBuffer.writeln();
            cssBuffer.writeln('@font-face {');
            cssBuffer.writeln("  font-family: '$family';");
            cssBuffer.writeln('  font-style: normal;');
            cssBuffer.writeln('  font-weight: ${rule.weight};');
            cssBuffer.writeln('  font-display: swap;');
            cssBuffer.writeln("  src: url('/generated/fonts/${rule.filename}') format('woff2');");
            cssBuffer.writeln('}');
          }

          // CLS mitigation fallback font face rule
          final overrideVal = sizeAdjustOverrides?[family];
          final sizeAdjustStr = overrideVal != null
              ? (overrideVal.truncateToDouble() == overrideVal
                  ? overrideVal.toInt().toString()
                  : overrideVal.toStringAsFixed(2))
              : '100';

          cssBuffer.writeln();
          cssBuffer.writeln('/* Fallback font definition for CLS mitigation */');
          cssBuffer.writeln('@font-face {');
          cssBuffer.writeln("  font-family: '$family Fallback';");
          cssBuffer.writeln('  src: local("Arial");');
          cssBuffer.writeln('  size-adjust: $sizeAdjustStr%;');
          cssBuffer.writeln('}');
        }

        final cssFile = File(p.join(fontsDir.path, 'fonts.g.css'));
        await cssFile.writeAsString(cssBuffer.toString());
        filesWritten.add(cssFile.path);
        cssPath = cssFile.path;
      }

      return BloomFontOptimizeResult(
        families: processedFamilies,
        filesWritten: filesWritten,
        cssPath: cssPath,
        warnings: warnings,
      );
    } finally {
      if (_ownsClient) {
        _client.close();
      }
    }
  }
}
