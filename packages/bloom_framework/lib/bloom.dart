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

// Widgets
export 'src/widgets/app.dart';
