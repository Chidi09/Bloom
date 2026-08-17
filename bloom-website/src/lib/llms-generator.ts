import fs from 'node:fs';
import path from 'node:path';
import { UI_REGISTRY, UI_CATEGORIES, type UIComponentDoc } from './ui-registry';
import { BLOCKS_DATA } from './blocks-data';

export interface PageDocMeta {
  slug: string;
  route: string;
  title: string;
  description: string;
  category: string;
  tags?: string[];
  docSourceFile?: string;
}

const SITE_URL = 'https://bloom-platform-ten.vercel.app';

// Comprehensive map of all docs pages to their source markdown files in /root/dev/Bloom/docs
export const DOCS_PAGE_METAS: PageDocMeta[] = [
  // UI & Getting Started
  {
    slug: 'docs/introduction',
    route: 'docs/introduction',
    title: 'Introduction & Vision',
    description: 'The strategy, architecture, and core philosophy behind the Bloom Application Platform.',
    category: 'UI & Getting Started',
    tags: ['overview', 'philosophy', 'architecture', 'strategy'],
    docSourceFile: '00_overview.md',
  },
  {
    slug: 'docs/installation',
    route: 'docs/installation',
    title: 'Installation & Setup',
    description: 'How to install and set up Bloom UI in your Flutter application via CLI and Pub.dev.',
    category: 'UI & Getting Started',
    tags: ['installation', 'setup', 'pub', 'cli', 'flutter'],
    docSourceFile: 'getting-started/01_installation.md',
  },
  {
    slug: 'docs/theming',
    route: 'docs/theming',
    title: 'Theming & Design Tokens',
    description: 'Master the 5-petal color palette, 8 style presets, modular spacing, and Flutter ThemeExtensions.',
    category: 'UI & Getting Started',
    tags: ['theming', 'tokens', 'colors', 'dark-mode', 'presets'],
  },
  {
    slug: 'docs/typography',
    route: 'docs/typography',
    title: 'Typography System',
    description: 'Structured typography scale for headings, body copy, lead text, and code snippets matching shadcn guidelines.',
    category: 'UI & Getting Started',
    tags: ['typography', 'fonts', 'headings', 'text-styles'],
  },
  {
    slug: 'docs/changelog',
    route: 'docs/changelog',
    title: 'Changelog & Releases',
    description: 'All notable changes, version history, and roadmap milestones for the Bloom ecosystem.',
    category: 'UI & Getting Started',
    tags: ['changelog', 'releases', 'versions', 'updates'],
  },

  // Framework Getting Started
  {
    slug: 'docs/framework/quickstart',
    route: 'docs/framework/quickstart',
    title: '5-Minute Quickstart',
    description: 'Build your first reactive Bloom app with Signals, DI, and filesystem routing in 5 minutes.',
    category: 'Framework Getting Started',
    tags: ['quickstart', 'tutorial', 'getting-started', 'signals'],
    docSourceFile: 'getting-started/02_quickstart.md',
  },
  {
    slug: 'docs/getting-started/project-anatomy',
    route: 'docs/getting-started/project-anatomy',
    title: 'Project Anatomy & Structure',
    description: 'Complete breakdown of Bloom project structure, conventions, and configuration files.',
    category: 'Framework Getting Started',
    tags: ['anatomy', 'project-structure', 'conventions', 'folders'],
    docSourceFile: 'getting-started/03_project_anatomy.md',
  },
  {
    slug: 'docs/getting-started/bloom-yaml-reference',
    route: 'docs/getting-started/bloom-yaml-reference',
    title: 'bloom.yaml Schema Reference',
    description: 'Complete schema reference for bloom.yaml declarative project configuration.',
    category: 'Framework Getting Started',
    tags: ['bloom.yaml', 'configuration', 'schema', 'manifest'],
    docSourceFile: 'getting-started/04_bloom_yaml_reference.md',
  },

  // Runtime & Architecture
  {
    slug: 'docs/framework/boot',
    route: 'docs/framework/boot',
    title: 'Boot Lifecycle & Initialization',
    description: 'Deterministic async boot stages, dependency registration, and bootstrap sequence in Bloom.',
    category: 'Runtime & Architecture',
    tags: ['boot', 'lifecycle', 'initialization', 'startup'],
    docSourceFile: 'runtime/boot_lifecycle.md',
  },
  {
    slug: 'docs/runtime/boot-lifecycle',
    route: 'docs/runtime/boot-lifecycle',
    title: 'Boot Lifecycle & Initialization',
    description: 'Deterministic async boot stages, dependency registration, and bootstrap sequence in Bloom.',
    category: 'Runtime & Architecture',
    tags: ['boot', 'lifecycle', 'initialization', 'startup'],
    docSourceFile: 'runtime/boot_lifecycle.md',
  },
  {
    slug: 'docs/runtime/config-and-env',
    route: 'docs/runtime/config-and-env',
    title: 'Config & Environment Management',
    description: 'Type-safe environment variables, dotenv support, and compile-time configuration validation.',
    category: 'Runtime & Architecture',
    tags: ['config', 'environment', 'dotenv', 'env'],
    docSourceFile: 'runtime/config_and_env.md',
  },
  {
    slug: 'docs/framework/routing',
    route: 'docs/framework/routing',
    title: 'Filesystem Routing & Navigation',
    description: 'Declarative Next.js-style file-based routing for Flutter compiled into strongly-typed GoRouter tables.',
    category: 'Runtime & Architecture',
    tags: ['routing', 'go_router', 'navigation', 'filesystem'],
    docSourceFile: 'runtime/filesystem_routing.md',
  },
  {
    slug: 'docs/runtime/filesystem-routing',
    route: 'docs/runtime/filesystem-routing',
    title: 'Filesystem Routing & Navigation',
    description: 'Declarative Next.js-style file-based routing for Flutter compiled into strongly-typed GoRouter tables.',
    category: 'Runtime & Architecture',
    tags: ['routing', 'go_router', 'navigation', 'filesystem'],
    docSourceFile: 'runtime/filesystem_routing.md',
  },
  {
    slug: 'docs/framework/signals',
    route: 'docs/framework/signals',
    title: 'Signals Reactivity & Controllers',
    description: 'Fine-grained reactive state management with Signals, Computed values, Effects, and BloomController.',
    category: 'Runtime & Architecture',
    tags: ['signals', 'reactivity', 'state-management', 'controllers'],
    docSourceFile: 'runtime/signals_and_controllers.md',
  },
  {
    slug: 'docs/runtime/signals-and-controllers',
    route: 'docs/runtime/signals-and-controllers',
    title: 'Signals Reactivity & Controllers',
    description: 'Fine-grained reactive state management with Signals, Computed values, Effects, and BloomController.',
    category: 'Runtime & Architecture',
    tags: ['signals', 'reactivity', 'state-management', 'controllers'],
    docSourceFile: 'runtime/signals_and_controllers.md',
  },
  {
    slug: 'docs/framework/di',
    route: 'docs/framework/di',
    title: 'Dependency Injection & Container',
    description: 'Lightweight hierarchical DI container with singleton, factory, and scoped bindings.',
    category: 'Runtime & Architecture',
    tags: ['di', 'dependency-injection', 'ioc', 'container'],
    docSourceFile: 'runtime/dependency_injection.md',
  },
  {
    slug: 'docs/runtime/dependency-injection',
    route: 'docs/runtime/dependency-injection',
    title: 'Dependency Injection & Container',
    description: 'Lightweight hierarchical DI container with singleton, factory, and scoped bindings.',
    category: 'Runtime & Architecture',
    tags: ['di', 'dependency-injection', 'ioc', 'container'],
    docSourceFile: 'runtime/dependency_injection.md',
  },
  {
    slug: 'docs/runtime/logging',
    route: 'docs/runtime/logging',
    title: 'Structured Logging & Diagnostics',
    description: 'Production-ready structured logging with severity levels, JSON output, and DevTools integration.',
    category: 'Runtime & Architecture',
    tags: ['logging', 'diagnostics', 'devtools', 'observability'],
    docSourceFile: 'runtime/logging.md',
  },

  // Data Layer & Offline
  {
    slug: 'docs/framework/data',
    route: 'docs/framework/data',
    title: 'Data Layer & Caching Architecture',
    description: 'TanStack-inspired data management for Flutter: queries, mutations, offline queue, and SWR caching.',
    category: 'Data Layer & Caching',
    tags: ['data', 'caching', 'swr', 'queries', 'mutations'],
    docSourceFile: '06_bloom_data_and_offline.md',
  },
  {
    slug: 'docs/data/queries',
    route: 'docs/data/queries',
    title: 'Asynchronous Server Queries',
    description: 'BloomQuery: reactive data fetching, automatic deduping, background revalidation, and caching.',
    category: 'Data Layer & Caching',
    tags: ['queries', 'fetching', 'bloomquery', 'caching'],
    docSourceFile: 'data/queries.md',
  },
  {
    slug: 'docs/data/mutations',
    route: 'docs/data/mutations',
    title: 'Mutations & Optimistic Updates',
    description: 'BloomMutation: async data modifications with optimistic UI updates and automated rollback.',
    category: 'Data Layer & Caching',
    tags: ['mutations', 'optimistic-ui', 'rollback', 'post'],
    docSourceFile: 'data/mutations.md',
  },
  {
    slug: 'docs/data/cache-and-garbage-collection',
    route: 'docs/data/cache-and-garbage-collection',
    title: 'Cache & Garbage Collection',
    description: 'In-memory LRU cache, stale-while-revalidate policies, and automated background garbage collection.',
    category: 'Data Layer & Caching',
    tags: ['cache', 'garbage-collection', 'lru', 'memory'],
    docSourceFile: 'data/cache_and_garbage_collection.md',
  },
  {
    slug: 'docs/data/http-client',
    route: 'docs/data/http-client',
    title: 'HTTP Client & Interceptors',
    description: 'Resilient HTTP client with retry policies, JWT auth injection, rate limiting, and request interceptors.',
    category: 'Data Layer & Caching',
    tags: ['http', 'client', 'interceptors', 'network'],
    docSourceFile: 'data/http_client.md',
  },
  {
    slug: 'docs/data/offline-queue',
    route: 'docs/data/offline-queue',
    title: 'Offline Queue & Synchronization',
    description: 'Persistent mutation queue with automatic retry, exponential backoff, and background network sync.',
    category: 'Data Layer & Caching',
    tags: ['offline', 'sync', 'queue', 'connectivity'],
    docSourceFile: 'data/offline_queue.md',
  },
  {
    slug: 'docs/data/storage-adapters',
    route: 'docs/data/storage-adapters',
    title: 'Storage Adapters (SQLite, Hive, Memory)',
    description: 'Pluggable persistent key-value and relational storage drivers for local persistence.',
    category: 'Data Layer & Caching',
    tags: ['storage', 'sqlite', 'hive', 'persistence'],
    docSourceFile: 'data/storage_adapters.md',
  },
  {
    slug: 'docs/data/authentication',
    route: 'docs/data/authentication',
    title: 'Authentication & Session Flow',
    description: 'Secure token storage, automatic token refreshing, route guard integration, and session management.',
    category: 'Data Layer & Caching',
    tags: ['auth', 'jwt', 'sessions', 'security'],
    docSourceFile: 'data/authentication.md',
  },
  {
    slug: 'docs/data/repositories',
    route: 'docs/data/repositories',
    title: 'Typed Repositories Pattern',
    description: 'Clean Architecture repository pattern standardizing domain models and data sources.',
    category: 'Data Layer & Caching',
    tags: ['repositories', 'clean-architecture', 'domain-models'],
    docSourceFile: 'data/repositories.md',
  },

  // Native & Prebuild
  {
    slug: 'docs/framework/native',
    route: 'docs/framework/native',
    title: 'Prebuild & Native Sync Engine',
    description: 'Expo-style continuous prebuild engine syncing iOS/Android native folders from bloom.yaml.',
    category: 'Native & Prebuild',
    tags: ['native', 'prebuild', 'ios', 'android', 'gradle'],
    docSourceFile: 'native/prebuild_engine.md',
  },
  {
    slug: 'docs/native/prebuild-engine',
    route: 'docs/native/prebuild-engine',
    title: 'Prebuild & Native Sync Engine',
    description: 'Expo-style continuous prebuild engine syncing iOS/Android native folders from bloom.yaml.',
    category: 'Native & Prebuild',
    tags: ['native', 'prebuild', 'ios', 'android', 'gradle'],
    docSourceFile: 'native/prebuild_engine.md',
  },
  {
    slug: 'docs/native/permissions',
    route: 'docs/native/permissions',
    title: 'Native Permissions Management',
    description: 'Declarative camera, location, notifications, and storage permissions with auto-generated manifests.',
    category: 'Native & Prebuild',
    tags: ['permissions', 'manifest', 'infoplist', 'security'],
    docSourceFile: 'native/permissions.md',
  },
  {
    slug: 'docs/native/deep-links',
    route: 'docs/native/deep-links',
    title: 'Deep Links & Universal Links',
    description: 'Universal Links (iOS) and App Links (Android) configuration with automated assetlinks.json generation.',
    category: 'Native & Prebuild',
    tags: ['deep-links', 'universal-links', 'app-links', 'routing'],
    docSourceFile: 'native/deep_links.md',
  },
  {
    slug: 'docs/native/flavors',
    route: 'docs/native/flavors',
    title: 'Flavors & Build Schemes',
    description: 'Multi-environment setup (development, staging, production) with distinct bundle IDs and app icons.',
    category: 'Native & Prebuild',
    tags: ['flavors', 'schemes', 'environments', 'build-variants'],
    docSourceFile: 'native/flavors.md',
  },
  {
    slug: 'docs/native/plugins',
    route: 'docs/native/plugins',
    title: 'Native Plugin Architecture',
    description: 'Writing custom Bloom native config plugins to inject CocoaPods, Gradle dependencies, and hooks.',
    category: 'Native & Prebuild',
    tags: ['plugins', 'config-plugins', 'cocoapods', 'gradle'],
    docSourceFile: 'native/plugins.md',
  },

  // CLI Tooling
  {
    slug: 'docs/cli',
    route: 'docs/cli',
    title: 'Bloom CLI Master Overview',
    description: 'The command-line interface orchestrating creation, dev server, code generation, prebuild, and deployment.',
    category: 'CLI Tooling',
    tags: ['cli', 'commands', 'tooling', 'terminal'],
    docSourceFile: '02_cli_and_developer_tooling.md',
  },
  {
    slug: 'docs/cli/commands',
    route: 'docs/cli/commands',
    title: 'Complete CLI Command Reference',
    description: 'Comprehensive flag, alias, and option guide for all bloom commands.',
    category: 'CLI Tooling',
    tags: ['cli', 'reference', 'commands', 'flags'],
    docSourceFile: 'cli/commands.md',
  },
  {
    slug: 'docs/cli/create',
    route: 'docs/cli/create',
    title: 'bloom create',
    description: 'Scaffold new production-ready Bloom applications with interactive templates and presets.',
    category: 'CLI Tooling',
    tags: ['cli', 'create', 'scaffold', 'template'],
    docSourceFile: 'cli/create.md',
  },
  {
    slug: 'docs/cli/dev',
    route: 'docs/cli/dev',
    title: 'bloom dev',
    description: 'Run the high-performance development server with live routing watcher, QR code launcher, and hot reload.',
    category: 'CLI Tooling',
    tags: ['cli', 'dev', 'dev-server', 'hot-reload'],
    docSourceFile: 'cli/dev.md',
  },
  {
    slug: 'docs/cli/generate',
    route: 'docs/cli/generate',
    title: 'bloom generate',
    description: 'Run automated code generation for routes, DI containers, models, and assets without build_runner friction.',
    category: 'CLI Tooling',
    tags: ['cli', 'generate', 'codegen', 'routes'],
    docSourceFile: 'cli/generate.md',
  },
  {
    slug: 'docs/cli/prebuild',
    route: 'docs/cli/prebuild',
    title: 'bloom prebuild',
    description: 'Generate and synchronize native iOS and Android folders from bloom.yaml definitions.',
    category: 'CLI Tooling',
    tags: ['cli', 'prebuild', 'native', 'sync'],
    docSourceFile: 'cli/prebuild.md',
  },
  {
    slug: 'docs/cli/deploy',
    route: 'docs/cli/deploy',
    title: 'bloom deploy',
    description: 'Deploy OTA updates, build cloud release artifacts, and publish patches directly to users.',
    category: 'CLI Tooling',
    tags: ['cli', 'deploy', 'ota', 'release'],
    docSourceFile: 'cli/deploy.md',
  },
  {
    slug: 'docs/cli/doctor',
    route: 'docs/cli/doctor',
    title: 'bloom doctor',
    description: 'Diagnose Flutter, Dart, CocoaPods, Android SDK, and Bloom project dependencies with automated repair hints.',
    category: 'CLI Tooling',
    tags: ['cli', 'doctor', 'diagnostics', 'health-check'],
    docSourceFile: 'cli/doctor.md',
  },

  // Developer Experience & OTA
  {
    slug: 'docs/dev-experience/bloom-go',
    route: 'docs/dev-experience/bloom-go',
    title: 'Bloom Go Companion App',
    description: 'Instant wireless sandbox for iOS and Android: test Bloom projects on physical devices without compilation.',
    category: 'Developer Experience',
    tags: ['bloom-go', 'wireless', 'qr-code', 'companion-app'],
    docSourceFile: 'dev-experience/bloom_go.md',
  },
  {
    slug: 'docs/dev-experience/dev-server',
    route: 'docs/dev-experience/dev-server',
    title: 'Local Dev Server & Live Orchestration',
    description: 'High-speed WebSocket orchestrator coordinating hot reload, file-watching, and diagnostics.',
    category: 'Developer Experience',
    tags: ['dev-server', 'live-reloading', 'watcher'],
    docSourceFile: 'dev-experience/dev_server.md',
  },
  {
    slug: 'docs/dev-experience/devtools-extensions',
    route: 'docs/dev-experience/devtools-extensions',
    title: 'Flutter DevTools Extension',
    description: 'Visual inspector for Signals graph, Query cache, Route hierarchy, and OTA update status.',
    category: 'Developer Experience',
    tags: ['devtools', 'inspector', 'signals-graph', 'debugging'],
    docSourceFile: 'dev-experience/devtools_extensions.md',
  },
  {
    slug: 'docs/framework/ota',
    route: 'docs/framework/ota',
    title: 'Cloud OTA Code Push Engine',
    description: 'Instant over-the-air Flutter code updates powered by Shorebird with rollback guarantees.',
    category: 'Developer Experience',
    tags: ['ota', 'shorebird', 'code-push', 'updates'],
    docSourceFile: 'dev-experience/ota_deployments.md',
  },
  {
    slug: 'docs/dev-experience/ota-deployments',
    route: 'docs/dev-experience/ota-deployments',
    title: 'Cloud OTA Code Push Engine',
    description: 'Instant over-the-air Flutter code updates powered by Shorebird with rollback guarantees.',
    category: 'Developer Experience',
    tags: ['ota', 'shorebird', 'code-push', 'updates'],
    docSourceFile: 'dev-experience/ota_deployments.md',
  },

  // Cloud Platform (Organizations, Builds, Releases, Deployments, Secrets, Signing, Hosting)
  {
    slug: 'docs/cloud/overview',
    route: 'docs/cloud/overview',
    title: 'Cloud Platform Overview',
    description: 'Organizations, projects, apps, and role-based access control for Bloom Cloud.',
    category: 'Cloud Platform',
    tags: ['cloud', 'organizations', 'projects', 'apps', 'rbac', 'audit-log'],
  },
  {
    slug: 'docs/cloud/build-and-release',
    route: 'docs/cloud/build-and-release',
    title: 'Build & Release Pipeline',
    description: 'Remote build farm, release approvals, rollout percentages, and multi-target deployments.',
    category: 'Cloud Platform',
    tags: ['cloud', 'builds', 'releases', 'deployments', 'environments'],
  },
  {
    slug: 'docs/cloud/secrets-and-signing',
    route: 'docs/cloud/secrets-and-signing',
    title: 'Secrets, Signing & Git',
    description: 'Versioned secrets vault, signing identity management, and Git provider connections.',
    category: 'Cloud Platform',
    tags: ['cloud', 'secrets', 'signing', 'git-connections'],
  },
  {
    slug: 'docs/cloud/hosting-and-automation',
    route: 'docs/cloud/hosting-and-automation',
    title: 'Hosting, Observability & Automation',
    description: 'Flutter Web hosting with custom domains, release health monitoring, workflow automation, and the template marketplace.',
    category: 'Cloud Platform',
    tags: ['cloud', 'web-hosting', 'observability', 'workflows', 'marketplace'],
  },

  // Backend Adapters
  {
    slug: 'docs/framework/adapters',
    route: 'docs/framework/adapters',
    title: 'Backend Adapters Overview',
    description: 'Turnkey integration with Supabase, Serverpod, Firebase, GraphQL, and REST APIs.',
    category: 'Backend Adapters',
    tags: ['adapters', 'backend', 'supabase', 'serverpod', 'rest'],
  },
  {
    slug: 'docs/adapters/supabase',
    route: 'docs/adapters/supabase',
    title: 'Supabase Adapter',
    description: 'Turnkey Supabase auth, Postgres real-time signals, Row-Level Security, and Storage integration.',
    category: 'Backend Adapters',
    tags: ['supabase', 'postgres', 'realtime', 'auth'],
    docSourceFile: 'adapters/supabase.md',
  },
  {
    slug: 'docs/adapters/serverpod',
    route: 'docs/adapters/serverpod',
    title: 'Serverpod Adapter',
    description: 'Full-stack Dart integration: end-to-end type safety, streaming WebSockets, and shared data classes.',
    category: 'Backend Adapters',
    tags: ['serverpod', 'fullstack-dart', 'websockets', 'rpc'],
    docSourceFile: 'adapters/serverpod.md',
  },

  // Bloom Server (Backend Ecosystem)
  {
    slug: 'docs/server/overview',
    route: 'docs/server/overview',
    title: 'Bloom Server Overview',
    description: 'A full-stack, Django-style backend ecosystem for Bloom applications sharing the same core framework as Flutter.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'backend', 'django', 'architecture'],
  },
  {
    slug: 'docs/server/scaffolding',
    route: 'docs/server/scaffolding',
    title: 'Scaffolding a Server',
    description: 'Scaffold new Bloom Server backends and apps with `bloom server create` and `bloom server startapp`.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'cli', 'scaffolding', 'startapp'],
  },
  {
    slug: 'docs/server/orm-and-migrations',
    route: 'docs/server/orm-and-migrations',
    title: 'ORM & Migrations',
    description: 'bloom_db QuerySet API, Q()/F() expressions, model annotations, and bloom_migrate schema migrations.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'orm', 'bloom_db', 'migrations', 'postgres', 'sqlite'],
  },
  {
    slug: 'docs/server/auth',
    route: 'docs/server/auth',
    title: 'Authentication',
    description: 'bloom_auth_server session tokens, password hashing, rate limiting, and auth middleware.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'auth', 'jwt', 'bcrypt', 'sessions'],
  },
  {
    slug: 'docs/server/validation-and-errors',
    route: 'docs/server/validation-and-errors',
    title: 'Validation & Errors',
    description: 'bloom_validate schema validation and bloom_errors typed HTTP exception hierarchy with dev/prod masking.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'validation', 'errors', 'exceptions'],
  },
  {
    slug: 'docs/server/rest-api',
    route: 'docs/server/rest-api',
    title: 'REST API Layer',
    description: 'bloom_rest DRF-style ViewSets, serializers, pagination, filters, and permission classes.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'rest', 'viewsets', 'serializers', 'drf'],
  },
  {
    slug: 'docs/server/admin-panel',
    route: 'docs/server/admin-panel',
    title: 'Admin Panel',
    description: 'bloom_admin automatic server-rendered HTML administration interface for Bloom Server applications.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'admin', 'html'],
  },
  {
    slug: 'docs/server/realtime',
    route: 'docs/server/realtime',
    title: 'Realtime & WebSockets',
    description: 'bloom_realtime pub/sub channels, broadcast, presence, and query-cache invalidation bridge.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'realtime', 'websockets', 'pubsub'],
  },
  {
    slug: 'docs/server/caching',
    route: 'docs/server/caching',
    title: 'Caching',
    description: 'bloom_cache in-memory LRU, database, and Redis caching backends with HTTP response caching middleware.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'cache', 'redis', 'lru'],
  },
  {
    slug: 'docs/server/jobs-mail-and-storage',
    route: 'docs/server/jobs-mail-and-storage',
    title: 'Jobs, Mail & Storage',
    description: 'bloom_jobs background queues, bloom_mail transactional email, and bloom_storage swappable file storage.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'jobs', 'queue', 'mail', 'storage', 's3'],
  },
  {
    slug: 'docs/server/i18n-and-security',
    route: 'docs/server/i18n-and-security',
    title: 'i18n & Security',
    description: 'bloom_i18n locale resolution and ICU formatting, bloom_security CORS, headers, and rate limiting.',
    category: 'Bloom Server',
    tags: ['bloom-server', 'i18n', 'security', 'cors'],
  },

  // Testing & Diagnostics
  {
    slug: 'docs/guides/testing',
    route: 'docs/guides/testing',
    title: 'Testing Overview & Strategy',
    description: 'Comprehensive testing guide for Bloom applications: unit, controller, widget, and E2E testing.',
    category: 'Testing & Diagnostics',
    tags: ['testing', 'unit-tests', 'widget-tests', 'e2e'],
    docSourceFile: '09_testing_ci_and_devtools.md',
  },
  {
    slug: 'docs/testing/harness',
    route: 'docs/testing/harness',
    title: 'Bloom Testing Harness',
    description: 'BloomTestContainer, mock adapters, signal testing utilities, and query test helpers.',
    category: 'Testing & Diagnostics',
    tags: ['testing-harness', 'mocking', 'container-testing'],
    docSourceFile: 'testing/bloom_testing_harness.md',
  },
  {
    slug: 'docs/testing/recipes',
    route: 'docs/testing/recipes',
    title: 'Testing Recipes & Cookbook',
    description: 'Ready-to-use testing recipes for controllers, route guards, offline queues, and UI components.',
    category: 'Testing & Diagnostics',
    tags: ['recipes', 'test-cookbook', 'mocks', 'assertions'],
    docSourceFile: 'testing/test_recipes.md',
  },

  // Engineering Guides
  {
    slug: 'docs/guides/cookbook',
    route: 'docs/guides/cookbook',
    title: 'Bloom Engineering Cookbook',
    description: 'Real-world recipes: infinite scrolling lists, file uploads, biometrics, dark mode, and multi-tenant auth.',
    category: 'Engineering Guides',
    tags: ['cookbook', 'recipes', 'patterns', 'solutions'],
    docSourceFile: 'guides/cookbook.md',
  },
  {
    slug: 'docs/guides/best-practices',
    route: 'docs/guides/best-practices',
    title: 'Architectural Best Practices',
    description: 'Production guidelines for performance, signal granularity, controller lifecycle, and memory management.',
    category: 'Engineering Guides',
    tags: ['best-practices', 'architecture', 'performance', 'clean-code'],
    docSourceFile: 'guides/best_practices.md',
  },
  {
    slug: 'docs/guides/migration',
    route: 'docs/guides/migration',
    title: 'Migration Guide',
    description: 'Step-by-step migration paths from raw Flutter, Riverpod, Bloc, and GetX to Bloom.',
    category: 'Engineering Guides',
    tags: ['migration', 'riverpod', 'bloc', 'getx', 'refactoring'],
    docSourceFile: 'guides/migration_guide.md',
  },
  {
    slug: 'docs/guides/contributing',
    route: 'docs/guides/contributing',
    title: 'Contributing to Bloom',
    description: 'How to contribute to Bloom framework, CLI, primitives, and documentation.',
    category: 'Engineering Guides',
    tags: ['contributing', 'open-source', 'guidelines', 'pull-requests'],
    docSourceFile: 'guides/contributing.md',
  },
  {
    slug: 'docs/guides/troubleshooting',
    route: 'docs/guides/troubleshooting',
    title: 'Troubleshooting & FAQ',
    description: 'Common issues, error codes, build fixes, and frequently asked questions.',
    category: 'Engineering Guides',
    tags: ['troubleshooting', 'faq', 'errors', 'debugging'],
    docSourceFile: 'guides/troubleshooting_and_faq.md',
  },
  {
    slug: 'docs/guides/api-reference',
    route: 'docs/guides/api-reference',
    title: 'Core API Reference',
    description: 'Exhaustive API signatures for BloomContainer, createSignal, BloomQuery, BloomMutation, and BloomController.',
    category: 'Engineering Guides',
    tags: ['api-reference', 'signatures', 'types', 'classes'],
    docSourceFile: 'guides/api_reference.md',
  },

  // Transparency
  {
    slug: 'docs/transparency/platform-capabilities',
    route: 'docs/transparency/platform-capabilities',
    title: 'Platform Capabilities & Ecosystem Gaps',
    description: 'Transparent evaluation of what Bloom does, what it delegates, and current ecosystem roadmap.',
    category: 'Transparency',
    tags: ['transparency', 'roadmap', 'trade-offs', 'limitations'],
    docSourceFile: 'transparency/platform_capabilities_and_gaps.md',
  },
];

