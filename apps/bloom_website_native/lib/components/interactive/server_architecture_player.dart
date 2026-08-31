import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import '../huge_icons.dart';

class _FeatureItem {
  final String id;
  final String name;
  final String shortName;
  final String filename;
  final String icon;
  final String packageName;
  final String efficiencyMetric;
  final String efficiencyBadge;
  final String efficiencyColor;
  final String description;
  final List<String> highlights;
  final String docLink;
  final String code;

  const _FeatureItem({
    required this.id,
    required this.name,
    required this.shortName,
    required this.filename,
    required this.icon,
    required this.packageName,
    required this.efficiencyMetric,
    required this.efficiencyBadge,
    required this.efficiencyColor,
    required this.description,
    required this.highlights,
    required this.docLink,
    required this.code,
  });
}

const _features = <_FeatureItem>[
  _FeatureItem(
    id: 'orm',
    name: 'ORM & Models',
    shortName: 'ORM & Models',
    filename: 'lib/apps/blog/models.dart',
    icon: 'server',
    packageName: 'bloom_db',
    efficiencyMetric: '12,500 ops/sec',
    efficiencyBadge:
        '400.7ms for 5,000 batched rows • Zero reflection overhead',
    efficiencyColor: 'emerald',
    description:
        'Declarative schema modeling with compile-time query safety, relation '
        'joins, and automatic migrations for SQLite and PostgreSQL.',
    highlights: [
      'Compile-time typed QuerySets: filter(), orderBy(), and limit()',
      'Zero reflection: code-generated native SQL bindings with WAL mode',
      'Automated schema diffing & linear migrations via bloom_migrate',
    ],
    docLink: '/docs/server/orm-and-migrations',
    code: '''import 'package:bloom_db/bloom_db.dart';

@Model(table: 'posts')
class Post {
  @PrimaryKey(autoIncrement: true)
  final int? id;

  @Field(type: FieldType.varchar, length: 255)
  final String title;

  @Field(type: FieldType.text)
  final String content;

  @Field(type: FieldType.boolean, defaultValue: false)
  final bool published;

  @Field(type: FieldType.timestamp, autoNowAdd: true)
  final DateTime createdAt;

  const Post({
    this.id,
    required this.title,
    required this.content,
    this.published = false,
    required this.createdAt,
  });
}

// Fluent Type-Safe Query Execution:
// final posts = await PostQuerySet()
//   .filter((p) => p.published.equals(true))
//   .orderBy((p) => p.createdAt.desc())
//   .limit(10)
//   .toList();''',
  ),
  _FeatureItem(
    id: 'rest',
    name: 'REST ViewSets',
    shortName: 'REST ViewSets',
    filename: 'lib/apps/blog/views.dart',
    icon: 'zap',
    packageName: 'bloom_rest',
    efficiencyMetric: '9,091 req/sec',
    efficiencyBadge: '29.3ms p99 latency @ 100 concurrent HTTP connections',
    efficiencyColor: 'purple',
    description:
        'Django REST Framework (DRF) style ViewSets with automated CRUD routing, '
        'field serializers, pagination, and throttles.',
    highlights: [
      'Full CRUD actions generated from a single ViewSet class',
      'Composable permission guards (IsAuthenticatedOrReadOnly)',
      'Built-in rate limiting with AnonRateThrottle & UserRateThrottle',
    ],
    docLink: '/docs/server/rest-api',
    code: '''import 'package:bloom_rest/bloom_rest.dart';
import '../models/post.dart';
import '../serializers/post_serializer.dart';

class PostViewSet extends BloomViewSet<Post> {
  @override
  final QuerySet<Post> queryset = PostQuerySet();

  @override
  final Serializer<Post> serializer = PostSerializer();

  @override
  final List<Permission> permissions = [
    IsAuthenticatedOrReadOnly(),
  ];

  @override
  final Pagination pagination = PageNumberPagination(pageSize: 20);

  @override
  final List<Throttle> throttles = [
    AnonRateThrottle(requestsPerMinute: 60),
    UserRateThrottle(requestsPerMinute: 1000),
  ];
}

// Router Registration:
// router.mountViewSet<Post>('/api/posts', PostViewSet());''',
  ),
  _FeatureItem(
    id: 'admin',
    name: 'HTML Admin Panel',
    shortName: 'HTML Admin',
    filename: 'lib/apps/blog/admin.dart',
    icon: 'check-circle',
    packageName: 'bloom_admin',
    efficiencyMetric: '0 kB Client JS',
    efficiencyBadge:
        'Server-rendered HTML • Instant CRUD dashboard with zero build step',
    efficiencyColor: 'cyan',
    description:
        'Instant server-rendered HTML administration interface with search '
        'filters, ordering, and role-based data governance.',
    highlights: [
      'Zero frontend compilation required — pure Dart HTML templates',
      'Search, filter, pagination, and bulk delete out of the box',
      'Integrates directly with bloom_auth_server for RBAC permissions',
    ],
    docLink: '/docs/server/admin-panel',
    code: '''import 'package:bloom_admin/bloom_admin.dart';
import '../models/post.dart';

class PostAdmin extends ModelAdmin<Post> {
  @override
  final List<String> listDisplay = ['id', 'title', 'published', 'createdAt'];

  @override
  final List<String> searchFields = ['title', 'content'];

  @override
  final List<String> listFilter = ['published', 'createdAt'];

  @override
  final bool ordering = true;
}

// Mount in Server Pipeline:
// adminSite.register<Post>(PostAdmin());
// app.mount('/admin', adminSite.handler);''',
  ),
  _FeatureItem(
    id: 'realtime',
    name: 'Realtime Cluster',
    shortName: 'Realtime Cluster',
    filename: 'bin/server.dart',
    icon: 'sparkles',
    packageName: 'bloom_realtime',
    efficiencyMetric: '78,125 msgs/sec',
    efficiencyBadge:
        '3.70 MB RSS memory @ 1,000 WebSocket connections (29x less RAM)',
    efficiencyColor: 'emerald',
    description:
        'Zero-copy WebSocket pub/sub with multi-isolate clustering across 100% '
        'of CPU cores without Node.js event-loop bottlenecks.',
    highlights: [
      'Kernel-mesh port sharing: HttpServer.bind(shared: true)',
      'Inter-isolate SendPort ring for zero-copy broadcast mesh',
      'Sub-millisecond frame delivery with binary WebSocket protocol',
    ],
    docLink: '/docs/server/realtime',
    code: '''import 'dart:io';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  // Spawns isolate workers across all available CPU cores
  final cluster = await BloomRealtimeCluster.spawn(
    isolateCount: Platform.numberOfProcessors,
    port: 8080,
    meshProtocol: InterIsolateMesh(),
  );

  print('⚡ Cluster active across \${cluster.workers.length} CPU cores');

  cluster.onMessage((channel, message) {
    // Zero-overhead binary stream broadcast across all isolates
    cluster.broadcast(channel, message);
  });
}''',
  ),
  _FeatureItem(
    id: 'jobs',
    name: 'Jobs & Workers',
    shortName: 'Jobs & Workers',
    filename: 'lib/jobs/email_worker.dart',
    icon: 'cpu',
    packageName: 'bloom_jobs',
    efficiencyMetric: '119,047 ops/sec',
    efficiencyBadge:
        'Non-blocking isolate queue with automatic exponential backoff',
    efficiencyColor: 'purple',
    description: 'Background worker queues with exponential backoff retries, '
        'concurrency limits, and scheduled cron executions.',
    highlights: [
      'Runs compute-heavy tasks in background isolates without stalling HTTP',
      'Configurable retry policies with jittered exponential backoff',
      'Swappable storage backends (In-memory, SQLite WAL, Redis)',
    ],
    docLink: '/docs/server/jobs-mail-and-storage',
    code: '''import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:bloom_mail/bloom_mail.dart';

class SendWelcomeEmailJob extends BloomJob<UserPayload> {
  @override
  int get maxRetries => 5;

  @override
  Duration get backoff => const Duration(seconds: 10);

  @override
  Future<void> handle(UserPayload payload) async {
    final mailer = BloomMailer();
    await mailer.send(
      to: payload.email,
      subject: 'Welcome to the platform!',
      template: 'welcome_template',
      context: {'name': payload.name},
    );
  }
}

// Dispatch asynchronously from any endpoint:
// await SendWelcomeEmailJob().dispatch(
//   UserPayload(name: 'Alex', email: 'alex@example.com'),
// );''',
  ),
];

