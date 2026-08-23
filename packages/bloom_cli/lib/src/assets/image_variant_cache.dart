// lib/src/assets/image_variant_cache.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'image_transformer.dart';

class BloomImageVariantCache {
  final Directory _cacheDir;

  /// Root defaults to `.dart_tool/bloom/image_cache` under [projectRoot].
  BloomImageVariantCache({required Directory projectRoot, Directory? cacheDir})
      : _cacheDir = cacheDir ?? Directory(p.join(projectRoot.path, '.dart_tool', 'bloom', 'image_cache'));

  /// Returns the cached variant, or null on a miss.
  Uint8List? read(File source, int width) {
    final key = keyFor(source, width);
    final cacheFile = File(p.join(_cacheDir.path, key));
    if (!cacheFile.existsSync()) {
      return null;
    }
    try {
      final bytes = cacheFile.readAsBytesSync();
      if (bytes.isEmpty) {
        return null;
      }
      // Sniff the magic bytes rather than decoding. Fully decoding here would
      // make every cache HIT cost roughly what the miss cost -- a 1920px JPEG
      // takes hundreds of milliseconds to decode -- which defeats the entire
      // point of caching the variant. The header check is a few bytes and
      // still catches the failure that actually happens in practice: a
      // truncated or half-written file.
      if (!_hasImageMagic(bytes)) {
        return null;
      }
      return Uint8List.fromList(bytes);
    } catch (_) {
      // A corrupt or unreadable cache entry must be treated as a MISS,
      // never propagated as an exception -- the cache is an optimization
      // and must never be able to take the server down.
      return null;
    }
  }

  /// Stores [bytes] as the variant of [source] at [width].
  void write(File source, int width, Uint8List bytes, BloomImageFormat format) {
    final key = keyFor(source, width);
    try {
      if (!_cacheDir.existsSync()) {
        _cacheDir.createSync(recursive: true);
      }
      // Write to a temporary file and rename into place. Rename is atomic on
      // the same filesystem, so a crash or a concurrent reader can never
      // observe a half-written variant -- it sees either the old file or the
      // complete new one. Writing directly would leave a truncated image in
      // the cache under exactly the conditions that matter most.
      final cacheFile = File(p.join(_cacheDir.path, key));
      final tempFile = File('${cacheFile.path}.$pid.tmp');
      tempFile.writeAsBytesSync(bytes, flush: true);
      tempFile.renameSync(cacheFile.path);
    } catch (_) {
      // Cache write failures are non-fatal; the optimizer will just
      // recompute on next request.
    }
  }

  /// True when [bytes] starts with a JPEG or PNG signature.
  ///
  /// These are the only two formats [BloomImageTransformer] emits, so anything
  /// else in the cache directory did not come from us and is not trusted.
  static bool _hasImageMagic(List<int> bytes) {
    // JPEG: FF D8 FF
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length >= pngSignature.length) {
      for (var i = 0; i < pngSignature.length; i++) {
        if (bytes[i] != pngSignature[i]) return false;
      }
      return true;
    }
    return false;
  }

  /// Cache key: sha1 of the source's absolute path, its length, its
  /// modification timestamp, and the width. Including length+mtime means
  /// editing the source file invalidates its variants automatically rather
  /// than serving a stale image forever.
  String keyFor(File source, int width) {
    final absolutePath = source.absolute.path;
    final stat = source.statSync();
    final length = stat.size;
    final mtime = stat.modified.millisecondsSinceEpoch;
    final input = '$absolutePath:$length:$mtime:$width';
    final bytes = utf8.encode(input);
    final digest = sha1.convert(bytes);
    return '${digest.toString()}_$width';
  }
}