// Helper to load root doc file content safely
function readDocFile(fileName?: string): string | null {
  if (!fileName) return null;
  const basePath = '/root/dev/Bloom/docs';
  const fullPath = path.resolve(basePath, fileName);
  try {
    if (fs.existsSync(fullPath)) {
      return fs.readFileSync(fullPath, 'utf-8');
    }
  } catch (err) {
    console.error(`Error reading doc file ${fullPath}:`, err);
  }
  return null;
}

// Generate LLM markdown for a single UI component
export function generateUIComponentMarkdown(comp: UIComponentDoc): string {
  const propsTable = comp.props.length > 0
    ? `### Properties & Parameters\n\n| Prop | Type | Default | Description |\n| :--- | :--- | :--- | :--- |\n` +
      comp.props
        .map(
          (p) =>
            `| \`${p.name}\` | \`${p.type}\` | ${p.defaultVal ? `\`${p.defaultVal}\`` : '*Required*'} | ${p.description} |`
        )
        .join('\n')
    : 'No custom properties required.';

  const slotsSection = comp.slots && comp.slots.length > 0
    ? `### Sub-Components & Slots\n\n| Sub-Component | Description |\n| :--- | :--- |\n` +
      comp.slots.map((s) => `| \`${s.name}\` | ${s.description} |`).join('\n') + '\n\n'
    : '';

  const variantsSection = comp.variants && comp.variants.length > 0
    ? `**Available Variants:** ${comp.variants.map((v) => `\`${v}\``).join(', ')}\n\n`
    : '';

  const sizesSection = comp.sizes && comp.sizes.length > 0
    ? `**Available Sizes:** ${comp.sizes.map((s) => `\`${s}\``).join(', ')}\n\n`
    : '';

  return `---
