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
    <div className="p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Interactive Control */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Zap className="w-5 h-5 text-amber-500" />
            <h3 className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Interactive Bloom Query &amp; Cache Sandbox
            </h3>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-400">
            Test automatic background refetching, focus revalidation, and optimistic mutations.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleRefetch}
            disabled={queryStatus === 'FETCHING'}
            className="px-4 py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-950 font-black text-xs shadow-md hover:bg-slate-800 dark:hover:bg-slate-200 transition-all active:scale-95 disabled:opacity-50"
          >
            Trigger Refetch
          </button>
          <button
            onClick={handleOptimisticAdd}
            className="px-4 py-2.5 rounded-xl bg-slate-100 dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 text-slate-900 dark:text-white font-bold text-xs hover:bg-slate-200 dark:hover:bg-zinc-800 transition-all active:scale-95"
          >
            + Optimistic Item
          </button>
        </div>
      </div>

      {/* Main Sandbox Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
        {/* Left: Query Cache Node State */}
        <div className="lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 font-mono text-xs space-y-4">
          <div className="flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400 pb-2 border-b border-slate-200 dark:border-zinc-800">
            <span>Query Cache Key: ['user', 42]</span>
            <span className={`font-bold ${
              queryStatus === 'FETCHING' ? 'text-amber-500 animate-pulse' : 'text-emerald-600 dark:text-emerald-400'
            }`}>
              STATUS: {queryStatus}
            </span>
          </div>

          <div className="space-y-2">
            {items.map((item, idx) => (
              <div key={idx} className="p-3 rounded-xl bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 flex items-center justify-between">
                <span className="text-slate-700 dark:text-slate-300">{item}</span>
                <span className="text-[10px] font-mono text-slate-400">Cached</span>
              </div>
            ))}
          </div>

          <div className="text-[11px] text-slate-500 pt-2 border-t border-slate-200 dark:border-zinc-800">
            staleTime: 5m &nbsp;·&nbsp; gcTime: 24h &nbsp;·&nbsp; retry: 3
          </div>
        </div>

        {/* Right: Real-time Event Logger */}
        <div className="lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 flex flex-col justify-between font-mono text-xs">
          <div>
            <div className="flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400 pb-2 border-b border-slate-200 dark:border-zinc-800 mb-3">
              <span>Cache Lifecycle Event</span>
              <span className="text-emerald-600 dark:text-emerald-400 font-bold">MEMORY_ACTIVE</span>
            </div>

            <div className="p-3.5 rounded-xl bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 text-slate-700 dark:text-slate-200 leading-relaxed">
              {log}
            </div>
          </div>

          <div className="mt-4 p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-700 dark:text-amber-400 text-[11px]">
            ⚡️ Mutations render on device immediately, auto-reverting if the remote API network call rejects.
          </div>
        </div>
      </div>
    </div>
  );
}
