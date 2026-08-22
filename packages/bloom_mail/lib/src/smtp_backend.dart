// lib/src/smtp_backend.dart
import 'package:bloom_server/bloom_server.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart' as mailer_smtp;

import 'backend.dart';
import 'message.dart';

/// Configuration parameters for SMTP mail delivery.
///
/// Follows a fluent builder style matching `SmtpConfig` and supports
/// automated population from environment variables via [BloomEnv].
class BloomSmtpConfig {
  /// Hostname or IP address of the SMTP server.
  final String host;

  /// Port number for the SMTP connection (default: 587).
  final int port;

  /// Optional username for SMTP authentication.
  final String? username;

  /// Optional password for SMTP authentication.
  final String? password;

  /// Whether to enforce TLS / STARTTLS encryption (default: true).
  final bool useTls;

  /// Whether to bypass TLS certificate validation (default: false, for local test servers).
  final bool ignoreBadCertificate;

  /// Creates a new [BloomSmtpConfig] with default port 587 and TLS enabled.
  const BloomSmtpConfig(
    this.host, {
    this.port = 587,
    this.username,
    this.password,
    this.useTls = true,
    this.ignoreBadCertificate = false,
  });

  /// Loads SMTP configuration from environment variables via [BloomEnv].
  ///
  /// Keys read:
  /// - [hostKey]: Server host (default: `SMTP_HOST`, required unless [defaultHost] is given)
  /// - [portKey]: Server port (default: `SMTP_PORT`, default value 587)
  /// - [userKey]: SMTP username (default: `SMTP_USER`, optional)
  /// - [passKey]: SMTP password (default: `SMTP_PASSWORD`, optional)
  /// - [useTlsKey]: Enforce TLS (default: `SMTP_USE_TLS`, default value true)
  factory BloomSmtpConfig.fromEnv({
    String hostKey = 'SMTP_HOST',
    String portKey = 'SMTP_PORT',
    String userKey = 'SMTP_USER',
    String passKey = 'SMTP_PASSWORD',
    String useTlsKey = 'SMTP_USE_TLS',
    String? defaultHost,
  }) {
    final host = defaultHost != null
        ? BloomEnv.get(hostKey, defaultValue: defaultHost)
        : BloomEnv.get(hostKey);

    final port = BloomEnv.getInt(portKey, defaultValue: 587);
    final username = BloomEnv.getOrNull(userKey);
    final password = BloomEnv.getOrNull(passKey);
    final useTls = BloomEnv.getBool(useTlsKey, defaultValue: true);

    return BloomSmtpConfig(
      host,
      port: port,
      username: username,
      password: password,
      useTls: useTls,
    );
  }

  /// Sets the SMTP server port.
  BloomSmtpConfig withPort(int port) => copyWith(port: port);

  /// Sets the username and password for SMTP authentication.
  BloomSmtpConfig withCredentials(String username, String password) =>
      copyWith(username: username, password: password);

  /// Builder alias for [withCredentials].
  BloomSmtpConfig credentials(String username, String password) =>
      withCredentials(username, password);

  /// Configures whether TLS / STARTTLS encryption should be required.
  BloomSmtpConfig withUseTls(bool useTls) => copyWith(useTls: useTls);

  /// Configures whether to ignore self-signed or invalid TLS certificates.
  BloomSmtpConfig withIgnoreBadCertificate(bool ignore) =>
      copyWith(ignoreBadCertificate: ignore);

  /// Builder alias for [withIgnoreBadCertificate].
  BloomSmtpConfig ignoreBadCertificates(bool ignore) =>
      withIgnoreBadCertificate(ignore);

  /// Creates a copy of this configuration with replacement values.
  BloomSmtpConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useTls,
    bool? ignoreBadCertificate,
  }) {
    return BloomSmtpConfig(
      host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useTls: useTls ?? this.useTls,
      ignoreBadCertificate: ignoreBadCertificate ?? this.ignoreBadCertificate,
    );
  }

  /// Validates the configuration parameters.
  /// Throws [BloomMailException] if parameters are invalid.
  void validate() {
    if (host.trim().isEmpty) {
      throw const BloomMailException('SMTP host cannot be empty');
    }
    final hasUser = username != null && username!.trim().isNotEmpty;
    final hasPass = password != null && password!.trim().isNotEmpty;
    if (hasUser != hasPass) {
      throw const BloomMailException(
        'SMTP username and password must be supplied together',
      );
    }
  }

  @override
  String toString() {
    // Redact password and sensitive credentials from toString output
    return 'BloomSmtpConfig(host: $host, port: $port, useTls: $useTls, hasAuth: ${username != null})';
  }
}

/// Real SMTP delivery backend using pure-Dart `package:mailer`.
///
/// Supports plain SMTP, explicit STARTTLS (default on port 587), and implicit
/// SSL/TLS (port 465). Configured via [BloomSmtpConfig].
class BloomSmtpBackend implements BloomMailBackend {
  /// The active SMTP configuration.
  final BloomSmtpConfig config;

  /// Creates a new [BloomSmtpBackend] after validating [config].
  BloomSmtpBackend(this.config) {
    config.validate();
  }

  @override
  Future<void> send(BloomMailMessage message) async {
    try {
      final smtpServer = mailer_smtp.SmtpServer(
        config.host,
        port: config.port,
        ssl: config.port == 465 && config.useTls,
        allowInsecure: !config.useTls,
        username: config.username,
        password: config.password,
        ignoreBadCertificate: config.ignoreBadCertificate,
      );

      final mailMessage = mailer.Message()
        ..from = mailer.Address(message.from)
        ..recipients = message.to.map((addr) => mailer.Address(addr)).toList()
        ..subject = message.subject
        ..text = message.body;

      if (message.htmlBody != null) {
        mailMessage.html = message.htmlBody;
      }
      if (message.cc.isNotEmpty) {
        mailMessage.ccRecipients =
            message.cc.map((addr) => mailer.Address(addr)).toList();
      }
      if (message.bcc.isNotEmpty) {
        mailMessage.bccRecipients =
            message.bcc.map((addr) => mailer.Address(addr)).toList();
      }

      await mailer.send(mailMessage, smtpServer);
    } catch (e, st) {
      if (e is BloomMailException) rethrow;
      throw BloomMailException(
        'Failed to send mail via SMTP (${config.host}:${config.port}): $e',
        cause: e,
        stackTrace: st,
      );
    }
  }
}

/// Alias for [BloomSmtpConfig].
typedef SmtpConfig = BloomSmtpConfig;

/// Alias for [BloomSmtpBackend].
typedef SmtpBackend = BloomSmtpBackend;