title: "${comp.title} (${comp.name}) — Bloom UI Primitive"
description: "${comp.description}"
category: "${comp.category}"
url: "${SITE_URL}/ui/${comp.slug}"
component_name: "${comp.name}"
pub_package: "${comp.pubPackage}"
cli_command: "${comp.cliCommand}"
last_updated: "2026-08-15"
---

# ${comp.title} (\`${comp.name}\`)

> ${comp.description}

**Category:** ${comp.category}  
**Package:** [\`${comp.pubPackage}\`](https://pub.dev/packages/${comp.pubPackage})  
**CLI Install:** \`${comp.cliCommand}\`  
**Web Preview:** [${SITE_URL}/ui/${comp.slug}](${SITE_URL}/ui/${comp.slug})

---

## 📦 Installation & Setup

### 1. Using Bloom CLI (Recommended)
Add the source code directly to your project without rigid package locks:
\`\`\`bash
${comp.cliCommand}
\`\`\`

### 2. Using Pub.dev Package
Add the dependency to your \`pubspec.yaml\`:
\`\`\`yaml
dependencies:
  ${comp.pubPackage}: ^0.1.0
\`\`\`

### 3. Import in Dart
\`\`\`dart
${comp.flutterImport}
\`\`\`

---

## 🚀 Usage Example

\`\`\`dart
${comp.usageCode}
\`\`\`

---

## 🛠️ API Reference

${variantsSection}${sizesSection}${slotsSection}${propsTable}

---

## 🎨 Theming & Styling

${comp.name} automatically respects the active \`BloomTheme\` (including \`BloomTheme.novaLight\`, \`BloomTheme.novaDark\`, etc.) and responds seamlessly to dark mode changes, custom border radii, and brand color tokens.

### Theme Overrides Example
\`\`\`dart
Theme(
  data: Theme.of(context).copyWith(
    extensions: [
      context.bloomTheme.copyWith(
        colors: context.bloomColors.copyWith(
          primary: const Color(0xFF8B5CF6), // Custom Purple Accent
        ),
      ),
    ],
  ),
  child: ${comp.usageCode.split('\n')[0]}...,
)
\`\`\`

---

## 🔗 Related Resources
- [Components Gallery](${SITE_URL}/ui)
- [Bloom Theming & Tokens Guide](${SITE_URL}/docs/theming)
- [Application Blocks Catalog](${SITE_URL}/blocks)
- [Bloom CLI Master Overview](${SITE_URL}/docs/cli)
`;
}

