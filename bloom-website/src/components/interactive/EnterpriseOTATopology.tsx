import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { Globe, Lock, Zap, ShieldCheck, CheckCircle2, Server } from 'lucide-preact';

interface NodeRegion {
  id: string;
  name: string;
  latency: string;
  nodes: number;
  status: string;
  hash: string;
}

const regions: NodeRegion[] = [
  { id: 'us-east', name: 'US-East (N. Virginia)', latency: '8ms', nodes: 48, status: 'HEALTHY', hash: 'sha256_8f9a2b' },
  { id: 'eu-central', name: 'EU-Central (Frankfurt)', latency: '12ms', nodes: 42, status: 'HEALTHY', hash: 'sha256_8f9a2b' },
  { id: 'ap-south', name: 'AP-South (Tokyo)', latency: '14ms', nodes: 36, status: 'HEALTHY', hash: 'sha256_8f9a2b' },
  { id: 'sa-east', name: 'SA-East (São Paulo)', latency: '18ms', nodes: 16, status: 'HEALTHY', hash: 'sha256_8f9a2b' },
];

export function EnterpriseOTATopology() {
  const [selectedRegionId, setSelectedRegionId] = useState<string>('us-east');
  const selectedRegion = regions.find((r) => r.id === selectedRegionId) || regions[0];

  return (
    <div className="p-8 sm:p-10 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Status Indicator */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 dark:border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Globe className="w-5 h-5 text-teal-400" />
            <h3 className="text-xl font-bold text-white tracking-tight">
              Global 142-Edge Node Topology &amp; RSA-2048 Security Engine
            </h3>
          </div>
          <p className="text-xs text-slate-400">
            Click region clusters to inspect real-time Edge CDN delivery latency and RSA-2048 cryptographic signatures.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="px-3 py-1 rounded-full bg-emerald-500/15 text-emerald-400 font-mono text-xs font-bold border border-emerald-500/30 flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            142 NODES ONLINE
          </span>
        </div>
      </div>

      {/* Grid: Interactive Regions */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {regions.map((r) => {
          const isSelected = r.id === selectedRegionId;

          return (
            <button
              key={r.id}
              onClick={() => setSelectedRegionId(r.id)}
              className={`p-5 rounded-2xl text-left transition-all duration-300 border ${
                isSelected
                  ? 'bg-zinc-900 border-white text-white shadow-xl scale-105'
                  : 'bg-black border-zinc-800 text-slate-400 hover:border-zinc-700 hover:text-white'
              }`}
            >
              <div className="flex items-center justify-between mb-3 text-[10px] font-mono font-bold">
                <span className="text-slate-400">{r.latency}</span>
                <span className="text-emerald-400">{r.status}</span>
              </div>
              <div className="text-xs font-bold text-white mb-1">{r.name}</div>
              <div className="text-[11px] text-slate-400">{r.nodes} Active Edge Nodes</div>
            </button>
          );
        })}
      </div>

      {/* Detailed Node Inspector Panel */}
      <div className="p-6 rounded-2xl bg-black border border-zinc-800 font-mono text-xs space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2 pb-3 border-b border-zinc-800 text-slate-300">
          <div>
            <span className="text-slate-400">Selected Cluster: </span>
            <strong className="text-white text-sm">{selectedRegion.name}</strong>
          </div>
          <div className="flex items-center gap-3 text-[11px]">
            <span>Latency: <strong className="text-emerald-400">{selectedRegion.latency}</strong></span>
            <span>RSA-2048: <strong className="text-purple-400">{selectedRegion.hash}</strong></span>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-[11px] text-slate-300">
          <div className="p-3 rounded-xl bg-zinc-900 border border-zinc-800">
            <span className="text-slate-400 block mb-1">Global Edge CDN</span>
            <p className="text-slate-300 leading-normal">150KB lightweight delta updates served in sub-20ms.</p>
          </div>
          <div className="p-3 rounded-xl bg-zinc-900 border border-zinc-800">
            <span className="text-slate-400 block mb-1">Cryptographic Keys</span>
            <p className="text-slate-300 leading-normal">Signed with private RSA-2048 key. Local device verification.</p>
          </div>
          <div className="p-3 rounded-xl bg-zinc-900 border border-zinc-800">
            <span className="text-slate-400 block mb-1">Instant Rollback</span>
            <p className="text-slate-300 leading-normal">Single CLI command invalidates bad patches globally in 340ms.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
