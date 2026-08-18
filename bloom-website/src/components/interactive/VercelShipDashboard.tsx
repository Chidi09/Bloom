import { useState } from 'preact/hooks';
import { Play, RotateCcw, CheckCircle2, AlertCircle, Clock, GitBranch, ArrowUpRight, Terminal, Server, Shield, Send, Cpu, Layers, Activity, Lock, Globe } from 'lucide-preact';

interface Deployment {
  id: string;
  commit: string;
  message: string;
  author: string;
  branch: string;
  status: 'ready' | 'building' | 'rolled_back';
  time: string;
  size: string;
  duration: string;
}

const INITIAL_DEPLOYMENTS: Deployment[] = [
  {
    id: 'dpl_89f2a01',
    commit: '04a2f8c',
    message: 'feat(signals): hot reload state preservation in dev client',
    author: 'chidi09',
    branch: 'main',
    status: 'ready',
    time: '2 mins ago',
    size: '142.8 KB',
    duration: '1.2s',
  },
  {
    id: 'dpl_74e1c99',
    commit: '991a34b',
    message: 'fix(ota): RSA-2048 cryptographic signature validation',
    author: 'chidi09',
    branch: 'staging',
    status: 'ready',
    time: '14 mins ago',
    size: '138.4 KB',
    duration: '1.4s',
  },
  {
    id: 'dpl_61b8f02',
    commit: '18f77a2',
    message: 'perf(engine): flutter 3.29 Skia/Impeller shader warmup',
    author: 'bloom-bot',
    branch: 'canary',
    status: 'ready',
    time: '1 hour ago',
    size: '156.1 KB',
    duration: '1.8s',
  },
];

