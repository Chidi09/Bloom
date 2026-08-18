// lib/src/observability/models.dart
import 'dart:convert';

/// Severity level for breadcrumb events.
enum BloomBreadcrumbLevel {
  /// Debug-level detail.
  debug,
  /// Informational breadcrumb event.
  info,
  /// Warning event that may precede an error.
  warning,
  /// Error breadcrumb event.
  error;

  /// Serializes level to JSON string.
  String toJson() => name;

  /// Parses level from string value.
  static BloomBreadcrumbLevel fromJson(String value) {
    return BloomBreadcrumbLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BloomBreadcrumbLevel.info,
    );
  }
}

/// Severity level for telemetry / crash events.
enum BloomErrorLevel {
  /// Fatal error causing app crash or unhandled termination.
  fatal,
  /// Standard error level for caught or uncaught exceptions.
  error,
  /// Warning event captured for telemetry.
  warning,
  /// Informational telemetry message.
  info;

  /// Serializes error level to JSON string.
  String toJson() => name;

  /// Parses error level from string value.
  static BloomErrorLevel fromJson(String value) {
    return BloomErrorLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BloomErrorLevel.error,
    );
  }
}

/// A structured breadcrumb recording a user action, network call, or state mutation.
class BloomBreadcrumb {
  /// Category label (e.g. `'ui'`, `'navigation'`, `'http'`, `'state'`).
  final String category;

  /// Human-readable message or description.
  final String message;

  /// Severity level of the breadcrumb.
  final BloomBreadcrumbLevel level;

  /// UTC timestamp when the breadcrumb was recorded.
  final DateTime timestamp;

  /// Optional contextual data key-value map.
  final Map<String, dynamic>? data;

  /// Creates a [BloomBreadcrumb] record.
  BloomBreadcrumb({
    required this.category,
    required this.message,
    this.level = BloomBreadcrumbLevel.info,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  /// Serializes breadcrumb to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'message': message,
      'level': level.toJson(),
      'timestamp': timestamp.toIso8601String(),
      if (data != null) 'data': data,
    };
  }

  /// Constructs a [BloomBreadcrumb] from a JSON map.
  factory BloomBreadcrumb.fromJson(Map<String, dynamic> json) {
    return BloomBreadcrumb(
      category: json['category'] as String? ?? 'general',
      message: json['message'] as String? ?? '',
      level: json['level'] != null
          ? BloomBreadcrumbLevel.fromJson(json['level'].toString())
          : BloomBreadcrumbLevel.info,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
    );
  }

  @override
  String toString() => '[${timestamp.toIso8601String()}] [$category] (${level.name}) $message';
}

/// A complete structured crash / telemetry event payload.
class BloomTelemetryEvent {
  /// Unique event ID.
  final String eventId;

  /// UTC timestamp when the event occurred.
  final DateTime timestamp;

  /// Severity level.
  final BloomErrorLevel level;

  /// Exception class name or error type.
  final String exceptionType;

  /// Exception or error message.
  final String message;

  /// Formatted stack trace string.
  final String? stackTrace;

  /// Grouping fingerprint tokens.
  final List<String> fingerprint;

  /// SHA-256 hash computed from [fingerprint].
  final String? fingerprintHash;

  /// Additional custom context parameters.
  final Map<String, dynamic> context;

  /// Chronological list of breadcrumbs leading up to the error.
  final List<BloomBreadcrumb> breadcrumbs;

  /// Application metadata map.
  final Map<String, dynamic> app;

  /// Bloom / Flutter runtime metadata map.
  final Map<String, dynamic> runtime;

  /// Device / OS metadata map.
  final Map<String, dynamic> device;

  /// Creates a [BloomTelemetryEvent] payload.
  BloomTelemetryEvent({
    required this.eventId,
    DateTime? timestamp,
    this.level = BloomErrorLevel.error,
    required this.exceptionType,
    required this.message,
    this.stackTrace,
    this.fingerprint = const [],
    this.fingerprintHash,
    this.context = const {},
    this.breadcrumbs = const [],
    this.app = const {},
    this.runtime = const {},
    this.device = const {},
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'timestamp': timestamp.toIso8601String(),
      'level': level.toJson(),
      'exceptionType': exceptionType,
      'message': message,
      if (stackTrace != null) 'stackTrace': stackTrace,
      'fingerprint': fingerprint,
      if (fingerprintHash != null) 'fingerprintHash': fingerprintHash,
      'context': context,
      'breadcrumbs': breadcrumbs.map((b) => b.toJson()).toList(),
      'app': app,
      'runtime': runtime,
      'device': device,
    };
  }

  factory BloomTelemetryEvent.fromJson(Map<String, dynamic> json) {
    return BloomTelemetryEvent(
      eventId: json['eventId'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      level: json['level'] != null
          ? BloomErrorLevel.fromJson(json['level'].toString())
          : BloomErrorLevel.error,
      exceptionType: json['exceptionType'] as String? ?? 'UnknownException',
      message: json['message'] as String? ?? '',
      stackTrace: json['stackTrace'] as String?,
      fingerprint: (json['fingerprint'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fingerprintHash: json['fingerprintHash'] as String?,
      context: json['context'] is Map ? Map<String, dynamic>.from(json['context'] as Map) : {},
      breadcrumbs: (json['breadcrumbs'] as List<dynamic>?)
              ?.map((e) => BloomBreadcrumb.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      app: json['app'] is Map ? Map<String, dynamic>.from(json['app'] as Map) : {},
      runtime: json['runtime'] is Map ? Map<String, dynamic>.from(json['runtime'] as Map) : {},
      device: json['device'] is Map ? Map<String, dynamic>.from(json['device'] as Map) : {},
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
