# 17. Structured Logging Subsystem (`BloomLogger`)

Bloom provides a lightweight structured logger with contextual metadata tagging, ANSI terminal color formatting, custom output writers, and adjustable severity levels.

---

## 🚦 Severity Levels

`BloomLogLevel` defines standard log thresholds:

```dart
enum BloomLogLevel {
  debug, // Verbose diagnostic output
  info,  // Standard informational events
  warn,  // Non-fatal warnings and deprecations
  error, // Failures and exceptions
  none,  // Suppress all log output
}
```

---

## 🪵 Using the Global Logger

Import `bloom.dart` to access the top-level `logger` instance:

```dart
import 'package:bloom_framework/bloom.dart';

logger.debug('Cache hit for key "user_profile"');
logger.info('Connected to Supabase WebSocket endpoint.');
logger.warn('Token expires in under 5 minutes.');
logger.error('Failed to process payment', error: exception, stackTrace: stack);
```

---

## 🏷️ Contextual Child Loggers

Create scoped loggers tagged with a specific subsystem or domain name:

```dart
final authLogger = logger.child('AUTH');
final dbLogger = logger.child('DATABASE');

authLogger.info('User 42 authenticated successfully.');
// Prints: 11:30:00 [INFO] [BLOOM:AUTH] User 42 authenticated successfully.
```

---

## 🎨 ANSI Terminal Formatting

The Bloom logger formats log messages with distinct ANSI colors:
* **`[DEBUG]`** ➔ Cyan (`\x1B[36m`)
* **`[INFO]`** ➔ Green (`\x1B[32m`)
* **`[WARN]`** ➔ Yellow (`\x1B[33m`)
* **`[ERROR]`** ➔ Red (`\x1B[31m`)

---

## 🔌 Custom Log Writers (e.g. Sentry / Datadog)

Redirect log entries to remote monitoring services by attaching a custom log writer:

```dart
BloomLogger.addWriter((entry) {
  if (entry.level == BloomLogLevel.error) {
    // Forward to remote crash reporting
    Sentry.captureException(entry.error, stackTrace: entry.stackTrace);
  }
});
```
