# Changelog

## 0.3.2 - 2026-08-31

### Security & Reliability Hardening
* **Header Injection & Address Validation**: Added comprehensive validation in `BloomMailMessage.validate()`. Rejects CR/LF (`\r`, `\n`) newline characters in subject, sender, and recipient addresses (`to`, `cc`, `bcc`) to prevent SMTP header injection. Validates structural correctness across standard and internationalized domain names (IDN).
* **Port Range Validation**: Enforced strict port bounds (1..65535) in `BloomSmtpConfig.validate()`.
* **TLS Production Safety**: `ignoreBadCertificate` is now blocked by default in production mode, requiring explicit `allowInsecureCertificates: true` to prevent accidental TLS downgrade attacks.
* **Configurable Timeouts & Bounded Retries**: Added configurable timeout (`timeout`) and bounded exponential backoff retries (`maxRetries`, `retryDelay`, `maxRetryDelay`) in `BloomSmtpBackend` for transient network failures (socket drops, timeouts, temporary 4xx responses) while failing fast on deterministic validation and authentication failures (535, 55x). Added test seams for reliable unit verification.

## 0.3.1 - 2026-08-25

### Fixed
* Bumped `bloom_server` dependency constraint from `^0.1.0` to `^0.2.0` — the stale constraint was incompatible with any sibling package (`bloom_cache`, `bloom_i18n`) requiring `bloom_server ^0.2.0`, breaking `pub get` in any app combining them.

## 0.3.0 - 2026-08-25

### Added
* **Email templating.** New `BloomMailTemplate` — a Django-inspired mini template engine (`{{ variable }}` interpolation with dot-path lookups and filters, `{% if %}/{% elif %}/{% else %}` with comparison/logical operators, `{% for %}` loops with `forloop.index0/first/last/length` and `{% empty %}`, comments, HTML auto-escaping with `safe`/`raw` opt-outs) supporting a companion plain-text template alongside the HTML one. `BloomMailMessage.fromTemplate`/`.singleFromTemplate` render a template + context directly into a ready-to-send message. Closes the previous gap where HTML emails had to be hand-built as raw strings.

## 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

## 0.1.0

- Initial release of `bloom_mail`.
- Provider-agnostic transactional email sending ported from `djangors-mail`.
- `BloomMailMessage` model with support for recipients, sender, subject, plain-text body, optional HTML body, CC, and BCC.
- Abstract `BloomMailBackend` interface designed for dependency injection via `BloomContainer`.
- `BloomSmtpBackend` and `BloomSmtpConfig` builder for real SMTP delivery using `package:mailer` with STARTTLS / SSL/TLS encryption support and `BloomEnv` integration.
- `BloomConsoleBackend` for development logging without leaking credentials.
- `BloomFileBackend` for local `.eml` delivery debugging.
- `BloomInMemoryBackend` with `sentMessages` inspection for unit and integration testing.
