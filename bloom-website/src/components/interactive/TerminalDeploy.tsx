import { useState } from 'preact/hooks';
import { Play, CheckCircle2, ShieldCheck, Zap, RefreshCw, Terminal } from 'lucide-preact';
import { showToast } from '../common/ToastSystem';

interface LogLine {
  time: string;
  msg: string;
  type: 'cmd' | 'info' | 'success' | 'warn';
}

export function TerminalDeploy() {
  const [isDeploying, setIsDeploying] = useState(false);
  const [stage, setStage] = useState<'idle' | 'bundle' | 'sign' | 'deploy' | 'complete'>('idle');
  const [logs, setLogs] = useState<LogLine[]>([
    { time: '12:00:00', msg: '// Standby. Click "Push Update" to simulate live OTA.', type: 'info' },
  ]);

  const getTime = () => new Date().toLocaleTimeString().split(' ')[0];

  const triggerDeploy = async () => {
    if (isDeploying) return;
    setIsDeploying(true);
    setStage('bundle');
    setLogs([{ time: getTime(), msg: '$ bloom cloud deploy --channel production', type: 'cmd' }]);

    const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

    await delay(400);
    setLogs((prev) => [
      ...prev,
      { time: getTime(), msg: 'Bundling Dart AOT engine & UI assets...', type: 'info' },
    ]);

    await delay(1000);
    setStage('sign');
    setLogs((prev) => [
      ...prev,
      { time: getTime(), msg: 'Bundle size: 4.2 MB (Gzipped)', type: 'info' },
      { time: getTime(), msg: 'Applying RSA-2048 cryptographic signature...', type: 'info' },
    ]);

    await delay(1000);
    setStage('deploy');
    setLogs((prev) => [
      ...prev,
      { time: getTime(), msg: 'Signature verified. Hash: 0x9f8a...2b1', type: 'info' },
      { time: getTime(), msg: 'Propagating byte-patch to 142 Edge CDN nodes...', type: 'info' },
    ]);

    await delay(1200);
    setStage('complete');
    setLogs((prev) => [
      ...prev,
      { time: getTime(), msg: '✓ Deployment successful! Live on Edge in 1.8s', type: 'success' },
    ]);
    setIsDeploying(false);
    showToast('Deployment Successful', 'OTA patch live across 142 Edge CDN nodes globally.', 'emerald');
  };

  return (
    <div className="bg-[#0D1117] rounded-3xl border border-slate-800 shadow-2xl p-6 relative overflow-hidden group">
      {/* Glow effect */}
      <div className="absolute inset-0 bg-blue-500/5 group-hover:bg-blue-500/10 transition-colors pointer-events-none" />

      {/* Terminal Top Bar */}
      <div className="flex items-center justify-between mb-6 border-b border-slate-800 pb-4 relative z-10">
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-full bg-slate-700" />
          <div className="w-3 h-3 rounded-full bg-slate-700" />
          <div className="w-3 h-3 rounded-full bg-slate-700" />
          <span className="ml-2 text-xs font-mono text-slate-400 flex items-center gap-1.5">
            <Terminal className="w-3.5 h-3.5 text-blue-400" strokeWidth={1.75} />
            bloom-cloud-cli v2.5.1
          </span>
        </div>
        <button
          onClick={triggerDeploy}
          disabled={isDeploying}
          className="px-3.5 py-1.5 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white rounded-lg text-xs font-mono font-bold shadow transition-all active:scale-95 flex items-center gap-1.5"
        >
          {isDeploying ? (
            <RefreshCw className="w-3.5 h-3.5 animate-spin" strokeWidth={2} />
          ) : (
            <Play className="w-3.5 h-3.5" strokeWidth={2} />
          )}
          <span>{isDeploying ? 'Deploying...' : 'Push Update'}</span>
        </button>
      </div>

      {/* Terminal Log Screen */}
      <div className="font-mono text-[13px] leading-relaxed h-[220px] overflow-y-auto space-y-1 relative z-10 pr-2">
        {logs.map((log, index) => (
          <div key={index} className="flex items-start gap-2">
            <span className="text-slate-600 text-[11px] shrink-0">[{log.time}]</span>
            {log.type === 'cmd' ? (
              <span className="text-blue-400 font-bold">{log.msg}</span>
            ) : log.type === 'success' ? (
              <span className="text-emerald-400 font-bold">{log.msg}</span>
            ) : (
              <span className="text-slate-300">{log.msg}</span>
            )}
          </div>
        ))}
        {isDeploying && (
          <div className="flex items-center gap-2 text-blue-400 font-mono text-xs pt-1">
            <span className="w-2 h-2 rounded-full bg-blue-400 animate-ping" />
            Processing OTA pipeline...
          </div>
        )}
      </div>

      {/* Pipeline Stage Nodes */}
      <div className="mt-6 flex items-center justify-between relative pt-6 border-t border-slate-800/80 z-10">
        <div className="absolute top-[38px] left-8 right-8 h-0.5 bg-slate-800 -z-10" />

        <div className="flex flex-col items-center gap-1.5">
          <div
            className={`w-7 h-7 rounded-full flex items-center justify-center transition-all border-2 ${
              stage === 'bundle' || stage === 'sign' || stage === 'deploy' || stage === 'complete'
                ? 'bg-blue-500 border-blue-400 text-white shadow-[0_0_15px_rgba(59,130,246,0.8)]'
                : 'bg-slate-800 border-slate-700 text-slate-500'
            }`}
          >
            <Zap className="w-3.5 h-3.5" strokeWidth={2} />
          </div>
          <span className="text-[10px] font-mono text-slate-400">Bundle</span>
        </div>

        <div className="flex flex-col items-center gap-1.5">
          <div
            className={`w-7 h-7 rounded-full flex items-center justify-center transition-all border-2 ${
              stage === 'sign' || stage === 'deploy' || stage === 'complete'
                ? 'bg-blue-500 border-blue-400 text-white shadow-[0_0_15px_rgba(59,130,246,0.8)]'
                : 'bg-slate-800 border-slate-700 text-slate-500'
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" strokeWidth={2} />
          </div>
          <span className="text-[10px] font-mono text-slate-400">Sign</span>
        </div>

        <div className="flex flex-col items-center gap-1.5">
          <div
            className={`w-7 h-7 rounded-full flex items-center justify-center transition-all border-2 ${
              stage === 'complete'
                ? 'bg-emerald-500 border-emerald-400 text-white shadow-[0_0_15px_rgba(16,185,129,0.8)]'
                : stage === 'deploy'
                ? 'bg-blue-500 border-blue-400 text-white shadow-[0_0_15px_rgba(59,130,246,0.8)]'
                : 'bg-slate-800 border-slate-700 text-slate-500'
            }`}
          >
            <CheckCircle2 className="w-3.5 h-3.5" strokeWidth={2} />
          </div>
          <span className="text-[10px] font-mono text-slate-400">Deploy</span>
        </div>
      </div>
    </div>
  );
}
