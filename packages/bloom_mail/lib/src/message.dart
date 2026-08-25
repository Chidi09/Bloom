// lib/src/message.dart
import 'template.dart';

/// An outgoing email message.
///
/// Models transactional email messages with support for multiple recipients,
/// sender addresses, subject line, plain text body, optional HTML formatted body,
/// and optional CC/BCC recipients.
class BloomMailMessage {
  /// Recipient email addresses.
  final List<String> to;

  /// Sender email address.
  final String from;

  /// Email subject line.
  final String subject;

  /// Plain text email body.
  final String body;

  /// Optional HTML formatted email body.
  final String? htmlBody;

  /// Optional carbon copy (CC) recipient email addresses.
  final List<String> cc;

  /// Optional blind carbon copy (BCC) recipient email addresses.
  final List<String> bcc;

  /// Creates a new [BloomMailMessage].
  const BloomMailMessage({
    required this.to,
    required this.from,
    required this.subject,
    required this.body,
    this.htmlBody,
    this.cc = const [],
    this.bcc = const [],
  });

  /// Convenience constructor for a single recipient email.
  factory BloomMailMessage.single({
    required String to,
    required String from,
    required String subject,
    required String body,
    String? htmlBody,
    List<String> cc = const [],
    List<String> bcc = const [],
  }) {
    return BloomMailMessage(
      to: [to],
      from: from,
      subject: subject,
      body: body,
      htmlBody: htmlBody,
      cc: cc,
      bcc: bcc,
    );
  }

  /// Creates a [BloomMailMessage] by rendering the provided [htmlTemplate] (and optional [textTemplate])
  /// with a data [context] map.
  ///
  /// If [htmlTemplate] has a companion text template (or [textTemplate] is provided),
  /// [body] is populated with the rendered plain text. If no text template is available,
  /// [body] uses [body] if provided, or an empty string.
  factory BloomMailMessage.fromTemplate({
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
    final renderedHtml = htmlTemplate.render(context);
    final effectiveTextTemplate = textTemplate ?? htmlTemplate.textTemplate;
    final renderedText = effectiveTextTemplate != null
        ? effectiveTextTemplate.render(context)
        : (body ?? '');

    return BloomMailMessage(
      to: to,
      from: from,
      subject: subject,
      body: renderedText,
      htmlBody: renderedHtml,
      cc: cc,
      bcc: bcc,
    );
  }

  /// Convenience constructor for a single recipient templated email.
  factory BloomMailMessage.singleFromTemplate({
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
    return BloomMailMessage.fromTemplate(
      to: [to],
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

  /// Creates a copy of this message with specified fields replaced.
  BloomMailMessage copyWith({
    List<String>? to,
    String? from,
    String? subject,
    String? body,
    String? htmlBody,
    List<String>? cc,
    List<String>? bcc,
  }) {
    return BloomMailMessage(
      to: to ?? this.to,
      from: from ?? this.from,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      htmlBody: htmlBody ?? this.htmlBody,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BloomMailMessage) return false;
    return _listEquals(to, other.to) &&
        from == other.from &&
        subject == other.subject &&
        body == other.body &&
        htmlBody == other.htmlBody &&
        _listEquals(cc, other.cc) &&
        _listEquals(bcc, other.bcc);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(to),
        from,
        subject,
        body,
        htmlBody,
        Object.hashAll(cc),
        Object.hashAll(bcc),
      );

  @override
  String toString() {
    return 'BloomMailMessage(to: $to, from: $from, subject: "$subject", bodyLength: ${body.length}, hasHtml: ${htmlBody != null})';
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Alias for [BloomMailMessage].
typedef MailMessage = BloomMailMessage;
