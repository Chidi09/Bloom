// lib/src/data/repository.dart
import '../di/container.dart';
import 'http_client.dart';

/// Base class for Bloom Repositories (data access & domain mapping layer).
abstract class BloomRepository {
  late final BloomHttpClient http;

  BloomRepository([BloomHttpClient? client]) {
    http = client ?? (globalContainer.injectOrNull<BloomHttpClient>() ?? BloomHttpClient());
  }
}
