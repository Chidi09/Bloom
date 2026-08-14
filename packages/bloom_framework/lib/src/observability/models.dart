// lib/src/observability/models.dart
import 'dart:convert';

/// Severity level for breadcrumb events.
enum BloomBreadcrumbLevel {
  debug,
  info,
  warning,
  error;

  String toJson() => name;

  static BloomBreadcrumbLevel fromJson(String value) {
    return BloomBreadcrumbLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BloomBreadcrumbLevel.info,
    );
  }
}

/// Severity level for telemetry / crash events.
enum BloomErrorLevel {
  fatal,
  error,
  warning,
  info;

  String toJson() => name;

  static BloomErrorLevel fromJson(String value) {
    return BloomErrorLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BloomErrorLevel.error,
    );
  }
}

/// A structured breadcrumb recording a user action, network call, or state mutation.
class BloomBreadcrumb {
  final String category;
  final String message;
  final BloomBreadcrumbLevel level;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  BloomBreadcrumb({
    required this.category,
    required this.message,
    this.level = BloomBreadcrumbLevel.info,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'message': message,
      'level': level.toJson(),
      'timestamp': timestamp.toIso8601String(),
      if (data != null) 'data': data,
    };
  }

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
  final String eventId;
  final DateTime timestamp;
  final BloomErrorLevel level;
  final String exceptionType;
  final String message;
  final String? stackTrace;
  final List<String> fingerprint;
  final Map<String, dynamic> context;
  final List<BloomBreadcrumb> breadcrumbs;
  final Map<String, dynamic> app;
  final Map<String, dynamic> runtime;
  final Map<String, dynamic> device;

  BloomTelemetryEvent({
    required this.eventId,
    DateTime? timestamp,
    this.level = BloomErrorLevel.error,
    required this.exceptionType,
    required this.message,
    this.stackTrace,
    this.fingerprint = const [],
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
