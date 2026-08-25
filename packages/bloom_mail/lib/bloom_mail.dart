// lib/bloom_mail.dart
/// Transactional email sending library for Bloom server applications.
///
/// Provides a provider-agnostic [BloomMailMessage] model, Django-inspired [BloomMailTemplate]
/// engine, and pluggable [BloomMailBackend] delivery mechanisms including [BloomSmtpBackend],
/// [BloomConsoleBackend], [BloomFileBackend], and [BloomInMemoryBackend]. Backends integrate
/// with Bloom's dependency injection container for testability and clean architecture.
///
/// Example usage:
/// ```dart
/// final template = BloomMailTemplate.fromString(
///   '<h1>Welcome, {{ name }}!</h1>',
///   textSource: 'Welcome, {{ name }}!',
/// );
///
/// final message = BloomMailMessage.fromTemplate(
///   to: ['user@example.com'],
///   from: 'noreply@bloom.dev',
///   subject: 'Welcome to Bloom',
///   htmlTemplate: template,
///   context: {'name': 'Alice'},
/// );
///
/// final backend = const BloomConsoleBackend();
/// await backend.send(message);
/// ```
library;

export 'src/backend.dart';
export 'src/console_backend.dart';
export 'src/file_backend.dart';
export 'src/in_memory_backend.dart';
export 'src/message.dart';
export 'src/smtp_backend.dart';
export 'src/template.dart';
export 'src/templated_message.dart';
