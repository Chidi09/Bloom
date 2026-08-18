import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { FolderTree, CheckCircle2, ShieldCheck, Code2, ArrowRight, Sparkles } from 'lucide-preact';
import { highlightDart } from '../../lib/dart-highlighter';

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
    <div className="p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto space-y-8">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <FolderTree className="w-5 h-5 text-purple-600 dark:text-purple-400" />
            <h3 className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Interactive File-System Routing Visualizer
            </h3>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-400">
            Click files in the directory tree to inspect automatically mapped go_router definitions.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left: Directory Tree */}
        <div className="lg:col-span-5 p-5 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 space-y-3 font-mono text-xs">
          <div className="text-[11px] font-bold text-slate-500 dark:text-slate-400 pb-2 border-b border-slate-200 dark:border-zinc-800">
            📁 lib / app / routes /
          </div>

          <div className="space-y-1.5 pt-1">
            {routes.map((r) => {
              const isActive = r.id === activeRouteId;
              return (
                <button
                  key={r.id}
                  onClick={() => setActiveRouteId(r.id)}
                  className={`w-full p-2.5 rounded-xl text-left transition flex items-center justify-between border ${
                    isActive
                      ? 'bg-purple-600 text-white font-bold border-purple-600 shadow-md'
                      : 'bg-white dark:bg-zinc-900 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-zinc-800 hover:border-purple-400'
                  }`}
                >
                  <span className="truncate">📄 {r.path}</span>
                  <span className={`text-[10px] px-1.5 py-0.5 rounded ${
                    isActive ? 'bg-purple-700 text-white' : 'bg-slate-100 dark:bg-zinc-800 text-slate-500 dark:text-slate-400'
                  }`}>
                    {r.type.split(' ')[0]}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Right: Code Generation Inspector */}
        <div className="lg:col-span-7 space-y-4">
          <div className="p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 flex items-center justify-between font-mono text-xs">
            <div>
              <span className="text-[10px] text-slate-500 dark:text-slate-400 block font-bold">MAPPED ROUTE PATH</span>
              <span className="text-sm font-bold text-purple-600 dark:text-purple-400">{activeRoute.urlRoute}</span>
            </div>
            <div className="text-right">
              <span className="text-[10px] text-slate-500 dark:text-slate-400 block font-bold">ROUTE GUARD</span>
              <span className="text-xs font-semibold text-emerald-600 dark:text-emerald-400">{activeRoute.guard}</span>
            </div>
          </div>

          <div className="rounded-2xl overflow-hidden bg-slate-950 dark:bg-black border border-slate-800 dark:border-zinc-800 shadow-2xl font-mono text-xs">
            <div className="flex items-center justify-between px-4 py-3 bg-slate-900 dark:bg-zinc-950 border-b border-slate-800 dark:border-zinc-800">
              <span className="text-[11px] text-slate-400 font-bold">{activeRoute.path}</span>
              <span className="text-[10px] text-purple-400 font-bold">AUTO_COMPILED</span>
            </div>
            <pre
              className="p-5 text-slate-100 leading-relaxed overflow-x-auto font-mono text-xs"
              dangerouslySetInnerHTML={{ __html: highlightDart(activeRoute.codeSnippet) }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
