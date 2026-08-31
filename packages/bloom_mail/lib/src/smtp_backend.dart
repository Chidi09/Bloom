// lib/src/smtp_backend.dart
import 'dart:async';
import 'dart:io';
import 'package:bloom_server/bloom_server.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart' as mailer_smtp;
import 'package:meta/meta.dart';

import 'backend.dart';
import 'message.dart';

/// Configuration parameters for SMTP mail delivery.
///
/// Follows a fluent builder style matching `SmtpConfig` and supports
/// automated population from environment variables via [BloomEnv].
class BloomSmtpConfig {
  /// Hostname or IP address of the SMTP server.
  final String host;

  /// Port number for the SMTP connection (default: 587, valid range: 1..65535).
  final int port;

  /// Optional username for SMTP authentication.
  final String? username;

  /// Optional password for SMTP authentication.
  final String? password;

  /// Whether to enforce TLS / STARTTLS encryption (default: true).
  final bool useTls;

  /// Whether to bypass TLS certificate validation (default: false).
  ///
  /// **Security Warning**: Enabling this in production weakens TLS transport security
  /// and exposes connections to man-in-the-middle attacks. It is rejected by default
  /// in production mode unless [allowInsecureCertificates] is explicitly set to `true`.
  final bool ignoreBadCertificate;

  /// Explicit opt-in required to permit [ignoreBadCertificate] in production environments.
  final bool allowInsecureCertificates;

  /// Timeout for establishing connection and sending email (default: 15 seconds).
  final Duration timeout;

  /// Maximum number of retries for transient transport failures (default: 2).
  /// Deterministic failures (validation, authentication) are never retried.
  final int maxRetries;

  /// Initial retry backoff delay (default: 500 milliseconds).
  final Duration retryDelay;

  /// Maximum retry backoff delay ceiling (default: 5 seconds).
  final Duration maxRetryDelay;

  /// Creates a new [BloomSmtpConfig] with default port 587, TLS enabled, and safe defaults.
  const BloomSmtpConfig(
    this.host, {
    this.port = 587,
    this.username,
    this.password,
    this.useTls = true,
    this.ignoreBadCertificate = false,
    this.allowInsecureCertificates = false,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 500),
    this.maxRetryDelay = const Duration(seconds: 5),
  });

  /// Loads SMTP configuration from environment variables via [BloomEnv].
  ///
  /// Keys read:
  /// - [hostKey]: Server host (default: `SMTP_HOST`, required unless [defaultHost] is given)
  /// - [portKey]: Server port (default: `SMTP_PORT`, default value 587)
  /// - [userKey]: SMTP username (default: `SMTP_USER`, optional)
  /// - [passKey]: SMTP password (default: `SMTP_PASSWORD`, optional)
  /// - [useTlsKey]: Enforce TLS (default: `SMTP_USE_TLS`, default value true)
  /// - [timeoutSecondsKey]: Timeout in seconds (default: `SMTP_TIMEOUT_SECONDS`, default 15)
  /// - [maxRetriesKey]: Max retries (default: `SMTP_MAX_RETRIES`, default 2)
  factory BloomSmtpConfig.fromEnv({
    String hostKey = 'SMTP_HOST',
    String portKey = 'SMTP_PORT',
    String userKey = 'SMTP_USER',
    String passKey = 'SMTP_PASSWORD',
    String useTlsKey = 'SMTP_USE_TLS',
    String timeoutSecondsKey = 'SMTP_TIMEOUT_SECONDS',
    String maxRetriesKey = 'SMTP_MAX_RETRIES',
    String? defaultHost,
  }) {
    final host = defaultHost != null
        ? BloomEnv.get(hostKey, defaultValue: defaultHost)
        : BloomEnv.get(hostKey);

    final port = BloomEnv.getInt(portKey, defaultValue: 587);
    final username = BloomEnv.getOrNull(userKey);
    final password = BloomEnv.getOrNull(passKey);
    final useTls = BloomEnv.getBool(useTlsKey, defaultValue: true);
    final timeoutSecs = BloomEnv.getInt(timeoutSecondsKey, defaultValue: 15);
    final maxRetries = BloomEnv.getInt(maxRetriesKey, defaultValue: 2);

    return BloomSmtpConfig(
      host,
      port: port,
      username: username,
      password: password,
      useTls: useTls,
      timeout: Duration(seconds: timeoutSecs),
      maxRetries: maxRetries,
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
  BloomSmtpConfig withIgnoreBadCertificate(
    bool ignore, {
    bool allowInsecureCertificates = false,
  }) =>
      copyWith(
        ignoreBadCertificate: ignore,
        allowInsecureCertificates: allowInsecureCertificates,
      );

  /// Builder alias for [withIgnoreBadCertificate].
  BloomSmtpConfig ignoreBadCertificates(
    bool ignore, {
    bool allowInsecureCertificates = false,
  }) =>
      withIgnoreBadCertificate(
        ignore,
        allowInsecureCertificates: allowInsecureCertificates,
      );

  /// Sets connection and send timeout.
  BloomSmtpConfig withTimeout(Duration timeout) => copyWith(timeout: timeout);

  /// Sets max retries for transient delivery failures.
  BloomSmtpConfig withMaxRetries(int maxRetries) =>
      copyWith(maxRetries: maxRetries);

  /// Creates a copy of this configuration with replacement values.
  BloomSmtpConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useTls,
    bool? ignoreBadCertificate,
    bool? allowInsecureCertificates,
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
    Duration? maxRetryDelay,
  }) {
    return BloomSmtpConfig(
      host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useTls: useTls ?? this.useTls,
      ignoreBadCertificate: ignoreBadCertificate ?? this.ignoreBadCertificate,
      allowInsecureCertificates:
          allowInsecureCertificates ?? this.allowInsecureCertificates,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
    );
  }

  /// Validates the configuration parameters for port range, host validity, credentials,
  /// and TLS production safety.
  ///
  /// Throws [BloomMailException] if parameters are invalid or unsafe.
  void validate({bool? isProduction}) {
    if (host.trim().isEmpty) {
      throw const BloomMailException('SMTP host cannot be empty');
    }
    if (host.contains('\r') || host.contains('\n')) {
      throw const BloomMailException(
          'SMTP host cannot contain newline characters');
    }
    if (port < 1 || port > 65535) {
      throw BloomMailException(
        'SMTP port must be in range 1..65535, received $port',
      );
    }

    final hasUser = username != null && username!.trim().isNotEmpty;
    final hasPass = password != null && password!.trim().isNotEmpty;
    if (hasUser != hasPass) {
      throw const BloomMailException(
        'SMTP username and password must be supplied together',
      );
    }

    // TLS Production Safety Check
    final inProd = isProduction ??
        (BloomEnv.getOrNull('BLOOM_ENV') == 'production' ||
            BloomEnv.getOrNull('ENVIRONMENT') == 'production' ||
            BloomEnv.getOrNull('NODE_ENV') == 'production' ||
            BloomEnv.getOrNull('DART_ENV') == 'production');

    if (ignoreBadCertificate && inProd && !allowInsecureCertificates) {
      throw const BloomMailException(
        'Insecure TLS configuration: ignoreBadCertificate is unsafe and rejected by default '
        'in production mode. Configure allowInsecureCertificates: true to explicitly override.',
      );
    }
  }

  @override
  String toString() {
    return 'BloomSmtpConfig(host: $host, port: $port, useTls: $useTls, hasAuth: ${username != null}, timeout: ${timeout.inSeconds}s, maxRetries: $maxRetries)';
  }
}

