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
    <div className="p-8 sm:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Status Indicator */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Globe className="w-5 h-5 text-teal-600 dark:text-teal-400" />
            <h3 className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Global 142-Edge Node Topology &amp; RSA-2048 Security Engine
            </h3>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-400">
            Click region clusters to inspect real-time Edge CDN delivery latency and RSA-2048 cryptographic signatures.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="px-3 py-1 rounded-full bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 font-mono text-xs font-bold border border-emerald-500/30 flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
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
                  ? 'bg-slate-900 text-white dark:bg-zinc-900 dark:border-white shadow-xl scale-105'
                  : 'bg-slate-50 dark:bg-zinc-950 border-slate-200 dark:border-zinc-800 text-slate-900 dark:text-white hover:border-teal-500'
              }`}
            >
              <div className="flex items-center justify-between mb-3">
                <span className="text-[10px] font-mono font-bold text-slate-500 dark:text-slate-400">
                  {r.nodes} Edge Nodes
                </span>
                <span className="text-xs font-mono font-black text-teal-600 dark:text-teal-400">
                  {r.latency}
                </span>
              </div>

              <div className="text-xs font-bold mb-1">
                {r.name}
              </div>

              <div className="text-[11px] font-mono text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>{r.status}</span>
              </div>
            </button>
          );
        })}
      </div>

      {/* Detail Inspector Card */}
      <div className="p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 font-mono text-xs shadow-inner">
        <div className="space-y-1">
          <span className="text-[10px] text-slate-500 dark:text-slate-400 font-bold block">CRYPTOGRAPHIC VERIFICATION</span>
          <div className="flex items-center gap-2 text-slate-900 dark:text-white font-bold">
            <Lock className="w-4 h-4 text-purple-600 dark:text-purple-400" />
            <span>RSA-2048 Bit Public Key · SHA-256 Digest Signature</span>
          </div>
          <p className="text-[11px] text-slate-600 dark:text-slate-400">
            Byte-patches verified on device hardware secure enclave before loading into memory.
          </p>
        </div>

        <div className="p-3 bg-white dark:bg-zinc-900 rounded-xl border border-slate-200 dark:border-zinc-800 text-slate-700 dark:text-slate-300 shrink-0">
          <span className="text-[10px] text-slate-500 dark:text-slate-400 block mb-0.5 font-bold">ACTIVE CLUSTER DIGEST</span>
          <span className="text-purple-600 dark:text-purple-400 font-bold text-xs">{selectedRegion.hash}</span>
        </div>
      </div>
    </div>
  );
}
