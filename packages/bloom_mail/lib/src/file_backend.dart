// lib/src/file_backend.dart
import 'dart:io';

import 'backend.dart';
import 'message.dart';

/// Email backend that writes outgoing messages as `.eml` files into a target directory.
///
/// Designed for local development, visual verification, and filesystem-based test assertions.
class BloomFileBackend implements BloomMailBackend {
  /// The destination directory where `.eml` files are written.
  final String directory;

  /// Creates a new [BloomFileBackend] targeting [directory].
  const BloomFileBackend(this.directory);

  /// Formats [message] into standard `.eml` plain-text structure.
  static String format(BloomMailMessage message) {
    final buffer = StringBuffer();
    buffer.writeln('From: ${message.from}');
    buffer.writeln('To: ${message.to.join(', ')}');
    if (message.cc.isNotEmpty) {
      buffer.writeln('Cc: ${message.cc.join(', ')}');
    }
    if (message.bcc.isNotEmpty) {
      buffer.writeln('Bcc: ${message.bcc.join(', ')}');
    }
    buffer.writeln('Subject: ${message.subject}');
    buffer.writeln();
    buffer.write(message.body);
    if (message.htmlBody != null) {
      buffer.writeln();
      buffer.writeln();
      buffer.writeln('[HTML body]');
      buffer.write(message.htmlBody);
    }
    return buffer.toString();
  }

  @override
  Future<void> send(BloomMailMessage message) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final file = File('${dir.path}/$timestamp.eml');
      await file.writeAsString(format(message));
    } catch (e, st) {
      if (e is BloomMailException) rethrow;
      throw BloomMailException(
        'Failed to write email file to directory "$directory": $e',
        cause: e,
        stackTrace: st,
      );
    }
  }
}

/// Alias for [BloomFileBackend].
typedef FileBackend = BloomFileBackend;

