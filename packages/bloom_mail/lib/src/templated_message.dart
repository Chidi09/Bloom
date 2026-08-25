// lib/src/templated_message.dart
import 'message.dart';
import 'template.dart';

/// Helper utilities and builder functions for templated [BloomMailMessage] instances.
class BloomTemplatedMessage {
  /// Builds a [BloomMailMessage] by rendering [htmlTemplate] and optional [textTemplate]
  /// against the provided data [context].
  static BloomMailMessage create({
    required List<String> to,
    required String from,
    required String subject,
    required BloomMailTemplate htmlTemplate,
    BloomMailTemplate? textTemplate,
    String? body,
    required Map<String, dynamic> context,
    List<String> cc = const [],
    List<String> bcc = const [],
  }) {
    return BloomMailMessage.fromTemplate(
      to: to,
      from: from,
      subject: subject,
      htmlTemplate: htmlTemplate,
      textTemplate: textTemplate,
      body: body,
      context: context,
      cc: cc,
      bcc: bcc,
    );
  }

  /// Builds a single-recipient [BloomMailMessage] by rendering [htmlTemplate] and optional [textTemplate]
  /// against the provided data [context].
  static BloomMailMessage single({
    required String to,
    required String from,
    required String subject,
    required BloomMailTemplate htmlTemplate,
    BloomMailTemplate? textTemplate,
    String? body,
    required Map<String, dynamic> context,
    List<String> cc = const [],
    List<String> bcc = const [],
  }) {
    return BloomMailMessage.singleFromTemplate(
      to: to,
      from: from,
      subject: subject,
      htmlTemplate: htmlTemplate,
      textTemplate: textTemplate,
      body: body,
      context: context,
      cc: cc,
      bcc: bcc,
    );
  }
}

/// Alias for [BloomTemplatedMessage].
typedef TemplatedMessage = BloomTemplatedMessage;
