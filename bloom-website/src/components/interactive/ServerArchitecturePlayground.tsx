import { useState } from 'preact/hooks';
import { Database, Layers, ShieldCheck, Activity, Cpu, Copy, Check, Terminal, ExternalLink } from 'lucide-preact';

interface TabItem {
  id: string;
  name: string;
  filename: string;
  icon: any;
  tag: string;
  tagColor: string;
  description: string;
  code: string;
}

const TABS: TabItem[] = [
  {
    id: 'orm',
    name: 'ORM & Models',
    filename: 'lib/apps/blog/models.dart',
    icon: Database,
    tag: 'bloom_db',
    tagColor: 'text-purple-400 bg-purple-500/10 border-purple-500/20',
    description: 'Declarative schema modeling with compile-time safety and automatic migration generation for SQLite & PostgreSQL.',
    code: `import 'package:bloom_db/bloom_db.dart';

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

// Fluent QuerySets:
// final activePosts = await PostQuerySet()
//   .filter((p) => p.published.equals(true))
//   .orderBy((p) => p.createdAt.desc())
//   .limit(10)
//   .toList();`,
  },
  {
    id: 'rest',
    name: 'REST ViewSets',
    filename: 'lib/apps/blog/views.dart',
    icon: Layers,
    tag: 'bloom_rest',
    tagColor: 'text-pink-400 bg-pink-500/10 border-pink-500/20',
    description: 'Django REST Framework (DRF) style ViewSets with automated CRUD routing, serializers, pagination, and permissions.',
    code: `import 'package:bloom_rest/bloom_rest.dart';
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
// router.mountViewSet<Post>('/api/posts', PostViewSet());`,
  },
  {
    id: 'admin',
    name: 'HTML Admin Panel',
    filename: 'lib/apps/blog/admin.dart',
    icon: ShieldCheck,
    tag: 'bloom_admin',
    tagColor: 'text-pink-400 bg-pink-500/10 border-pink-500/20',
    description: 'Instant server-rendered HTML administration dashboard with search, filtering, and role-based data management.',
    code: `import 'package:bloom_admin/bloom_admin.dart';
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

// Mount in your server pipeline:
// adminSite.register<Post>(PostAdmin());
// app.mount('/admin', adminSite.handler);`,
  },
  {
    id: 'realtime',
    name: 'Realtime Cluster',
    filename: 'bin/server.dart',
    icon: Activity,
    tag: 'bloom_realtime',
    tagColor: 'text-cyan-400 bg-cyan-500/10 border-cyan-500/20',
    description: 'Zero-copy WebSocket pub/sub with multi-core isolate clustering delivering 78,125 msgs/sec @ 3.70 MB RAM.',
    code: `import 'dart:io';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  // Spawns isolate workers across all available CPU cores
  final cluster = await BloomRealtimeCluster.spawn(
    isolateCount: Platform.numberOfProcessors,
    port: 8080,
    meshProtocol: InterIsolateMesh(),
  );

  print('⚡ Multi-isolate cluster running across \${cluster.workers.length} CPU cores');

  cluster.onMessage((channel, message) {
    // Zero-overhead binary stream broadcast across all isolates
    cluster.broadcast(channel, message);
  });
}`,
  },
  {
    id: 'jobs',
    name: 'Jobs & Workers',
    filename: 'lib/jobs/email_worker.dart',
    icon: Cpu,
    tag: 'bloom_jobs',
    tagColor: 'text-amber-400 bg-amber-500/10 border-amber-500/20',
    description: 'Background worker queues with automatic exponential backoff retries, concurrency limits, and scheduled cron execution.',
    code: `import 'package:bloom_jobs/bloom_jobs.dart';
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
// await SendWelcomeEmailJob().dispatch(UserPayload(email: 'user@bloom.dev', name: 'Alex'));`,
  },
];

export function ServerArchitecturePlayground() {
  const [activeTabId, setActiveTabId] = useState('orm');
  const [copied, setCopied] = useState(false);

  const activeTab = TABS.find((t) => t.id === activeTabId) || TABS[0];

  const handleCopy = () => {
    navigator.clipboard.writeText(activeTab.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="w-full max-w-5xl mx-auto rounded-3xl bg-slate-900/90 dark:bg-black/90 border border-slate-700/60 dark:border-zinc-800 shadow-2xl backdrop-blur-2xl overflow-hidden text-left">
      {/* Header bar with tabs */}
      <div className="flex flex-wrap items-center justify-between border-b border-slate-800 p-3 sm:p-4 gap-2 bg-slate-950/60">
        <div className="flex flex-wrap items-center gap-1.5 sm:gap-2">
          {TABS.map((tab) => {
            const Icon = tab.icon;
            const isActive = tab.id === activeTabId;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTabId(tab.id)}
                className={`flex items-center gap-2 px-3 sm:px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-all duration-200 ${
                  isActive
                    ? 'bg-gradient-to-r from-pink-500/20 to-purple-500/20 text-white border border-pink-500/40 shadow-sm'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
                }`}
              >
                <Icon className={`w-3.5 h-3.5 sm:w-4 sm:h-4 ${isActive ? 'text-pink-400' : 'text-slate-500'}`} />
                <span>{tab.name}</span>
              </button>
            );
          })}
        </div>

        <div className="flex items-center gap-2">
          <span className={`px-2.5 py-1 rounded-full text-[10px] font-mono font-bold border ${activeTab.tagColor}`}>
            {activeTab.tag}
          </span>
          <button
            onClick={handleCopy}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800/80 hover:bg-slate-700 text-slate-300 text-xs font-mono font-semibold transition border border-slate-700/50 cursor-pointer"
            title="Copy code to clipboard"
          >
            {copied ? (
              <>
                <Check className="w-3.5 h-3.5 text-emerald-400" />
                <span className="text-emerald-400">Copied</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5 text-slate-400" />
                <span>Copy</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Description banner */}
      <div className="px-5 py-3 bg-slate-900/40 border-b border-slate-800/80 flex flex-wrap items-center justify-between gap-2 text-xs text-slate-400">
        <div className="flex items-center gap-2 font-mono text-[11px] text-slate-300">
          <Terminal className="w-3.5 h-3.5 text-pink-400" />
          <span>{activeTab.filename}</span>
        </div>
        <p className="text-slate-400 text-xs">{activeTab.description}</p>
      </div>

      {/* Code Viewer */}
      <div className="p-4 sm:p-6 overflow-x-auto bg-[#0d1117]/95 font-mono text-xs sm:text-sm text-slate-200 leading-relaxed max-h-[480px] scrollbar-thin">
        <pre className="text-slate-300 font-mono">
          <code>{activeTab.code}</code>
        </pre>
      </div>

      {/* Footer quick action */}
      <div className="px-5 py-3 bg-slate-950/80 border-t border-slate-800 flex items-center justify-between text-xs font-mono text-slate-400">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
          <span>Zero external runtime dependencies • Pure Dart AOT</span>
        </div>
        <a
          href={`/docs/server/${activeTabId === 'orm' ? 'orm-and-migrations' : activeTabId === 'rest' ? 'rest-api' : activeTabId === 'admin' ? 'admin-panel' : activeTabId === 'realtime' ? 'realtime' : 'jobs-mail-and-storage'}`}
          className="text-pink-400 hover:text-pink-300 flex items-center gap-1 font-bold transition hover:underline"
        >
          <span>View full guide</span>
          <ExternalLink className="w-3 h-3" />
        </a>
      </div>
    </div>
  );
}
