/// Configuration and environment variable management for Bloom applications.
///
/// Exports typed configurations, dot-env loaders, and runtime validation schemas.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_config.dart';
///
/// void main() {
///   BloomConfig.init(values: {'API_URL': 'https://api.example.com'});
///   final apiUrl = BloomConfig.get('API_URL');
/// }
/// ```
library bloom_config;

export 'src/config/typed_config.dart';
export 'src/config/config.dart';

