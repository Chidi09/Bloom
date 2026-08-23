// lib/src/assets/image_transformer.dart
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Widths the optimizer will produce. A request for any other width is
/// rejected. This allowlist is a DoS guard: without it an attacker requests
/// ?w=1,2,3... and pins every core re-encoding images forever.
const List<int> kBloomImageWidths = [640, 750, 828, 1080, 1200, 1920, 2048, 3840];

const int kBloomImageJpegQuality = 80;

enum BloomImageFormat { jpeg, png }

class BloomImageTransformResult {
  final Uint8List bytes;
  final BloomImageFormat format;
  final int width;
  final int height;

  BloomImageTransformResult({
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
  });
}

class BloomImageTransformer {
  /// Resizes [sourceBytes] to [width] and re-encodes it.
  ///
  /// Throws [ArgumentError] if [width] is not in [kBloomImageWidths].
  /// Throws [StateError] if the source is not a decodable image, or if the
  /// encoder produces an empty payload -- never returns a corrupt result.
  BloomImageTransformResult transform(Uint8List sourceBytes, int width) {
    if (!isAllowedWidth(width)) {
      throw ArgumentError('Width $width is not an allowed variant width. Allowed: $kBloomImageWidths');
    }

    // decodeImage does not merely return null on bad input: it probes the
    // registered decoders in turn, and a decoder handed a buffer shorter than
    // the header it expects throws instead. A 4-byte payload, for instance,
    // comes back as a RangeError out of the PSD decoder. Normalise every
    // rejection to the documented StateError so callers have one thing to
    // catch, and untrusted bytes cannot surface an unexpected exception type.
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(Uint8List.fromList(sourceBytes));
    } catch (e) {
      throw StateError('source is not a decodable image format: $e');
    }
    if (decoded == null) {
      throw StateError('source is not a decodable image format');
    }

    // If the decoded image's width is <= the requested width, DO NOT upscale;
    // re-encode at the original dimensions. Upscaling only wastes bytes.
    final int targetWidth;
    if (decoded.width <= width) {
      targetWidth = decoded.width;
    } else {
      targetWidth = width;
    }

    final resized = img.copyResize(decoded, width: targetWidth, interpolation: img.Interpolation.average);

    // Choose the format: decoded.numChannels >= 4 (has alpha) => PNG via
    // encodePng(resized, level: 6). Otherwise JPEG via
    // encodeJpg(resized, quality: kBloomImageJpegQuality).
    //
    // WebP via package:image is LOSSLESS VP8L ONLY, with no quality parameter.
    // Benchmarked on real photographs at width 640:
    //   photo   : lossless WebP 376.6KB / 2879ms   vs   JPEG q80 53.2KB / 164ms
    //   photo   : lossless WebP 561.0KB /  756ms   vs   JPEG q80 147.0KB / 81ms
    //   UI png  : lossless WebP 178.6KB / 10053ms  vs   PNG 257.1KB
    // WebP via package:image is therefore up to 7x LARGER and 18x SLOWER than JPEG
    // on photographs, and takes 10-40 SECONDS on flat graphics. It is unusable.
    // DO NOT call img.encodeWebP anywhere. (It does not even exist in 4.8.0.)
    // Re-encode in the source's own best lossy codec instead: JPEG for photographic
    // sources, PNG for sources with alpha.
    final List<int> encodedBytes;
    final BloomImageFormat format;
    if (decoded.numChannels >= 4) {
      encodedBytes = img.encodePng(resized, level: 6);
      format = BloomImageFormat.png;
    } else {
      encodedBytes = img.encodeJpg(resized, quality: kBloomImageJpegQuality);
      format = BloomImageFormat.jpeg;
    }

    if (encodedBytes.isEmpty) {
      throw StateError('image encoder produced an empty payload');
    }

    return BloomImageTransformResult(
      bytes: Uint8List.fromList(encodedBytes),
      format: format,
      width: resized.width,
      height: resized.height,
    );
  }

  /// True when [width] is an allowed variant width.
  static bool isAllowedWidth(int width) {
    return kBloomImageWidths.contains(width);
  }
}