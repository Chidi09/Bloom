// lib/bloom_data.dart
//
// Client-side data/query/cache layer (BloomData, BloomQuery, BloomMutation,
// offline queue, HTTP client, repository). NOTE: despite the name, this is
// NOT Flutter-independent — `query.dart`/`mutation.dart` build on the
// reactive `Signal` type from `package:signals_flutter` (via
// `src/state/signals.dart`), so importing this barrel still pulls in
// `package:flutter`. It exists as a narrower alternative to `bloom.dart`
// for client code that needs the query/cache layer without the rest of
// the widget/router/native surface — it is NOT safe to import from a
// pure-Dart server entrypoint. Servers must use `bloom_server.dart`
// (which re-exports the truly Flutter-free `bloom_core.dart`) instead.
// Does NOT include `src/data/auth.dart` (BloomAuth) — import `bloom.dart`
// for that.
library bloom_data;

export 'src/data/cache.dart';
export 'src/data/query.dart';
export 'src/data/mutation.dart';
export 'src/data/storage.dart';
export 'src/data/offline_queue.dart';
export 'src/data/http_client.dart';
export 'src/data/repository.dart';