// Generate LLM markdown for the UI catalog index (/ui)
export function generateUICatalogMarkdown(): string {
  let content = `---
title: "Bloom UI Primitives Catalog (60+ Flutter Components)"
description: "Comprehensive catalog of unstyled, accessible, copy-paste Flutter primitives inspired by shadcn/ui."
category: "Bloom UI"
url: "${SITE_URL}/ui"
last_updated: "2026-08-15"
---

# Bloom UI Primitives Catalog

> Over 60 production-grade, accessible, customizable Flutter components and charts built on pure Dart with zero external runtime dependencies.

Inspired by the philosophy of **shadcn/ui**, Bloom UI allows you to own your code. You can install components directly into your codebase using \`bloom ui add <component>\` or consume them via the published \`bloom_ui\` package on Pub.dev.

---

## 🚀 Quick Installation

\`\`\`bash
# Initialize Bloom UI in your Flutter project
bloom ui init

# Add individual primitives
bloom ui add button card dialog tabs sheet
\`\`\`

---

## 📂 Components by Category

`;

  for (const cat of UI_CATEGORIES) {
    const items = UI_REGISTRY.filter((c) => c.category === cat);
    content += `### ${cat} (${items.length} components)\n\n`;
    content += `| Component | Dart Class | Description | CLI Command |\n| :--- | :--- | :--- | :--- |\n`;
    for (const item of items) {
      content += `| [${item.title}](${SITE_URL}/ui/${item.slug}.md) | \`${item.name}\` | ${item.description} | \`${item.cliCommand}\` |\n`;
    }
    content += '\n';
  }

  content += `---

## 📊 Complete List of Component Markdown Endpoints

Every component has a dedicated LLM markdown file:

`;

  for (const item of UI_REGISTRY) {
    content += `- [${item.title} (\`${item.name}\`)](${SITE_URL}/ui/${item.slug}.md): \`${item.cliCommand}\`\n`;
  }

  return content;
}

// Generate LLM markdown for Application Blocks (/blocks)
export function generateBlocksMarkdown(): string {
  let content = `---
title: "Bloom Application Blocks Catalog"
description: "Pre-built, responsive Flutter application blocks: dashboards, authentication flows, chat interfaces, and settings screens."
category: "Bloom UI Studio"
url: "${SITE_URL}/blocks"
last_updated: "2026-08-15"
---

# Bloom Application Blocks Catalog

> Full-screen, beautifully designed, composable Flutter screen templates built with Bloom UI primitives and reactive state.

---

`;

  for (const block of BLOCKS_DATA) {
    content += `## ${block.title} (\`${block.id}\`)

**Category:** ${block.category}  
**Description:** ${block.description}

### Complete Flutter Implementation

\`\`\`dart
${block.flutterCode}
\`\`\`

---

`;
  }

  return content;
}

// Generate LLM markdown for Themes & Tokens (/themes)
export function generateThemesMarkdown(): string {
  return `---
title: "Bloom Design System: Themes, Color Presets & Tokens"
description: "Specification for Bloom's 8 design presets (Nova, Vega, Maia, Lyra, Mira, Luma, Sera, Rhea), radius scale, motion curves, and ThemeExtension tokens."
category: "Design System"
url: "${SITE_URL}/themes"
last_updated: "2026-08-15"
---

# Bloom Themes & Token Specification

> Bloom provides an opinionated, multi-theme architecture powered by Flutter's official \`ThemeExtension\` API.

---

## 🎨 8 Built-in Style Presets

Bloom includes 8 calibrated aesthetic presets with synchronous light and dark modes:

1. **Nova (Default)**: Modern, refined enterprise palette featuring rich indigo accents, high-contrast surfaces, and subtle slate borders.
2. **Vega**: Futuristic cyber aesthetic with electric violet accents, deep obsidian dark mode, and neon glow indicators.
3. **Maia**: Minimalist Nordic design with balanced neutrals, warm grays, and soft charcoal contrast.
4. **Lyra**: Vibrant, punchy coral and rose palette crafted for consumer and social experiences.
5. **Mira**: Crisp oceanic cyan and teal palette optimized for fintech, analytics, and data-dense dashboards.
6. **Luma**: High-contrast, accessibility-first monochrome palette with sharp contrast ratios exceeding WCAG AAA standards.
7. **Sera**: Warm amber and golden dusk palette with earthy undertones.
8. **Rhea**: Emerald and mint palette tailored for health, ecology, and productivity applications.

---

## 📐 Token Scales

### 1. Border Radius Scale (\`context.bloomRadius\`)
- \`none\`: \`0.0\`
- \`xs\`: \`2.0\`
- \`sm\`: \`4.0\`
- \`md\`: \`6.0\` (Default component radius)
- \`lg\`: \`8.0\` (Card & dialog radius)
- \`xl\`: \`12.0\` (Sheet & drawer radius)
- \`xxl\`: \`16.0\`
- \`full\`: \`9999.0\` (Pills, badges & avatars)

### 2. Motion & Animation Scale (\`BloomMotion\`)
- \`fast\`: \`Duration(milliseconds: 150)\` — Spring curve for button presses and toggles.
- \`normal\`: \`Duration(milliseconds: 250)\` — \`Curves.easeOutCubic\` for dialogs, popovers, and accordions.
- \`slow\`: \`Duration(milliseconds: 400)\` — \`Curves.easeInOutCubic\` for page transitions and drawer sliding.

### 3. Surface & Color Hierarchy (\`context.bloomColors\`)
- \`surface0\`: Base background canvas (Light: \`#FFFFFF\`, Dark: \`#000000\`)
- \`surface1\`: Elevated cards, popovers, and modals (Light: \`#F8FAFC\`, Dark: \`#050505\`)
- \`surface2\`: Secondary containers, inputs, and dropdown panels (Light: \`#F1F5F9\`, Dark: \`#0A0A0A\`)
- \`border\`: Structural stroke lines (Light: \`#E2E8F0\`, Dark: \`#262626\`)
- \`primary\`: Active brand accent (Light: \`#4F46E5\`, Dark: \`#6366F1\`)
- \`destructive\`: Soft error and deletion tint (Light: \`#EF4444\`, Dark: \`#F87171\`)
- \`ring\`: Focus indicator ring for keyboard accessibility (Light: \`#6366F1\`, Dark: \`#818CF8\`)

---

## 💻 Dart Code Usage

\`\`\`dart
import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Themed Bloom App',
      theme: ThemeData(
        brightness: Brightness.light,
        extensions: const [BloomTheme.novaLight],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        extensions: const [BloomTheme.novaDark],
      ),
      home: const HomeScreen(),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access design tokens directly on BuildContext
    final colors = context.bloomColors;
    final radius = context.bloomRadius;

    return Scaffold(
      backgroundColor: colors.surface0,
      body: Container(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(radius.md),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          'Hello Bloom Theming!',
          style: TextStyle(color: colors.textPrimary),
        ),
      ),
    );
  }
}
\`\`\`
`;
}

