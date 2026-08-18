// lib/src/observability/transport.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Exception thrown when telemetry transmission over HTTP fails.
class BloomHttpException implements Exception {
  /// Description of the HTTP exception.
  final String message;

  /// HTTP status code if returned by server.
  final int? statusCode;

  /// Target endpoint URI.
  final Uri? uri;

  /// Creates a [BloomHttpException].
  BloomHttpException(this.message, {this.statusCode, this.uri});

  @override
  String toString() => 'BloomHttpException: $message';
}

/// Transport contract for dispatching telemetry and crash events.
abstract class BloomTelemetryTransport {
  const BloomTelemetryTransport();

  /// Transmits a single telemetry event to the target collector.
  Future<void> send(BloomTelemetryEvent event);

  /// Closes the transport and flushes any pending buffer.
  Future<void> close() async {}
}

/// In-memory transport storing telemetry events in a list (ideal for testing and debugging).
class BloomMemoryTelemetryTransport implements BloomTelemetryTransport {
  /// In-memory list of transmitted telemetry events.
  final List<BloomTelemetryEvent> events = [];

  /// Creates a [BloomMemoryTelemetryTransport].
  BloomMemoryTelemetryTransport();

  @override
  Future<void> send(BloomTelemetryEvent event) async {
    events.add(event);
  }

  /// Clears stored events.
  void clear() {
    events.clear();
  }

  @override
  Future<void> close() async {
    clear();
  }
}

/// Production HTTP transport that posts JSON telemetry payloads to a collector endpoint.
class BloomHttpTelemetryTransport implements BloomTelemetryTransport {
  /// Remote collector endpoint URI.
  final Uri endpoint;

  /// Custom HTTP headers attached to transmission POST requests.
  final Map<String, String> headers;
  final http.Client _client;

  /// Network timeout for sending telemetry packets.
  final Duration timeout;

  /// Optional error callback invoked when transmission fails.
  final void Function(BloomTelemetryEvent event, Object error, StackTrace stackTrace)? onError;

  /// Creates a [BloomHttpTelemetryTransport].
  BloomHttpTelemetryTransport({
    required this.endpoint,
    Map<String, String>? headers,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    this.onError,
  })  : headers = headers ?? const {},
        _client = client ?? http.Client();

  @override
  Future<void> send(BloomTelemetryEvent event) async {
    try {
      final payload = jsonEncode(event.toJson());
      final requestHeaders = {
        'content-type': 'application/json',
        'user-agent': 'Bloom-Observability/1.0',
        ...headers,
      };

      final response = await _client
          .post(
            endpoint,
            headers: requestHeaders,
            body: payload,
          )
          .timeout(timeout);

      if (response.statusCode >= 400) {
        throw BloomHttpException(
          'Telemetry endpoint rejected event with status ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
          uri: endpoint,
        );
      }
    } catch (e, stack) {
      if (onError != null) {
        onError!(event, e, stack);
      }
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}