/// Real SMTP delivery backend using pure-Dart `package:mailer`.
///
/// Supports plain SMTP, explicit STARTTLS (default on port 587), and implicit
/// SSL/TLS (port 465). Configured via [BloomSmtpConfig].
class BloomSmtpBackend implements BloomMailBackend {
  /// The active SMTP configuration.
  final BloomSmtpConfig config;

  /// Optional transport function seam for unit testing without live SMTP servers.
  @visibleForTesting
  final Future<void> Function(
      mailer.Message message, mailer_smtp.SmtpServer server)? transport;

  /// Creates a new [BloomSmtpBackend] after validating [config].
  BloomSmtpBackend(this.config, {this.transport}) {
    config.validate();
  }

  @override
  Future<void> send(BloomMailMessage message) async {
    // 1. Validate email structure and reject CR/LF header injection
    message.validate();

    final maxAttempts = 1 + config.maxRetries;
    var attempts = 0;
    var currentDelay = config.retryDelay;

    while (true) {
      attempts++;
      try {
        await _sendDirect(message).timeout(config.timeout);
        return;
      } catch (e, st) {
        final isTransient = _isTransientError(e);
        if (!isTransient || attempts >= maxAttempts) {
          if (e is BloomMailException) rethrow;
          throw BloomMailException(
            'Failed to send mail via SMTP (${config.host}:${config.port}) after $attempts attempt(s): $e',
            cause: e,
            stackTrace: st,
          );
        }

        // Wait before retrying with bounded backoff
        await Future<void>.delayed(currentDelay);
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * 2).clamp(
            0,
            config.maxRetryDelay.inMilliseconds,
          ),
        );
      }
    }
  }

  Future<void> _sendDirect(BloomMailMessage message) async {
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

    if (transport != null) {
      await transport!(mailMessage, smtpServer);
    } else {
      await mailer.send(mailMessage, smtpServer);
    }
  }

  /// Classifies whether an error is a transient transport/network issue or deterministic failure.
  static bool _isTransientError(Object error) {
    if (error is BloomMailException) {
      final cause = error.cause;
      if (cause != null) return _isTransientError(cause);
      return false; // Validation or configuration errors are deterministic
    }

    if (error is TimeoutException || error is SocketException) {
      return true;
    }

    final msg = error.toString().toLowerCase();

    // Deterministic authentication failures: do not retry
    if (msg.contains('535') ||
        msg.contains('authentication failed') ||
        msg.contains('invalid credentials') ||
        msg.contains('auth failed')) {
      return false;
    }

    // Deterministic permanent recipient / syntax failures (5xx): do not retry
    if (msg.contains('550') ||
        msg.contains('551') ||
        msg.contains('552') ||
        msg.contains('553') ||
        msg.contains('554') ||
        msg.contains('501') ||
        msg.contains('502') ||
        msg.contains('503')) {
      return false;
    }

    // Temporary / transient SMTP 4xx codes or connection resets: retry
    if (msg.contains('421') ||
        msg.contains('450') ||
        msg.contains('451') ||
        msg.contains('452') ||
        msg.contains('connection closed') ||
        msg.contains('connection reset') ||
        msg.contains('connection refused') ||
        msg.contains('network unreachable') ||
        msg.contains('broken pipe') ||
        msg.contains('timed out') ||
        msg.contains('timeout')) {
      return true;
    }

    // Other IO failures are assumed transient
    return error is IOException;
  }
}

/// Alias for [BloomSmtpConfig].
typedef SmtpConfig = BloomSmtpConfig;

/// Alias for [BloomSmtpBackend].
typedef SmtpBackend = BloomSmtpBackend;