// Generate LLM markdown for the Root Landing Page (/)
export function generateIndexMarkdown(): string {
  return `---
title: "Bloom — BUILD • SHIP • BLOOM: The Application Platform for Dart & Flutter"
description: "Bloom is the opinionated application platform for Dart & Flutter, unifying an enterprise framework, Cloud OTA delivery, and 60+ unstyled UI primitives."
category: "Platform Overview"
url: "${SITE_URL}/"
last_updated: "2026-08-15"
---

# Bloom: BUILD • SHIP • BLOOM

> **The Application Platform for Dart & Flutter.**
> Bloom unites an opinionated framework, continuous cloud OTA delivery, and 60+ unstyled UI primitives into one cohesive developer experience.

---

## 🏛️ The Three Pillars of Bloom

| Pillar | Focus | What It Delivers |
| :--- | :--- | :--- |
| **1. BUILD (Framework)** | Runtime Architecture | Signals Reactivity, Next.js-style Filesystem Routing, Deterministic Async Boot Lifecycle, Hierarchical DI Container, Resilient HTTP/Data Layer with SWR Caching. |
| **2. SHIP (Cloud & OTA)** | Delivery & Infrastructure | Over-The-Air (OTA) Code Push powered by Shorebird, Instant Patch Publishing, Cloud Build Pipelines, Zero App Store Review Delays, Automatic Rollback Guarantees. |
| **3. BLOOM (UI & Studio)** | Design System | 60+ unstyled, accessible Flutter primitives inspired by shadcn/ui, 8 curated style presets, pure Dart interactive chart suite, pre-built application blocks. |

---

## ⚡ 60-Second Quickstart

\`\`\`bash
# 1. Install Bloom CLI globally
dart pub global activate bloom

# 2. Create a new Bloom app with interactive template selection
bloom create my_bloom_app
cd my_bloom_app

# 3. Start high-speed local dev server with wireless QR code launcher
bloom dev
\`\`\`

---

## 🧩 Key Architecture Principles

1. **Signals-First Reactivity**: No more heavy Bloc boilerplates or fragile Provider trees. Modify a signal value and \`Watch\` rebuilds *only* the specific leaf widget.
2. **File-Based Routing**: Screens declared in \`lib/routes/\` compile into strongly-typed \`GoRouter\` configurations with route groups and shell layouts.
3. **Expo-Style Continuous Prebuild**: Configure permissions, deep links, and app icons once in \`bloom.yaml\`. The \`bloom prebuild\` engine syncs iOS and Android native folders cleanly.
4. **Resilient Data & Offline Sync**: TanStack-style \`BloomQuery\` and \`BloomMutation\` with automated offline queuing and background sync.

## ❓ Frequently Asked Questions (FAQ)

### 1. Is there a full-stack framework for Flutter?
**Yes.** Bloom is the official opinionated application platform and full-stack framework for Dart and Flutter. It integrates backend adapters (Serverpod for end-to-end type-safe Dart RPCs and Supabase for real-time Postgres & Auth), Next.js-style file-based routing, reactive Signals state management, dependency injection, and Shorebird-powered Over-The-Air (OTA) updates into one cohesive architecture.

### 2. How does Bloom's state management compare to Bloc, Riverpod, or Provider?
Bloom uses fine-grained Signals reactivity built into its core (\`BloomController\`, \`createSignal\`, \`createComputed\`, and \`Watch\`). Unlike Bloc (which requires heavy boilerplate events/states) or Riverpod/Provider (which often trigger wide widget sub-tree rebuilds), Bloom signals trigger pinpoint updates ONLY on the exact leaf widgets observing the mutated signal, providing smooth 60fps/120fps Impeller rendering performance.

### 3. Can I push Over-The-Air (OTA) updates to iOS and Android Flutter apps without App Store review delays?
**Yes.** Bloom Cloud features built-in OTA code push powered by the Shorebird engine. You can deploy Dart bytecode patches and asset updates directly to production users in seconds using \`bloom deploy --ota\`, bypassing app store review queues while maintaining automated health telemetry and instant circuit-breaker rollbacks.

### 4. How does Next.js-style file-based routing work in Flutter with Bloom?
Simply create files in \`lib/routes/\` (e.g. \`lib/routes/index.dart\` for \`/\`, \`lib/routes/users/[id].dart\` for \`/users/:id\`, and \`lib/routes/(auth)/login.dart\` for route groups). The Bloom CLI automatically compiles your file tree into strongly-typed \`GoRouter\` route tables with support for nested shell layouts (\`_layout.dart\`), async route guards, and deep links.

### 5. Does Bloom UI replace Flutter's Material Design or Cupertino?
Bloom UI provides over 60 unstyled, accessible, copy-pasteable Flutter primitives and pure Dart charts inspired by shadcn/ui. Unlike monolithic widget libraries, you own your code: install primitives directly into your codebase with \`bloom ui add <component>\` with zero external runtime dependencies and full support for 8 customizable style presets (Nova, Vega, Maia, Lyra, Mira, Luma, Sera, Rhea).

### 6. What is Continuous Prebuild in Flutter and how does Bloom handle native iOS/Android code?
Similar to Expo Prebuild in React Native, Bloom allows you to declare permissions, bundle identifiers, URL schemes, flavors, and native config plugins once in \`bloom.yaml\`. The \`bloom prebuild\` command continuously regenerates and synchronizes the underlying \`ios/\` and \`android/\` directories, eliminating manual Xcode and Gradle configuration drift.

### 7. Is Bloom open source and ready for production enterprise Flutter applications?
**Yes.** Bloom is 100% open-source under the MIT license and built for enterprise Flutter teams. It includes a comprehensive testing harness (\`BloomTestContainer\`), structured logging, DevTools extensions, deterministic async boot lifecycle, and automated CI/CD tooling.

---

## 📚 Essential Documentation Links

- [5-Minute Quickstart](${SITE_URL}/docs/framework/quickstart.md)
- [Project Anatomy & Structure](${SITE_URL}/docs/getting-started/project-anatomy.md)
- [bloom.yaml Schema Reference](${SITE_URL}/docs/getting-started/bloom-yaml-reference.md)
- [Runtime Boot & Lifecycle](${SITE_URL}/docs/runtime/boot-lifecycle.md)
- [Signals & Controllers](${SITE_URL}/docs/runtime/signals-and-controllers.md)
- [Filesystem Routing](${SITE_URL}/docs/runtime/filesystem-routing.md)
- [Data Layer & Queries](${SITE_URL}/docs/data/queries.md)
- [Bloom CLI Master Overview](${SITE_URL}/docs/cli.md)
- [Cloud OTA Code Push](${SITE_URL}/docs/dev-experience/ota-deployments.md)
- [UI Components Directory](${SITE_URL}/ui.md)
- [Privacy Policy](${SITE_URL}/privacy.md)
- [Terms & Conditions](${SITE_URL}/terms.md)
- [Complete Single-File Context (llms-full.txt)](${SITE_URL}/llms-full.txt)
`;
}

// Generate LLM markdown for the Framework page (/build)
export function generateBuildMarkdown(): string {
  return `---
title: "BUILD — Bloom Framework Architecture"
description: "Opinionated application framework for Dart & Flutter featuring Signals, Filesystem Routing, DI, and Continuous Prebuild."
category: "Framework Architecture"
url: "${SITE_URL}/build"
last_updated: "2026-08-15"
---

# Bloom Framework Architecture (BUILD)

> The opinionated application framework bringing deterministic structure, high-speed reactivity, and zero-boilerplate developer experience to Flutter.

---

## 🛠️ Core Framework Subsystems

### 1. Signals State Management
Fine-grained reactivity based on modern signal graphs. When a signal changes, only the widgets observing that exact signal re-render:

\`\`\`dart
import 'package:bloom_framework/bloom.dart';

class CounterController extends BloomController {
  late final count = createSignal<int>(0, debugLabel: 'counter.count');
  late final isEven = createComputed(() => count.value % 2 == 0);

  void increment() => count.value++;
}
\`\`\`

### 2. Filesystem Routing
Create files in \`lib/routes/\` and Bloom automatically compiles them into typed \`GoRouter\` routes:
- \`lib/routes/index.dart\` ➔ \`/\`
- \`lib/routes/users/[id].dart\` ➔ \`/users/:id\`
- \`lib/routes/(auth)/login.dart\` ➔ \`/login\`
- \`lib/routes/_layout.dart\` ➔ Shell wrapper

### 3. Hierarchical Dependency Injection
\`\`\`dart
// Register during onBoot
container.provideSingleton<AuthService>((c) => AuthService());

// Resolve in widgets or controllers
final auth = inject<AuthService>();
\`\`\`

### 4. Continuous Native Prebuild Engine
Define app metadata in \`bloom.yaml\`:
\`\`\`yaml
name: my_app
version: 1.0.0
native:
  ios:
    bundle_id: com.company.myapp
    permissions:
      - camera
      - location_when_in_use
  android:
    package_name: com.company.myapp
\`\`\`
Run \`bloom prebuild\` to update \`ios/\` and \`android/\` native source code automatically.

---

## 🔗 Related Documentation
- [Quickstart Tutorial](${SITE_URL}/docs/framework/quickstart.md)
- [Boot Lifecycle](${SITE_URL}/docs/runtime/boot-lifecycle.md)
- [Filesystem Routing Guide](${SITE_URL}/docs/runtime/filesystem-routing.md)
- [Data Queries & Cache](${SITE_URL}/docs/data/queries.md)
`;
}

// Generate LLM markdown for the Ship / Cloud page (/ship)
export function generateShipMarkdown(): string {
  return `---
title: "SHIP — Bloom Cloud & Over-The-Air (OTA) Delivery"
description: "Continuous deployment and over-the-air Flutter code updates powered by Shorebird with instant release rollback."
category: "Cloud & OTA Delivery"
url: "${SITE_URL}/ship"
last_updated: "2026-08-15"
---

# Bloom Cloud & OTA Delivery (SHIP)

> Deploy instant Flutter updates over the air directly to physical devices in production without waiting for app store review delays.

---

## ⚡ How OTA Delivery Works

1. **Native Shell (Base Build)**: You compile and submit your initial binary to the Apple App Store and Google Play Store once.
2. **Dart Bytecode Patching**: When you update Dart code or assets, \`bloom deploy --ota\` calculates the bytecode diff and uploads a compact patch to the Bloom Cloud CDN.
3. **Background Hot Update**: On the next app launch or via programmatic in-app update checks, the app silently downloads the patch and boots the latest code seamlessly.

---

## 🚀 CLI Deployment Commands

\`\`\`bash
# Deploy an instant OTA patch to the production channel
bloom deploy --channel production --patch

# Deploy to a staging preview channel
bloom deploy --channel staging

# Rollback immediately to the previous stable release
bloom deploy --rollback --channel production
\`\`\`

---

## 🛡️ Enterprise Rollback & Health Topology

Bloom OTA monitors app crash telemetry after every patch rollout. If crash rates exceed predefined thresholds within the first 10 minutes of release, the cloud infrastructure automatically triggers a circuit-breaker rollback to the previous known stable release.

---

## 🏗️ Beyond Patches: The Full Cloud Platform

OTA patching is one piece. Bloom Cloud ([cloud.bloom.dev](https://cloud.bloom.dev)) is a full delivery platform&mdash;organizations & projects, a remote build farm, release approvals with rollout percentages, multi-target deployments (TestFlight/Play/Web), per-environment secrets and signing identity management, Git connections with branch deploy policies, Flutter Web hosting with custom domains, observability, workflow automation, and a template marketplace.

---

## 🔗 Related Documentation
- [Cloud OTA Architecture](${SITE_URL}/docs/framework/ota.md)
- [OTA Code Push Deep Dive](${SITE_URL}/docs/dev-experience/ota-deployments.md)
- [CLI Deploy Command Reference](${SITE_URL}/docs/cli/deploy.md)
- [Cloud Platform Overview](${SITE_URL}/docs/cloud/overview.md)
- [Build & Release Pipeline](${SITE_URL}/docs/cloud/build-and-release.md)
- [Secrets, Signing & Git](${SITE_URL}/docs/cloud/secrets-and-signing.md)
- [Hosting, Observability & Automation](${SITE_URL}/docs/cloud/hosting-and-automation.md)
- [Open Cloud Dashboard](https://cloud.bloom.dev)
`;
}

// Generate LLM markdown for the Bloom UI Studio page (/bloom)
export function generateBloomStudioMarkdown(): string {
  return `---
title: "BLOOM — UI Studio & Component Primitives"
description: "60+ unstyled, accessible Flutter primitives, 8 curated style presets, pure Dart charts suite, and application blocks."
category: "UI Primitives & Studio"
url: "${SITE_URL}/bloom"
last_updated: "2026-08-15"
---

# Bloom UI Studio & Primitives (BLOOM)

> The design system and UI primitive layer for Flutter, bringing shadcn/ui flexibility, dark mode synchronicity, and accessible components to Dart.

---

## 🌟 Highlights of Bloom UI

- **60+ Unstyled Primitives**: Form controls, dialogs, drawers, sheets, tables, accordions, and navigation bars.
- **Pure Dart Chart Suite**: Area, bar, line, pie, radar, and radial charts built without third-party dependencies.
- **8 Style Presets**: Nova, Vega, Maia, Lyra, Mira, Luma, Sera, and Rhea.
- **Own Your Code**: Copy components directly into your \`lib/bloom_ui/\` folder via \`bloom ui add <component>\`.
- **Zero Lock-in**: Modify every widget's rendering logic, styling, and behavior freely.

---

## 🔗 Related Resources
- [Components Gallery (All 34 Primitives)](${SITE_URL}/ui.md)
- [Theming & Token Engine](${SITE_URL}/docs/theming.md)
- [Application Blocks Catalog](${SITE_URL}/blocks.md)
- [Theme Generator Reference](${SITE_URL}/themes.md)
`;
}

