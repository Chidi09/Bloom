import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { Play, CheckCircle2, RefreshCw, Zap, Download, RotateCcw } from 'lucide-preact';
import { highlightDart } from '../../lib/dart-highlighter';

export function ProgrammaticUpdateExplorer() {
  const [step, setStep] = useState<'IDLE' | 'CHECKING' | 'FOUND' | 'DOWNLOADING' | 'DOWNLOADED' | 'APPLIED'>('IDLE');
  const [downloadProgress, setDownloadProgress] = useState<number>(0);

  const handleRunPipeline = () => {
    setStep('CHECKING');
    setDownloadProgress(0);

    setTimeout(() => {
      setStep('FOUND');
      setTimeout(() => {
        setStep('DOWNLOADING');
        let prog = 0;
        const interval = setInterval(() => {
          prog += 25;
          setDownloadProgress(prog);
          if (prog >= 100) {
            clearInterval(interval);
            setStep('DOWNLOADED');
          }
        }, 200);
      }, 600);
    }, 600);
  };

  const handleApplyRestart = () => {
    setStep('APPLIED');
    setTimeout(() => setStep('IDLE'), 2000);
  };

  const dartSnippet = `// Programmatic OTA download & restart
final ota = BloomCloud.instance;
final update = await ota.checkForUpdate();

if (update.isAvailable) {
  await ota.downloadUpdate(
    onProgress: (p) => progress.value = p,
  );
  await ota.applyAndRestart();
}`;

  return (
    <div className="p-8 sm:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Control */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Zap className="w-5 h-5 text-purple-600 dark:text-purple-400" />
            <h3 className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Interactive Programmatic BloomCloud API Inspector
            </h3>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-400">
            Click run to test silent background download, progress hooks, and hot app restart.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleRunPipeline}
            disabled={step !== 'IDLE'}
            className="px-4 py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-950 font-black text-xs shadow-md hover:bg-slate-800 dark:hover:bg-slate-200 transition-all active:scale-95 disabled:opacity-50"
          >
            {step === 'CHECKING' || step === 'DOWNLOADING' ? (
              <span className="flex items-center gap-1.5">
                <RefreshCw className="w-3.5 h-3.5 animate-spin" /> Running...
              </span>
            ) : (
              <span className="flex items-center gap-1.5">
                <Play className="w-3.5 h-3.5" /> Execute Update Flow
              </span>
            )}
          </button>
          {step === 'DOWNLOADED' && (
            <button
              onClick={handleApplyRestart}
              className="px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-black text-xs shadow-md animate-bounce transition-all"
            >
              Restart App (Apply Patch)
            </button>
          )}
        </div>
      </div>

      {/* Grid: Code vs State Simulation */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
        {/* Left: Dart API Code */}
        <div className="lg:col-span-6 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono text-slate-500 dark:text-slate-400">
            <span className="font-bold text-slate-900 dark:text-white">lib / services / update_service.dart</span>
            <span className="text-purple-600 dark:text-purple-400 font-bold text-[10px]">CLIENT_SDK</span>
          </div>

          <div className="rounded-2xl overflow-hidden bg-slate-950 dark:bg-black border border-slate-800 dark:border-zinc-800 font-mono text-xs shadow-xl">
            <pre
              className="p-5 text-slate-100 leading-relaxed overflow-x-auto font-mono text-xs"
              dangerouslySetInnerHTML={{ __html: highlightDart(dartSnippet) }}
            />
          </div>
        </div>

        {/* Right: State Pipeline Visualizer */}
        <div className="lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 flex flex-col justify-between space-y-4 font-mono text-xs">
          <div className="space-y-3">
            <div className="flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400 pb-2 border-b border-slate-200 dark:border-zinc-800">
              <span>Client State Machine</span>
              <span className={`font-bold ${step === 'APPLIED' ? 'text-emerald-600 dark:text-emerald-400' : 'text-blue-600 dark:text-blue-400'}`}>
                {step}
              </span>
            </div>

            <div className="space-y-2">
              <div className={`p-3 rounded-xl border transition-all ${step !== 'IDLE' ? 'bg-white dark:bg-zinc-900 border-blue-500/40 text-blue-600 dark:text-blue-400 font-bold' : 'bg-white/60 dark:bg-zinc-900/60 border-slate-200 dark:border-zinc-800 text-slate-400'}`}>
                1. Checking Shorebird Edge CDN...
              </div>
              <div className={`p-3 rounded-xl border transition-all ${step === 'DOWNLOADING' || step === 'DOWNLOADED' || step === 'APPLIED' ? 'bg-white dark:bg-zinc-900 border-teal-500/40 text-teal-600 dark:text-teal-400 font-bold' : 'bg-white/60 dark:bg-zinc-900/60 border-slate-200 dark:border-zinc-800 text-slate-400'}`}>
                2. Downloading byte delta patch ({downloadProgress}%)
              </div>
              <div className={`p-3 rounded-xl border transition-all ${step === 'APPLIED' ? 'bg-white dark:bg-zinc-900 border-emerald-500/40 text-emerald-600 dark:text-emerald-400 font-bold' : 'bg-white/60 dark:bg-zinc-900/60 border-slate-200 dark:border-zinc-800 text-slate-400'}`}>
                3. AOT delta mounted — App state preserved cleanly
              </div>
            </div>
          </div>

          <div className="p-3 bg-white dark:bg-zinc-900 rounded-xl border border-slate-200 dark:border-zinc-800 text-[11px] text-slate-600 dark:text-slate-400">
            ⚡️ Downloads execute silently on low-priority background I/O threads.
          </div>
        </div>
      </div>
    </div>
  );
}
