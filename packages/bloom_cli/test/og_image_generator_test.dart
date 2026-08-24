// packages/bloom_cli/test/og_image_generator_test.dart
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:bloom_cli/src/assets/og_image_generator.dart';

void main() {
  group('BloomOgImageGenerator', () {
    late BloomOgImageGenerator generator;

    setUp(() {
      generator = BloomOgImageGenerator();
    });

    test('generates valid PNG with standard OG dimensions (1200x630)', () {
      final bytes = generator.generate(
        title: 'Building Modern Full-Stack Flutter Applications with Bloom',
        subtitle: 'A high-performance web framework for Dart & Flutter developers.',
        eyebrow: 'Framework Guide',
        theme: BloomOgTheme.dark,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));

      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(kOgImageWidth));
      expect(decoded.height, equals(kOgImageHeight));
      expect(kOgImageWidth, equals(1200));
      expect(kOgImageHeight, equals(630));
    });

    test('generates dark theme card with correct gradient palette', () {
      final bytes = generator.generate(
        title: 'Bloom Dark Theme',
        theme: BloomOgTheme.dark,
      );

      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(1200));
      expect(decoded.height, equals(630));

      // Check top-left pixel is dark carbon background
      final pTop = decoded.getPixel(0, 0);
      expect(pTop.r, closeTo(9, 3));
      expect(pTop.g, closeTo(9, 3));
      expect(pTop.b, closeTo(11, 3));
    });

    test('generates light theme card with correct gradient palette', () {
      final bytes = generator.generate(
        title: 'Bloom Light Theme',
        theme: BloomOgTheme.light,
      );

      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(1200));
      expect(decoded.height, equals(630));

      // Check top-left pixel is light background
      final pTop = decoded.getPixel(0, 0);
      expect(pTop.r, closeTo(255, 3));
      expect(pTop.g, closeTo(255, 3));
      expect(pTop.b, closeTo(255, 3));
    });

    test('applies font size heuristic based on title length', () {
      // Short title (<= 40 chars)
      final shortBytes = generator.generate(title: 'Short Title');
      final shortDecoded = img.decodeImage(shortBytes);
      expect(shortDecoded, isNotNull);
      expect(shortDecoded!.width, equals(1200));
      expect(shortDecoded.height, equals(630));

      // Long title (> 40 chars)
      final longBytes = generator.generate(
        title: 'This is an unusually long title designed to trigger the smaller bitmap font rendering heuristic',
      );
      final longDecoded = img.decodeImage(longBytes);
      expect(longDecoded, isNotNull);
      expect(longDecoded!.width, equals(1200));
      expect(longDecoded.height, equals(630));
    });

    test('handles title with and without optional eyebrow and subtitle', () {
      final minimalBytes = generator.generate(title: 'Minimal Card');
      expect(minimalBytes, isA<Uint8List>());
      expect(minimalBytes.length, greaterThan(1000));

      final fullBytes = generator.generate(
        title: 'Full Featured Card',
        eyebrow: 'Announcement',
        subtitle: 'Everything you need to know about Bloom version 1.0',
      );
      expect(fullBytes, isA<Uint8List>());
      expect(fullBytes.length, greaterThan(1000));
    });
  });
}