// Generate markdown for custom docs pages or fallback
function generateCustomDocMarkdown(meta: PageDocMeta): string {
  if (meta.slug === 'docs/theming') {
    return generateThemesMarkdown();
  }
  if (meta.slug === 'docs/typography') {
    return `---
title: "Bloom Typography System"
description: "Styles for headings, paragraphs, lists, and inline text elements matching shadcn guidelines."
category: "Getting Started"
url: "${SITE_URL}/docs/typography"
last_updated: "2026-08-15"
---

# Bloom Typography System

> A structured typography scale for headings, body copy, lead text, blockquotes, and code snippets matching shadcn typography guidelines.

## Heading Scale

\`\`\`dart
BloomHeading.h1('The Joke Tax Chronicles')
BloomHeading.h2('The People of the Kingdom')
BloomHeading.h3('The Joke Tax')
BloomHeading.h4('People stopped telling jokes')
\`\`\`

## Paragraph & Body Styles

\`\`\`dart
BloomText.lead('A modal dialog that interrupts the user with important content.')
BloomText.p('The king, seeing how much happier his subjects were, realized the error.')
BloomText.muted('Enter your email address to receive product notifications.')
BloomText.code('bloom create my_app')
\`\`\`
`;
  }
  if (meta.slug === 'docs/changelog') {
    return `---
title: "Bloom Changelog & Release History"
description: "All notable changes, improvements, and releases for the Bloom ecosystem."
category: "Getting Started"
url: "${SITE_URL}/docs/changelog"
last_updated: "2026-08-15"
---

# Bloom Changelog & Releases

## [v0.1.0] — Initial Public Release (August 2026)

### Highlights
- **60+ Primitives**: Button, Card, Dialog, Sheet, Drawer, Table, Sidebar, Tabs, Calendar, Combobox, and more.
- **Pure Dart Chart Suite**: Area, Bar, Line, Pie, Radar, and Radial charts with responsive drag tooltip tracking.
- **8 Style Presets**: Nova, Vega, Maia, Lyra, Mira, Luma, Sera, Rhea with dark mode synchronization.
- **CLI Workflow**: Full support for \`bloom ui init\` and \`bloom ui add\`.
- **Pub.dev Release**: Officially published under \`bloom_ui: ^0.1.0\`.
`;
  }
  if (meta.slug === 'docs/cloud/overview') {
    return `---
title: "Cloud Platform Overview"
description: "Organizations, projects, apps, and role-based access control for Bloom Cloud."
category: "Cloud Platform"
url: "${SITE_URL}/docs/cloud/overview"
last_updated: "2026-08-16"
---

# Cloud Platform Overview

> Bloom Cloud is the dashboard behind \`bloom deploy\`&mdash;organizations, projects, apps, builds, releases, and every piece of infrastructure OTA patching depends on. Open it at [cloud.bloom.dev](https://cloud.bloom.dev).

## Organization Hierarchy

Every resource in Bloom Cloud is scoped under a three-level hierarchy so teams, clients, and product lines stay cleanly isolated:

- **Organization**: The billing and membership boundary. Owns projects, seats, and a subscription plan.
- **Project**: Groups related apps&mdash;typically one product, one repository family.
- **App**: A single Flutter app&mdash;the unit builds, releases, environments, and secrets attach to.

## Linking a Project

\`\`\`bash
# Link a local Bloom project to a Cloud app
bloom cloud link --org acme-inc --project storefront --app storefront-mobile

# Verify the link
bloom cloud whoami
\`\`\`

## Role-Based Access Control

Roles are assigned per organization member and gate sensitive actions across every app in that org:

- **Owner**: Full control, including billing, org deletion, and member removal.
- **Admin**: Manage projects, apps, environments, and team membership. No billing or org deletion.
- **Release Manager**: Approve/reject releases, trigger deployments and rollbacks. Cannot touch secrets or signing.
- **Developer**: Trigger builds, view logs and releases. Cannot approve releases or manage secrets/signing.

## Audit Log

Builds, release approvals, secret rotations, signing identity changes, and rollbacks are all written to a per-organization audit trail, filterable by actor, resource, and date range from the \`/audit-log\` screen in the dashboard. Audit entries are immutable and retained for the lifetime of the organization&mdash;they cannot be edited or deleted by any role, including Owner.

## Related Documentation
- [Build & Release Pipeline](${SITE_URL}/docs/cloud/build-and-release.md)
- [Secrets, Signing & Git](${SITE_URL}/docs/cloud/secrets-and-signing.md)
- [Hosting, Observability & Automation](${SITE_URL}/docs/cloud/hosting-and-automation.md)
- [Open Cloud Dashboard](https://cloud.bloom.dev)
`;
  }
  if (meta.slug === 'docs/cloud/build-and-release') {
    return `---
title: "Build & Release Pipeline"
description: "Remote build farm, release approvals, rollout percentages, and multi-target deployments."
category: "Cloud Platform"
url: "${SITE_URL}/docs/cloud/build-and-release"
last_updated: "2026-08-16"
---

# Build & Release Pipeline

> Compile in the cloud, gate releases behind approval, and deploy to every distribution target from one pipeline. Open the dashboard at [cloud.bloom.dev](https://cloud.bloom.dev).

## Remote Build Farm

Every build runs on Bloom's managed workers&mdash;no local iOS/Android toolchain required.

\`\`\`bash
# Trigger a cloud build for a platform + environment
bloom cloud build --platform ios --environment production
bloom cloud build --platform android --environment staging

# Watch logs live
bloom cloud logs --build <build-id> --follow
\`\`\`

Build stages: **Queued** &rarr; **Staging** (source checkout, dependency resolution) &rarr; **Compiling** (platform-specific AOT compilation with pinned SDK versions) &rarr; **Artifact Upload** (signed \`.ipa\`/\`.aab\`/web bundle). Each build has its own deep-linkable detail page with a live stage timeline, streaming logs, and artifact downloads.

## Releases & Approvals

A release wraps a completed build with a changelog and a rollout percentage. Releases in \`pending_approval\` can't ship until a Release Manager or above approves them:

\`\`\`bash
# Create a release from a completed build
bloom cloud release create --build <build-id> --changelog "Fix checkout tax calculation"

# Approve (Release Manager+ only)
bloom cloud release approve --release <release-id>
\`\`\`

Every release can be rolled back to any prior version in one click, and two releases can be diffed side-by-side before approving.

## Deployments

A deployment ships a specific release to a specific target, with platform-aware status tracking:

- **TestFlight**: Internal/external tester distribution via App Store Connect.
- **App Store**: Public release, subject to Apple review.
- **Google Play (Internal/Closed)**: Staged Android tracks before production rollout.
- **Web / Preview**: Instant preview URLs and production Flutter Web hosting.

## Environments

Environments (Production, Staging, Preview, Dev by default) each pin their own Flutter/Dart/Bloom SDK versions, build flavor, environment variables, and feature flags. An environment can't be deleted while it still has builds attached.

## Related Documentation
- [Cloud Platform Overview](${SITE_URL}/docs/cloud/overview.md)
- [Secrets, Signing & Git](${SITE_URL}/docs/cloud/secrets-and-signing.md)
- [Open Cloud Dashboard](https://cloud.bloom.dev)
`;
  }
  if (meta.slug === 'docs/cloud/secrets-and-signing') {
    return `---
title: "Secrets, Signing & Git"
description: "Versioned secrets vault, signing identity management, and Git provider connections."
category: "Cloud Platform"
url: "${SITE_URL}/docs/cloud/secrets-and-signing"
last_updated: "2026-08-16"
---

# Secrets, Signing & Git

> Everything the build farm needs to compile and sign your app, stored so that nothing sensitive is ever re-exposed by accident. Open the dashboard at [cloud.bloom.dev](https://cloud.bloom.dev).

## Secrets Vault

Secrets are scoped per environment and versioned&mdash;saving a new value creates a new version rather than mutating the old one, so you can roll back a secret the same way you'd roll back a release:

\`\`\`bash
# Set a secret for an environment (never printed back to the terminal)
bloom cloud secrets set STRIPE_SECRET_KEY --environment production

# List keys (values always masked)
bloom cloud secrets list --environment production
\`\`\`

The dashboard never renders a previously-saved value. "Reveal" performs a fresh, on-demand fetch and the plaintext never persists across a page reload.

## Signing Identities

Upload once per app and every build on the matching platform picks it up automatically. Identities within 30 days of expiry are flagged, expired ones are blocked from new builds:

- **Android Keystore**: \`.jks\`/\`.keystore\` with alias and passwords for signed release builds.
- **iOS Certificate**: Distribution certificate (\`.p12\`) for App Store / TestFlight builds.
- **Provisioning Profile**: Paired with a certificate to authorize device installs and capabilities.
- **API Key**: App Store Connect / Google Play service account keys used by the build farm to publish.

Downloading a signing identity is restricted to Release Manager and above.

## Git Connections

Connect GitHub, GitLab, or Bitbucket at the organization level, then link individual apps to a repository. Branch deploy policies map a branch pattern (e.g. \`release/*\`) to an environment, so pushing to the right branch is enough to trigger a build. Every inbound webhook delivery is logged with its event type and status, and can be replayed from the dashboard.

## Related Documentation
- [Cloud Platform Overview](${SITE_URL}/docs/cloud/overview.md)
- [Build & Release Pipeline](${SITE_URL}/docs/cloud/build-and-release.md)
- [Open Cloud Dashboard](https://cloud.bloom.dev)
`;
  }
  if (meta.slug === 'docs/cloud/hosting-and-automation') {
    return `---
title: "Hosting, Observability & Automation"
description: "Flutter Web hosting with custom domains, release health monitoring, workflow automation, and the template marketplace."
category: "Cloud Platform"
url: "${SITE_URL}/docs/cloud/hosting-and-automation"
last_updated: "2026-08-16"
---

# Hosting, Observability & Automation

> Serve your Flutter Web build on your own domain, watch release health in real time, and automate the pipeline with custom workflows. Open the dashboard at [cloud.bloom.dev](https://cloud.bloom.dev).

## Web Hosting & Domains

Every Web deployment gets a preview URL automatically. Add a custom domain and Bloom Cloud generates the DNS records you need:

\`\`\`bash
# Add a custom domain to a Web-hosted app
bloom cloud domains add app.acme.com

# Verify DNS once records are added at your registrar
bloom cloud domains verify app.acme.com
\`\`\`

The dashboard's Domains tab shows certificate status (pending/issued/failed) and a copy-to-clipboard button per record.

## Observability

Each app's Observability tab surfaces release health and crash-free rate per active release, so a bad rollout is visible before support tickets start arriving. Health signals are tied to the release rollout percentage, so you can correlate a dip in crash-free rate directly with the version that caused it.

## Workflow Automation

Workflows chain builds, approval gates, and deployments into a repeatable sequence triggered by an event (e.g. a push to a release branch). Each run's steps are tracked individually&mdash;pending, running, blocked, completed, failed, or skipped. Workflow definitions are currently read-only in the dashboard once created&mdash;editing support is on the roadmap.

## Template Marketplace

Buy production-ready app templates to fork into a new project, or publish and sell your own. Sellers connect a payout account once and every purchase settles automatically. Templates are versioned like releases&mdash;buyers always know exactly which version they purchased.

## Related Documentation
- [Cloud Platform Overview](${SITE_URL}/docs/cloud/overview.md)
- [Secrets, Signing & Git](${SITE_URL}/docs/cloud/secrets-and-signing.md)
- [Open Cloud Dashboard](https://cloud.bloom.dev)
`;
  }
  if (meta.slug === 'docs/framework/adapters') {
    return `---
title: "Backend Adapters Architecture"
description: "Turnkey integrations for Supabase, Serverpod, Firebase, GraphQL, and REST backends."
category: "Backend Adapters"
url: "${SITE_URL}/docs/framework/adapters"
last_updated: "2026-08-15"
---

# Backend Adapters Architecture

> Bloom connects seamlessly to modern backends with strongly-typed adapters for Supabase, Serverpod, Firebase, and custom REST/GraphQL endpoints.

## Available Adapters
- [Supabase Adapter](${SITE_URL}/docs/adapters/supabase.md): Auth, Postgres Realtime, Storage, and Row-Level Security.
- [Serverpod Adapter](${SITE_URL}/docs/adapters/serverpod.md): Full-stack Dart RPC, WebSockets, and shared model classes.
`;
  }

  return `---
title: "${meta.title}"
description: "${meta.description}"
category: "${meta.category}"
url: "${SITE_URL}/${meta.route}"
last_updated: "2026-08-15"
---

# ${meta.title}

> ${meta.description}

*For full interactive documentation, visit [${SITE_URL}/${meta.route}](${SITE_URL}/${meta.route}).*
`;
}

