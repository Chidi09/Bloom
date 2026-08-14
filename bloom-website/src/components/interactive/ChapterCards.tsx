import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { FolderTree, Send, Sliders, ArrowRight, CheckCircle2, Sparkles, Code2, RefreshCw, Zap, Layers } from 'lucide-preact';

export function ChapterCards() {
  // Chapter 1 state: selected route
  const [selectedRoute, setSelectedRoute] = useState<'home' | 'user' | 'layout'>('home');

  // Chapter 2 state: rollout percentage
  const [rolloutPct, setRolloutPct] = useState<number>(50);

  // Chapter 3 state: theme accent & radius
  const [accentColor, setAccentColor] = useState<string>('#8B5CF6'); // Purple
  const [radius, setRadius] = useState<number>(12);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 max-w-6xl mx-auto">
      {/* CHAPTER 01 BUILD CARD */}
      <div className="group relative p-8 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 hover:border-purple-500/50 dark:hover:border-purple-400/50 hover:shadow-2xl transition-all duration-300 flex flex-col justify-between overflow-hidden">
        <div className="absolute top-0 right-0 p-6 opacity-10 group-hover:opacity-20 transition-opacity">
          <FolderTree className="w-24 h-24 text-purple-500" />
        </div>

        <div>
          <div className="flex items-center justify-between mb-4">
            <span className="px-3 py-1 rounded-full bg-purple-500/10 text-purple-600 dark:text-purple-400 text-xs font-mono font-bold border border-purple-500/20">
              CHAPTER 01
            </span>
            <span className="text-xs font-mono font-bold text-slate-400">FRAMEWORK</span>
          </div>

          <h3 className="text-2xl font-black text-slate-900 dark:text-white mb-2 tracking-tight">
            BUILD
          </h3>

          <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed mb-6 font-normal">
            Filesystem routing over <code className="font-mono text-purple-600 dark:text-purple-400">go_router</code>, zero-boilerplate <code className="font-mono text-purple-600 dark:text-purple-400">signals</code> state API, and automated CLI code generators.
          </p>

          {/* Interactive Micro-Demo: Route Previewer */}
          <div className="p-4 rounded-2xl bg-slate-950 text-white border border-slate-800 mb-6 font-mono text-xs space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800 text-[10px] text-slate-400">
              <span>File-System Routes</span>
              <span className="text-purple-400 font-bold">Generated AST</span>
            </div>

            <div className="flex gap-1.5">
              <button
                onClick={() => setSelectedRoute('home')}
                className={`px-2 py-1 rounded text-[10px] transition-colors ${
                  selectedRoute === 'home' ? 'bg-purple-600 text-white font-bold' : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
                }`}
              >
                index.dart
              </button>
              <button
                onClick={() => setSelectedRoute('user')}
                className={`px-2 py-1 rounded text-[10px] transition-colors ${
                  selectedRoute === 'user' ? 'bg-purple-600 text-white font-bold' : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
                }`}
              >
                users/[id].dart
              </button>
              <button
                onClick={() => setSelectedRoute('layout')}
                className={`px-2 py-1 rounded text-[10px] transition-colors ${
                  selectedRoute === 'layout' ? 'bg-purple-600 text-white font-bold' : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
                }`}
              >
                _layout.dart
              </button>
            </div>

            <div className="text-[11px] text-slate-300 bg-slate-900/80 p-2.5 rounded border border-slate-800">
              {selectedRoute === 'home' && (
                <span>Route: <strong className="text-teal-400">'/'</strong> → HomeView()</span>
              )}
              {selectedRoute === 'user' && (
                <span>Route: <strong className="text-teal-400">'/users/:id'</strong> → UserView(id: String)</span>
              )}
              {selectedRoute === 'layout' && (
                <span>Route: <strong className="text-teal-400">'/_layout'</strong> → AppScaffold(child)</span>
              )}
            </div>
          </div>
        </div>

        <a
          href="/build"
          className="inline-flex items-center justify-between w-full px-5 py-3 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-950 font-bold text-xs shadow-md hover:bg-slate-800 dark:hover:bg-slate-100 transition-all group/btn"
        >
          <span>Explore Framework Architecture</span>
          <ArrowRight className="w-4 h-4 group-hover/btn:translate-x-1 transition-transform" />
        </a>
      </div>

      {/* CHAPTER 02 SHIP CARD */}
      <div className="group relative p-8 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 hover:border-blue-500/50 dark:hover:border-blue-400/50 hover:shadow-2xl transition-all duration-300 flex flex-col justify-between overflow-hidden">
        <div className="absolute top-0 right-0 p-6 opacity-10 group-hover:opacity-20 transition-opacity">
          <Send className="w-24 h-24 text-blue-500" />
        </div>

        <div>
          <div className="flex items-center justify-between mb-4">
            <span className="px-3 py-1 rounded-full bg-blue-500/10 text-blue-600 dark:text-blue-400 text-xs font-mono font-bold border border-blue-500/20">
              CHAPTER 02
            </span>
            <span className="text-xs font-mono font-bold text-slate-400">CLOUD OTA</span>
          </div>

          <h3 className="text-2xl font-black text-slate-900 dark:text-white mb-2 tracking-tight">
            SHIP
          </h3>

          <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed mb-6 font-normal">
            Integrated Shorebird over-the-air (OTA) updates, remote build pipeline, and instant cryptographic byte-patching.
          </p>

          {/* Interactive Micro-Demo: OTA Rollout Simulator */}
          <div className="p-4 rounded-2xl bg-slate-950 text-white border border-slate-800 mb-6 font-mono text-xs space-y-3">
            <div className="flex items-center justify-between text-[10px]">
              <span className="text-slate-400">Canary Rollout</span>
              <span className="text-blue-400 font-bold">{rolloutPct}% Traffic</span>
            </div>

            <input
              type="range"
              min="10"
              max="100"
              step="10"
              value={rolloutPct}
              onChange={(e) => setRolloutPct(Number((e.target as HTMLInputElement).value))}
              className="w-full h-1.5 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-blue-500"
            />

            <div className="flex items-center justify-between text-[10px] text-slate-400 pt-1">
              <span>Patch: <strong className="text-slate-200">v2.4.1 (142KB)</strong></span>
              <span className="flex items-center gap-1 text-emerald-400 font-bold">
                <CheckCircle2 className="w-3 h-3" /> RSA-2048
              </span>
            </div>
          </div>
        </div>

        <a
          href="/ship"
          className="inline-flex items-center justify-between w-full px-5 py-3 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-950 font-bold text-xs shadow-md hover:bg-slate-800 dark:hover:bg-slate-100 transition-all group/btn"
        >
          <span>Explore Cloud & Deploy Pipeline</span>
          <ArrowRight className="w-4 h-4 group-hover/btn:translate-x-1 transition-transform" />
        </a>
      </div>

      {/* CHAPTER 03 BLOOM CARD */}
      <div className="group relative p-8 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 hover:border-pink-500/50 dark:hover:border-pink-400/50 hover:shadow-2xl transition-all duration-300 flex flex-col justify-between overflow-hidden">
        <div className="absolute top-0 right-0 p-6 opacity-10 group-hover:opacity-20 transition-opacity">
          <Sliders className="w-24 h-24 text-pink-500" />
        </div>

        <div>
          <div className="flex items-center justify-between mb-4">
            <span className="px-3 py-1 rounded-full bg-pink-500/10 text-pink-600 dark:text-pink-400 text-xs font-mono font-bold border border-pink-500/20">
              CHAPTER 03
            </span>
            <span className="text-xs font-mono font-bold text-slate-400">UI STUDIO</span>
          </div>

          <h3 className="text-2xl font-black text-slate-900 dark:text-white mb-2 tracking-tight">
            BLOOM
          </h3>

          <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 leading-relaxed mb-6 font-normal">
            shadcn-inspired UI primitives with live interactive design token controls and fluid Flutter micro-interactions.
          </p>

          {/* Interactive Micro-Demo: Token Live Preview */}
          <div className="p-4 rounded-2xl bg-slate-950 text-white border border-slate-800 mb-6 font-mono text-xs space-y-3">
            <div className="flex items-center justify-between text-[10px]">
              <span className="text-slate-400">Live Token Sandbox</span>
              <span className="text-pink-400 font-bold">r: {radius}px</span>
            </div>

            <div className="flex items-center justify-between gap-2">
              <div className="flex gap-1.5">
                {['#FF4B8B', '#8B5CF6', '#20C9B0', '#FF884D'].map((c) => (
                  <button
                    key={c}
                    onClick={() => setAccentColor(c)}
                    className={`w-5 h-5 rounded-full transition-transform ${
                      accentColor === c ? 'scale-125 ring-2 ring-white' : 'opacity-70 hover:opacity-100'
                    }`}
                    style={{ backgroundColor: c }}
                  />
                ))}
              </div>

              {/* Sample Button Token Rendering */}
              <button
                className="px-3 py-1.5 text-[10px] font-bold text-white shadow-md transition-all"
                style={{ backgroundColor: accentColor, borderRadius: `${radius}px` }}
              >
                BloomButton
              </button>
            </div>
          </div>
        </div>

        <a
          href="/bloom"
          className="inline-flex items-center justify-between w-full px-5 py-3 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-950 font-bold text-xs shadow-md hover:bg-slate-800 dark:hover:bg-slate-100 transition-all group/btn"
        >
          <span>Explore UI Studio & Tokens</span>
          <ArrowRight className="w-4 h-4 group-hover/btn:translate-x-1 transition-transform" />
        </a>
      </div>
    </div>
  );
}