export function VercelShipDashboard() {
  const [activeTab, setActiveTab] = useState<'deployments' | 'pipeline' | 'webhooks'>('deployments');
  const [rollout, setRollout] = useState<number>(100);
  const [deployments, setDeployments] = useState<Deployment[]>(INITIAL_DEPLOYMENTS);
  const [isDeploying, setIsDeploying] = useState<boolean>(false);
  const [logs, setLogs] = useState<string[]>([
    '[01:54:10] INFO: Listening on Edge CDN cluster (142 nodes worldwide)',
    '[01:54:12] SUCCESS: RSA-2048 public key verification passed',
    '[01:54:15] BROADCAST: OTA bundle dpl_89f2a01 active across 400,000 devices',
  ]);

  const triggerNewDeployment = () => {
    setIsDeploying(true);
    const newId = `dpl_${Math.random().toString(36).substring(2, 9)}`;
    const newCommit = Math.random().toString(36).substring(2, 9);

    setLogs(prev => [
      `[${new Date().toLocaleTimeString()}] TRIGGER: $ bloom ship --prod --channel=production`,
      `[${new Date().toLocaleTimeString()}] COMPILING: AOT Dart bytecode patch...`,
      ...prev,
    ]);

    setTimeout(() => {
      setLogs(prev => [
        `[${new Date().toLocaleTimeString()}] SIGNING: Cryptographic RSA-2048 signature generated`,
        `[${new Date().toLocaleTimeString()}] BROADCAST: Pushed to 142 Edge CDN nodes in 1.1s`,
        ...prev,
      ]);

      const newDpl: Deployment = {
        id: newId,
        commit: newCommit,
        message: 'chore(release): automated canary OTA patch deployment',
        author: 'you (CLI)',
        branch: 'main',
        status: 'ready',
        time: 'Just now',
        size: '141.2 KB',
        duration: '1.1s',
      };

      setDeployments(prev => [newDpl, ...prev]);
      setIsDeploying(false);
    }, 1800);
  };

  const rollbackDeployment = (id: string) => {
    setDeployments(prev =>
      prev.map(d => (d.id === id ? { ...d, status: 'rolled_back' } : d))
    );
    setLogs(prev => [
      `[${new Date().toLocaleTimeString()}] WARN: Rollback triggered for deployment ${id}`,
      `[${new Date().toLocaleTimeString()}] SUCCESS: Reverted active patch pointers to previous stable bundle`,
      ...prev,
    ]);
  };

  return (
    <div className="w-full max-w-5xl mx-auto rounded-3xl bg-white dark:bg-black border border-slate-200 dark:border-zinc-800 shadow-2xl overflow-hidden font-sans text-slate-800 dark:text-slate-200">
      
      {/* Header Bar */}
      <div className="px-6 py-4 bg-slate-50 dark:bg-zinc-950/90 border-b border-slate-200 dark:border-zinc-800 flex flex-wrap items-center justify-between gap-4 backdrop-blur-xl">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-700 flex items-center justify-center shadow-sm">
            <Server className="w-4 h-4 text-blue-600 dark:text-blue-400" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-mono font-black text-sm text-slate-900 dark:text-white tracking-tight">bloom-cloud-ota</span>
              <span className="px-2.5 py-0.5 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-[10px] font-mono font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                ACTIVE
              </span>
            </div>
            <div className="text-[11px] text-slate-500 dark:text-slate-400 font-mono mt-0.5">142 Edge CDN Nodes · RSA-2048 Signed · Shorebird Powered</div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={triggerNewDeployment}
            disabled={isDeploying}
            className="px-4 py-2 rounded-xl bg-slate-900 dark:bg-white hover:bg-slate-800 dark:hover:bg-slate-200 text-white dark:text-slate-950 font-mono text-xs font-black flex items-center gap-2 transition active:scale-95 disabled:opacity-50 shadow-md"
          >
            {isDeploying ? (
              <Clock className="w-3.5 h-3.5 animate-spin" />
            ) : (
              <Send className="w-3.5 h-3.5" />
            )}
            <span>{isDeploying ? 'Packaging Patch...' : 'Ship New Patch'}</span>
          </button>
        </div>
      </div>

      {/* Top Telemetry Stats Strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 border-b border-slate-200 dark:border-zinc-800 bg-slate-50/50 dark:bg-zinc-950/60 divide-x divide-slate-200 dark:divide-zinc-800/80 font-mono text-xs">
        <div className="p-3.5 px-6">
          <span className="text-[10px] text-slate-500 dark:text-slate-400 uppercase block font-bold">Active Patch</span>
          <span className="text-slate-900 dark:text-white font-bold text-xs">v2.5.1-production</span>
        </div>
        <div className="p-3.5 px-6">
          <span className="text-[10px] text-slate-500 dark:text-slate-400 uppercase block font-bold">Edge Latency</span>
          <span className="text-emerald-600 dark:text-emerald-400 font-bold text-xs">1.1s (142 Nodes)</span>
        </div>
        <div className="p-3.5 px-6">
          <span className="text-[10px] text-slate-500 dark:text-slate-400 uppercase block font-bold">Devices Reached</span>
          <span className="text-blue-600 dark:text-blue-400 font-bold text-xs">400,000 Active</span>
        </div>
        <div className="p-3.5 px-6">
          <span className="text-[10px] text-slate-500 dark:text-slate-400 uppercase block font-bold">Canary Rollout</span>
          <span className="text-purple-600 dark:text-purple-400 font-bold text-xs">{rollout}% Global</span>
        </div>
      </div>

      {/* Navigation Tabs Bar */}
      <div className="px-6 border-b border-slate-200 dark:border-zinc-800 bg-slate-50/30 dark:bg-zinc-950/40 flex items-center justify-between overflow-x-auto">
        <div className="flex items-center gap-6">
          <button
            onClick={() => setActiveTab('deployments')}
            className={`py-3 text-xs font-mono font-bold border-b-2 transition-colors flex items-center gap-2 ${
              activeTab === 'deployments'
                ? 'border-purple-600 dark:border-white text-slate-900 dark:text-white'
                : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            <GitBranch className="w-3.5 h-3.5 text-blue-600 dark:text-blue-400" />
            <span>Deployments ({deployments.length})</span>
          </button>

          <button
            onClick={() => setActiveTab('pipeline')}
            className={`py-3 text-xs font-mono font-bold border-b-2 transition-colors flex items-center gap-2 ${
              activeTab === 'pipeline'
                ? 'border-purple-600 dark:border-white text-slate-900 dark:text-white'
                : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            <Layers className="w-3.5 h-3.5 text-purple-600 dark:text-purple-400" />
            <span>Rollout &amp; Channels</span>
          </button>

          <button
            onClick={() => setActiveTab('webhooks')}
            className={`py-3 text-xs font-mono font-bold border-b-2 transition-colors flex items-center gap-2 ${
              activeTab === 'webhooks'
                ? 'border-purple-600 dark:border-white text-slate-900 dark:text-white'
                : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            <Terminal className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400" />
            <span>Edge Event Stream</span>
          </button>
        </div>

        <div className="hidden sm:flex items-center gap-2 text-[11px] font-mono text-slate-500 dark:text-slate-400">
          <span>Target Branch:</span>
          <span className="px-2 py-0.5 rounded bg-slate-100 dark:bg-zinc-900 text-slate-900 dark:text-white font-bold border border-slate-200 dark:border-zinc-800">main</span>
        </div>
      </div>

      {/* Main Body Views */}
      <div className="p-6 space-y-6">

        {activeTab === 'deployments' && (
          <div className="space-y-4">
            <div className="text-xs font-mono text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2 flex items-center justify-between">
              <span className="font-bold text-slate-900 dark:text-white">Production &amp; Staging Build Log</span>
              <span>Sorted by Recency</span>
            </div>

            <div className="space-y-3">
              {deployments.map(dpl => (
                <div
                  key={dpl.id}
                  className="p-4 rounded-2xl bg-slate-50 dark:bg-zinc-950 hover:bg-slate-100 dark:hover:bg-zinc-900 border border-slate-200 dark:border-zinc-800 transition-all flex flex-col sm:flex-row sm:items-center justify-between gap-4 group shadow-sm"
                >
                  <div className="flex items-start gap-3.5">
                    <div className="mt-1">
                      {dpl.status === 'ready' && (
                        <div className="w-6 h-6 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center">
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" strokeWidth={2.5} />
                        </div>
                      )}
                      {dpl.status === 'building' && (
                        <div className="w-6 h-6 rounded-full bg-amber-500/10 border border-amber-500/30 flex items-center justify-center">
                          <Clock className="w-3.5 h-3.5 text-amber-500 dark:text-amber-400 animate-spin" strokeWidth={2.5} />
                        </div>
                      )}
                      {dpl.status === 'rolled_back' && (
                        <div className="w-6 h-6 rounded-full bg-rose-500/10 border border-rose-500/30 flex items-center justify-center">
                          <RotateCcw className="w-3.5 h-3.5 text-rose-500 dark:text-rose-400" strokeWidth={2.5} />
                        </div>
                      )}
                    </div>

                    <div>
                      <div className="flex items-center gap-2 font-mono text-xs">
                        <span className="font-bold text-slate-900 dark:text-white group-hover:text-purple-600 dark:group-hover:text-purple-300 transition-colors">
                          {dpl.message}
                        </span>
                        <span className="px-2 py-0.5 rounded bg-slate-200 dark:bg-zinc-900 text-[10px] text-purple-700 dark:text-purple-400 font-bold border border-slate-300 dark:border-zinc-800">
                          {dpl.commit}
                        </span>
                      </div>

                      <div className="flex flex-wrap items-center gap-3 text-[11px] font-mono text-slate-500 dark:text-slate-400 mt-1.5">
                        <span className="text-slate-900 dark:text-white font-bold">{dpl.author}</span>
                        <span>•</span>
                        <span className="text-purple-600 dark:text-purple-400">{dpl.branch}</span>
                        <span>•</span>
                        <span>{dpl.size}</span>
                        <span>•</span>
                        <span>{dpl.time}</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3 self-end sm:self-center">
                    <span className="text-xs font-mono text-slate-700 dark:text-slate-200 font-bold bg-white dark:bg-zinc-900 px-3 py-1 rounded-xl border border-slate-200 dark:border-zinc-800 shadow-sm">
                      {dpl.duration}
                    </span>

                    {dpl.status === 'ready' && (
                      <button
                        onClick={() => rollbackDeployment(dpl.id)}
                        title="Rollback this patch"
                        className="px-3 py-1 rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-600 dark:text-rose-400 text-xs font-mono font-bold border border-rose-500/30 transition flex items-center gap-1.5"
                      >
                        <RotateCcw className="w-3 h-3" />
                        <span>Rollback</span>
                      </button>
                    )}

                    {dpl.status === 'rolled_back' && (
                      <span className="px-2.5 py-1 rounded-xl bg-rose-500/10 text-rose-600 dark:text-rose-400 text-[10px] font-mono font-bold border border-rose-500/20">
                        ROLLED_BACK
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'pipeline' && (
          <div className="space-y-6">
            <div className="p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="font-mono font-bold text-sm text-slate-900 dark:text-white">Gradual Canary Traffic Split</h4>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Control percentage of active mobile devices receiving patch updates.</p>
                </div>
                <div className="text-xl font-mono font-black text-slate-900 dark:text-white bg-white dark:bg-zinc-900 px-4 py-1.5 rounded-xl border border-slate-200 dark:border-zinc-800 shadow-sm">
                  {rollout}%
                </div>
              </div>

              <input
                type="range"
                min="0"
                max="100"
                step="10"
                value={rollout}
                onInput={(e: any) => setRollout(parseInt(e.target.value))}
                className="w-full h-2 bg-slate-200 dark:bg-zinc-900 rounded-lg appearance-none cursor-pointer accent-purple-600"
              />

              <div className="flex items-center justify-between text-[11px] font-mono text-slate-500 dark:text-slate-400">
                <span>0% (Internal Staging)</span>
                <span>50% (Canary Batch)</span>
                <span>100% (Full Production)</span>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="p-5 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-mono font-bold text-slate-900 dark:text-white">RSA-2048 Hardware Keys</span>
                  <Lock className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                </div>
                <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">Cryptographic hardware signing key verified against local device trust store.</p>
              </div>

              <div className="p-5 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-mono font-bold text-slate-900 dark:text-white">Edge CDN Sync</span>
                  <Globe className="w-4 h-4 text-teal-600 dark:text-teal-400" />
                </div>
                <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">142 global nodes synchronized with automatic HTTP/3 fallback.</p>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'webhooks' && (
          <div className="space-y-4">
            <div className="text-xs font-mono text-slate-500 dark:text-slate-400 uppercase tracking-wider font-bold">Live Edge Event Stream</div>
            
            <div className="p-5 rounded-2xl bg-slate-950 dark:bg-black border border-slate-800 dark:border-zinc-800 font-mono text-xs text-slate-300 space-y-2 max-h-60 overflow-y-auto shadow-xl">
              {logs.map((log, idx) => (
                <div key={idx} className="flex items-center gap-2 text-[11px] leading-relaxed">
                  <span className="text-blue-400 font-bold">&gt;</span>
                  <span className={log.includes('SUCCESS') ? 'text-emerald-400 font-bold' : log.includes('WARN') ? 'text-rose-400' : 'text-slate-300'}>
                    {log}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
