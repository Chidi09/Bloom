import * as React from 'preact/compat';
import { useState, useEffect, useRef } from 'preact/hooks';
import { 
  Database, 
  Layers, 
  ShieldCheck, 
  Activity, 
  Cpu, 
  Copy, 
  Check, 
  Terminal, 
  Play, 
  Pause, 
  Zap, 
  ArrowRight,
  ExternalLink,
  Sparkles
} from 'lucide-preact';
import { highlightDart } from '../../lib/dart-highlighter';

interface FeatureItem {
  id: string;
  name: string;
  shortName: string;
  filename: string;
  icon: any;
  packageName: string;
  efficiencyMetric: string;
  efficiencyBadge: string;
  efficiencyColor: string;
  description: string;
  highlights: string[];
  docLink: string;
  code: string;
}

const FEATURES: FeatureItem[] = [
  {
    id: 'orm',
    name: 'ORM & Models',
    shortName: 'ORM & Models',
    filename: 'lib/apps/blog/models.dart',
    icon: Database,
    packageName: 'bloom_db',
    efficiencyMetric: '12,500 ops/sec',
    efficiencyBadge: '400.7ms for 5,000 batched rows • Zero reflection overhead',
    efficiencyColor: 'emerald',
    description: 'Declarative schema modeling with compile-time query safety, relation joins, and automatic migrations for SQLite and PostgreSQL.',
    highlights: [
      'Compile-time typed QuerySets: filter(), orderBy(), and limit()',
      'Zero reflection: code-generated native SQL bindings with WAL mode',
      'Automated schema diffing & linear migrations via bloom_migrate',
    ],
    docLink: '/docs/server/orm-and-migrations',
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

// Fluent Type-Safe Query Execution:
// final posts = await PostQuerySet()
//   .filter((p) => p.published.equals(true))
//   .orderBy((p) => p.createdAt.desc())
//   .limit(10)
//   .toList();`,
  },
  {
    id: 'rest',
    name: 'REST ViewSets',
    shortName: 'REST ViewSets',
    filename: 'lib/apps/blog/views.dart',
    icon: Layers,
    packageName: 'bloom_rest',
    efficiencyMetric: '9,091 req/sec',
    efficiencyBadge: '29.3ms p99 latency @ 100 concurrent HTTP connections',
    efficiencyColor: 'purple',
    description: 'Django REST Framework (DRF) style ViewSets with automated CRUD routing, field serializers, pagination, and throttles.',
    highlights: [
      'Full CRUD actions generated from a single ViewSet class',
      'Composable permission guards (IsAuthenticatedOrReadOnly)',
      'Built-in rate limiting with AnonRateThrottle & UserRateThrottle',
    ],
    docLink: '/docs/server/rest-api',
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
    shortName: 'HTML Admin',
    filename: 'lib/apps/blog/admin.dart',
    icon: ShieldCheck,
    packageName: 'bloom_admin',
    efficiencyMetric: '0 kB Client JS',
    efficiencyBadge: 'Server-rendered HTML • Instant CRUD dashboard with zero build step',
    efficiencyColor: 'cyan',
    description: 'Instant server-rendered HTML administration interface with search filters, ordering, and role-based data governance.',
    highlights: [
      'Zero frontend compilation required — pure Dart HTML templates',
      'Search, filter, pagination, and bulk delete out of the box',
      'Integrates directly with bloom_auth_server for RBAC permissions',
    ],
    docLink: '/docs/server/admin-panel',
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

// Mount in Server Pipeline:
// adminSite.register<Post>(PostAdmin());
// app.mount('/admin', adminSite.handler);`,
  },
  {
    id: 'realtime',
    name: 'Realtime Cluster',
    shortName: 'Realtime Cluster',
    filename: 'bin/server.dart',
    icon: Activity,
    packageName: 'bloom_realtime',
    efficiencyMetric: '78,125 msgs/sec',
    efficiencyBadge: '3.70 MB RSS memory @ 1,000 WebSocket connections (29x less RAM)',
    efficiencyColor: 'emerald',
    description: 'Zero-copy WebSocket pub/sub with multi-isolate clustering across 100% of CPU cores without Node.js event-loop bottlenecks.',
    highlights: [
      'Kernel-mesh port sharing: HttpServer.bind(shared: true)',
      'Inter-isolate SendPort ring for zero-copy broadcast mesh',
      'Sub-millisecond frame delivery with binary WebSocket protocol',
    ],
    docLink: '/docs/server/realtime',
    code: `import 'dart:io';
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
}`,
  },
  {
    id: 'jobs',
    name: 'Jobs & Workers',
    shortName: 'Jobs & Workers',
    filename: 'lib/jobs/email_worker.dart',
    icon: Cpu,
    packageName: 'bloom_jobs',
    efficiencyMetric: '119,047 ops/sec',
    efficiencyBadge: 'Non-blocking isolate queue with automatic exponential backoff',
    efficiencyColor: 'purple',
    description: 'Background worker queues with exponential backoff retries, concurrency limits, and scheduled cron executions.',
    highlights: [
      'Runs compute-heavy tasks in background isolates without stalling HTTP',
      'Configurable retry policies with jittered exponential backoff',
      'Swappable storage backends (In-memory, SQLite WAL, Redis)',
    ],
    docLink: '/docs/server/jobs-mail-and-storage',
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
// await SendWelcomeEmailJob().dispatch(
//   UserPayload(email: 'user@bloom.dev', name: 'Alex'),
// );`,
  },
];

