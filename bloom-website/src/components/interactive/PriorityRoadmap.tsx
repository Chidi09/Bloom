import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { CheckCircle2, Clock, Sparkles, Layers, ShieldCheck, Zap } from 'lucide-preact';

interface RoadmapItem {
  capability: string;
  bloomOwnership: string;
  ecosystemProvider: string;
  priority: 'P0 (v0.1)' | 'P1 (v0.2)' | 'P2 (v0.5)' | 'P2 (v0.7)';
  status: 'Complete' | 'In Progress' | 'Planned';
  description: string;
}

const items: RoadmapItem[] = [
  {
    capability: 'CLI & Project Conventions',
    bloomOwnership: 'Yes (Full CLI)',
    ecosystemProvider: 'Flutter CLI',
    priority: 'P0 (v0.1)',
    status: 'Complete',
    description: 'Unified project scaffolding, environment config, and diagnostic doctor tool.',
  },
  {
    capability: 'Signals Reactive State API',
    bloomOwnership: 'Thin Wrapper',
    ecosystemProvider: 'signals',
    priority: 'P0 (v0.1)',
    status: 'Complete',
    description: 'Fine-grained reactivity API wrapping signals package with zero setState boilerplate.',
  },
  {
    capability: 'Filesystem Routing Engine',
    bloomOwnership: 'AST Generator',
    ecosystemProvider: 'go_router',
    priority: 'P0 (v0.1)',
    status: 'Complete',
    description: 'Next.js-style directory router compiling to type-safe go_router definitions.',
  },
  {
    capability: 'Data & Bloom Query Engine',
    bloomOwnership: 'Full Custom Engine',
    ecosystemProvider: 'HTTP / SQLite',
    priority: 'P1 (v0.2)',
    status: 'In Progress',
    description: 'Declarative server-state caching, background refetching, and optimistic mutations.',
  },
  {
    capability: 'Bloom Go Dev Client App',
    bloomOwnership: 'Native Mobile Shell',
    ecosystemProvider: 'Flutter Engine',
    priority: 'P2 (v0.5)',
    status: 'Planned',
    description: 'Expo-style wireless development shell for instant mobile test device pairing.',
  },
  {
    capability: 'OTA Code Push Orchestration',
    bloomOwnership: 'Cloud Orchestrator',
    ecosystemProvider: 'Shorebird OTA',
    priority: 'P2 (v0.7)',
    status: 'Planned',
    description: 'Cryptographically signed over-the-air byte-patch distribution pipeline.',
  },
];

