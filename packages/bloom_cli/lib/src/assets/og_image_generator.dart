// lib/src/assets/og_image_generator.dart
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Real standard Open Graph image dimensions (1200x630).
const int kOgImageWidth = 1200;
const int kOgImageHeight = 630;

/// Color themes for generated Open Graph cards.
enum BloomOgTheme {
  dark,
  light,
}

// Dark theme palette (Linear / Vercel dark carbon aesthetic)
final _darkBgTop = img.ColorRgb8(9, 9, 11); // #09090B
final _darkBgBottom = img.ColorRgb8(24, 24, 32); // #181820
final _darkTitleColor = img.ColorRgb8(250, 250, 250); // #FAFAFA
final _darkSubtitleColor = img.ColorRgb8(161, 161, 170); // #A1A1AA
final _darkAccentColor = img.ColorRgb8(99, 102, 241); // #6366F1 (Indigo)

// Light theme palette
final _lightBgTop = img.ColorRgb8(255, 255, 255); // #FFFFFF
final _lightBgBottom = img.ColorRgb8(238, 242, 255); // #EEF2FF
final _lightTitleColor = img.ColorRgb8(15, 23, 42); // #0F172A
final _lightSubtitleColor = img.ColorRgb8(100, 116, 139); // #64748B
final _lightAccentColor = img.ColorRgb8(79, 70, 229); // #4F46E5

/// A lightweight, build-time Open Graph social card PNG generator for Bloom.
///
/// NOTE ON ARCHITECTURE & SCOPE:
/// Unlike Next.js's dynamic `ImageResponse` (which uses Satori to parse arbitrary
/// JSX and compute a full CSS flexbox layout tree into SVG before rasterization),
/// Bloom deliberately implements a fixed-layout social card template engine
/// powered directly by `package:image`'s bundled bitmap fonts (`arial14`, `arial24`,
/// `arial48`).
///
/// This generator does NOT support arbitrary CSS layouts, external TrueType font
/// loading, or sub-pixel text measurement. Text wrapping and font size selection
/// use character-count heuristics that reliably fit the 1200x630 canvas for
/// standard article, documentation, and product titles.
class BloomOgImageGenerator {
  /// Generates a 1200x630 PNG social card image.
  ///
  /// This is a pure, synchronous function with no I/O operations, mirroring
  /// `BloomImageTransformer.transform`.
  Uint8List generate({
    required String title,
    String? subtitle,
    String? eyebrow,
    BloomOgTheme theme = BloomOgTheme.dark,
  }) {
    final image = img.Image(width: kOgImageWidth, height: kOgImageHeight);

    // Theme color selection
    final isDark = theme == BloomOgTheme.dark;
    final bgTop = isDark ? _darkBgTop : _lightBgTop;
    final bgBottom = isDark ? _darkBgBottom : _lightBgBottom;
    final titleColor = isDark ? _darkTitleColor : _lightTitleColor;
    final subtitleColor = isDark ? _darkSubtitleColor : _lightSubtitleColor;
    final accentColor = isDark ? _darkAccentColor : _lightAccentColor;

    // Fill background with smooth two-stop vertical gradient
    for (var y = 0; y < kOgImageHeight; y++) {
      final t = y / (kOgImageHeight - 1);
      final r = (bgTop.r + (bgBottom.r - bgTop.r) * t).round();
      final g = (bgTop.g + (bgBottom.g - bgTop.g) * t).round();
      final b = (bgTop.b + (bgBottom.b - bgTop.b) * t).round();
      for (var x = 0; x < kOgImageWidth; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Font selection heuristic: use arial24 if title length exceeds 40 characters,
    // otherwise use the prominent arial48 font.
    final bool isLongTitle = title.trim().length > 40;
    final img.BitmapFont titleFont = isLongTitle ? img.arial24 : img.arial48;
    final int titleLineHeight = isLongTitle ? 34 : 60;
    final int titleMaxChars = isLongTitle ? 48 : 28;

    final titleLines = _wrapText(title, titleMaxChars);

    // Process optional eyebrow text (category/site label above title)
    final bool hasEyebrow = eyebrow != null && eyebrow.trim().isNotEmpty;
    final List<String> eyebrowLines =
        hasEyebrow ? _wrapText(eyebrow.trim().toUpperCase(), 60) : const [];

    // Process optional subtitle text below title
    final bool hasSubtitle = subtitle != null && subtitle.trim().isNotEmpty;
    final List<String> subtitleLines =
        hasSubtitle ? _wrapText(subtitle.trim(), 65) : const [];

    // Calculate vertical layout metrics for centering
    const int eyebrowLineHeight = 20;
    const int eyebrowGap = 20;
    const int subtitleGap = 24;
    const int subtitleLineHeight = 22;
    const int leftX = 100;

    final int eyebrowBlockHeight =
        hasEyebrow ? (eyebrowLines.length * eyebrowLineHeight + eyebrowGap) : 0;
    final int titleBlockHeight = titleLines.length * titleLineHeight;
    final int subtitleBlockHeight =
        hasSubtitle ? (subtitleGap + subtitleLines.length * subtitleLineHeight) : 0;

    final int totalContentHeight =
        eyebrowBlockHeight + titleBlockHeight + subtitleBlockHeight;

    int currentY = ((kOgImageHeight - totalContentHeight) / 2).round();
    if (currentY < 60) {
      currentY = 60;
    }

    // 1. Draw Eyebrow
    if (hasEyebrow) {
      for (final line in eyebrowLines) {
        img.drawString(
          image,
          line,
          font: img.arial14,
          x: leftX,
          y: currentY,
          color: accentColor,
        );
        currentY += eyebrowLineHeight;
      }
      currentY += eyebrowGap;
    }

    // 2. Draw Title
    for (final line in titleLines) {
      img.drawString(
        image,
        line,
        font: titleFont,
        x: leftX,
        y: currentY,
        color: titleColor,
      );
      currentY += titleLineHeight;
    }

    // 3. Draw Subtitle
    if (hasSubtitle) {
      currentY += subtitleGap;
      for (final line in subtitleLines) {
        img.drawString(
          image,
          line,
          font: img.arial14,
          x: leftX,
          y: currentY,
          color: subtitleColor,
        );
        currentY += subtitleLineHeight;
      }
    }

    // Re-encode to PNG matching the encodePng invocation used across Bloom CLI
    final encodedPng = img.encodePng(image, level: 6);
    if (encodedPng.isEmpty) {
      throw StateError('image encoder produced an empty payload');
    }

    return Uint8List.fromList(encodedPng);
  }

  /// Simple word-wrapping heuristic based on character counts.
  static List<String> _wrapText(String text, int maxCharsPerLine) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    final paragraphs = trimmed.split('\n');
    final result = <String>[];

    for (final para in paragraphs) {
      final words = para.trim().split(RegExp(r'\s+'));
      if (words.isEmpty || (words.length == 1 && words.first.isEmpty)) continue;

      var currentLine = StringBuffer();
      for (final word in words) {
        if (word.isEmpty) continue;
        if (currentLine.isEmpty) {
          currentLine.write(word);
        } else if (currentLine.length + 1 + word.length <= maxCharsPerLine) {
          currentLine.write(' $word');
        } else {
          result.add(currentLine.toString());
          currentLine = StringBuffer(word);
        }
      }
      if (currentLine.isNotEmpty) {
        result.add(currentLine.toString());
      }
    }

    return result.isEmpty ? [trimmed] : result;
  }
}
