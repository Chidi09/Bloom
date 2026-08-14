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

  return (
    <div className="p-8 sm:p-10 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Control */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 dark:border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Zap className="w-5 h-5 text-purple-400" />
            <h3 className="text-xl font-bold text-white tracking-tight">
              Interactive Programmatic BloomCloud API Inspector
            </h3>
          </div>
          <p className="text-xs text-slate-400">
            Click run to test silent background download, progress hooks, and hot app restart.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleRunPipeline}
            disabled={step !== 'IDLE'}
            className="px-4 py-2.5 rounded-xl bg-white text-slate-950 font-black text-xs shadow-md hover:bg-slate-200 transition-all active:scale-95 disabled:opacity-50"
          >
            {step === 'CHECKING' || step === 'DOWNLOADING' ? (
              <span className="flex items-center gap-1.5">
                <RefreshCw className="w-3.5 h-3.5 animate-spin" /> Running...
              </span>
            ) : (
              'Run Update Flow'
            )}
          </button>

          {step === 'DOWNLOADED' && (
            <button
              onClick={handleApplyRestart}
              className="px-4 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs shadow-lg shadow-emerald-500/20 transition-all active:scale-95 animate-pulse"
            >
              Restart App &amp; Apply
            </button>
          )}
        </div>
      </div>

      {/* Main Grid: Code Inspector vs Live API Output */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left: Code Snippet */}
        <div className="lg:col-span-6 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono text-slate-400">
            <span className="font-bold text-white">lib / services / update_service.dart</span>
            <span className="text-purple-400 font-bold text-[10px]">DART_API</span>
          </div>

          <div className="rounded-2xl overflow-hidden bg-black border border-zinc-800 font-mono text-xs">
            <pre
              className="p-5 text-slate-100 leading-relaxed overflow-x-auto font-mono text-xs"
              dangerouslySetInnerHTML={{
                __html: highlightDart(`class UpdateService {
  Future<void> checkForPatches() async {
    final update = await BloomCloud.checkForUpdate();
    if (update.hasPatch) {
      await BloomCloud.downloadPatch(update.patchId);
      BloomCloud.restartApp();
    }
  }
}`),
              }}
            />
          </div>
        </div>

        {/* Right: Live API State Machine Output */}
        <div className="lg:col-span-6 space-y-4">
          <div className="p-5 rounded-2xl bg-black border border-zinc-800 space-y-4 font-mono text-xs">
            <div className="flex items-center justify-between text-[11px] text-slate-400 pb-2 border-b border-zinc-800">
              <span>BloomCloud Runtime State</span>
              <span className="text-emerald-400 font-bold">{step}</span>
            </div>

            <div className="space-y-2 text-[11px]">
              <div className={`p-3 rounded-xl border transition-all ${
                step === 'CHECKING' ? 'bg-zinc-900 border-purple-500 text-white' : 'bg-black border-zinc-800 text-slate-400'
              }`}>
                1. checkForUpdate() ➔ {step === 'IDLE' ? 'Waiting...' : step === 'CHECKING' ? 'Checking 142 Edge nodes...' : 'Patch v2.5.1 Found!'}
              </div>

              <div className={`p-3 rounded-xl border transition-all ${
                step === 'DOWNLOADING' || step === 'DOWNLOADED' ? 'bg-zinc-900 border-blue-500 text-white' : 'bg-black border-zinc-800 text-slate-400'
              }`}>
                2. downloadPatch() ➔ {step === 'DOWNLOADING' ? `Downloading... ${downloadProgress}%` : step === 'DOWNLOADED' || step === 'APPLIED' ? '142KB RSA-2048 Signed Patch Cached' : 'Pending'}
              </div>

              <div className={`p-3 rounded-xl border transition-all ${
                step === 'APPLIED' ? 'bg-emerald-950/60 border-emerald-500 text-emerald-300 font-bold' : 'bg-black border-zinc-800 text-slate-400'
              }`}>
                3. restartApp() ➔ {step === 'APPLIED' ? '✔ App Restarted! v2.5.1 Bytecode Active' : 'Pending'}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
