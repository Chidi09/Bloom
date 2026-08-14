import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { Play, RotateCcw, ShieldCheck, Zap, ArrowRight, CheckCircle2, Terminal, Server } from 'lucide-preact';
import { highlightDart } from '../../lib/dart-highlighter';

interface CommandMode {
  id: string;
  command: string;
  badge: string;
  description: string;
  configSnippet: string;
  outputLog: string[];
  trafficPct: number;
}

const modes: CommandMode[] = [
  {
    id: 'patch',
    command: '$ bloom patch --channel staging',
    badge: 'AOT_BYTECODE_PATCH',
    description: 'Compiles Dart AOT delta bytecode and securely uploads to staging CDN nodes.',
    configSnippet: `ota:\n  app_id: "com.bloom.dashboard"\n  channels:\n    - staging\n  rollout:\n    canary_percentage: 10`,
    outputLog: [
      '[BUILD] Compiling Dart AOT byte patch for v2.4.1...',
      '[SIGN] Cryptographic RSA-2048 signature generated (SHA256: 8f9a2b)',
      '[UPLOAD] Lightweight delta patch (142.8 KB) uploaded to Staging CDN',
      '[SUCCESS] Staging channel live: v2.4.1 active across 10% canary devices',
    ],
    trafficPct: 10,
  },
  {
    id: 'promote',
    command: '$ bloom promote --from staging --to production --rollout 50',
    badge: 'CANARY_PROMOTION',
    description: 'Promotes verified staging patch to production with controlled 50% canary traffic allocation.',
    configSnippet: `ota:\n  app_id: "com.bloom.dashboard"\n  channels:\n    - production\n  rollout:\n    canary_percentage: 50\n    auto_promote: true`,
    outputLog: [
      '[PROMOTE] Promoting patch v2.4.1 to Production channel',
      '[CANARY] Scaling traffic split: 10% ➔ 50% active instances',
      '[HEALTH] Executing automated /api/health probe checks (200 OK)',
      '[SUCCESS] Production canary active: 50% traffic served by v2.4.1',
    ],
    trafficPct: 50,
  },
  {
    id: 'rollback',
    command: '$ bloom rollback --patch-v2',
    badge: 'INSTANT_ROLLBACK',
    description: 'Instantly invalidates V2 patch pointers across Edge CDN, forcing immediate local client revert.',
    configSnippet: `ota:\n  app_id: "com.bloom.dashboard"\n  channels:\n    - production\n  rollout:\n    active_patch: "v2.4.0_fallback"`,
    outputLog: [
      '[ROLLBACK] Emergency rollback triggered for patch v2.4.1',
      '[INVALIDATE] Edge CDN cache key invalidated on 142 global nodes in 340ms',
      '[CLIENT] App instances local state restored to v2.4.0 clean build',
      '[SUCCESS] Rollback complete: 0 active errors reported',
    ],
    trafficPct: 0,
  },
];

export function OTAReleasePlayground() {
  const [activeModeId, setActiveModeId] = useState<string>('patch');
  const activeMode = modes.find((m) => m.id === activeModeId) || modes[0];

  return (
    <div className="p-8 sm:p-10 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Mode Switcher */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 dark:border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Server className="w-5 h-5 text-blue-400" />
            <h3 className="text-xl font-bold text-white tracking-tight">
              Declarative Release Management Sandbox
            </h3>
          </div>
          <p className="text-xs text-slate-400">
            Select a deployment mode to inspect <code className="font-mono text-purple-300">bloom.yaml</code> configs and CLI outputs.
          </p>
        </div>

        <div className="flex items-center gap-2">
          {modes.map((m) => (
            <button
              key={m.id}
              onClick={() => setActiveModeId(m.id)}
              className={`px-3.5 py-2 rounded-xl text-xs font-mono font-bold transition-all border ${
                activeModeId === m.id
                  ? 'bg-white text-slate-950 border-white shadow-md scale-105'
                  : 'bg-zinc-900 text-slate-400 border-zinc-800 hover:text-white'
              }`}
            >
              {m.id.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* Traffic Rollout Visualizer Bar */}
      <div className="p-5 rounded-2xl bg-black border border-zinc-800 space-y-3 font-mono text-xs">
        <div className="flex items-center justify-between text-slate-400">
          <span>Active CDN Rollout Allocation</span>
          <span className="text-blue-400 font-bold">{activeMode.trafficPct}% Canary Traffic</span>
        </div>
        <div className="w-full h-2.5 bg-zinc-900 rounded-full overflow-hidden border border-zinc-800">
          <div
            className="h-full bg-gradient-to-r from-purple-500 via-blue-500 to-teal-400 transition-all duration-700"
            style={{ width: `${activeMode.trafficPct}%` }}
          />
        </div>
      </div>

      {/* Main Grid: Config vs Terminal */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left: bloom.yaml Config */}
        <div className="lg:col-span-5 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono text-slate-400">
            <span className="font-bold text-white">bloom.yaml</span>
            <span className="px-2 py-0.5 rounded bg-zinc-900 text-purple-400 border border-zinc-800 text-[10px] font-bold">
              {activeMode.badge}
            </span>
          </div>

          <div className="rounded-2xl overflow-hidden bg-black border border-zinc-800 font-mono text-xs">
            <pre
              className="p-5 text-slate-100 leading-relaxed overflow-x-auto font-mono text-xs"
              dangerouslySetInnerHTML={{ __html: highlightDart(activeMode.configSnippet) }}
            />
          </div>
        </div>

        {/* Right: Terminal CLI Execution */}
        <div className="lg:col-span-7 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono text-slate-400">
            <span className="font-bold text-white">{activeMode.command}</span>
            <span className="text-emerald-400 font-bold text-[10px]">RSA-2048_SIGNED</span>
          </div>

          <div className="rounded-2xl overflow-hidden bg-black border border-zinc-800 font-mono text-xs">
            <div className="flex items-center gap-2 px-4 py-3 bg-zinc-900/90 border-b border-zinc-800 text-[11px] text-slate-400 font-bold">
              <Terminal className="w-3.5 h-3.5 text-blue-400" />
              <span>Execution Terminal Stream</span>
            </div>
            <div className="p-5 space-y-2 text-slate-300 text-[11px] leading-relaxed">
              {activeMode.outputLog.map((line, idx) => (
                <div key={idx} className="flex items-start gap-2">
                  <span className="text-blue-400 font-bold">&gt;</span>
                  <span>{line}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
