// lib/bloom.dart
library bloom;

// Core
export 'src/core/boot.dart';
export 'src/core/env.dart';
export 'src/core/logger.dart';

// Config
export 'src/config/config.dart';

// Dependency Injection
export 'src/di/container.dart';
export 'src/di/scope.dart';

// Lifecycle
export 'src/lifecycle/lifecycle.dart';

// State & Reactivity
export 'src/state/signals.dart';
export 'src/state/controller.dart';
export 'src/state/watch.dart';

// Router & Navigation
export 'src/router/route.dart';
export 'src/router/router.dart';
export 'package:go_router/go_router.dart'
    show GoRouter, GoRoute, RouteBase, ShellRoute, GoRouterState;

// Data, Queries & Offline Architecture (Phase 2)
export 'src/data/cache.dart';
export 'src/data/query.dart';
export 'src/data/mutation.dart';
export 'src/data/storage.dart';
export 'src/data/offline_queue.dart';
export 'src/data/http_client.dart';
export 'src/data/repository.dart';
export 'src/data/auth.dart';

// Native Architecture & Plugins (Phase 3 & 4)
export 'src/native/permissions.dart';
export 'src/native/secure_storage.dart';
export 'src/native/notifications.dart';
export 'src/native/camera.dart';
export 'src/native/deep_links.dart';
export 'src/native/background.dart';

// Developer Experience & Bloom Go (Phase 5 & 6)
export 'src/dev/bloom_go_client.dart';
export 'src/devtools/devtools_service.dart';
export 'src/devtools/bloom_overlay.dart';

// Deployment & Over-The-Air Updates (Phase 7)
export 'src/deployment/bloom_ota.dart';

// Full-Stack Adapters (Phase 8)
export 'src/adapters/supabase_adapter.dart';
export 'src/adapters/serverpod_adapter.dart';

// Native Module Platform & DSL (Phase 9)
export 'bloom_modules.dart';

// Updates Platform & Runtime Fingerprinting (Phase 11)
export 'bloom_updates.dart';

// Widgets
export 'src/widgets/app.dart';
