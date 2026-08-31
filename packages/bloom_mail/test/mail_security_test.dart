import 'dart:async';
import 'dart:io';
import 'package:bloom_mail/bloom_mail.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:test/test.dart';

void main() {
  group('BloomMailMessage validation & header injection prevention', () {
    test('valid standard and international email addresses pass validation',
        () {
      final msg = BloomMailMessage(
        to: [
          'user@example.com',
          'admin+filter@sub.domain.co.uk',
          'münchen.user@münchen.de',
          'café@café.fr',
          'Alice Smith <alice@example.org>',
        ],
        from: 'Support Team <support@bloom.dev>',
        subject: 'Welcome to Bloom - Multi-language support',
        body: 'Hello world!',
        cc: ['cc.user@domain.com'],
        bcc: ['bcc.audit@domain.com'],
      );

      expect(() => msg.validate(), returnsNormally);
    });

    test('rejects empty "to" recipient list', () {
      final msg = BloomMailMessage(
        to: [],
        from: 'sender@bloom.dev',
        subject: 'No recipients',
        body: 'Text',
      );
      expect(() => msg.validate(), throwsA(isA<BloomMailException>()));
    });

    test('rejects CR/LF newline header injection in subject', () {
      final crMsg = BloomMailMessage(
        to: ['user@example.com'],
        from: 'sender@bloom.dev',
        subject: 'Subject with\rBcc: victim@example.com',
        body: 'Text',
      );
      expect(() => crMsg.validate(), throwsA(isA<BloomMailException>()));

      final lfMsg = BloomMailMessage(
        to: ['user@example.com'],
        from: 'sender@bloom.dev',
        subject: 'Subject with\nBcc: victim@example.com',
        body: 'Text',
      );
      expect(() => lfMsg.validate(), throwsA(isA<BloomMailException>()));
    });

    test('rejects CR/LF newline header injection in sender or recipients', () {
      final badFrom = BloomMailMessage(
        to: ['user@example.com'],
        from: 'sender@bloom.dev\nBcc: spy@attacker.com',
        subject: 'Clean Subject',
        body: 'Text',
      );
      expect(() => badFrom.validate(), throwsA(isA<BloomMailException>()));

      final badTo = BloomMailMessage(
        to: ['user@example.com\r\nTo: hijacked@attacker.com'],
        from: 'sender@bloom.dev',
        subject: 'Clean Subject',
        body: 'Text',
      );
      expect(() => badTo.validate(), throwsA(isA<BloomMailException>()));

      final badDisplayName = BloomMailMessage(
        to: ['Attacker\nName <valid@example.com>'],
        from: 'sender@bloom.dev',
        subject: 'Clean Subject',
        body: 'Text',
      );
      expect(
          () => badDisplayName.validate(), throwsA(isA<BloomMailException>()));
    });

    test(
        'rejects structurally invalid email addresses without breaking international forms',
        () {
      final invalidEmails = [
        'missing-at-sign.com',
        '@missing-local.com',
        'missing-domain@',
        'user@domain..com',
        'user@-invalid-label.com',
        'user@invalid-label-.com',
        '',
      ];

      for (final badEmail in invalidEmails) {
        final msg = BloomMailMessage(
          to: [badEmail],
          from: 'sender@bloom.dev',
          subject: 'Test',
          body: 'Test',
        );
        expect(
          () => msg.validate(),
          throwsA(isA<BloomMailException>()),
          reason: 'Expected "$badEmail" to be rejected as invalid',
        );
      }
    });
  });

  group('BloomSmtpConfig security & TLS production safety', () {
    test('validates port range 1..65535', () {
      expect(
        () => BloomSmtpConfig('smtp.example.com', port: 587).validate(),
        returnsNormally,
      );
      expect(
        () => BloomSmtpConfig('smtp.example.com', port: 0).validate(),
        throwsA(isA<BloomMailException>()),
      );
      expect(
        () => BloomSmtpConfig('smtp.example.com', port: 65536).validate(),
        throwsA(isA<BloomMailException>()),
      );
      expect(
        () => BloomSmtpConfig('smtp.example.com', port: -1).validate(),
        throwsA(isA<BloomMailException>()),
      );
    });

    test('rejects empty or newline host', () {
      expect(
        () => const BloomSmtpConfig('').validate(),
        throwsA(isA<BloomMailException>()),
      );
      expect(
        () => const BloomSmtpConfig('smtp.example.com\n').validate(),
        throwsA(isA<BloomMailException>()),
      );
    });

    test(
        'rejects ignoreBadCertificate in production mode without explicit allowInsecureCertificates',
        () {
      const unsafeConfig = BloomSmtpConfig(
        'smtp.example.com',
        ignoreBadCertificate: true,
      );

      // In development / test (non-production), it passes
      expect(() => unsafeConfig.validate(isProduction: false), returnsNormally);

      // In production mode without allowInsecureCertificates, it throws
      expect(
        () => unsafeConfig.validate(isProduction: true),
        throwsA(isA<BloomMailException>().having(
          (e) => e.message,
          'message',
          contains('Insecure TLS configuration'),
        )),
      );

      // With explicit opt-in in production, it is permitted
      const explicitOptIn = BloomSmtpConfig(
        'smtp.example.com',
        ignoreBadCertificate: true,
        allowInsecureCertificates: true,
      );
      expect(() => explicitOptIn.validate(isProduction: true), returnsNormally);
    });
  });

  group('BloomSmtpBackend retry policy & deterministic failure handling', () {
    test('retries transient transport failures up to maxRetries and succeeds',
        () async {
      var callCount = 0;
      final config = BloomSmtpConfig(
        'smtp.example.com',
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 10),
      );

      final backend = BloomSmtpBackend(
        config,
        transport: (message, server) async {
          callCount++;
          if (callCount < 3) {
            throw const SocketException(
                'Connection refused / temporary network drop');
          }
          // Third attempt succeeds
        },
      );

      final msg = BloomMailMessage.single(
        to: 'user@example.com',
        from: 'noreply@bloom.dev',
        subject: 'Test',
        body: 'Body',
      );

      await backend.send(msg);
      expect(callCount, 3);
    });

    test('retries transient timeout up to maxRetries then throws', () async {
      var callCount = 0;
      final config = BloomSmtpConfig(
        'smtp.example.com',
        timeout: const Duration(milliseconds: 50),
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 10),
      );

      final backend = BloomSmtpBackend(
        config,
        transport: (message, server) async {
          callCount++;
          await Future.delayed(
              const Duration(milliseconds: 100)); // Will trigger timeout
        },
      );

      final msg = BloomMailMessage.single(
        to: 'user@example.com',
        from: 'noreply@bloom.dev',
        subject: 'Timeout Test',
        body: 'Body',
      );

      await expectLater(
        () => backend.send(msg),
        throwsA(isA<BloomMailException>().having(
          (e) => e.message,
          'message',
          contains('after 3 attempt(s)'),
        )),
      );
      expect(callCount, 3);
    });

    test('never retries deterministic authentication failures (SMTP 535)',
        () async {
      var callCount = 0;
      final config = BloomSmtpConfig(
        'smtp.example.com',
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 10),
      );

      final backend = BloomSmtpBackend(
        config,
        transport: (message, server) async {
          callCount++;
          throw mailer.SmtpClientCommunicationException(
            '535 5.7.8 Authentication failed: invalid credentials',
          );
        },
      );

      final msg = BloomMailMessage.single(
        to: 'user@example.com',
        from: 'noreply@bloom.dev',
        subject: 'Auth Fail Test',
        body: 'Body',
      );

      await expectLater(
        () => backend.send(msg),
        throwsA(isA<BloomMailException>()),
      );
      // Must fail immediately on attempt 1 without retry
      expect(callCount, 1);
    });

    test('never retries deterministic validation errors', () async {
      var callCount = 0;
      final config = BloomSmtpConfig(
        'smtp.example.com',
        maxRetries: 3,
      );

      final backend = BloomSmtpBackend(
        config,
        transport: (message, server) async {
          callCount++;
        },
      );

      final msg = BloomMailMessage.single(
        to: 'invalid-address-without-at',
        from: 'noreply@bloom.dev',
        subject: 'Invalid Msg',
        body: 'Body',
      );

      await expectLater(
        () => backend.send(msg),
        throwsA(isA<BloomMailException>()),
      );
      expect(callCount, 0); // Validation blocked before transport
    });
  });
}
