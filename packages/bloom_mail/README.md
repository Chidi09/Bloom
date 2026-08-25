# bloom_mail

Transactional email sending for Bloom server applications, ported from [`djangors-mail`](https://crates.io/crates/djangors-mail).

Provides a provider-agnostic [`BloomMailMessage`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/message.dart) model, Django-inspired [`BloomMailTemplate`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/template.dart) rendering engine, and swappable [`BloomMailBackend`](file:///root/dev/Bloom/packages/bloom_mail/lib/src/backend.dart) delivery adapters that integrate directly with `bloom_framework`'s dependency injection container.

---

## Features

- **Provider-Agnostic Message Model**: Full support for `to`, `from`, `subject`, plain-text `body`, optional `htmlBody`, `cc`, and `bcc`.
- **Django-Inspired Templating Engine**:
  - Variable interpolation (`{{ user.name }}`) with nested dot navigation.
  - Automatic XSS prevention & HTML-escaping by default, with `| safe` / `| raw` filters.
  - Conditionals (`{% if %}`, `{% elif %}`, `{% else %}`, `{% endif %}`) and loops (`{% for item in items %}`, `{% empty %}`, `{% endfor %}`) with loop metadata (`forloop.index`, `forloop.first`, `forloop.last`).
  - Seamless companion plain-text template loading (`welcome_email.html` + `welcome_email.txt`).
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

## Templating

`bloom_mail` includes a lightweight, safe-by-default Django-style template engine for transactional emails.

### Template Loading & Rendering

Templates can be loaded from strings, files, or filesystem paths:

```dart
import 'package:bloom_mail/bloom_mail.dart';

// Load from path (automatically discovers companion .txt if present)
final template = BloomMailTemplate.fromPath('templates/welcome_email.html');

// Or create in memory with HTML and companion plain-text templates
final template = BloomMailTemplate.fromString(
  '''
  <h1>Welcome, {{ user.name }}!</h1>
  <p>Your account is ready on {{ app_name }}.</p>
  {% if is_admin %}
  <p><strong>Admin role active.</strong></p>
  {% endif %}
  <p><a href="{{ action_url|safe }}">Open Dashboard</a></p>
  ''',
  textSource: '''
  Welcome, {{ user.name }}!
  Your account is ready on {{ app_name }}.
  {% if is_admin %}
  Admin role active.
  {% endif %}
  Open Dashboard: {{ action_url }}
  ''',
);
```

### Creating Templated Messages

Use `BloomMailMessage.fromTemplate` or `BloomTemplatedMessage.create` to render templates directly into an outgoing message:

```dart
final message = BloomMailMessage.fromTemplate(
  to: ['alice@example.com'],
  from: 'noreply@bloom.dev',
  subject: 'Welcome to Bloom',
  htmlTemplate: template,
  context: {
    'user': {'name': 'Alice'},
    'app_name': 'Bloom Studio',
    'is_admin': true,
    'action_url': 'https://app.bloom.dev/dashboard',
  },
);

// Send message via injected backend
await mailBackend.send(message);
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
  final BloomMailTemplate _passwordResetTemplate;

  AuthService({BloomMailBackend? mailBackend})
      : _mailBackend = mailBackend ?? inject<BloomMailBackend>(),
        _passwordResetTemplate = BloomMailTemplate.fromPath('templates/password_reset.html');

  Future<void> sendPasswordReset(String recipientEmail, String userName, String resetToken) async {
    final message = BloomMailMessage.singleFromTemplate(
      to: recipientEmail,
      from: 'noreply@bloom.dev',
      subject: 'Reset your Bloom password',
      htmlTemplate: _passwordResetTemplate,
      context: {
        'user': {'name': userName},
        'app_name': 'Bloom',
        'expires_in': '30 minutes',
        'reset_url': 'https://app.bloom.dev/reset?token=$resetToken',
      },
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
    await authService.sendPasswordReset('alice@example.com', 'Alice', 'xyz-token-123');

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
