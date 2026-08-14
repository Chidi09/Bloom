import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { FolderTree, RefreshCw, Zap, Cpu, CheckCircle2, ArrowRight, Code2, Play, Sparkles } from 'lucide-preact';

interface ArchitectureTab {
  id: string;
  name: string;
  badge: string;
  icon: any;
  description: string;
  code: string;
  highlights: string[];
}

const tabs: ArchitectureTab[] = [
  {
    id: 'routing',
    name: 'File-System Routing',
    badge: 'AST_GENERATOR',
    icon: FolderTree,
    description: 'Next.js-style directory structure mapping directly to type-safe go_router definitions automatically on file save.',
    code: `// lib/app/routes/products/[id].dart\n@RoutePage()\nclass ProductPage extends BloomPage {\n  @PathParam('id')\n  final String productId;\n\n  ProductPage({required this.productId});\n\n  @override\n  Widget build(BuildContext context) {\n    return Watch((_) => Text('Product ID: \$productId'));\n  }\n}`,
    highlights: [
      'Automatic URL parameter binding (@PathParam)',
      'Group routes with parentheses `(auth)/login.dart`',
      'Nested layout inheritance via `_layout.dart`',
    ],
  },
  {
    id: 'signals',
    name: 'Signals State API',
    badge: 'ZERO_SETSTATE',
    icon: RefreshCw,
    description: 'Fine-grained reactive signals tracking widget dependencies automatically. Zero setState, zero verbose Bloc streams.',
    code: `// lib/controllers/cart_controller.dart\nclass CartController extends BloomController {\n  final items = signal<List<CartItem>>([]);\n\n  late final totalPrice = computed(() =>\n    items.value.fold(0.0, (sum, i) => sum + i.price)\n  );\n\n  void addItem(CartItem item) => items.value = [...items.value, item];\n}`,
    highlights: [
      'Sub-millisecond dependency tracking at 60fps',
      'Computed signals auto-memoize derived state',
      'Rebuilds only the exact widget reading the signal',
    ],
  },
  {
    id: 'query',
    name: 'Bloom Query Engine',
    badge: 'SERVER_STATE',
    icon: Zap,
    description: 'Declarative data fetching, background revalidation, global memory cache, and optimistic mutation rollbacks.',
    code: `// Declarative query hook\nfinal productQuery = useBloomQuery<Product>(\n  key: 'product_\$id',\n  fetcher: () => api.fetchProduct(id),\n  staleTime: Duration(minutes: 5),\n);\n\nreturn productQuery.when(\n  data: (p) => ProductCard(product: p),\n  loading: () => SkeletonLoader(),\n  error: (e) => ErrorNotice(e),\n);`,
    highlights: [
      'Global in-memory cache with stale-while-revalidate',
      'Window focus & app resume revalidation',
      'Automatic optimistic UI updates with rollback',
    ],
  },
  {
    id: 'boot',
    name: 'Thin Boot & DI',
    badge: 'LIFECYCLE_BOOT',
    icon: Cpu,
    description: 'Handles environment loading, DI registration, logging, and router initialization cleanly before runApp().',
    code: `// lib/main.dart\nFuture<void> main() async {\n  // 1. Boot environment & DI container\n  await Bloom.boot(config: 'bloom.yaml');\n\n  // 2. Inject singletons cleanly\n  inject<AuthService>();\n\n  // 3. Launch application\n  runApp(const MyApp());\n}`,
    highlights: [
      'Deterministic boot pipeline prevents null states',
      'Scoped DI container without global service locator pollution',
      'Unified environment manifest in `bloom.yaml`',
    ],
  },
];

export function BuildArchitecturePlayground() {
  const [activeTabId, setActiveTabId] = useState<string>('routing');
  const activeTab = tabs.find((t) => t.id === activeTabId) || tabs[0];

  return (
    <div className="p-5 sm:p-8 lg:p-10 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 shadow-2xl relative overflow-hidden max-w-6xl mx-auto">
      <div className="absolute top-0 right-0 w-96 h-96 bg-purple-500/5 rounded-full blur-3xl pointer-events-none" />

      {/* Tab Selectors */}
      <div className="flex items-center gap-2 mb-8 pb-4 border-b border-slate-800 dark:border-white/10 relative z-10 overflow-x-auto no-scrollbar">
        {tabs.map((t) => {
          const IconComp = t.icon;
          const isActive = t.id === activeTabId;

          return (
            <button
              key={t.id}
              onClick={() => setActiveTabId(t.id)}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-xl font-bold text-xs tracking-tight transition-all duration-200 border ${
                isActive
                  ? 'bg-white text-slate-950 border-white shadow-lg shadow-white/10 scale-105 font-black'
                  : 'bg-slate-900/80 dark:bg-zinc-900/80 text-slate-400 border-slate-800 dark:border-zinc-800 hover:text-white hover:border-slate-700'
              }`}
            >
              <IconComp className="w-4 h-4" />
              <span>{t.name}</span>
            </button>
          );
        })}
      </div>

      {/* Main Sandbox Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start relative z-10">
        {/* Left Column: Description & Highlights */}
        <div className="lg:col-span-5 space-y-5">
          <div className="flex items-center gap-2">
            <span className="px-3 py-1 rounded-full bg-purple-500/10 text-purple-400 text-xs font-mono font-bold border border-purple-500/20">
              {activeTab.badge}
            </span>
          </div>

          <h3 className="text-2xl sm:text-3xl font-black text-white tracking-tight">
            {activeTab.name}
          </h3>

          <p className="text-sm text-slate-300 leading-relaxed font-normal">
            {activeTab.description}
          </p>

          <div className="space-y-3 pt-2">
            {activeTab.highlights.map((h, i) => (
              <div key={i} className="flex items-start gap-2.5 text-xs sm:text-sm text-slate-200 font-medium">
                <CheckCircle2 className="w-4 h-4 text-purple-400 flex-shrink-0 mt-0.5" />
                <span>{h}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Right Column: Code Editor */}
        <div className="lg:col-span-7">
          <div className="rounded-2xl overflow-hidden bg-black border border-zinc-800 shadow-2xl font-mono text-xs">
            <div className="flex items-center justify-between px-4 py-3 bg-zinc-900/90 border-b border-zinc-800">
              <div className="flex items-center gap-2">
                <div className="w-2.5 h-2.5 rounded-full bg-rose-500/80" />
                <div className="w-2.5 h-2.5 rounded-full bg-amber-500/80" />
                <div className="w-2.5 h-2.5 rounded-full bg-emerald-500/80" />
                <span className="ml-2 text-[11px] text-slate-400 font-bold">bloom-playground.dart</span>
              </div>
              <span className="text-[10px] text-purple-400 font-bold">AOT_SAFE</span>
            </div>
            <pre className="p-5 text-slate-300 leading-relaxed overflow-x-auto">
              <code>{activeTab.code}</code>
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
}
