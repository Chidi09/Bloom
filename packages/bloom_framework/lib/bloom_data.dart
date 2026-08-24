/// Client-side data, caching, query, and offline synchronization layer for Bloom applications.
///
/// Exports [BloomData], [BloomQuery], [BloomMutation], [BloomStorage], the offline mutation queue,
/// HTTP client wrapper, and repository interfaces.
///
/// **Note**: This barrel builds on the reactive `Signal` type from `package:signals_flutter` (via
/// `src/state/signals.dart`), so importing this barrel pulls in `package:flutter`. It is designed
/// as a dedicated, focused alternative to `bloom.dart` for client data layers without routing or UI widgets.
/// For Flutter-free server entrypoints, use `bloom_server.dart` or `bloom_core.dart`.
///
/// Example:
/// ```dart
/// import 'package:bloom_framework/bloom_data.dart';
///
/// final userQuery = BloomData.query<User>(
///   key: 'user:123',
///   fetcher: () => fetchUser(123),
/// );
/// ```
library bloom_data;

export 'src/data/cache.dart';
export 'src/data/query.dart';
export 'src/data/mutation.dart';
export 'src/data/storage.dart';
export 'src/data/offline_queue.dart';
export 'src/data/http_client.dart';
export 'src/data/repository.dart';
