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

/// Allowed font styles for Google Fonts requests.
const List<String> kAllowedFontStyles = [
  'normal',
  'italic',
];

/// Modern desktop browser User-Agent header string.
///
/// Google Fonts serves modern WOFF2 font files only when requested with a
/// modern browser User-Agent. Legacy or absent User-Agent headers may receive
/// older TTF/WOFF/EOT formats.
/// Modern desktop browser User-Agent header string.
///
/// Google Fonts serves modern WOFF2 font files only when requested with a
/// modern browser User-Agent. Legacy or absent User-Agent headers may receive
/// older TTF/WOFF/EOT formats.
const String kModernBrowserUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Represents a requested font face configuration with family name, weights, and styles.
class FontFaceRequest {
  /// Font family name (e.g. `'Plus Jakarta Sans'`, `'JetBrains Mono'`).
  final String family;

  /// List of CSS font weight strings (e.g. `['300', '400', '700']`).
  final List<String> weights;

  /// List of font style strings (e.g. `['normal', 'italic']`).
  final List<String> styles;

  const FontFaceRequest({
    required this.family,
    this.weights = const ['400', '700'],
    this.styles = const ['normal'],
  });

  /// Parses a font face manifest spec in `Family:weights:styles` format.
  ///
  /// Example inputs:
  /// - `Plus Jakarta Sans:300,400,500,600,700,800:normal`
  /// - `JetBrains Mono:400,700:normal,italic`
  ///
  /// Throws [ArgumentError] if the format is malformed or weights/styles are invalid.
  static FontFaceRequest parse(String spec) {
    final parts = spec.split(':');
    if (parts.length != 3) {
      throw ArgumentError(
        'Invalid font face format "$spec". Expected format: "Family:weights:styles" (e.g. "Inter:400,700:normal,italic").',
      );
    }

    final family = parts[0].trim();
    if (family.isEmpty) {
      throw ArgumentError(
        'Font family name in face manifest cannot be empty: "$spec".',
      );
    }

    final rawWeights = parts[1]
        .split(',')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    if (rawWeights.isEmpty) {
      throw ArgumentError(
        'Font weights in face manifest cannot be empty: "$spec".',
      );
    }
    for (final weight in rawWeights) {
      if (!kAllowedFontWeights.contains(weight)) {
        throw ArgumentError(
          'Weight "$weight" in face manifest "$spec" is not an allowed font weight. Allowed weights: $kAllowedFontWeights',
        );
      }
    }

    final rawStyles = parts[2]
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (rawStyles.isEmpty) {
      throw ArgumentError(
        'Font styles in face manifest cannot be empty: "$spec".',
      );
    }
    for (final style in rawStyles) {
      if (!kAllowedFontStyles.contains(style)) {
        throw ArgumentError(
          'Style "$style" in face manifest "$spec" is not an allowed font style. Allowed styles: $kAllowedFontStyles',
        );
      }
    }

    return FontFaceRequest(
      family: family,
      weights: rawWeights,
      styles: rawStyles,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFaceRequest &&
          runtimeType == other.runtimeType &&
          family == other.family &&
          _listEquals(weights, other.weights) &&
          _listEquals(styles, other.styles);

  @override
  int get hashCode =>
      family.hashCode ^ Object.hashAll(weights) ^ Object.hashAll(styles);

  @override
  String toString() =>
      'FontFaceRequest(family: $family, weights: $weights, styles: $styles)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Result summary returned by [BloomFontOptimizer.optimize] and [BloomFontOptimizer.optimizeManifest].
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

  /// Downloads specified Google Fonts [families], [weights], and [styles], writing `.woff2` files
  /// to `<project>/lib/generated/fonts/` and generating `fonts.g.css`.
  ///
  /// - [families]: List of Google Font family names (e.g. `['Inter', 'JetBrains Mono']`).
  /// - [weights]: List of CSS font weight strings (defaults to `['400', '700']`).
  /// - [styles]: List of font style strings (defaults to `['normal']`). Allowed: `'normal'`, `'italic'`.
  /// - [requireAllRequestedFaces]: If `true`, returns no CSS bundle if any requested
  ///   `(family, weight, style)` combination fails to download.
  /// - [subset]: Character subset (defaults to `'latin'`).
  /// - [sizeAdjustOverrides]: Optional map of family names to explicit `size-adjust`
  ///   percentages (e.g. `{'Inter': 107.0}`). When not supplied for a family, defaults
  ///   to `100.0` (honest baseline no-op).
  ///
  /// Throws [ArgumentError] if [families] or [styles] is empty, or if any weight or style is invalid.
  Future<BloomFontOptimizeResult> optimize({
    required List<String> families,
    List<String> weights = const ['400', '700'],
    List<String> styles = const ['normal'],
    bool requireAllRequestedFaces = false,
    String subset = 'latin',
    Map<String, double>? sizeAdjustOverrides,
  }) async {
    if (families.isEmpty) {
      throw ArgumentError('Font families list must not be empty.');
    }
    final requests = families
        .map(
          (f) => FontFaceRequest(
            family: f,
            weights: weights,
            styles: styles,
          ),
        )
        .toList();
    return optimizeManifest(
      requests,
      requireAllRequestedFaces: requireAllRequestedFaces,
      subset: subset,
      sizeAdjustOverrides: sizeAdjustOverrides,
    );
  }

  /// Downloads specified Google Fonts per-family [requests], writing `.woff2` files
  /// to `<project>/lib/generated/fonts/` and generating a single combined `fonts.g.css`.
  ///
  /// - [requests]: List of [FontFaceRequest] objects specifying family name, weights, and styles.
  /// - [requireAllRequestedFaces]: If `true`, returns no CSS bundle if any requested
  ///   `(family, weight, style)` combination fails to download.
  /// - [subset]: Character subset (defaults to `'latin'`).
  /// - [sizeAdjustOverrides]: Optional map of family names to explicit `size-adjust`
  ///   percentages (e.g. `{'Inter': 107.0}`). When not supplied for a family, defaults
  ///   to `100.0` (honest baseline no-op).
  ///
  /// Throws [ArgumentError] if [requests] is empty, or if any request has invalid family/weights/styles.
  Future<BloomFontOptimizeResult> optimizeManifest(
    List<FontFaceRequest> requests, {
    bool requireAllRequestedFaces = false,
    String subset = 'latin',
    Map<String, double>? sizeAdjustOverrides,
  }) async {
    if (requests.isEmpty) {
      throw ArgumentError('Font requests list must not be empty.');
    }

    for (final request in requests) {
      if (request.family.trim().isEmpty) {
        throw ArgumentError('Font family name must not be empty.');
      }
      if (request.styles.isEmpty) {
        throw ArgumentError('Font styles list must not be empty.');
      }
      for (final style in request.styles) {
        if (!kAllowedFontStyles.contains(style)) {
          throw ArgumentError(
            'Style "$style" is not an allowed font style. Allowed styles: $kAllowedFontStyles',
          );
        }
      }
      if (request.weights.isEmpty) {
        throw ArgumentError('Font weights list must not be empty.');
      }
      for (final weight in request.weights) {
        if (!kAllowedFontWeights.contains(weight)) {
          throw ArgumentError(
            'Weight "$weight" is not an allowed font weight. Allowed weights: $kAllowedFontWeights',
          );
        }
      }
    }

    final fontsDir = Directory(
      p.join(project.rootDir.path, 'lib', 'generated', 'fonts'),
    );

    final filesWritten = <String>[];
    final warnings = <String>[];
    final processedFamilies = <String>[];
    final downloadedRules =
        <String, List<({String weight, String style, String filename})>>{};

    try {
      if (!fontsDir.existsSync()) {
        fontsDir.createSync(recursive: true);
      }

      for (final request in requests) {
        final family = request.family;
        if (!processedFamilies.contains(family)) {
          processedFamilies.add(family);
        }
        final kebabFamily = toKebabCase(family);
        final sortedWeights = request.weights.toSet().toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
        final uniqueStyles = request.styles.toSet().toList();

        try {
          final hasNormal = uniqueStyles.contains('normal');
          final hasItalic = uniqueStyles.contains('italic');

          final String axisQuery;
          if (hasNormal && hasItalic) {
            final normalTuples = sortedWeights.map((w) => '0,$w');
            final italicTuples = sortedWeights.map((w) => '1,$w');
            axisQuery =
                ':ital,wght@${[...normalTuples, ...italicTuples].join(';')}';
          } else if (hasItalic) {
            final italicTuples = sortedWeights.map((w) => '1,$w');
            axisQuery = ':ital,wght@${italicTuples.join(';')}';
          } else {
            axisQuery = ':wght@${sortedWeights.join(';')}';
          }

          final uri = Uri.parse(
            'https://fonts.googleapis.com/css2?family=${Uri.encodeComponent(family)}$axisQuery&display=swap',
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
          final downloadedForFamily =
              <({String weight, String style, String filename})>[];

          // Parse @font-face blocks to associate weights and styles with woff2 URLs
          final fontFaceRegex =
              RegExp(r'@font-face\s*\{([^}]+)\}', multiLine: true);
          final fontFaceMatches = fontFaceRegex.allMatches(cssContent);

          final selectedFontUrls =
              <({String style, String weight}), ({String url, bool isLatin})>{};

          for (final match in fontFaceMatches) {
            final block = match.group(1) ?? '';
            final styleMatch =
                RegExp(r'font-style:\s*(normal|italic)', caseSensitive: false)
                    .firstMatch(block);
            final blockStyle = styleMatch?.group(1)?.toLowerCase() ?? 'normal';

            final weightMatch =
                RegExp(r'font-weight:\s*(\d+)').firstMatch(block);
            final blockWeight = weightMatch?.group(1) ??
                (sortedWeights.length == 1 ? sortedWeights.first : '400');

            if (!uniqueStyles.contains(blockStyle) ||
                !sortedWeights.contains(blockWeight)) {
              continue;
            }

            final urlMatch = RegExp(r'url\(([^)]+\.woff2)\)').firstMatch(block);
            if (urlMatch == null) {
              continue;
            }

            var fontUrl = urlMatch.group(1)!.trim();
            if ((fontUrl.startsWith("'") && fontUrl.endsWith("'")) ||
                (fontUrl.startsWith('"') && fontUrl.endsWith('"'))) {
              fontUrl = fontUrl.substring(1, fontUrl.length - 1).trim();
            }
            final isLatin = RegExp(
              r'unicode-range:\s*[^;]*U\+0000-00FF',
              caseSensitive: false,
            ).hasMatch(block);
            final key = (style: blockStyle, weight: blockWeight);
            final existing = selectedFontUrls[key];
            if (existing == null || (isLatin && !existing.isLatin)) {
              selectedFontUrls[key] = (url: fontUrl, isLatin: isLatin);
            }
          }

          for (final style in uniqueStyles) {
            for (final weight in sortedWeights) {
              final key = (style: style, weight: weight);
              final selected = selectedFontUrls[key];
              if (selected == null) {
                continue;
              }

              final filename = style == 'italic'
                  ? '$kebabFamily-$weight-italic.woff2'
                  : '$kebabFamily-$weight.woff2';
              final targetFile = File(p.join(fontsDir.path, filename));
              try {
                final fontResponse = await _client.get(Uri.parse(selected.url));
                if (fontResponse.statusCode == 200) {
                  await targetFile.writeAsBytes(fontResponse.bodyBytes);
                  if (!filesWritten.contains(targetFile.path)) {
                    filesWritten.add(targetFile.path);
                  }
                  downloadedForFamily.add((
                    weight: weight,
                    style: style,
                    filename: filename,
                  ));
                } else {
                  warnings.add(
                    'Failed to download font file for "$family" weight $weight style $style: HTTP ${fontResponse.statusCode}',
                  );
                }
              } catch (e) {
                warnings.add(
                    'Failed to download font file for "$family" weight $weight style $style: $e');
              }
            }
          }

          // Fallback: if block parsing did not catch woff2 URLs, try global regex search
          if (downloadedForFamily.isEmpty) {
            final globalUrlRegex = RegExp(r'url\(([^)]+\.woff2)\)');
            final globalMatches =
                globalUrlRegex.allMatches(cssContent).toList();

            var matchIndex = 0;
            for (final style in uniqueStyles) {
              for (final weight in sortedWeights) {
                if (matchIndex >= globalMatches.length) break;
                var fontUrl = globalMatches[matchIndex++].group(1)!.trim();
                if ((fontUrl.startsWith("'") && fontUrl.endsWith("'")) ||
                    (fontUrl.startsWith('"') && fontUrl.endsWith('"'))) {
                  fontUrl = fontUrl.substring(1, fontUrl.length - 1).trim();
                }
                final filename = style == 'italic'
                    ? '$kebabFamily-$weight-italic.woff2'
                    : '$kebabFamily-$weight.woff2';
                final targetFile = File(p.join(fontsDir.path, filename));

                try {
                  final fontResponse = await _client.get(Uri.parse(fontUrl));
                  if (fontResponse.statusCode == 200) {
                    await targetFile.writeAsBytes(fontResponse.bodyBytes);
                    if (!filesWritten.contains(targetFile.path)) {
                      filesWritten.add(targetFile.path);
                    }
                    downloadedForFamily.add((
                      weight: weight,
                      style: style,
                      filename: filename,
                    ));
                  }
                } catch (e) {
                  warnings.add(
                      'Failed to download font file for "$family" weight $weight style $style: $e');
                }
              }
            }
          }

          if (downloadedForFamily.isEmpty) {
            warnings.add(
                'No woff2 font files found or downloaded for family "$family".');
          } else {
            downloadedRules
                .putIfAbsent(family, () => [])
                .addAll(downloadedForFamily);
          }
        } catch (e) {
          warnings.add('Failed to optimize font family "$family": $e');
        }
      }

      final missingFaces = <({String family, String weight, String style})>[];
      for (final request in requests) {
        final family = request.family;
        final familyRules = downloadedRules[family] ?? const [];
        final sortedWeights = request.weights.toSet().toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
        final uniqueStyles = request.styles.toSet().toList();
        for (final style in uniqueStyles) {
          for (final weight in sortedWeights) {
            final found = familyRules.any(
              (r) => r.weight == weight && r.style == style,
            );
            if (!found) {
              missingFaces.add((family: family, weight: weight, style: style));
            }
          }
        }
      }

      if (requireAllRequestedFaces && missingFaces.isNotEmpty) {
        for (final missing in missingFaces) {
          warnings.add(
            'Missing requested font face: family "${missing.family}", weight ${missing.weight}, style ${missing.style}.',
          );
        }
      }

      var cssPath = '';
      if (downloadedRules.isNotEmpty &&
          (!requireAllRequestedFaces || missingFaces.isEmpty)) {
        final cssBuffer = StringBuffer();
        cssBuffer.writeln(
            '/* Generated by Bloom Font Optimizer. Do not edit manually. */');

        for (final entry in downloadedRules.entries) {
          final family = entry.key;
          final rules = entry.value;

          for (final rule in rules) {
            cssBuffer.writeln();
            cssBuffer.writeln('@font-face {');
            cssBuffer.writeln("  font-family: '$family';");
            cssBuffer.writeln('  font-style: ${rule.style};');
            cssBuffer.writeln('  font-weight: ${rule.weight};');
            cssBuffer.writeln('  font-display: swap;');
            cssBuffer.writeln(
                "  src: url('/generated/fonts/${rule.filename}') format('woff2');");
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
          cssBuffer
              .writeln('/* Fallback font definition for CLS mitigation */');
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
