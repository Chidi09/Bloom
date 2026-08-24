/// Error observability, crash reporting SDK, breadcrumbs, and telemetry subsystem for Bloom.
///
/// Exports breadcrumb logging, hardware/software device fingerprinting, error event models,
/// navigation routing observers, and HTTP telemetry transports.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_observability.dart';
///
/// void main() {
///   BloomObservability.init(
///     options: BloomObservabilityOptions(
///       endpoint: 'https://telemetry.example.com/events',
///     ),
///   );
///   BloomObservability.leaveBreadcrumb('App started');
/// }
/// ```
library bloom_observability;

export 'src/observability/breadcrumbs.dart';
export 'src/observability/fingerprint.dart';
export 'src/observability/models.dart';
export 'src/observability/navigation_observer.dart';
export 'src/observability/observability.dart';
export 'src/observability/transport.dart';
