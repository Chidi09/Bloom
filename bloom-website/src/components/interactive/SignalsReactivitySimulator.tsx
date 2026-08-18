import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { RefreshCw, Zap, CheckCircle2, Activity, Play } from 'lucide-preact';

export function SignalsReactivitySimulator() {
  const [count, setCount] = useState<number>(5);
  const [rebuildCount, setRebuildCount] = useState<number>(1);
  const [lastRebuildTime, setLastRebuildTime] = useState<string>('0.2ms');

  const isEven = count % 2 === 0;

  const handleIncrement = () => {
    setCount((prev) => prev + 1);
    setRebuildCount((prev) => prev + 1);
    setLastRebuildTime((Math.random() * 0.3 + 0.1).toFixed(2) + 'ms');
  };

  const handleReset = () => {
    setCount(0);
    setRebuildCount((prev) => prev + 1);
  };

  return (
    <div className="p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto space-y-8">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <RefreshCw className="w-5 h-5 text-teal-600 dark:text-teal-400" />
            <h3 className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Live 60FPS Signals Reactivity Simulator
            </h3>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-400">
            Click to update signal state and observe sub-millisecond targeted widget rebuilds.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleIncrement}
            className="px-4 py-2.5 rounded-xl bg-teal-600 hover:bg-teal-500 text-white font-bold text-xs shadow-md shadow-teal-500/20 transition-all active:scale-95"
          >
            + Increment Signal
          </button>
          <button
            onClick={handleReset}
            className="px-3 py-2.5 rounded-xl bg-slate-100 dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 text-slate-700 dark:text-slate-300 font-bold text-xs hover:bg-slate-200 dark:hover:bg-zinc-800 transition-all"
          >
            Reset
          </button>
        </div>
      </div>

      {/* Grid: Signal State vs Target Widget */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
        {/* Left: Signals Controller State */}
        <div className="lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 text-slate-900 dark:text-white border border-slate-200 dark:border-zinc-800 font-mono text-xs space-y-4">
          <div className="flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400 pb-2 border-b border-slate-200 dark:border-zinc-800">
            <span>CounterController (Signal Memory)</span>
            <span className="text-teal-600 dark:text-teal-400 font-bold">REBUILD_TIME: {lastRebuildTime}</span>
          </div>

          <div className="space-y-3">
            <div className="p-3 rounded-xl bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 flex items-center justify-between">
              <span className="text-slate-600 dark:text-slate-400">final count = signal({count});</span>
              <span className="text-teal-600 dark:text-teal-400 font-bold text-sm">{count}</span>
            </div>

            <div className="p-3 rounded-xl bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 flex items-center justify-between">
              <span className="text-slate-600 dark:text-slate-400">computed(() =&gt; count % 2 == 0)</span>
              <span className={`font-bold ${isEven ? 'text-emerald-600 dark:text-emerald-400' : 'text-amber-600 dark:text-amber-400'}`}>
                {isEven ? 'TRUE (Even)' : 'FALSE (Odd)'}
              </span>
            </div>
          </div>

          <div className="text-[11px] text-slate-500 pt-2 border-t border-slate-200 dark:border-zinc-800">
            Total Widget Rebuilds Triggered: <strong className="text-slate-900 dark:text-slate-200">{rebuildCount}</strong>
          </div>
        </div>

        {/* Right: Targeted Widget Tree */}
        <div className="lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between text-xs font-mono font-bold text-slate-500 dark:text-slate-400 mb-4 pb-2 border-b border-slate-200 dark:border-zinc-800">
              <span>Flutter Widget Tree</span>
              <span className="text-emerald-600 dark:text-emerald-400 flex items-center gap-1 text-[10px] font-bold">
                <Activity className="w-3 h-3" /> Impeller 60FPS
              </span>
            </div>

            <div className="space-y-3 text-xs font-mono">
              <div className="p-2.5 rounded-lg bg-white dark:bg-zinc-900 text-slate-600 dark:text-slate-400 text-[11px] border border-slate-200 dark:border-zinc-800">
                Scaffold (No Rebuild)
              </div>
              <div className="p-2.5 rounded-lg bg-white dark:bg-zinc-900 text-slate-600 dark:text-slate-400 text-[11px] ml-4 border border-slate-200 dark:border-zinc-800">
                Column (No Rebuild)
              </div>
              
              {/* Target Highlighted Watch Widget */}
              <div className="p-4 rounded-xl bg-teal-500/10 border-2 border-teal-500 ml-8 text-teal-700 dark:text-teal-300 shadow-md animate-pulse">
                <div className="flex items-center justify-between font-bold">
                  <span>Watch((context) =&gt; Text('Count: {count}'))</span>
                  <span className="text-[10px] px-2 py-0.5 rounded bg-teal-600 text-white">REBUILT</span>
                </div>
              </div>
            </div>
          </div>

          <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-4">
            Only the <code className="font-mono text-teal-600 dark:text-teal-400 font-bold">Watch()</code> widget is rebuilt when <code className="font-mono text-teal-600 dark:text-teal-400 font-bold">count.value</code> mutates. The parent Scaffold and Column remain completely untouched.
          </p>
        </div>
      </div>
    </div>
  );
}
