// packages/bloom_cli/test/image_transformer_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:bloom_cli/src/assets/image_transformer.dart';
import 'package:bloom_cli/src/assets/image_variant_cache.dart';

void main() {
  group('BloomImageTransformer', () {
    late BloomImageTransformer transformer;

    setUp(() {
      transformer = BloomImageTransformer();
    });

    test('transform produces a decodable image of the requested width', () {
      final sourceImg = img.Image(width: 1920, height: 1080);
      img.fill(sourceImg, color: img.ColorRgb8(255, 0, 0));
      final sourceBytes = Uint8List.fromList(img.encodeJpg(sourceImg, quality: 80));

      final result = transformer.transform(sourceBytes, 640);

      expect(result.width, equals(640));
      expect(result.height, equals(360)); // 1080 * 640 / 1920 = 360
      expect(result.bytes, isNotEmpty);

      final decoded = img.decodeImage(result.bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(640));
      expect(decoded.height, equals(360));
    });

    test('a width outside kBloomImageWidths throws ArgumentError', () {
      final sourceImg = img.Image(width: 100, height: 100);
      img.fill(sourceImg, color: img.ColorRgb8(0, 255, 0));
      final sourceBytes = Uint8List.fromList(img.encodeJpg(sourceImg, quality: 80));

      expect(() => transformer.transform(sourceBytes, 100), throwsArgumentError);
      expect(() => transformer.transform(sourceBytes, 500), throwsArgumentError);
      expect(() => transformer.transform(sourceBytes, 9999), throwsArgumentError);
    });

    test('non-image bytes throw StateError', () {
      final sourceBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(() => transformer.transform(sourceBytes, 640), throwsStateError);
    });

    test('a source narrower than the requested width is NOT upscaled', () {
      final sourceImg = img.Image(width: 400, height: 300);
      img.fill(sourceImg, color: img.ColorRgb8(0, 0, 255));
      final sourceBytes = Uint8List.fromList(img.encodeJpg(sourceImg, quality: 80));

      final result = transformer.transform(sourceBytes, 640);

      // Should NOT upscale; should stay at original 400 width
      expect(result.width, equals(400));
      expect(result.height, equals(300));
    });

    test('an image with alpha comes back as PNG; one without comes back as JPEG', () {
      // Image with alpha (4 channels)
      final rgbaImg = img.Image(width: 800, height: 600, numChannels: 4);
      img.fill(rgbaImg, color: img.ColorRgba8(255, 0, 0, 128));
      final rgbaBytes = Uint8List.fromList(img.encodePng(rgbaImg));

      final pngResult = transformer.transform(rgbaBytes, 640);
      expect(pngResult.format, equals(BloomImageFormat.png));

      // Image without alpha (3 channels)
      final rgbImg = img.Image(width: 800, height: 600, numChannels: 3);
      img.fill(rgbImg, color: img.ColorRgb8(0, 255, 0));
      final rgbBytes = Uint8List.fromList(img.encodeJpg(rgbImg, quality: 80));

      final jpegResult = transformer.transform(rgbBytes, 640);
      expect(jpegResult.format, equals(BloomImageFormat.jpeg));
    });

    test('isAllowedWidth returns true for allowed widths and false otherwise', () {
      expect(BloomImageTransformer.isAllowedWidth(640), isTrue);
      expect(BloomImageTransformer.isAllowedWidth(750), isTrue);
      expect(BloomImageTransformer.isAllowedWidth(828), isTrue);
      expect(BloomImageTransformer.isAllowedWidth(1080), isTrue);
      expect(BloomImageTransformer.isAllowedWidth(1200), isTrue);
      expect(BloomImageTransformer.isAllowedWidth(1920), isTrue);
      expect(BloomImageTransformer.isAllowedWidth(2048), isTrue);
      expect(BloomImageTransformer.isAllowedWidth(3840), isTrue);

      expect(BloomImageTransformer.isAllowedWidth(100), isFalse);
      expect(BloomImageTransformer.isAllowedWidth(500), isFalse);
      expect(BloomImageTransformer.isAllowedWidth(9999), isFalse);
    });
  });

  group('BloomImageVariantCache', () {
    late Directory tempDir;
    late Directory projectRoot;
    late BloomImageVariantCache cache;
    late File sourceFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bloom_image_cache_test_');
      projectRoot = Directory(p.join(tempDir.path, 'project'));
      projectRoot.createSync(recursive: true);
      cache = BloomImageVariantCache(projectRoot: projectRoot);

      sourceFile = File(p.join(projectRoot.path, 'source.jpg'));
      final sourceImg = img.Image(width: 1920, height: 1080);
      img.fill(sourceImg, color: img.ColorRgb8(255, 128, 0));
      sourceFile.writeAsBytesSync(img.encodeJpg(sourceImg, quality: 80));
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('the variant cache round-trips: write then read returns identical bytes', () {
      // Real encoded bytes, not an arbitrary byte list: the cache only ever
      // holds encoder output, and it rejects anything without a JPEG/PNG
      // signature as a not-ours entry.
      final variant = img.Image(width: 64, height: 48);
      img.fill(variant, color: img.ColorRgb8(12, 34, 56));
      final variantBytes = Uint8List.fromList(img.encodeJpg(variant, quality: 80));
      cache.write(sourceFile, 640, variantBytes, BloomImageFormat.jpeg);

      final readBytes = cache.read(sourceFile, 640);
      expect(readBytes, isNotNull);
      expect(readBytes, equals(variantBytes));
    });

    test('a cache miss returns null', () {
      final readBytes = cache.read(sourceFile, 750); // Different width, not written
      expect(readBytes, isNull);
    });

    test('touching the source file (changing mtime/length) invalidates the key', () async {
      final variant = img.Image(width: 32, height: 32);
      img.fill(variant, color: img.ColorRgb8(200, 100, 50));
      final variantBytes = Uint8List.fromList(img.encodeJpg(variant, quality: 80));
      cache.write(sourceFile, 640, variantBytes, BloomImageFormat.jpeg);

      // Verify it reads back
      expect(cache.read(sourceFile, 640), equals(variantBytes));

      // Modify the source file (change length and mtime)
      await Future.delayed(Duration(milliseconds: 10)); // Ensure mtime changes
      sourceFile.writeAsBytesSync([5, 6, 7, 8, 9, 10]);

      // Should now be a miss because key changed
      expect(cache.read(sourceFile, 640), isNull);
    });

    test('a corrupt file in the cache directory reads as a miss rather than throwing', () {
      // Write a corrupt cache file manually
      final key = cache.keyFor(sourceFile, 640);
      final cacheDir = Directory(p.join(projectRoot.path, '.dart_tool', 'bloom', 'image_cache'));
      cacheDir.createSync(recursive: true);
      final corruptFile = File(p.join(cacheDir.path, key));
      corruptFile.writeAsBytesSync([0xFF, 0xFE, 0xFD, 0xFC]); // Not a valid image

      // Should return null (miss) not throw
      expect(cache.read(sourceFile, 640), isNull);
    });

    test('empty cache file reads as a miss', () {
      final key = cache.keyFor(sourceFile, 640);
      final cacheDir = Directory(p.join(projectRoot.path, '.dart_tool', 'bloom', 'image_cache'));
      cacheDir.createSync(recursive: true);
      final emptyFile = File(p.join(cacheDir.path, key));
      emptyFile.writeAsBytesSync([]);

      expect(cache.read(sourceFile, 640), isNull);
    });

    test('keyFor includes path, length, mtime, and width', () {
      final key1 = cache.keyFor(sourceFile, 640);
      final key2 = cache.keyFor(sourceFile, 750);
      expect(key1, isNot(equals(key2)));

      // Same file, same width should produce same key
      final key3 = cache.keyFor(sourceFile, 640);
      expect(key1, equals(key3));
    });
  });
}