import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { FolderTree, RefreshCw, Send, Sliders, Code, Zap, ArrowRight, CheckCircle2, Sparkles, Terminal, Activity } from 'lucide-preact';

interface Feature {
  id: string;
  icon: any;
  title: string;
  description: string;
  badge: string;
  demoType: 'routing' | 'signals' | 'query' | 'ota' | 'studio' | 'codegen';
  color: string;
}

const features: Feature[] = [
  {
    id: 'routing',
    icon: FolderTree,
    title: 'File-System Routing',
    description: 'Next.js-style directory routing over go_router with typed params, layout groups, and route guards.',
    badge: 'ARCHITECTURE',
    demoType: 'routing',
    color: '#8B5CF6',
  },
  {
    id: 'signals',
    icon: RefreshCw,
    title: 'Signals Reactive State',
    description: 'Fine-grained reactivity with zero setState. Rebuilds only the exact widgets reading a signal at 60fps.',
    badge: 'STATE_ENGINE',
    demoType: 'signals',
    color: '#20C9B0',
  },
  {
    id: 'query',
    icon: Zap,
    title: 'Bloom Query',
    description: 'Declarative server-state caching, background refetching, and pagination with optimistic mutations.',
    badge: 'SERVER_STATE',
    demoType: 'query',
    color: '#FF884D',
  },
  {
    id: 'ota',
    icon: Send,
    title: 'Shorebird OTA Updates',
    description: 'Code-signed over-the-air byte patches with canary rollouts, instant rollback, and zero App Store delays.',
    badge: 'CLOUD_DEPLOY',
    demoType: 'ota',
    color: '#3B82F6',
  },
  {
    id: 'studio',
    icon: Sliders,
    title: 'Bloom UI Studio',
    description: 'shadcn-style composable primitives with live design-token controls for Flutter Mobile & Web.',
    badge: 'UI_SYSTEM',
    demoType: 'studio',
    color: '#FF4B8B',
  },
  {
    id: 'codegen',
    icon: Code,
    title: 'Deterministic Code Gen',
    description: 'CLI generators scaffold routes, controllers, and models deterministically on file save in sub-50ms.',
    badge: 'CLI_AST',
    demoType: 'codegen',
    color: '#10B981',
  },
];

export function FeatureGridShowcase() {
  // Signals demo state
  const [signalCount, setSignalCount] = useState<number>(42);

  // Query demo state
  const [queryState, setQueryState] = useState<'IDLE' | 'FETCHING' | 'SUCCESS'>('SUCCESS');

  // Codegen demo state
  const [genCount, setGenCount] = useState<number>(14);

  const handleFetchQuery = () => {
    setQueryState('FETCHING');
    setTimeout(() => setQueryState('SUCCESS'), 800);
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 max-w-6xl mx-auto">
      {features.map((f) => {
        const IconComponent = f.icon;

        return (
          <div
            key={f.id}
            className="group relative p-7 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 hover:border-slate-300 dark:hover:border-zinc-700 hover:shadow-xl transition-all duration-300 flex flex-col justify-between"
          >
            <div>
              {/* Header Icon & Badge */}
              <div className="flex items-center justify-between mb-5">
                <div 
                  className="w-12 h-12 rounded-2xl flex items-center justify-center border shadow-sm transition-transform group-hover:scale-110"
                  style={{ backgroundColor: `${f.color}15`, borderColor: `${f.color}30` }}
                >
                  <IconComponent className="w-6 h-6" style={{ color: f.color }} />
                </div>
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border border-slate-200 dark:border-zinc-800">
                  {f.badge}
                </span>
              </div>

              <h3 className="text-xl font-bold text-slate-900 dark:text-white mb-2 tracking-tight">
                {f.title}
              </h3>

              <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed mb-6 font-normal">
                {f.description}
              </p>
            </div>

            {/* Interactive Feature Micro-Interactive Sandbox */}
            <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-zinc-950 text-slate-900 dark:text-white border border-slate-200 dark:border-zinc-800 font-mono text-xs space-y-2">
              {f.demoType === 'routing' && (
                <div className="flex items-center justify-between text-[11px]">
                  <span className="text-slate-500 dark:text-slate-400">/routes/users/[id].dart</span>
                  <span className="text-purple-600 dark:text-purple-400 font-bold">params.id</span>
                </div>
              )}

              {f.demoType === 'signals' && (
                <div className="flex items-center justify-between text-[11px]">
                  <span className="text-slate-500 dark:text-slate-400">count.value = {signalCount}</span>
                  <button
                    onClick={() => setSignalCount((c) => c + 1)}
                    className="px-2.5 py-1 rounded bg-teal-600 hover:bg-teal-500 text-white font-bold text-[10px] transition-colors shadow-sm"
                  >
                    + Increment Signal
                  </button>
                </div>
              )}

              {f.demoType === 'query' && (
                <div className="flex items-center justify-between text-[11px]">
                  <span className={`font-bold ${queryState === 'FETCHING' ? 'text-amber-500 animate-pulse' : 'text-emerald-600 dark:text-emerald-400'}`}>
                    [{queryState}] Stale: 5m
                  </span>
                  <button
                    onClick={handleFetchQuery}
                    className="px-2.5 py-1 rounded bg-amber-600 hover:bg-amber-500 text-white font-bold text-[10px] transition-colors shadow-sm"
                  >
                    Refetch
                  </button>
                </div>
              )}

              {f.demoType === 'ota' && (
                <div className="flex items-center justify-between text-[11px]">
                  <span className="text-slate-500 dark:text-slate-400">Delta Bytecode</span>
                  <span className="text-blue-600 dark:text-blue-400 font-bold">142KB Signed</span>
                </div>
              )}

              {f.demoType === 'studio' && (
                <div className="flex items-center justify-between text-[11px]">
                  <span className="text-slate-500 dark:text-slate-400">Token Variant</span>
                  <span className="text-pink-600 dark:text-pink-400 font-bold">shadcn/mobile</span>
                </div>
              )}

              {f.demoType === 'codegen' && (
                <div className="flex items-center justify-between text-[11px]">
                  <span className="text-slate-500 dark:text-slate-400">Generated {genCount} files</span>
                  <button
                    onClick={() => setGenCount((c) => c + 1)}
                    className="px-2.5 py-1 rounded bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[10px] transition-colors shadow-sm"
                  >
                    $ bloom gen
                  </button>
                </div>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