BloomNode serverArchitecturePlayer() {
  final activeIndex = signal(0);
  final isPaused = signal(false);
  Timer? autoRotateTimer;

  return Mount(
    Div(
      className:
          'p-6 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur '
          'border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-6xl '
          'mx-auto space-y-8 text-left relative overflow-hidden',
      children: [
        // Top Controls & Mode Switcher
        Div(
          className:
              'flex flex-col sm:flex-row sm:items-center justify-between gap-4 '
              'pb-6 border-b border-slate-200 dark:border-zinc-800',
          children: [
            Div(
              className: 'flex items-center gap-2 overflow-x-auto no-scrollbar',
              children: [
                for (int i = 0; i < _features.length; i++)
                  Live(() {
                    final isActive = activeIndex.value == i;
                    final feat = _features[i];

                    return Button(
                      attrs: {'type': 'button'},
                      onClick: (_) {
                        activeIndex.value = i;
                        isPaused.value = true;
                      },
                      className:
                          'flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs '
                          'font-mono font-bold transition-all border cursor-pointer ${isActive ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-md scale-105' : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white'}',
                      children: [
                        hugeIcon(feat.icon, className: 'w-3.5 h-3.5'),
                        Span(text: feat.shortName),
                      ],
                    );
                  }),
              ],
            ),

            // Auto-play Pause Toggle
            Live(() {
              final paused = isPaused.value;
              return Button(
                attrs: {'type': 'button'},
                onClick: (_) => isPaused.value = !paused,
                className:
                    'flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-100 '
                    'dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 '
                    'text-[11px] font-mono text-slate-600 dark:text-slate-400 '
                    'hover:text-slate-900 dark:hover:text-white transition cursor-pointer',
                children: [
                  hugeIcon(paused ? 'sparkles' : 'refresh',
                      className: 'w-3 h-3'),
                  Text(paused ? 'Paused' : 'Auto-Rotating (6s)'),
                ],
              );
            }),
          ],
        ),

        // Efficiency Metric HUD Bar
        Live(() {
          final feat = _features[activeIndex.value];
          return Div(
            className: 'p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 border '
                'border-slate-200 dark:border-zinc-800 flex flex-wrap items-center '
                'justify-between gap-4 font-mono text-xs shadow-inner',
            children: [
              Div(
                className: 'flex items-center gap-3',
                children: [
                  Span(
                    className:
                        'px-2.5 py-1 rounded bg-purple-500/10 text-purple-600 '
                        'dark:text-purple-400 font-bold border border-purple-500/20',
                    text: feat.packageName,
                  ),
                  Span(
                    className:
                        'text-slate-700 dark:text-slate-300 font-semibold',
                    text: feat.efficiencyBadge,
                  ),
                ],
              ),
              Div(
                className:
                    'flex items-center gap-2 font-black text-emerald-600 '
                    'dark:text-emerald-400',
                children: [
                  Span(
                    className:
                        'w-2 h-2 rounded-full bg-emerald-500 animate-pulse',
                  ),
                  Span(text: feat.efficiencyMetric),
                ],
              ),
            ],
          );
        }),

        // Main Feature Grid: Overview vs Live Code
        Live(() {
          final feat = _features[activeIndex.value];

          return Div(
            className: 'grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch',
            children: [
              // Left Pane: Descriptions & Highlights
              Div(
                className:
                    'lg:col-span-5 space-y-6 flex flex-col justify-between',
                children: [
                  Div(
                    className: 'space-y-4',
                    children: [
                      H3(
                        className:
                            'text-2xl font-black text-slate-900 dark:text-white '
                            'tracking-tight',
                        text: feat.name,
                      ),
                      P(
                        className: 'text-sm text-slate-600 dark:text-slate-400 '
                            'leading-relaxed',
                        text: feat.description,
                      ),
                      Div(
                        className: 'space-y-2.5 pt-2',
                        children: [
                          for (final h in feat.highlights)
                            Div(
                              className:
                                  'flex items-start gap-2 text-xs text-slate-700 '
                                  'dark:text-slate-300',
                              children: [
                                hugeIcon(
                                  'check-circle',
                                  className:
                                      'w-4 h-4 text-purple-600 dark:text-purple-400 '
                                      'shrink-0 mt-0.5',
                                ),
                                Span(text: h),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                  A(
                    href: '/build',
                    className:
                        'inline-flex items-center gap-2 text-xs font-bold '
                        'text-purple-600 dark:text-purple-400 hover:underline',
                    children: [
                      const Text('Explore Documentation'),
                      hugeIcon('arrow-right', className: 'w-3.5 h-3.5'),
                    ],
                  ),
                ],
              ),

              // Right Pane: Code Snippet Card
              Div(
                className: 'lg:col-span-7 space-y-2',
                children: [
                  Div(
                    className:
                        'flex items-center justify-between text-xs font-mono '
                        'text-slate-500 dark:text-slate-400 px-1',
                    children: [
                      Span(
                        className: 'font-bold text-slate-900 dark:text-white',
                        text: feat.filename,
                      ),
                      Button(
                        attrs: {
                          'type': 'button',
                          'onclick':
                              "navigator.clipboard.writeText(`${feat.code.replaceAll('`', r'\`').replaceAll(r'$', r'\$')}`); window.dispatchEvent(new CustomEvent('bloom:toast', { detail: { title: 'Code Copied', message: 'Copied server snippet.', type: 'purple' } }));",
                        },
                        className:
                            'hover:text-slate-900 dark:hover:text-white transition '
                            'cursor-pointer flex items-center gap-1',
                        children: [
                          hugeIcon(
                            'sparkles',
                            className: 'w-3 h-3 text-purple-400',
                          ),
                          const Text('Copy'),
                        ],
                      ),
                    ],
                  ),
                  Div(
                    className:
                        'rounded-2xl overflow-hidden bg-slate-950 dark:bg-black '
                        'border border-slate-800 dark:border-zinc-800 font-mono '
                        'text-xs shadow-xl',
                    children: [
                      Pre(
                        className: 'p-4 sm:p-6 leading-relaxed overflow-x-auto '
                            'text-slate-200',
                        children: [
                          Code(className: 'language-dart', text: feat.code),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        }),
      ],
    ),
    onMount: () {
      autoRotateTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!isPaused.value) {
          activeIndex.value = (activeIndex.value + 1) % _features.length;
        }
      });
    },
    onUnmount: () => autoRotateTimer?.cancel(),
  );
}
