// lib/src/console_backend.dart
import 'backend.dart';
import 'message.dart';

/// Email backend that prints outgoing messages to standard output.
///
/// Designed for local development where a real SMTP server is not needed.
/// Never logs credentials or server configurations.
class BloomConsoleBackend implements BloomMailBackend {
  /// Output function to use (defaults to [print]).
  final void Function(String message)? logger;

  /// Creates a new [BloomConsoleBackend].
  const BloomConsoleBackend({this.logger});

  @override
  Future<void> send(BloomMailMessage message) async {
    final buffer = StringBuffer();
    buffer.writeln('========== [Bloom Mail: ConsoleBackend] ==========');
    buffer.writeln('From: ${message.from}');
    buffer.writeln('To: ${message.to.join(', ')}');
    if (message.cc.isNotEmpty) {
      buffer.writeln('Cc: ${message.cc.join(', ')}');
    }
    if (message.bcc.isNotEmpty) {
      buffer.writeln('Bcc: ${message.bcc.join(', ')}');
    }
    buffer.writeln('Subject: ${message.subject}');
    buffer.writeln('--- Plain Text Body ---');
    buffer.writeln(message.body);
    if (message.htmlBody != null) {
      buffer.writeln('--- HTML Body ---');
      buffer.writeln(message.htmlBody);
    }
    buffer.writeln('==================================================');

    final output = buffer.toString();
    if (logger != null) {
      logger!(output);
    } else {
      // ignore: avoid_print
      print(output);
    }
  }
}

/// Alias for [BloomConsoleBackend].
typedef ConsoleBackend = BloomConsoleBackend;

