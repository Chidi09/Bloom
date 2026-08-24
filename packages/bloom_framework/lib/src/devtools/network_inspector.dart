/// Network request inspection, trace recording, and replay engine for Bloom DevTools.
library;

import 'dart:async';
import 'dart:collection';
import '../data/http_client.dart';

/// Recorded network request / response trace event.
///
/// Contains headers, request/response bodies, HTTP method, status codes, and roundtrip latency.
///
/// Example:
/// ```dart
/// final trace = BloomNetworkTrace(
///   id: 'req_123',
///   method: 'GET',
///   url: 'https://api.example.com/items',
///   timestamp: DateTime.now(),
///   statusCode: 200,
/// );
/// ```
class BloomNetworkTrace {
  /// Unique request trace ID.
  final String id;

  /// HTTP method string (e.g. `'GET'`, `'POST'`).
  final String method;

  /// Target request URL.
  final String url;

  /// Request headers map.
  final Map<String, String> headers;

  /// Request body payload.
  final dynamic body;

  /// Timestamp when the request was dispatched.
  final DateTime timestamp;

  /// HTTP status code returned.
  final int? statusCode;

  /// Response body data.
  final dynamic responseBody;

  /// Network round-trip duration.
  final Duration? latency;

  /// Error message if the request failed.
  final String? error;

  /// Whether this request was executed as a replay.
  final bool isReplay;

  /// Original trace ID if this trace is a replay.
  final String? originalTraceId;

  /// Creates a [BloomNetworkTrace] record.
  BloomNetworkTrace({
    required this.id,
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    required this.timestamp,
    this.statusCode,
    this.responseBody,
    this.latency,
    this.error,
    this.isReplay = false,
    this.originalTraceId,
  });

  /// Whether the response status code indicates success (2xx).
  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// Serializes trace event to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'statusCode': statusCode,
        'responseBody': responseBody,
        'latencyMs': latency?.inMilliseconds,
        'error': error,
        'isReplay': isReplay,
        if (originalTraceId != null) 'originalTraceId': originalTraceId,
      };
}

/// Central network inspection and request replay engine for Bloom DevTools.
///
/// Records network traces in a bounded ring buffer (up to 200 traces) and supports replaying
/// requests with custom overrides.
///
/// Example:
/// ```dart
/// final traces = BloomNetworkInspector.traces;
/// final result = await BloomNetworkInspector.replayRequest(traces.first.id);
/// ```
class BloomNetworkInspector {
  static final List<BloomNetworkTrace> _traces = [];

  /// Chronological list of recorded network traces.
  static List<BloomNetworkTrace> get traces => UnmodifiableListView(_traces);

  /// Records a new network trace into the inspector buffer.
  static void recordTrace(BloomNetworkTrace trace) {
    _traces.add(trace);
    // Keep max 200 traces
    if (_traces.length > 200) {
      _traces.removeAt(0);
    }
  }

  /// Replays a captured request with optional parameter overrides, re-executing it and recording a new trace.
  static Future<dynamic> replayRequest(
    String traceId, {
    Map<String, String>? modifiedHeaders,
    dynamic modifiedBody,
    String? modifiedUrl,
    BloomHttpClient? client,
  }) async {
    final original = _traces.firstWhere(
      (t) => t.id == traceId,
      orElse: () => throw StateError('BloomNetworkInspector: Trace with ID "$traceId" not found.'),
    );

    final httpClient = client ?? BloomHttpClient();
    final targetUrl = modifiedUrl ?? original.url;
    final targetHeaders = {
      ...original.headers,
      if (modifiedHeaders != null) ...modifiedHeaders,
    };
    final targetBody = modifiedBody ?? original.body;

    final stopwatch = Stopwatch()..start();

    try {
      dynamic result;
      switch (original.method.toUpperCase()) {
        case 'GET':
          result = await httpClient.get<dynamic>(targetUrl, headers: targetHeaders);
          break;
        case 'POST':
          result = await httpClient.post<dynamic>(targetUrl, body: targetBody, headers: targetHeaders);
          break;
        case 'PUT':
          result = await httpClient.put<dynamic>(targetUrl, body: targetBody, headers: targetHeaders);
          break;
        case 'PATCH':
          result = await httpClient.patch<dynamic>(targetUrl, body: targetBody, headers: targetHeaders);
          break;
        case 'DELETE':
          result = await httpClient.delete<dynamic>(targetUrl, body: targetBody, headers: targetHeaders);
          break;
        default:
          result = await httpClient.get<dynamic>(targetUrl, headers: targetHeaders);
      }
      stopwatch.stop();

      // Annotate the last recorded trace from BloomHttpClient
      if (_traces.isNotEmpty) {
        final lastIdx = _traces.length - 1;
        final lastTrace = _traces[lastIdx];
        _traces[lastIdx] = BloomNetworkTrace(
          id: lastTrace.id,
          method: lastTrace.method,
          url: lastTrace.url,
          headers: lastTrace.headers,
          body: lastTrace.body,
          timestamp: lastTrace.timestamp,
          statusCode: lastTrace.statusCode,
          responseBody: lastTrace.responseBody,
          latency: lastTrace.latency,
          error: lastTrace.error,
          isReplay: true,
          originalTraceId: traceId,
        );
      }
      return result;
    } catch (e) {
      stopwatch.stop();
      if (_traces.isNotEmpty) {
        final lastIdx = _traces.length - 1;
        final lastTrace = _traces[lastIdx];
        _traces[lastIdx] = BloomNetworkTrace(
          id: lastTrace.id,
          method: lastTrace.method,
          url: lastTrace.url,
          headers: lastTrace.headers,
          body: lastTrace.body,
          timestamp: lastTrace.timestamp,
          statusCode: lastTrace.statusCode,
          responseBody: lastTrace.responseBody,
          latency: lastTrace.latency,
          error: lastTrace.error,
          isReplay: true,
          originalTraceId: traceId,
        );
      }
      rethrow;
    }
  }

  /// Clears all recorded traces.
  static void clear() {
    _traces.clear();
  }
}
