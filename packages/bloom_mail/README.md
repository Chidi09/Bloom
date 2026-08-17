# bloom_mail

Transactional email sending for Bloom server applications, ported from [`djangors-mail`](https://crates.io/crates/djangors-mail).

Provides a provider-agnostic [`BloomMailMessage`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/message.dart) model and swappable [`BloomMailBackend`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/backend.dart) delivery adapters that integrate directly with `bloom_framework`'s dependency injection container.

---

## Features

- **Provider-Agnostic Message Model**: Full support for `to`, `from`, `subject`, plain-text `body`, optional `htmlBody`, `cc`, and `bcc`.
- **Pluggable Delivery Backends**:
  - [`BloomSmtpBackend`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/smtp_backend.dart): Real SMTP delivery with explicit STARTTLS or implicit SSL/TLS.
  - [`BloomConsoleBackend`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/console_backend.dart): Formatted stdout logging for local development.
  - [`BloomFileBackend`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/file_backend.dart): Writes individual `.eml` files to disk for inspection.
  - [`BloomInMemoryBackend`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/in_memory_backend.dart): Records sent messages in memory for test assertions.
- **Dependency Injection Ready**: Seamlessly register with `BloomContainer` (`globalContainer.provideSingleton<BloomMailBackend>(...)`) so business logic depends solely on the abstract backend interface.
- **Credential Safety**: SMTP credentials (host, username, password) are never logged or exposed in dev backends.
- **Environment Driven**: Built-in support for loading configuration via `BloomEnv`.

---

## Installation

Add `bloom_mail` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_framework:
    path: ../bloom_framework
  bloom_mail:
    path: ../bloom_mail
```

---

## Usage

### 1. Registering the Backend at Boot

In your server bootstrap or service initialization (e.g. `boot.dart` / `app.dart`), configure and register the appropriate backend into the `BloomContainer`:

```dart
import 'package:bloom_framework/bloom_framework.dart';
import 'package:bloom_mail/bloom_mail.dart';

void configureMailBackend() {
  final isProduction = BloomEnv.getOrNull('APP_ENV') == 'production';

  if (isProduction) {
    // Configure real SMTP backend from environment variables
    final smtpConfig = BloomSmtpConfig.fromEnv(
      hostKey: 'SMTP_HOST',
      portKey: 'SMTP_PORT',
      userKey: 'SMTP_USER',
      passKey: 'SMTP_PASSWORD',
      useTlsKey: 'SMTP_USE_TLS',
    );

    globalContainer.provideSingleton<BloomMailBackend>(
      () => BloomSmtpBackend(smtpConfig),
    );
  } else {
    // Local dev: log to stdout without leaking credentials
    globalContainer.provideSingleton<BloomMailBackend>(
      () => const BloomConsoleBackend(),
    );
  }
}
```

### 2. Sending Emails in Services / Handlers

Application code injects the abstract `BloomMailBackend` interface without depending on any concrete delivery implementation:

```dart
import 'package:bloom_framework/bloom_framework.dart';
import 'package:bloom_mail/bloom_mail.dart';

class AuthService {
  final BloomMailBackend _mailBackend;

  AuthService({BloomMailBackend? mailBackend})
      : _mailBackend = mailBackend ?? inject<BloomMailBackend>();

  Future<void> sendPasswordReset(String recipientEmail, String resetToken) async {
    final message = BloomMailMessage(
      to: [recipientEmail],
      from: 'noreply@bloom.dev',
      subject: 'Reset your Bloom password',
      body: 'Use this link to reset your password: https://app.bloom.dev/reset?token=$resetToken',
      htmlBody: '''
        <h1>Password Reset</h1>
        <p>Click <a href="https://app.bloom.dev/reset?token=$resetToken">here</a> to reset your password.</p>
      ''',
    );

    await _mailBackend.send(message);
  }
}
```

---

## Testing with `BloomInMemoryBackend`

In your unit and integration tests, override or inject `BloomInMemoryBackend` to verify outgoing emails without sending network requests:

```dart
import 'package:bloom_framework/bloom_framework.dart';
import 'package:bloom_mail/bloom_mail.dart';
import 'package:test/test.dart';

void main() {
  late BloomInMemoryBackend mailBackend;
  late AuthService authService;

  setUp(() {
    mailBackend = BloomInMemoryBackend();
    
    // Override DI container or pass explicitly to service
    globalContainer.override<BloomMailBackend>(mailBackend);
    authService = AuthService();
  });

  tearDown(() {
    globalContainer.removeOverride<BloomMailBackend>();
  });

  test('sends password reset email with valid link', () async {
    await authService.sendPasswordReset('alice@example.com', 'xyz-token-123');

    // Assert on captured messages
    expect(mailBackend.sentMessages, hasLength(1));

    final sent = mailBackend.sentMessages.first;
    expect(sent.to, equals(['alice@example.com']));
    expect(sent.from, equals('noreply@bloom.dev'));
    expect(sent.subject, equals('Reset your Bloom password'));
    expect(sent.body, contains('https://app.bloom.dev/reset?token=xyz-token-123'));
    expect(sent.htmlBody, contains('href="https://app.bloom.dev/reset?token=xyz-token-123"'));
  });
}
```

---

## Fluent `BloomSmtpConfig` Builder

You can also construct SMTP configuration programmatically using fluent chaining:

```dart
final config = BloomSmtpConfig('smtp.example.com')
    .withPort(587)
    .credentials('smtp_user', 'secret_password')
    .withUseTls(true);

final backend = BloomSmtpBackend(config);
```

---

## Dev Backends

### Console Backend
Prints formatted email contents to stdout for local rapid prototyping:
```dart
final backend = BloomConsoleBackend();
```

### File Backend
Writes outgoing emails as timestamped `.eml` files into a directory for offline inspection:
```dart
final backend = BloomFileBackend('.bloom/emails');
```