export function PriorityRoadmap() {
  const [filter, setFilter] = useState<'all' | 'P0' | 'P1' | 'P2'>('all');

  const filteredItems = filter === 'all' 
    ? items 
    : items.filter((i) => i.priority.startsWith(filter));

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* Priority Filter Bar - Fluid Mobile Horizontal Scroll */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-2xl bg-slate-950/90 dark:bg-black backdrop-blur border border-slate-800 dark:border-white/10">
        <div className="flex items-center gap-2 overflow-x-auto pb-1 sm:pb-0 no-scrollbar">
          {[
            { id: 'all', label: 'All Priorities (P0 - P2)' },
            { id: 'P0', label: 'P0 Core Platform' },
            { id: 'P1', label: 'P1 Data Engine' },
            { id: 'P2', label: 'P2 Ecosystem Shell' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setFilter(tab.id as any)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all border ${
                filter === tab.id
                  ? 'bg-white text-slate-950 border-white shadow-md font-black'
                  : 'bg-zinc-900 text-slate-400 hover:text-white border-zinc-800'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <span className="text-xs font-mono font-bold text-slate-400 self-end sm:self-center shrink-0">
          Showing {filteredItems.length} Capabilities
        </span>
      </div>

      {/* Desktop Table View (hidden on mobile) */}
      <div className="hidden md:block rounded-3xl overflow-hidden bg-black border border-zinc-800 shadow-xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-zinc-800 bg-zinc-900/90 text-[11px] font-mono text-slate-400 uppercase tracking-wider">
                <th className="py-4 px-6 font-bold">Capability</th>
                <th className="py-4 px-6 font-bold">Bloom Ownership</th>
                <th className="py-4 px-6 font-bold">Ecosystem Provider</th>
                <th className="py-4 px-6 font-bold text-right">Priority &amp; Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800/80 text-xs">
              {filteredItems.map((item, idx) => (
                <tr key={idx} className="hover:bg-zinc-900/60 transition-colors">
                  <td className="py-4 px-6">
                    <div className="font-bold text-white text-sm">
                      {item.capability}
                    </div>
                    <div className="text-[11px] text-slate-400 mt-0.5 font-normal">
                      {item.description}
                    </div>
                  </td>

                  <td className="py-4 px-6 font-mono text-slate-300">
                    <span className="px-2.5 py-1 rounded-md bg-purple-950/60 text-purple-300 font-bold border border-purple-800/60 text-[11px]">
                      {item.bloomOwnership}
                    </span>
                  </td>

                  <td className="py-4 px-6 font-mono text-slate-400 font-semibold">
                    {item.ecosystemProvider}
                  </td>

                  <td className="py-4 px-6 text-right font-mono">
                    <div className="inline-flex items-center gap-2">
                      <span className={`px-2.5 py-1 rounded-md text-[10px] font-bold border ${
                        item.priority.startsWith('P0')
                          ? 'bg-purple-500/15 text-purple-400 border-purple-500/30'
                          : item.priority.startsWith('P1')
                          ? 'bg-amber-500/15 text-amber-400 border-amber-500/30'
                          : 'bg-blue-500/15 text-blue-400 border-blue-500/30'
                      }`}>
                        {item.priority}
                      </span>
                      <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${
                        item.status === 'Complete'
                          ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                          : item.status === 'In Progress'
                          ? 'bg-amber-500/15 text-amber-400 border border-amber-500/30 animate-pulse'
                          : 'bg-zinc-800 text-slate-400 border border-zinc-700'
                      }`}>
                        {item.status}
                      </span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Touch-Optimized Mobile Card View (block on mobile, hidden on md+) */}
      <div className="block md:hidden space-y-4">
        {filteredItems.map((item, idx) => (
          <div
            key={idx}
            className="p-5 rounded-2xl bg-black border border-zinc-800 space-y-3.5 shadow-lg"
          >
            {/* Header: Title & Status */}
            <div className="flex items-start justify-between gap-3">
              <h4 className="font-bold text-white text-base leading-snug">
                {item.capability}
              </h4>
              <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold shrink-0 ${
                item.status === 'Complete'
                  ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                  : item.status === 'In Progress'
                  ? 'bg-amber-500/15 text-amber-400 border border-amber-500/30 animate-pulse'
                  : 'bg-zinc-800 text-slate-400 border border-zinc-700'
              }`}>
                {item.status}
              </span>
            </div>

            {/* Description */}
            <p className="text-xs text-slate-400 leading-relaxed font-normal">
              {item.description}
            </p>

            {/* Ownership & Priority Badges */}
            <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-zinc-900 font-mono text-[11px]">
              <span className="px-2.5 py-1 rounded-md bg-purple-950/60 text-purple-300 font-bold border border-purple-800/60">
                {item.bloomOwnership}
              </span>
              <span className="text-slate-500">via {item.ecosystemProvider}</span>
              <span className={`ml-auto px-2.5 py-1 rounded-md text-[10px] font-bold border ${
                item.priority.startsWith('P0')
                  ? 'bg-purple-500/15 text-purple-400 border-purple-500/30'
                  : item.priority.startsWith('P1')
                  ? 'bg-amber-500/15 text-amber-400 border-amber-500/30'
                  : 'bg-blue-500/15 text-blue-400 border-blue-500/30'
              }`}>
                {item.priority}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