const ROTATION_INTERVAL_MS = 6000;

export function ServerArchitectureDynamicPlayer() {
  const [activeIndex, setActiveIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(true);
  const [isHovered, setIsHovered] = useState(false);
  const [progress, setProgress] = useState(0);
  const [copied, setCopied] = useState(false);

  // Typewriter streaming state
  const [typedChars, setTypedChars] = useState(0);
  const [isTyping, setIsTyping] = useState(true);

  const codeContainerRef = useRef<HTMLDivElement>(null);
  const activeFeature = FEATURES[activeIndex];

  // Reset and trigger typing stream whenever active feature changes
  useEffect(() => {
    setTypedChars(0);
    setIsTyping(true);

    if (codeContainerRef.current) {
      codeContainerRef.current.scrollTop = 0;
    }

    const fullLength = activeFeature.code.length;
    // Type fast enough to finish within ~1.2s
    const chunkSize = Math.max(6, Math.ceil(fullLength / 60));
    const typeIntervalMs = 18;

    const typeTimer = setInterval(() => {
      setTypedChars((prev) => {
        const next = prev + chunkSize;
        if (next >= fullLength) {
          clearInterval(typeTimer);
          setIsTyping(false);
          return fullLength;
        }
        return next;
      });
    }, typeIntervalMs);

    return () => clearInterval(typeTimer);
  }, [activeIndex]);

  // Auto-scroll code container to the bottom as new lines are typed
  useEffect(() => {
    if (codeContainerRef.current && isTyping) {
      codeContainerRef.current.scrollTop = codeContainerRef.current.scrollHeight;
    }
  }, [typedChars, isTyping]);

  // Rotation timer loop
  useEffect(() => {
    if (!isPlaying || isHovered) return;

    const stepMs = 50;
    const progressIncrement = (stepMs / ROTATION_INTERVAL_MS) * 100;

    const timer = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          setActiveIndex((current) => (current + 1) % FEATURES.length);
          return 0;
        }
        return prev + progressIncrement;
      });
    }, stepMs);

    return () => clearInterval(timer);
  }, [isPlaying, isHovered, activeIndex]);

  const handleSelectTab = (index: number) => {
    setActiveIndex(index);
    setProgress(0);
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(activeFeature.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Sliced code for typewriter streaming
  const displayedCode = activeFeature.code.slice(0, typedChars);

  return (
    <div 
      className="w-full max-w-5xl mx-auto rounded-3xl bg-zinc-950/95 border border-zinc-800/90 shadow-2xl overflow-hidden text-left backdrop-blur-2xl transition-all"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Top Header Bar */}
      <div className="border-b border-zinc-800 p-3 sm:p-4 bg-black/60 flex flex-wrap items-center justify-between gap-3">
        {/* Navigation Tabs with Progress Rails */}
        <div className="flex flex-wrap items-center gap-1.5 sm:gap-2">
          {FEATURES.map((feature, idx) => {
            const Icon = feature.icon;
            const isActive = idx === activeIndex;
            return (
              <button
                key={feature.id}
                onClick={() => handleSelectTab(idx)}
                className={`relative overflow-hidden flex items-center gap-2 px-3 sm:px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-all duration-200 cursor-pointer ${
                  isActive
                    ? 'bg-zinc-800 text-white border border-zinc-700 shadow-sm'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-zinc-900/60'
                }`}
              >
                <Icon className={`w-3.5 h-3.5 sm:w-4 sm:h-4 ${isActive ? 'text-purple-400' : 'text-slate-500'}`} />
                <span>{feature.shortName}</span>

                {/* Animated Progress Rail on Active Tab */}
                {isActive && isPlaying && !isHovered && (
                  <div
                    className="absolute bottom-0 left-0 h-[2px] bg-purple-500 transition-all duration-75"
                    style={{ width: `${progress}%` }}
                  />
                )}
              </button>
            );
          })}
        </div>

        {/* Playback & Status Controls */}
        <div className="flex items-center gap-2">
          {isTyping && (
            <span className="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-mono text-purple-300 bg-purple-500/10 border border-purple-500/20">
              <span className="w-1.5 h-1.5 rounded-full bg-purple-400 animate-ping"></span>
              STREAMING DART
            </span>
          )}

          {isHovered && (
            <span className="hidden sm:inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-mono text-amber-400 bg-amber-400/10 border border-amber-400/20">
              PAUSED ON HOVER
            </span>
          )}

          <button
            onClick={() => setIsPlaying(!isPlaying)}
            className="p-2 rounded-lg bg-zinc-900 hover:bg-zinc-800 text-slate-400 hover:text-slate-200 transition border border-zinc-800 cursor-pointer"
            title={isPlaying ? 'Pause Auto-Play' : 'Resume Auto-Play'}
          >
            {isPlaying ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5 text-purple-400" />}
          </button>

          <button
            onClick={handleCopy}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-zinc-900 hover:bg-zinc-800 text-slate-300 hover:text-white transition font-mono text-xs font-medium border border-zinc-800 cursor-pointer"
            title="Copy snippet"
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

      {/* Dynamic Efficiency & Hardware HUD Banner */}
      <div className="px-4 sm:px-6 py-3 bg-zinc-900/60 border-b border-zinc-800/80 flex flex-wrap items-center justify-between gap-3 text-xs">
        <div className="flex items-center gap-3 min-w-0">
          <div className="flex items-center gap-1.5 font-mono text-slate-300 text-xs truncate">
            <Terminal className="w-3.5 h-3.5 text-purple-400 shrink-0" />
            <span className="font-bold">{activeFeature.filename}</span>
          </div>
          <span className="px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase tracking-wider bg-purple-500/10 text-purple-300 border border-purple-500/20 shrink-0">
            {activeFeature.packageName}
          </span>
        </div>

        {/* Live Efficiency Indicator Badge */}
        <div className="flex items-center gap-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 font-mono text-[11px] font-bold shadow-sm">
            <span className="flex h-2 w-2 relative shrink-0">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span>⚡ {activeFeature.efficiencyMetric}</span>
            <span className="text-emerald-500/50 hidden md:inline">•</span>
            <span className="text-slate-400 font-normal hidden md:inline">{activeFeature.efficiencyBadge}</span>
          </div>
        </div>
      </div>

      {/* Code Body with Auto-Scrolling Typewriter Stream */}
      <div 
        ref={codeContainerRef}
        className="p-4 sm:p-6 font-mono text-xs sm:text-[13px] leading-relaxed max-h-[440px] overflow-y-auto overflow-x-auto bg-[#0d1117]/95 scrollbar-thin relative scroll-smooth"
      >
        <pre className="text-slate-300 font-mono">
          <code dangerouslySetInnerHTML={{ __html: highlightDart(displayedCode) }} />
          {/* Animated Blinking Insertion Cursor */}
          <span 
            className={`inline-block w-2 h-4 bg-purple-400 align-middle ml-0.5 shadow-[0_0_8px_rgba(168,85,247,0.8)] ${
              isTyping ? 'animate-pulse' : 'animate-ping'
            }`}
          />
        </pre>
      </div>

      {/* Architectural Highlights & Concrete Rationale */}
      <div className="p-4 sm:p-5 bg-zinc-950 border-t border-zinc-800 grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
        {activeFeature.highlights.map((item, i) => (
          <div key={i} className="flex items-start gap-2 text-slate-400">
            <Sparkles className="w-3.5 h-3.5 text-purple-400 shrink-0 mt-0.5" />
            <span className="leading-snug">{item}</span>
          </div>
        ))}
      </div>

      {/* Bottom Footer Action Rail */}
      <div className="px-5 py-3 bg-black/80 border-t border-zinc-800/80 flex items-center justify-between text-xs font-mono text-slate-400">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
          <span>Zero external runtime dependencies • Pure Dart Ahead-of-Time Binary</span>
        </div>
        <a
          href={activeFeature.docLink}
          className="text-purple-400 hover:text-purple-300 flex items-center gap-1 font-bold transition hover:underline"
        >
          <span>Read {activeFeature.shortName} Docs</span>
          <ArrowRight className="w-3 h-3" />
        </a>
      </div>
    </div>
  );
}
