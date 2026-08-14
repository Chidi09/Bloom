import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { FolderTree, CheckCircle2, ShieldCheck, Code2, ArrowRight, Sparkles } from 'lucide-preact';

interface RouteFile {
  id: string;
  path: string;
  urlRoute: string;
  guard: string;
  type: string;
  codeSnippet: string;
}

const routes: RouteFile[] = [
  {
    id: 'index',
    path: 'index.dart',
    urlRoute: '/',
    guard: 'None (Public)',
    type: 'Root View',
    codeSnippet: `// lib/app/routes/index.dart\n@RoutePage()\nclass HomeView extends BloomView<HomeController> {\n  @override\n  Widget build(BuildContext context) => Scaffold(body: HomeHero());\n}`,
  },
  {
    id: 'login',
    path: '(auth) / login.dart',
    urlRoute: '/login',
    guard: 'GuestGuard',
    type: 'Grouped Route',
    codeSnippet: `// lib/app/routes/(auth)/login.dart\n@RoutePage()\nclass LoginView extends BloomView<LoginController> {\n  @override\n  Widget build(BuildContext context) => LoginForm();\n}`,
  },
  {
    id: 'product',
    path: 'products / [id].dart',
    urlRoute: '/products/42',
    guard: 'AuthGuard',
    type: 'Dynamic Parameter',
    codeSnippet: `// lib/app/routes/products/[id].dart\n@RoutePage()\nclass ProductDetailsView extends BloomPage {\n  @PathParam('id')\n  final String productId;\n  ProductDetailsView({required this.productId});\n}`,
  },
  {
    id: 'layout',
    path: '_layout.dart',
    urlRoute: '/_layout',
    guard: 'AppGuard',
    type: 'Scaffold Layout',
    codeSnippet: `// lib/app/routes/_layout.dart\nclass RootScaffold extends BloomLayout {\n  @override\n  Widget build(BuildContext context, Widget child) {\n    return MainShell(navigationBar: BottomBar(), body: child);\n  }\n}`,
  },
];

export function FileSystemTreeExplorer() {
  const [activeRouteId, setActiveRouteId] = useState<string>('index');
  const activeRoute = routes.find((r) => r.id === activeRouteId) || routes[0];

  return (
    <div className="p-5 sm:p-8 lg:p-10 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 shadow-2xl max-w-5xl mx-auto space-y-8">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 dark:border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <FolderTree className="w-5 h-5 text-purple-400" />
            <h3 className="text-xl font-bold text-white tracking-tight">
              Interactive File-System Routing Visualizer
            </h3>
          </div>
          <p className="text-xs text-slate-400">
            Click any route file in the tree to inspect its auto-generated AST URL route definition.
          </p>
        </div>

        <span className="px-3 py-1 rounded-full bg-purple-500/10 text-purple-400 font-mono text-xs font-bold border border-purple-500/20">
          ZERO_BOILERPLATE
        </span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
        {/* Left Column: Interactive Directory Tree */}
        <div className="lg:col-span-5 p-6 rounded-2xl bg-black border border-zinc-800 flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-2 mb-4 pb-3 border-b border-zinc-800 font-mono text-xs font-bold text-slate-400">
              <FolderTree className="w-4 h-4 text-purple-400" />
              <span>lib / app / routes</span>
            </div>

            <div className="space-y-2 font-mono text-xs">
              {routes.map((r) => {
                const isActive = r.id === activeRouteId;

                return (
                  <button
                    key={r.id}
                    onClick={() => setActiveRouteId(r.id)}
                    className={`w-full flex items-center justify-between p-3 rounded-xl transition-all duration-200 border text-left ${
                      isActive
                        ? 'bg-purple-600 text-white font-bold border-purple-500 shadow-md shadow-purple-500/20'
                        : 'bg-zinc-900/80 text-slate-300 border-zinc-800 hover:border-zinc-700 hover:text-white'
                    }`}
                  >
                    <span className="truncate">{r.path}</span>
                    <span className={`text-[10px] px-2 py-0.5 rounded font-bold ${
                      isActive ? 'bg-white/20 text-white' : 'bg-black text-slate-400 border border-zinc-800'
                    }`}>
                      {r.type}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {/* Right Column: Code & Generated Route Inspector */}
        <div className="lg:col-span-7 space-y-4">
          <div className="p-4 rounded-2xl bg-zinc-900 border border-zinc-800 font-mono text-xs flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="text-slate-400">Resolved URL Route: </span>
              <strong className="text-purple-400 text-sm font-bold">{activeRoute.urlRoute}</strong>
            </div>
            <div>
              <span className="text-slate-400">Guard: </span>
              <strong className="text-teal-400 font-bold">{activeRoute.guard}</strong>
            </div>
          </div>

          <div className="rounded-2xl overflow-hidden bg-black border border-zinc-800 shadow-xl font-mono text-xs">
            <div className="flex items-center justify-between px-4 py-3 bg-zinc-900 border-b border-zinc-800">
              <span className="text-slate-300 font-bold">{activeRoute.path}</span>
              <span className="text-emerald-400 font-bold">TYPE_SAFE</span>
            </div>
            <pre className="p-5 text-slate-300 leading-relaxed overflow-x-auto">
              <code>{activeRoute.codeSnippet}</code>
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
}
