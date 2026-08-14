// lib/routes/api/health.dart
import 'package:bloom_framework/bloom_server.dart';

BloomResponse handleHealth(BloomRequest request) {
  return BloomResponse.json({
    'status': 'healthy',
    'version': '1.0.0',
    'timestamp': DateTime.now().toIso8601String(),
  });
}
