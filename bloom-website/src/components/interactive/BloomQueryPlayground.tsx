import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { Zap, RefreshCw, CheckCircle2, RotateCcw, AlertTriangle } from 'lucide-preact';

export function BloomQueryPlayground() {
  const [queryStatus, setQueryStatus] = useState<'FRESH' | 'STALE' | 'FETCHING' | 'OPTIMISTIC_MUTATION'>('FRESH');
  const [items, setItems] = useState<string[]>(['User Profile #42', 'User Preferences', 'Security Tokens']);
  const [log, setLog] = useState<string>('Query initialized with 5m staleTime');

  const handleRefetch = () => {
    setQueryStatus('FETCHING');
    setLog('[REFETCH] Revalidating in background...');
    setTimeout(() => {
      setQueryStatus('FRESH');
      setLog('[SUCCESS] Cache updated in background');
    }, 700);
  };

  const handleOptimisticAdd = () => {
    setQueryStatus('OPTIMISTIC_MUTATION');
    const newItem = `Optimistic Entry #${items.length + 1}`;
    setItems((prev) => [...prev, newItem]);
    setLog('[MUTATION] Added optimistically before server ACK');

    setTimeout(() => {
      setQueryStatus('FRESH');
      setLog('[SERVER_ACK] Server validated mutation');
    }, 900);
  };

  return (
    <div className="p-5 sm:p-8 lg:p-10 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Interactive Control */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 dark:border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Zap className="w-5 h-5 text-slate-300" />
            <h3 className="text-xl font-bold text-white tracking-tight">
              Interactive Bloom Query &amp; Cache Sandbox
            </h3>
          </div>
          <p className="text-xs text-slate-400">
            Test automatic background refetching, focus revalidation, and optimistic mutations.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleRefetch}
            disabled={queryStatus === 'FETCHING'}
            className="px-4 py-2.5 rounded-xl bg-white text-slate-950 font-black text-xs shadow-md hover:bg-slate-200 transition-all active:scale-95 disabled:opacity-50"
          >
            Trigger Refetch
          </button>
          <button
            onClick={handleOptimisticAdd}
            className="px-4 py-2.5 rounded-xl bg-zinc-900 border border-zinc-800 text-white font-bold text-xs hover:bg-zinc-800 transition-all active:scale-95"
          >
            + Optimistic Item
          </button>
        </div>
      </div>

      {/* Grid: 3 Pillars */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Pillar 1: Automatic Caching */}
        <div className="p-6 rounded-2xl bg-black border border-zinc-800 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-mono font-bold text-slate-400">1. Global Cache</span>
            <span className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold border ${
              queryStatus === 'FRESH' ? 'bg-emerald-950/40 text-emerald-400 border-emerald-800/40' : 'bg-amber-950/40 text-amber-400 border-amber-800/40'
            }`}>
              {queryStatus}
            </span>
          </div>

          <h4 className="text-sm font-bold text-white">Stale-While-Revalidate</h4>
          <p className="text-xs text-slate-400 leading-relaxed">
            Instant UI rendering from memory cache while fetching fresh data asynchronously.
          </p>
        </div>

        {/* Pillar 2: Focus Revalidation */}
        <div className="p-6 rounded-2xl bg-black border border-zinc-800 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-mono font-bold text-slate-400">2. Focus Listener</span>
            <span className="px-2 py-0.5 rounded bg-zinc-900 text-slate-300 font-mono text-[10px] font-bold border border-zinc-800">
              ACTIVE
            </span>
          </div>

          <h4 className="text-sm font-bold text-white">App Resume Refetch</h4>
          <p className="text-xs text-slate-400 leading-relaxed">
            Automatically refreshes query key states when device resumes focus.
          </p>
        </div>

        {/* Pillar 3: Optimistic Mutations */}
        <div className="p-6 rounded-2xl bg-black border border-zinc-800 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-mono font-bold text-slate-400">3. Mutations</span>
            <span className="px-2 py-0.5 rounded bg-zinc-900 text-slate-300 font-mono text-[10px] font-bold border border-zinc-800">
              AUTO_ROLLBACK
            </span>
          </div>

          <h4 className="text-sm font-bold text-white">Optimistic UI</h4>
          <p className="text-xs text-slate-400 leading-relaxed">
            Mutates UI state before server confirmation, rolling back cleanly if network fails.
          </p>
        </div>
      </div>

      {/* Live Data Items Preview */}
      <div className="p-5 rounded-2xl bg-black border border-zinc-800 font-mono text-xs space-y-3">
        <div className="flex items-center justify-between text-[11px] text-slate-400 pb-2 border-b border-zinc-800">
          <span>Cached Query Results ({items.length})</span>
          <span className="text-slate-300 font-bold">{log}</span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
          {items.map((it, idx) => (
            <div key={idx} className="p-2.5 rounded-lg bg-zinc-900 border border-zinc-800 flex items-center gap-2 text-slate-300">
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 flex-shrink-0" />
              <span className="truncate">{it}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
