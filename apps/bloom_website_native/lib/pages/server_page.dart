import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/common/server_faq.dart';
import '../components/hero_video_bg.dart';
import '../components/huge_icons.dart';
import '../components/interactive/server_architecture_player.dart';
import '../components/tech_marquee.dart';
import 'page_layout.dart';

const _monorepoTree = '''my_bloom_project/
├── bloom.yaml                    # Root workspace + CLI configuration
├── melos.yaml                    # Monorepo task pipeline
│
├── apps/                         # Executable Applications
│   ├── mobile/                   # 📱 iOS & Android Flutter client (Bloom UI + Signals)
│   ├── web/                      # 🌐 Flutter Web / Admin Dashboard
│   └── server/                   # 🖥️ Bloom Server (Pure Dart AOT @ 78k msgs/s)
│
└── packages/                     # 📦 Shared Internal Packages
    ├── core/                     # 🧠 Shared Models, Schemas & Query Keys (Pure Dart)
    ├── ui/                       # 🎨 Design System & 60+ Bloom UI Primitives
    └── config/                   # ⚙️  Typed Environment Config & Feature Flags''';

BloomNode serverPage() {
  return pageLayout(
    currentPath: '/server',
    petalHighlight: 'purple',
    nextChapterTitle: 'Cloud & CLI — Automated Pipelines',
    nextChapterLink: '/ship',
    nextChapterSubtitle:
        'Deploy over-the-air binary updates and provision server '
        'clusters with bloom deploy.',
    child: Div(
      className: 'relative space-y-24 pb-20',
      children: [
        // 1. Hero Section
        Section(
          className:
              'pt-16 pb-16 lg:pt-24 lg:pb-20 relative overflow-hidden '
              'text-center',
          children: [
            heroVideoBg(mode: 'build'),
            Div(
              className: 'max-w-6xl mx-auto space-y-12 relative z-10 px-4',
              children: [
                Div(
                  className: 'text-center max-w-4xl mx-auto space-y-6',
                  children: [
                    // Status Badge
                    Div(
                      className:
                          'inline-flex items-center gap-2.5 px-3.5 py-1.5 '
                          'rounded-full bg-slate-900/90 dark:bg-black/90 border '
                          'border-slate-700/60 dark:border-zinc-800 text-xs font-mono '
                          'text-slate-300 shadow-md',
                      children: [
                        Span(
                          className: 'flex h-2 w-2 relative shrink-0',
                          children: [
                            Span(
                              className:
                                  'animate-ping absolute inline-flex h-full w-full '
                                  'rounded-full bg-purple-400 opacity-75',
                            ),
                            Span(
                              className:
                                  'relative inline-flex rounded-full h-2 w-2 bg-purple-500',
                            ),
                          ],
                        ),
                        Span(
                          className: 'font-semibold text-slate-200',
                          text: 'BLOOM SERVER',
                        ),
                        Span(
                          className: 'text-slate-600 dark:text-slate-500',
                          text: '•',
                        ),
                        Span(
                          className: 'text-purple-400 font-mono',
                          text: 'PURE_DART_BACKEND',
                        ),
                      ],
                    ),
                    H1(
                      className:
                          'text-4xl sm:text-6xl lg:text-7xl font-black '
                          'tracking-tight text-slate-900 dark:text-white '
                          'leading-[1.05]',
                      children: [
                        const Text('Pure Dart Backend.'),
                        El('br'),
                        Span(
                          className: 'text-gradient-silver',
                          text: 'Django Power. Rust-Grade Concurrency.',
                        ),
                      ],
                    ),
                    P(
                      className:
                          'text-slate-600 dark:text-slate-400 text-base sm:text-xl '
                          'max-w-3xl mx-auto leading-relaxed',
                      text:
                          'Stop writing backend APIs in Node or Go with duplicate '
                          'data models. Bloom delivers an integrated 15-package '
                          'backend ecosystem for pure Dart: typed ORM, schema '
                          'migrations, DRF ViewSets, auto HTML admin, and 78k '
                          'msgs/s multi-isolate realtime clustering.',
                    ),

                    // Command Pill Bar
                    Div(
                      className:
                          'pt-2 max-w-xl mx-auto w-full px-2 sm:px-0 space-y-4',
                      children: [
                        Div(
                          attrs: {
                            'onclick':
                                "navigator.clipboard.writeText('dart pub global activate bloom_cli && bloom server create my_backend'); window.dispatchEvent(new CustomEvent('bloom:toast', { detail: { title: 'Command Copied', message: 'Run in terminal to scaffold server.', type: 'emerald' } }));",
                          },
                          className: 'relative group cursor-pointer w-full',
                          children: [
                            Div(
                              className:
                                  'absolute -inset-1 bg-slate-200/70 dark:bg-white/10 '
                                  'rounded-2xl blur opacity-40 group-hover:opacity-70 '
                                  'transition duration-500',
                            ),
                            Div(
                              className:
                                  'relative glass-panel p-3 sm:p-4 rounded-2xl flex '
                                  'items-center justify-between gap-2 sm:gap-4 '
                                  'overflow-hidden border border-slate-200/80 '
                                  'dark:border-zinc-800 shadow-sm',
                              children: [
                                Div(
                                  className:
                                      'flex items-center gap-2 sm:gap-3 font-mono '
                                      'text-xs sm:text-sm overflow-hidden text-left min-w-0',
                                  children: [
                                    Span(
                                      className:
                                          'text-purple-500 font-bold shrink-0',
                                      text: r'$',
                                    ),
                                    Span(
                                      className:
                                          'text-slate-800 dark:text-slate-200 font-semibold '
                                          'truncate',
                                      text: 'bloom server create my_backend',
                                    ),
                                  ],
                                ),
                                Button(
                                  className:
                                      'px-3 sm:px-4 py-2 bg-white dark:bg-zinc-900 '
                                      'group-hover:bg-slate-900 group-hover:text-white '
                                      'rounded-xl text-xs font-mono font-bold '
                                      'text-slate-700 dark:text-slate-200 '
                                      'dark:group-hover:text-white transition-colors '
                                      'flex items-center gap-1.5 shrink-0 border '
                                      'border-slate-200 dark:border-zinc-800 shadow-sm',
                                  children: [
                                    hugeIcon('code', className: 'w-3.5 h-3.5'),
                                    const Text('Copy'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Hero Action Buttons
                        Div(
                          className:
                              'flex flex-wrap items-center justify-center gap-3 pt-2',
                          children: [
                            A(
                              href: '/build',
                              className:
                                  'px-5 py-2.5 rounded-xl bg-purple-600 '
                                  'hover:bg-purple-500 text-white font-bold '
                                  'text-xs shadow-md transition flex items-center gap-1.5',
                              children: [
                                hugeIcon('server', className: 'w-3.5 h-3.5'),
                                const Text('Server Documentation'),
                                hugeIcon(
                                  'arrow-right',
                                  className: 'w-3.5 h-3.5',
                                ),
                              ],
                            ),
                            A(
                              href: '/build',
                              className:
                                  'px-5 py-2.5 rounded-xl bg-slate-100 '
                                  'dark:bg-zinc-950 hover:bg-slate-200 '
                                  'dark:hover:bg-zinc-800 text-slate-900 '
                                  'dark:text-white font-bold text-xs border '
                                  'border-slate-200 dark:border-zinc-800 shadow-sm '
                                  'transition flex items-center gap-1.5',
                              children: [
                                hugeIcon(
                                  'sparkles',
                                  className: 'w-3.5 h-3.5 text-purple-400',
                                ),
                                const Text('Scaffolding Tutorial'),
                              ],
                            ),
                            A(
                              href: '/build',
                              className:
                                  'px-5 py-2.5 rounded-xl bg-slate-100 '
                                  'dark:bg-zinc-950 hover:bg-slate-200 '
                                  'dark:hover:bg-zinc-800 text-slate-900 '
                                  'dark:text-white font-bold text-xs border '
                                  'border-slate-200 dark:border-zinc-800 shadow-sm '
                                  'transition flex items-center gap-1.5',
                              children: [
                                hugeIcon(
                                  'folder',
                                  className: 'w-3.5 h-3.5 text-purple-400',
                                ),
                                const Text('Monorepo Layout'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                // Dynamic Architecture Player
                Div(className: 'mt-8', children: [serverArchitecturePlayer()]),
              ],
            ),
          ],
        ),

        // 2. Tech Marquee
        techMarquee(),

        // 3. Monorepo Architecture Showcase (#monorepo)
        Section(
          attrs: const {'id': 'monorepo'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                Div(
                  className:
                      'inline-flex items-center gap-2 px-3 py-1 rounded-full '
                      'bg-purple-500/10 border border-purple-500/20 text-purple-400 '
                      'text-xs font-mono font-bold',
                  children: [
                    hugeIcon('folder', className: 'w-3.5 h-3.5'),
                    Span(text: 'Full-Stack Monorepo Architecture'),
                  ],
                ),
                H2(
                  className:
                      'text-3xl sm:text-5xl font-black text-slate-900 '
                      'dark:text-white tracking-tight',
                  text: 'One Language. One Workspace.',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Organize Mobile (Flutter), Web (Flutter Web), and '
                      'Backend (Bloom Server) in a clean, pipeline-first monorepo '
                      'with 100% shared type safety.',
                ),
              ],
            ),
            Div(
              className: 'max-w-5xl mx-auto space-y-8',
              children: [
                Div(
                  className:
                      'rounded-2xl overflow-hidden bg-slate-950 dark:bg-black '
                      'border border-slate-800 dark:border-zinc-800 font-mono text-xs '
                      'shadow-2xl text-left',
                  children: [
                    Div(
                      className:
                          'px-4 py-3 bg-slate-900 border-b border-slate-800 '
                          'text-slate-400 font-bold',
                      text: 'Full-Stack Workspace Layout (Turborepo-Style)',
                    ),
                    Pre(
                      className:
                          'p-5 sm:p-6 leading-relaxed overflow-x-auto '
                          'text-purple-300',
                      children: [Code(text: _monorepoTree)],
                    ),
                  ],
                ),
                Div(
                  className: 'grid grid-cols-1 md:grid-cols-3 gap-6 text-left',
                  children: [
                    _renderMonorepoCard(
                      icon: 'folder',
                      title: 'Pure Dart packages/core',
                      desc:
                          'Data models, serializers, and query keys live in pure '
                          'Dart. Zero Flutter engine dependencies allows the backend '
                          'server to import models directly.',
                    ),
                    _renderMonorepoCard(
                      icon: 'zap',
                      title: 'Zero Codegen Drift',
                      desc:
                          'Client BloomQuery and server BloomViewSet communicate '
                          'directly using identical Dart schemas. No OpenAPI or '
                          'JSON generators needed.',
                    ),
                    _renderMonorepoCard(
                      icon: 'refresh',
                      title: 'Unified Melos Task Pipelines',
                      desc:
                          'Run melos run dev to hot-reload backend servers, '
                          'mobile emulators, and web clients simultaneously '
                          'across all CPU cores.',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // 4. Hardware Benchmarks Grid (#benchmarks)
        Section(
          attrs: const {'id': 'benchmarks'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                Div(
                  className:
                      'inline-flex items-center gap-2 px-3 py-1 rounded-full '
                      'bg-emerald-500/10 border border-emerald-500/20 '
                      'text-emerald-500 text-xs font-mono font-bold',
                  children: [
                    hugeIcon('zap', className: 'w-3.5 h-3.5'),
                    Span(text: 'Verified Hardware Benchmarks'),
                  ],
                ),
                H2(
                  className:
                      'text-3xl sm:text-5xl font-black text-slate-900 '
                      'dark:text-white tracking-tight',
                  text: 'Hardware Performance Breakdown',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Pure Ahead-of-Time (AOT) machine compilation and '
                      'dedicated isolate memory heaps deliver 29x less RAM and '
                      'zero garbage collection spikes.',
                ),
              ],
            ),

            // 4 Metrics Cards
            Div(
              className:
                  'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16',
              children: [
                _renderBenchmarkCard(
                  icon: 'sparkles',
                  metric: '78,125',
                  subtitle: 'msgs/sec throughput',
                  desc:
                      '1,000 active concurrent WebSocket connections @ 3.70 MB '
                      'RSS memory (Node.js/Fastify requires 107 MB).',
                  pkg: 'bloom_realtime',
                  badge: '29x less RAM',
                ),
                _renderBenchmarkCard(
                  icon: 'server',
                  metric: '12,500',
                  subtitle: 'ORM ops/sec',
                  desc:
                      '5,000 database rows batched in 400.7ms with zero '
                      'object allocation overhead and typed query builders.',
                  pkg: 'bloom_db',
                  badge: 'WAL native',
                ),
                _renderBenchmarkCard(
                  icon: 'zap',
                  metric: '9,091',
                  subtitle: 'req/sec @ 29.3ms p99',
                  desc:
                      '100 parallel HTTP connections handled with 0 socket '
                      'drops and sub-30ms latency ceilings.',
                  pkg: 'BloomApiRouter',
                  badge: 'Zero drops',
                ),
                _renderBenchmarkCard(
                  icon: 'cpu',
                  metric: '119,047',
                  subtitle: 'cache ops/sec',
                  desc:
                      '10,000 operations in 84.0ms with built-in dogpile '
                      'stampede locks and swappable Redis backends.',
                  pkg: 'bloom_cache',
                  badge: 'Stampede safe',
                ),
              ],
            ),

            // Side-by-Side Benchmark Table
            Div(
              className:
                  'max-w-5xl mx-auto rounded-3xl bg-white/60 dark:bg-zinc-950/80 '
                  'border border-slate-200/80 dark:border-zinc-800 backdrop-blur-xl '
                  'shadow-2xl overflow-hidden text-left',
              children: [
                Div(
                  className:
                      'p-6 sm:p-8 border-b border-slate-200 '
                      'dark:border-zinc-800',
                  children: [
                    H3(
                      className:
                          'text-2xl font-bold text-slate-900 dark:text-white',
                      text: 'Architectural & Benchmark Audit Comparison',
                    ),
                    P(
                      className:
                          'text-slate-600 dark:text-slate-400 text-sm mt-1',
                      text:
                          'Direct comparison across server architectures tested '
                          'on Apple M-Series Silicon and Linux AMD64 hardware.',
                    ),
                  ],
                ),
                Div(
                  className: 'overflow-x-auto',
                  children: [
                    El(
                      'table',
                      className: 'w-full text-left text-sm',
                      children: [
                        El(
                          'thead',
                          children: [
                            El(
                              'tr',
                              className:
                                  'border-b border-slate-200 dark:border-zinc-800 '
                                  'bg-slate-100/60 dark:bg-zinc-900/60 text-xs '
                                  'font-mono text-slate-500 dark:text-slate-400 '
                                  'uppercase tracking-wider',
                              children: [
                                El(
                                  'th',
                                  className: 'py-4 px-6',
                                  children: [const Text('Capability / Metric')],
                                ),
                                El(
                                  'th',
                                  className:
                                      'py-4 px-6 text-purple-600 dark:text-purple-400 '
                                      'font-black',
                                  children: [const Text('Bloom (Dart AOT)')],
                                ),
                                El(
                                  'th',
                                  className: 'py-4 px-6',
                                  children: [
                                    const Text('Node.js (NestJS/Fastify)'),
                                  ],
                                ),
                                El(
                                  'th',
                                  className: 'py-4 px-6',
                                  children: [const Text('Go (Gin/Fiber)')],
                                ),
                                El(
                                  'th',
                                  className: 'py-4 px-6',
                                  children: [
                                    const Text('Python (Django/FastAPI)'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        El(
                          'tbody',
                          className:
                              'divide-y divide-slate-200/60 dark:divide-zinc-800/60 '
                              'text-xs sm:text-sm text-slate-700 dark:text-slate-300',
                          children: [
                            _renderTableRow(
                              'Compilation & Runtime',
                              'Pure Native AOT',
                              'V8 JIT / Bytecode',
                              'Native Machine Code',
                              'Interpreted CPython',
                            ),
                            _renderTableRow(
                              '1,000 WebSocket RAM (RSS)',
                              '3.70 MB (Baseline)',
                              '107.4 MB (29x more)',
                              '42.1 MB (11x more)',
                              '182.0 MB (49x more)',
                            ),
                            _renderTableRow(
                              '5k Batched ORM Inserts',
                              '400.7ms (12.5k ops/s)',
                              '1,620ms (Prisma GC lag)',
                              '610ms (GORM reflection)',
                              '2,450ms (Python loop lag)',
                            ),
                            _renderTableRow(
                              '100 Concurrency p99 Latency',
                              '29.3ms (9,091 req/s)',
                              '118.0ms (4,210 req/s)',
                              '38.2ms (8,400 req/s)',
                              '240.0ms (1,850 req/s)',
                            ),
                            _renderTableRow(
                              'Flutter Client Sharing',
                              '100% Shared Primitives',
                              'Requires Codegen / DTOs',
                              'Requires Protobuf / OpenAPI',
                              'Requires OpenAPI Codegen',
                            ),
                            _renderTableRow(
                              'Multi-Core Scaling',
                              'Native Isolate Mesh',
                              'PM2 Process Cluster',
                              'Goroutines & Channels',
                              'Gunicorn Multi-Worker',
                            ),
                            _renderTableRow(
                              'Auto HTML Admin Panel',
                              'Built-in (bloom_admin)',
                              'External Third-Party',
                              'None (Manual UI)',
                              'Built-in (Django Admin)',
                            ),
                            _renderTableRow(
                              'Schema Migrations',
                              'Deterministic Linear Diff',
                              'Prisma / TypeORM CLI',
                              'golang-migrate',
                              'Django makemigrations',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // 5. 15-Package Server Ecosystem Grid (#ecosystem)
        Section(
          attrs: const {'id': 'ecosystem'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [
            Div(
              className: 'text-center max-w-3xl mx-auto space-y-4 mb-16',
              children: [
                Div(
                  className:
                      'inline-flex items-center gap-2 px-3 py-1 rounded-full '
                      'bg-purple-500/10 border border-purple-500/20 text-purple-400 '
                      'text-xs font-mono font-bold',
                  children: [
                    hugeIcon('folder', className: 'w-3.5 h-3.5'),
                    Span(text: 'Official Packages'),
                  ],
                ),
                H2(
                  className:
                      'text-3xl sm:text-5xl font-black text-slate-900 '
                      'dark:text-white tracking-tight',
                  text: 'The 15-Package Server Ecosystem',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg',
                  text:
                      'Modeled on Django\'s battle-tested modularity and designed '
                      'to work seamlessly together or as standalone Dart packages.',
                ),
              ],
            ),
            Div(
              className: 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6',
              children: [
                _renderEcosystemCard(
                  'bloom_framework',
                  'v0.2.2',
                  'Core foundational primitives, request/response models, and unified client-server pipeline.',
                ),
                _renderEcosystemCard(
                  'bloom_db',
                  'v0.1.0',
                  'Declarative typed ORM with compile-time query safety for SQLite and PostgreSQL.',
                ),
                _renderEcosystemCard(
                  'bloom_migrate',
                  'v0.1.0',
                  'Automatic schema diffing and linear migration execution engine without manual SQL.',
                ),
                _renderEcosystemCard(
                  'bloom_rest',
                  'v0.1.0',
                  'DRF-style REST layer with ViewSets, serializers, pagination, filters, and throttle rules.',
                ),
                _renderEcosystemCard(
                  'bloom_admin',
                  'v0.1.0',
                  'Zero-config server-rendered HTML administration interface for your database models.',
                ),
                _renderEcosystemCard(
                  'bloom_realtime',
                  'v0.2.0',
                  'High-throughput WebSocket pub/sub with multi-isolate clustering (78,125 msgs/s).',
                ),
                _renderEcosystemCard(
                  'bloom_cache',
                  'v0.1.0',
                  'Memory LRU, Database, and Redis backends with cache stampede prevention locks.',
                ),
                _renderEcosystemCard(
                  'bloom_auth_server',
                  'v0.1.0',
                  'Session and JWT authentication server with bcrypt password hashing and RBAC.',
                ),
                _renderEcosystemCard(
                  'bloom_jobs',
                  'v0.1.0',
                  'Asynchronous background worker queue with retries, cron, and concurrency controls.',
                ),
                _renderEcosystemCard(
                  'bloom_mail',
                  'v0.1.0',
                  'Transactional email engine with SMTP, SendGrid, and Postmark delivery backends.',
                ),
                _renderEcosystemCard(
                  'bloom_storage',
                  'v0.1.0',
                  'Swappable file storage abstraction (Local disk, AWS S3, Cloudflare R2, MinIO).',
                ),
                _renderEcosystemCard(
                  'bloom_security',
                  'v0.1.0',
                  'Security headers, CSRF token validation, CORS, and rate-limiting middleware.',
                ),
              ],
            ),
          ],
        ),

        // 6. Server FAQ Section (#faq)
        Section(
          attrs: const {'id': 'faq'},
          className: 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8',
          children: [serverFaq()],
        ),

        // 7. Final Call to Action
        Section(
          className: 'max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pb-12',
          children: [
            Div(
              className:
                  'p-8 sm:p-14 rounded-3xl bg-slate-900/80 dark:bg-zinc-950/80 '
                  'border border-slate-800 dark:border-zinc-800 text-center '
                  'space-y-6 shadow-2xl relative overflow-hidden backdrop-blur-xl',
              children: [
                Div(
                  className:
                      'w-12 h-12 rounded-2xl bg-purple-500/10 border '
                      'border-purple-500/20 flex items-center justify-center '
                      'text-purple-400 mx-auto',
                  children: [
                    hugeIcon('server', className: 'w-6 h-6 text-purple-400'),
                  ],
                ),
                H2(
                  className:
                      'text-3xl sm:text-5xl font-black text-slate-900 '
                      'dark:text-white tracking-tight',
                  text: 'Build Full-Stack Apps with Pure Dart',
                ),
                P(
                  className:
                      'text-slate-600 dark:text-slate-400 text-base sm:text-lg '
                      'max-w-xl mx-auto leading-relaxed',
                  text:
                      'Scaffold your first server application in seconds with '
                      'full database migrations, authentication, and REST '
                      'ViewSets out of the box.',
                ),
                Div(
                  className:
                      'flex flex-wrap items-center justify-center gap-4 pt-2',
                  children: [
                    A(
                      href: '/build',
                      className:
                          'px-7 py-3.5 rounded-2xl bg-purple-600 hover:bg-purple-500 '
                          'text-white font-bold shadow-lg shadow-purple-500/20 '
                          'transition text-sm flex items-center gap-2',
                      children: [
                        const Text('Read Server Documentation'),
                        hugeIcon('arrow-right', className: 'w-4 h-4'),
                      ],
                    ),
                    A(
                      href: '/build',
                      className:
                          'px-7 py-3.5 rounded-2xl bg-white dark:bg-zinc-900 '
                          'hover:bg-slate-100 dark:hover:bg-zinc-800 text-slate-900 '
                          'dark:text-white font-semibold border border-slate-200 '
                          'dark:border-zinc-800 transition text-sm',
                      children: const [Text('Quickstart Tutorial')],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

BloomNode _renderMonorepoCard({
  required String icon,
  required String title,
  required String desc,
}) {
  return Div(
    className:
        'p-6 rounded-2xl bg-white/60 dark:bg-zinc-900/60 border '
        'border-slate-200/80 dark:border-zinc-800 backdrop-blur-xl space-y-3',
    children: [
      Div(
        className:
            'w-10 h-10 rounded-xl bg-purple-500/10 border border-purple-500/20 '
            'flex items-center justify-center text-purple-400',
        children: [hugeIcon(icon, className: 'w-5 h-5 text-purple-400')],
      ),
      H3(
        className: 'font-bold text-slate-900 dark:text-white text-base',
        text: title,
      ),
      P(
        className:
            'text-xs text-slate-600 dark:text-slate-400 '
            'leading-relaxed font-sans',
        text: desc,
      ),
    ],
  );
}

BloomNode _renderBenchmarkCard({
  required String icon,
  required String metric,
  required String subtitle,
  required String desc,
  required String pkg,
  required String badge,
}) {
  return Div(
    className:
        'p-6 space-y-4 rounded-3xl glass-panel border border-slate-200/80 '
        'dark:border-zinc-800 hover:border-purple-500/40 transition group '
        'hover:shadow-xl text-left',
    children: [
      Div(
        className:
            'w-12 h-12 rounded-2xl bg-purple-500/10 border border-purple-500/20 '
            'flex items-center justify-center text-purple-400 group-hover:scale-110 '
            'transition-transform',
        children: [hugeIcon(icon, className: 'w-6 h-6 text-purple-400')],
      ),
      Div(
        children: [
          Div(
            className:
                'text-4xl font-black text-slate-900 dark:text-white font-mono',
            text: metric,
          ),
          Div(
            className:
                'text-xs font-mono text-purple-400 font-bold '
                'tracking-wide mt-1',
            text: subtitle,
          ),
        ],
      ),
      P(
        className:
            'text-xs text-slate-600 dark:text-slate-400 '
            'leading-relaxed font-sans',
        text: desc,
      ),
      Div(
        className:
            'text-[11px] font-mono text-slate-500 pt-2 border-t '
            'border-slate-200 dark:border-zinc-800 flex items-center justify-between',
        children: [
          Span(text: pkg),
          Span(className: 'text-emerald-500 font-bold', text: badge),
        ],
      ),
    ],
  );
}

BloomNode _renderTableRow(
  String col1,
  String col2,
  String col3,
  String col4,
  String col5,
) {
  return El(
    'tr',
    className: 'hover:bg-purple-500/5 transition',
    children: [
      El(
        'td',
        className: 'py-4 px-6 font-semibold text-slate-900 dark:text-white',
        children: [Text(col1)],
      ),
      El(
        'td',
        className: 'py-4 px-6 font-bold text-emerald-600 dark:text-emerald-400',
        children: [Text(col2)],
      ),
      El('td', className: 'py-4 px-6 text-slate-500', children: [Text(col3)]),
      El('td', className: 'py-4 px-6 text-slate-500', children: [Text(col4)]),
      El('td', className: 'py-4 px-6 text-slate-500', children: [Text(col5)]),
    ],
  );
}

BloomNode _renderEcosystemCard(String name, String ver, String desc) {
  return A(
    href: '/build',
    className:
        'p-5 rounded-2xl bg-white/60 dark:bg-zinc-900/60 border '
        'border-slate-200/80 dark:border-zinc-800 hover:border-purple-500/40 '
        'backdrop-blur-xl transition group hover:shadow-lg text-left block',
    children: [
      Div(
        className: 'flex items-center justify-between mb-2',
        children: [
          Span(
            className:
                'font-mono font-bold text-purple-600 dark:text-purple-400 '
                'group-hover:underline',
            text: name,
          ),
          Span(
            className:
                'text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 '
                'text-emerald-500 font-bold',
            text: ver,
          ),
        ],
      ),
      P(
        className: 'text-xs text-slate-600 dark:text-slate-400 leading-relaxed',
        text: desc,
      ),
    ],
  );
}
