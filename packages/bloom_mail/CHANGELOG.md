# Changelog

## 0.1.0

- Initial release of `bloom_mail`.
- Provider-agnostic transactional email sending ported from `djangors-mail`.
- `BloomMailMessage` model with support for recipients, sender, subject, plain-text body, optional HTML body, CC, and BCC.
- Abstract `BloomMailBackend` interface designed for dependency injection via `BloomContainer`.
- `BloomSmtpBackend` and `BloomSmtpConfig` builder for real SMTP delivery using `package:mailer` with STARTTLS / SSL/TLS encryption support and `BloomEnv` integration.
- `BloomConsoleBackend` for development logging without leaking credentials.
- `BloomFileBackend` for local `.eml` delivery debugging.
- `BloomInMemoryBackend` with `sentMessages` inspection for unit and integration testing.
