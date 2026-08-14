import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  setUp(() {
    BloomObservability.reset();
  });

  tearDown(() {
    BloomObservability.reset();
  });

  group('Phase 13: Breadcrumb Ring Buffer & Models', () {
    test('Ring buffer enforces maxCapacity and evicts oldest items', () {
      final buffer = BloomBreadcrumbRingBuffer(maxCapacity: 3);
      expect(buffer.isEmpty, isTrue);

      buffer.add(BloomBreadcrumb(category: 'nav', message: 'Step 1'));
      buffer.add(BloomBreadcrumb(category: 'nav', message: 'Step 2'));
      buffer.add(BloomBreadcrumb(category: 'nav', message: 'Step 3'));

      expect(buffer.length, 3);
      expect(buffer.toList().map((b) => b.message).toList(), ['Step 1', 'Step 2', 'Step 3']);

      // Add 4th item -> Step 1 should be evicted
      buffer.add(BloomBreadcrumb(category: 'ui', message: 'Step 4'));
      expect(buffer.length, 3);
      expect(buffer.toList().map((b) => b.message).toList(), ['Step 2', 'Step 3', 'Step 4']);
    });

    test('BloomBreadcrumb and BloomTelemetryEvent serialize and deserialize to JSON cleanly', () {
      final breadcrumb = BloomBreadcrumb(
        category: 'auth',
        message: 'User logged in',
        level: BloomBreadcrumbLevel.info,
        data: {'userId': 'u_123'},
      );

      final bJson = breadcrumb.toJson();
      final restoredBreadcrumb = BloomBreadcrumb.fromJson(bJson);
      expect(restoredBreadcrumb.category, 'auth');
      expect(restoredBreadcrumb.message, 'User logged in');
      expect(restoredBreadcrumb.data?['userId'], 'u_123');

      final event = BloomTelemetryEvent(
        eventId: 'err_test_1',
        level: BloomErrorLevel.fatal,
        exceptionType: 'StateError',
        message: 'Null check operator failed',
        stackTrace: '#0 main (file:///test.dart:10:5)',
        fingerprint: ['StateError', 'main'],
        context: {'tag': 'checkout'},
        breadcrumbs: [breadcrumb],
        app: {'name': 'shop', 'version': '1.2.0'},
      );

      final eJson = event.toJson();
      final restoredEvent = BloomTelemetryEvent.fromJson(eJson);
      expect(restoredEvent.eventId, 'err_test_1');
      expect(restoredEvent.level, BloomErrorLevel.fatal);
      expect(restoredEvent.exceptionType, 'StateError');
      expect(restoredEvent.fingerprint, ['StateError', 'main']);
      expect(restoredEvent.breadcrumbs.length, 1);
      expect(restoredEvent.breadcrumbs.first.message, 'User logged in');
      expect(restoredEvent.app['name'], 'shop');
    });
  });

  group('Phase 13: Deterministic Crash Fingerprinting', () {
    test('Calculates deterministic fingerprint from user stack frames and exception type', () {
      const mockStack = '''
#0      CartController.checkout (package:bloom_app/src/cart.dart:45:12)
#1      CheckoutButton._onTap (package:bloom_app/src/button.dart:12:3)
#2      _rootRun (dart:async/zone.dart:1399:13)
''';

      final fp = BloomCrashFingerprint.compute(
        exceptionType: 'PaymentException',
        message: 'Insufficient funds',
        stackTrace: mockStack,
      );

      expect(fp.length, 3);
      expect(fp[0], 'PaymentException');
      expect(fp[1], 'CartController.checkout');
      expect(fp[2], 'CheckoutButton._onTap');

      final hash = BloomCrashFingerprint.hashTokens(fp);
      expect(hash.isNotEmpty, isTrue);
      expect(hash.length, 64); // SHA-256 length
    });

    test('Honors custom explicit fingerprint override', () {
      final customFp = BloomCrashFingerprint.compute(
        exceptionType: 'CustomException',
        message: 'Some error',
        customFingerprint: ['custom_group', 'gateway_v2'],
      );

      expect(customFp, ['custom_group', 'gateway_v2']);
    });
  });

  group('Phase 13: Observability Engine, Sampling & beforeSend Filter', () {
    test('Captures exceptions, attaches breadcrumbs, and delivers to transport', () async {
      final memoryTransport = BloomMemoryTelemetryTransport();
      BloomObservability.initialize(BloomObservabilityConfig(
        enabled: true,
        transport: memoryTransport,
        appInfo: {'name': 'bloom_store', 'version': '2.0.0'},
      ));

      Bloom.addBreadcrumb(category: 'nav', message: 'Mounted /cart');
      Bloom.addBreadcrumb(category: 'ui', message: 'Tapped checkout');

      final captured = await Bloom.captureException(
        FormatException('Invalid card number'),
        context: {'cart_total': 120},
      );

      expect(captured, isNotNull);
      expect(memoryTransport.events.length, 1);

      final event = memoryTransport.events.first;
      expect(event.exceptionType, 'FormatException');
      expect(event.message, contains('Invalid card number'));
      expect(event.context['cart_total'], 120);
      expect(event.breadcrumbs.length, 2);
      expect(event.breadcrumbs.map((b) => b.message).toList(), ['Mounted /cart', 'Tapped checkout']);
      expect(event.app['name'], 'bloom_store');
    });

    test('beforeSend filter can modify event or drop it by returning null', () async {
      final memoryTransport = BloomMemoryTelemetryTransport();
      BloomObservability.initialize(BloomObservabilityConfig(
        enabled: true,
        transport: memoryTransport,
        beforeSend: (event) {
          if (event.message.contains('IgnoredException') || event.exceptionType == 'IgnoredException') {
            return null; // Drop event
          }
          // Redact PII in context
          final newContext = Map<String, dynamic>.from(event.context);
          if (newContext.containsKey('password')) {
            newContext['password'] = '[REDACTED]';
          }
          return BloomTelemetryEvent(
            eventId: event.eventId,
            level: event.level,
            exceptionType: event.exceptionType,
            message: event.message,
            stackTrace: event.stackTrace,
            fingerprint: event.fingerprint,
            context: newContext,
            breadcrumbs: event.breadcrumbs,
            app: event.app,
            runtime: event.runtime,
            device: event.device,
          );
        },
      ));

      // 1. Send dropped event
      final dropped = await Bloom.captureException(StateError('IgnoredException'));
      expect(dropped, isNull);
      expect(memoryTransport.events.isEmpty, isTrue);

      // 2. Send event with redacted field
      final captured = await Bloom.captureException(
        Exception('Login failed'),
        context: {'username': 'alice', 'password': 'secret_password_123'},
      );

      expect(captured, isNotNull);
      expect(memoryTransport.events.length, 1);
      expect(memoryTransport.events.first.context['password'], '[REDACTED]');
      expect(memoryTransport.events.first.context['username'], 'alice');
    });

    test('Sample rate of 0.0 drops all captured exceptions', () async {
      final memoryTransport = BloomMemoryTelemetryTransport();
      BloomObservability.initialize(BloomObservabilityConfig(
        enabled: true,
        sampleRate: 0.0,
        transport: memoryTransport,
      ));

      final captured = await Bloom.captureException(Exception('Sampled out'));
      expect(captured, isNull);
      expect(memoryTransport.events.isEmpty, isTrue);
    });
  });

  group('Phase 13: Navigation Observer & HTTP Telemetry Transport', () {
    testWidgets('BloomObservabilityNavigatorObserver records navigation breadcrumbs', (tester) async {
      BloomObservability.initialize(BloomObservabilityConfig(enabled: true));
      final observer = BloomObservabilityNavigatorObserver();

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          navigatorObservers: [observer],
          pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
              PageRouteBuilder<T>(settings: settings, pageBuilder: (ctx, a1, a2) => builder(ctx)),
          onGenerateRoute: (settings) => PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, _, __) => Container(),
          ),
          initialRoute: '/home',
        ),
      );

      final breadcrumbs = BloomObservability.breadcrumbs;
      expect(breadcrumbs.isNotEmpty, isTrue);
      expect(breadcrumbs.any((b) => b.category == 'navigation' && b.message.contains('/home')), isTrue);
    });

    test('BloomHttpTelemetryTransport transmits JSON payload via HTTP client', () async {
      late String capturedPayload;
      late Map<String, String> capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedPayload = request.body;
        capturedHeaders = request.headers;
        return http.Response('{"status": "ok"}', 200);
      });

      final transport = BloomHttpTelemetryTransport(
        endpoint: Uri.parse('https://telemetry.bloom.dev/events'),
        headers: {'x-api-key': 'secret_bloom_key'},
        client: mockClient,
      );

      final event = BloomTelemetryEvent(
        eventId: 'err_http_1',
        exceptionType: 'NetworkException',
        message: 'Gateway Timeout',
      );

      await transport.send(event);

      expect(capturedHeaders['x-api-key'], 'secret_bloom_key');
      expect(capturedHeaders['content-type'], 'application/json');

      final decoded = jsonDecode(capturedPayload) as Map<String, dynamic>;
      expect(decoded['eventId'], 'err_http_1');
      expect(decoded['exceptionType'], 'NetworkException');
      expect(decoded['message'], 'Gateway Timeout');
    });
  });
}