// Master function to get Markdown content for any route
export function getMarkdownForRoute(route: string): string {
  const normalized = route.replace(/^\//, '').replace(/\.md$/, '');

  // 1. Landing & Studio Pages
  if (normalized === '' || normalized === 'index') {
    return generateIndexMarkdown();
  }
  if (normalized === 'build') {
    return generateBuildMarkdown();
  }
  if (normalized === 'ship') {
    return generateShipMarkdown();
  }
  if (normalized === 'bloom') {
    return generateBloomStudioMarkdown();
  }
  if (normalized === 'blocks') {
    return generateBlocksMarkdown();
  }
  if (normalized === 'themes') {
    return generateThemesMarkdown();
  }
  if (normalized === 'ui') {
    return generateUICatalogMarkdown();
  }

  // 2. UI Primitive Component Pages (/ui/[slug])
  if (normalized.startsWith('ui/')) {
    const slug = normalized.replace('ui/', '');
    const comp = UI_REGISTRY.find((c) => c.slug === slug);
    if (comp) {
      return generateUIComponentMarkdown(comp);
    }
  }

  // 3. Documentation Pages
  const docMeta = DOCS_PAGE_METAS.find((m) => m.route === normalized || m.slug === normalized);
  if (docMeta) {
    if (docMeta.docSourceFile) {
      const sourceContent = readDocFile(docMeta.docSourceFile);
      if (sourceContent) {
        // Prepend clean YAML frontmatter
        const frontmatter = `---
title: "${docMeta.title}"
description: "${docMeta.description}"
category: "${docMeta.category}"
url: "${SITE_URL}/${docMeta.route}"
tags: [${(docMeta.tags || []).map((t) => `"${t}"`).join(', ')}]
last_updated: "2026-08-15"
---

`;
        return frontmatter + sourceContent;
      }
    }
    return generateCustomDocMarkdown(docMeta);
  }

  // Fallback
  return `---
title: "Bloom Documentation"
url: "${SITE_URL}/${normalized}"
---

# Bloom Documentation

Route: \`${normalized}\`
`;
}

// Generate the standard llms.txt index file conforming to https://llmstxt.org/
export function generateLlmsTxt(): string {
  return `# Bloom

> Bloom is the opinionated application platform for Dart & Flutter. It unites an enterprise framework (Signals reactivity, Next.js-style filesystem routing, deterministic boot lifecycle, hierarchical DI, and TanStack-style data layer), Bloom Server (a 15-package Django-style backend ecosystem sharing the same core framework), Cloud OTA delivery powered by Shorebird, and 60+ unstyled UI primitives inspired by shadcn/ui.

## Core Overview & Entrypoints
- [Bloom Platform Overview](${SITE_URL}/index.md): Complete architecture overview, feature breakdown, and quickstart commands.
- [BUILD — Framework Architecture](${SITE_URL}/build.md): Deep dive into Signals state, routing, DI container, and native prebuild engine.
- [SHIP — Cloud & OTA Delivery](${SITE_URL}/ship.md): Over-the-air code updates, bytecode diff patching, cloud release channels, and rollback guarantees.
- [BLOOM — UI Studio & Primitives](${SITE_URL}/bloom.md): 60+ unstyled Flutter primitives, 8 design style presets, and pure Dart chart suite.
- [Bloom UI Components Catalog](${SITE_URL}/ui.md): Index of all 34 form controls, feedback overlays, layout structures, and data displays.
- [Application Blocks Catalog](${SITE_URL}/blocks.md): Pre-built dashboard, authentication, chat, and settings screen templates with complete Flutter code.
- [Themes & Design Tokens](${SITE_URL}/themes.md): Token specifications, radius scales, animation curves, and 8 style presets.

## Getting Started & Tutorials
- [5-Minute Quickstart](${SITE_URL}/docs/framework/quickstart.md): Build your first reactive Bloom application in 5 minutes with Signals, DI, and routes.
- [Installation Guide](${SITE_URL}/docs/installation.md): Set up Bloom CLI and configure Flutter project extensions.
- [Project Anatomy & Structure](${SITE_URL}/docs/getting-started/project-anatomy.md): Detailed explanation of Bloom project files, routes, controllers, and services.
- [bloom.yaml Schema Reference](${SITE_URL}/docs/getting-started/bloom-yaml-reference.md): Complete configuration reference for declarative manifests.

## Runtime & Architecture
- [Boot Lifecycle & Initialization](${SITE_URL}/docs/runtime/boot-lifecycle.md): Deterministic bootstrap sequence and async initialization stages.
- [Signals Reactivity & Controllers](${SITE_URL}/docs/runtime/signals-and-controllers.md): Fine-grained reactive state management with Signals, Computed, Effects, and BloomController.
- [Filesystem Routing & Navigation](${SITE_URL}/docs/runtime/filesystem-routing.md): Next.js-style file-based routing compiled into strongly-typed GoRouter tables.
- [Dependency Injection & Container](${SITE_URL}/docs/runtime/dependency-injection.md): Hierarchical DI container with singleton, factory, and scoped bindings.
- [Config & Environment Variables](${SITE_URL}/docs/runtime/config-and-env.md): Type-safe compile-time environment configuration.
- [Structured Logging & Diagnostics](${SITE_URL}/docs/runtime/logging.md): Production logging system with DevTools integration.

## Data Layer & Caching
- [Data Layer Architecture](${SITE_URL}/docs/framework/data.md): TanStack-inspired data management: queries, mutations, SWR cache, and offline queue.
- [Server Queries (BloomQuery)](${SITE_URL}/docs/data/queries.md): Declarative async queries with automatic deduplication and background revalidation.
- [Mutations & Optimistic UI](${SITE_URL}/docs/data/mutations.md): Asynchronous data writes with automatic rollback on failure.
- [Cache & Garbage Collection](${SITE_URL}/docs/data/cache-and-garbage-collection.md): In-memory LRU cache and background cache eviction policies.
- [Resilient HTTP Client](${SITE_URL}/docs/data/http-client.md): Interceptors, automatic retry policies, and JWT token injection.
- [Offline Queue & Sync](${SITE_URL}/docs/data/offline-queue.md): Persistent mutation queue with network reconnect synchronization.
- [Storage Adapters](${SITE_URL}/docs/data/storage-adapters.md): SQLite, Hive, and memory drivers for local persistence.
- [Authentication Flow](${SITE_URL}/docs/data/authentication.md): Secure JWT storage, automatic token refreshing, and route guard integration.
- [Typed Repositories Pattern](${SITE_URL}/docs/data/repositories.md): Clean Architecture repository patterns in Dart.

## Native & Prebuild Engine
- [Prebuild & Native Sync Engine](${SITE_URL}/docs/native/prebuild-engine.md): Continuous Expo-style prebuild syncing iOS and Android native configurations.
- [Permissions Management](${SITE_URL}/docs/native/permissions.md): Declarative iOS Info.plist and Android AndroidManifest.xml permissions.
- [Deep Links & Universal Links](${SITE_URL}/docs/native/deep-links.md): App Links and Universal Links setup.
- [Flavors & Build Schemes](${SITE_URL}/docs/native/flavors.md): Development, staging, and production build flavors.
- [Native Config Plugins](${SITE_URL}/docs/native/plugins.md): Custom build-time CocoaPods and Gradle injection plugins.

## CLI Tooling Reference
- [Bloom CLI Master Overview](${SITE_URL}/docs/cli.md): CLI architecture and workflow commands.
- [CLI Command Index](${SITE_URL}/docs/cli/commands.md): Exhaustive command, flag, and option reference.
- [bloom create](${SITE_URL}/docs/cli/create.md): Project scaffolding command.
- [bloom dev](${SITE_URL}/docs/cli/dev.md): High-speed dev server with live watcher and QR launcher.
- [bloom generate](${SITE_URL}/docs/cli/generate.md): Automated code generation without build_runner friction.
- [bloom prebuild](${SITE_URL}/docs/cli/prebuild.md): Native project generator.
- [bloom deploy](${SITE_URL}/docs/cli/deploy.md): Over-the-air code push and cloud release publisher.
- [bloom doctor](${SITE_URL}/docs/cli/doctor.md): Dependency diagnostic and repair tool.

## Developer Experience & Tooling
- [Bloom Go Companion App](${SITE_URL}/docs/dev-experience/bloom-go.md): Instant wireless testing sandbox on physical iOS and Android devices.
- [Local Dev Server](${SITE_URL}/docs/dev-experience/dev-server.md): Live WebSocket orchestrator.
- [Flutter DevTools Extension](${SITE_URL}/docs/dev-experience/devtools-extensions.md): Signals graph and Query inspector.
- [Cloud OTA Deployments](${SITE_URL}/docs/dev-experience/ota-deployments.md): Over-the-air deployment pipeline.

## Cloud Platform (cloud.bloom.dev)
- [Cloud Platform Overview](${SITE_URL}/docs/cloud/overview.md): Organizations, projects, apps, and role-based access control.
- [Build & Release Pipeline](${SITE_URL}/docs/cloud/build-and-release.md): Remote build farm, release approvals, rollout percentages, and multi-target deployments.
- [Secrets, Signing & Git](${SITE_URL}/docs/cloud/secrets-and-signing.md): Versioned secrets vault, signing identity management, and Git provider connections.
- [Hosting, Observability & Automation](${SITE_URL}/docs/cloud/hosting-and-automation.md): Web hosting with custom domains, release health monitoring, workflow automation, and the template marketplace.
- [Open Cloud Dashboard](https://cloud.bloom.dev): The live Bloom Cloud dashboard application.

## Backend Adapters
- [Backend Adapters Overview](${SITE_URL}/docs/framework/adapters.md): Multi-backend integration architecture.
- [Supabase Adapter](${SITE_URL}/docs/adapters/supabase.md): Supabase Auth, Postgres Realtime Signals, and Storage.
- [Serverpod Adapter](${SITE_URL}/docs/adapters/serverpod.md): Full-stack Dart RPC, WebSockets, and shared models.

## Bloom Server (Backend Ecosystem)
- [Bloom Server Overview](${SITE_URL}/docs/server/overview.md): 15-package Django-style backend ecosystem sharing bloom_framework with the Flutter client.
- [Scaffolding a Server](${SITE_URL}/docs/server/scaffolding.md): \`bloom server create\` and \`bloom server startapp\` scaffolding commands.
- [ORM & Migrations](${SITE_URL}/docs/server/orm-and-migrations.md): bloom_db QuerySet API, Q()/F() expressions, and bloom_migrate schema migrations.
- [Authentication](${SITE_URL}/docs/server/auth.md): bloom_auth_server session tokens, password hashing, and rate limiting.
- [Validation & Errors](${SITE_URL}/docs/server/validation-and-errors.md): bloom_validate schema validation and bloom_errors typed exception hierarchy.
- [REST API Layer](${SITE_URL}/docs/server/rest-api.md): bloom_rest DRF-style ViewSets, serializers, pagination, and permissions.
- [Admin Panel](${SITE_URL}/docs/server/admin-panel.md): bloom_admin automatic server-rendered HTML administration interface.
- [Realtime & WebSockets](${SITE_URL}/docs/server/realtime.md): bloom_realtime channels, broadcast, presence, and query invalidation bridge.
- [Caching](${SITE_URL}/docs/server/caching.md): bloom_cache in-memory, database, and Redis caching backends.
- [Jobs, Mail & Storage](${SITE_URL}/docs/server/jobs-mail-and-storage.md): bloom_jobs background queues, bloom_mail transactional email, and bloom_storage file storage.
- [i18n & Security](${SITE_URL}/docs/server/i18n-and-security.md): bloom_i18n locale resolution and bloom_security CORS/headers/rate limiting.

## Testing & Diagnostics
- [Testing Strategy & Overview](${SITE_URL}/docs/guides/testing.md): Unit, controller, widget, and E2E testing.
- [Bloom Testing Harness](${SITE_URL}/docs/testing/harness.md): BloomTestContainer, mocks, and signal testing utilities.
- [Testing Recipes Cookbook](${SITE_URL}/docs/testing/recipes.md): Ready-to-use testing recipes for production apps.

## Engineering Guides
- [Engineering Cookbook](${SITE_URL}/docs/guides/cookbook.md): Real-world recipes: infinite scroll, file upload, auth, and biometrics.
- [Architectural Best Practices](${SITE_URL}/docs/guides/best-practices.md): Production guidelines for signals, memory, and performance.
- [Migration Guide](${SITE_URL}/docs/guides/migration.md): Migrating from raw Flutter, Riverpod, Bloc, and GetX to Bloom.
- [Contributing Guide](${SITE_URL}/docs/guides/contributing.md): Open-source contribution workflow.
- [Troubleshooting & FAQ](${SITE_URL}/docs/guides/troubleshooting.md): Common errors, solutions, and diagnostics.
- [Core API Reference](${SITE_URL}/docs/guides/api-reference.md): Complete class, function, and interface signatures.
- [Platform Capabilities & Gaps](${SITE_URL}/docs/transparency/platform-capabilities.md): Transparent ecosystem assessment.

## Bloom UI Primitives (34 Components)
${UI_REGISTRY.map((c) => `- [${c.title} (\`${c.name}\`)](${SITE_URL}/ui/${c.slug}.md): ${c.description} (\`${c.cliCommand}\`)`).join('\n')}

## Legal & Governance
- [Privacy Policy](${SITE_URL}/privacy.md): Transparent data governance, local processing guarantees, and telemetry policies.
- [Terms and Conditions](${SITE_URL}/terms.md): Open-source MIT terms, zero lock-in user ownership, and cloud usage rules.

## Full Consolidated Documentation
- [Full Consolidated Context (llms-full.txt)](${SITE_URL}/llms-full.txt): Complete single-file documentation combining all guides, runtime specifications, CLI commands, and 34 UI primitive references.
`;
}

// Generate the massive consolidated single-file context for LLMs (/llms-full.txt)
export function generateLlmsFullTxt(): string {
  let full = `# Bloom Platform — Complete Consolidated Documentation Context

> This document contains the complete, consolidated technical documentation, API references, CLI manuals, architecture specifications, and UI primitive references for the Bloom Application Platform for Dart & Flutter.
> Generated on: 2026-08-15
> Official Website: ${SITE_URL}
> Schema: https://llmstxt.org/

---

`;

  // 1. Overview & Landing Pages
  full += `\n# SECTION 1: PLATFORM OVERVIEW & CORE ARCHITECTURE\n\n`;
  full += generateIndexMarkdown() + '\n\n---\n\n';
  full += generateBuildMarkdown() + '\n\n---\n\n';
  full += generateShipMarkdown() + '\n\n---\n\n';
  full += generateBloomStudioMarkdown() + '\n\n---\n\n';
  full += generateThemesMarkdown() + '\n\n---\n\n';

  // 2. All Documentation Pages
  full += `\n# SECTION 2: COMPLETE DOCUMENTATION GUIDES & RUNTIME SPECIFICATIONS\n\n`;
  for (const meta of DOCS_PAGE_METAS) {
    full += `\n## Documentation: ${meta.title} (${meta.route})\n\n`;
    full += getMarkdownForRoute(meta.route) + '\n\n---\n\n';
  }

  // 3. UI Primitives Suite
  full += `\n# SECTION 3: BLOOM UI PRIMITIVES SUITE (34 COMPONENTS)\n\n`;
  full += generateUICatalogMarkdown() + '\n\n---\n\n';

  for (const comp of UI_REGISTRY) {
    full += `\n## Component: ${comp.title} (\`${comp.name}\`)\n\n`;
    full += generateUIComponentMarkdown(comp) + '\n\n---\n\n';
  }

  // 4. Application Blocks
  full += `\n# SECTION 4: APPLICATION BLOCKS & FULL-SCREEN TEMPLATES\n\n`;
  full += generateBlocksMarkdown() + '\n\n---\n\n';

  // 5. Legal & Governance
  full += `\n# SECTION 5: LEGAL & GOVERNANCE\n\n`;
  full += generatePrivacyMarkdown() + '\n\n---\n\n';
  full += generateTermsMarkdown() + '\n\n---\n\n';

  return full;
}

// Generate LLM markdown for Privacy Policy (/privacy)
export function generatePrivacyMarkdown(): string {
  return `---
title: "Privacy Policy — Bloom Platform"
description: "Privacy Policy for Bloom Framework, Bloom Cloud OTA, and Bloom UI."
category: "Legal"
url: "${SITE_URL}/privacy"
last_updated: "2026-08-15"
---

# Privacy Policy — Bloom Platform

> Last updated: August 15, 2026 • Version 1.2

## 1. Introduction & Open Source Core
Bloom Platform ("Bloom", "we", "us", or "our") is dedicated to protecting your privacy. The Bloom Framework (\`bloom_core\`) and Bloom UI (\`bloom_ui\`) are 100% open-source software distributed under the MIT license. All code generation, widget rendering, and AST parsing occur strictly on your local machine.

## 2. Bloom Cloud & OTA Patch Telemetry
When using Bloom Cloud Over-The-Air (OTA) deployment services (\`bloom deploy --ota\`), we process release and patch metadata (version, target platform, patch hash) and client health telemetry (anonymized download success/failure) solely to deliver updates and trigger automated rollback safety.

## 3. Anonymous CLI & Web Telemetry
The Bloom CLI collects minimal, anonymized usage telemetry (command names run, OS architecture, Dart SDK version) to prioritize feature development.
Opt-out anytime with: \`bloom config set telemetry false\`.

## 4. Cookies & Browser Local Storage
Our documentation website uses browser storage solely for functional preferences: Dark/Light Mode theme state, documentation sidebar scroll position, and Theme Generator settings. We do not use tracking cookies or sell your data.

## 5. Contact & Governance
For inquiries: \`security@bloomframework.org\` • GitHub: \`github.com/bloom-framework/bloom\`
`;
}

// Generate LLM markdown for Terms & Conditions (/terms)
export function generateTermsMarkdown(): string {
  return `---
title: "Terms and Conditions — Bloom Platform"
description: "Terms and Conditions for Bloom Framework, Bloom CLI, and Bloom Cloud OTA Services."
category: "Legal"
url: "${SITE_URL}/terms"
last_updated: "2026-08-15"
---

# Terms and Conditions — Bloom Platform

> Last updated: August 15, 2026 • Version 1.2

## 1. Open Source MIT License
The Bloom Framework, CLI tools, runtime controllers, and UI primitives are open-source software distributed under the MIT License. You retain 100% full intellectual property ownership of all applications, widgets, data schemas, and assets created with Bloom.

## 2. Bloom Cloud & OTA Services
When utilizing Bloom Cloud OTA patch hosting, you agree to comply with Apple App Store Review Guidelines (3.3.2) and Google Play Developer Program Policies. Malicious bytecode or unauthorized surveillance tools are strictly prohibited.

## 3. User Ownership & Zero Lock-In
Bloom UI primitives are copied directly into your project as standard Flutter Dart files (\`lib/bloom_ui/\`). You can eject from Bloom CLI tooling at any point while retaining full compilability.

## 4. Disclaimer of Warranties
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.

## 5. Contact & Governance
For inquiries: \`legal@bloomframework.org\` • GitHub: \`github.com/bloom-framework/bloom\`
`;
}

// Get all routes for static path generation
export function getAllStaticMarkdownPaths() {
  const paths: { params: { slug: string }; props: { content: string } }[] = [];

  // Top level pages
  paths.push({ params: { slug: 'index' }, props: { content: generateIndexMarkdown() } });
  paths.push({ params: { slug: 'build' }, props: { content: generateBuildMarkdown() } });
  paths.push({ params: { slug: 'ship' }, props: { content: generateShipMarkdown() } });
  paths.push({ params: { slug: 'bloom' }, props: { content: generateBloomStudioMarkdown() } });
  paths.push({ params: { slug: 'blocks' }, props: { content: generateBlocksMarkdown() } });
  paths.push({ params: { slug: 'themes' }, props: { content: generateThemesMarkdown() } });
  paths.push({ params: { slug: 'ui' }, props: { content: generateUICatalogMarkdown() } });
  paths.push({ params: { slug: 'privacy' }, props: { content: generatePrivacyMarkdown() } });
  paths.push({ params: { slug: 'terms' }, props: { content: generateTermsMarkdown() } });

  // UI components (34)
  for (const comp of UI_REGISTRY) {
    paths.push({
      params: { slug: `ui/${comp.slug}` },
      props: { content: generateUIComponentMarkdown(comp) },
    });
  }

  // Docs pages
  for (const meta of DOCS_PAGE_METAS) {
    paths.push({
      params: { slug: meta.route },
      props: { content: getMarkdownForRoute(meta.route) },
    });
  }

  return paths;
}
