import { useState } from 'preact/hooks';
import {
  Smartphone,
  Monitor,
  Copy,
  Check,
  Sparkles,
  Terminal,
  Layers,
  Code2,
  ExternalLink,
  ChevronDown,
  Info
} from 'lucide-preact';
import type { UIComponentDoc } from '../../lib/ui-registry';
import { highlightDart } from '../../lib/dart-highlighter';

interface ComponentViewerProps {
  component: UIComponentDoc;
}

export function ComponentViewer({ component }: ComponentViewerProps) {
  const [viewport, setViewport] = useState<'mobile' | 'web'>('mobile');
  const [activeTab, setActiveTab] = useState<'preview' | 'code' | 'install' | 'props'>('preview');
  const [copied, setCopied] = useState(false);
  const [themeStyle, setThemeStyle] = useState<'nova' | 'vega' | 'maia' | 'lyra' | 'mira' | 'luma' | 'sera' | 'rhea'>('nova');
  const [isDark, setIsDark] = useState(true);

  // Interactive demo states
  const [btnVariant, setBtnVariant] = useState('defaultVariant');
  const [btnSize, setBtnSize] = useState('defaultSize');
  const [isLoading, setIsLoading] = useState(false);
  const [isChecked, setIsChecked] = useState(true);
  const [switchVal, setSwitchVal] = useState(true);
  const [sliderVal, setSliderVal] = useState(65);
  const [selectedRadio, setSelectedRadio] = useState('pro');
  const [activeTabKey, setActiveTabKey] = useState('tab1');
  const [accordionOpen, setAccordionOpen] = useState(true);
  const [alertType, setAlertType] = useState('info');

  const themeStyles = {
    nova: { name: 'Nova', primary: '#18181b', primaryText: '#ffffff', accent: '#8b5cf6' },
    vega: { name: 'Vega', primary: '#d97706', primaryText: '#ffffff', accent: '#f59e0b' },
    maia: { name: 'Maia', primary: '#059669', primaryText: '#ffffff', accent: '#10b981' },
    lyra: { name: 'Lyra', primary: '#7c3aed', primaryText: '#ffffff', accent: '#a78bfa' },
    mira: { name: 'Mira', primary: '#2563eb', primaryText: '#ffffff', accent: '#60a5fa' },
    luma: { name: 'Luma', primary: '#db2777', primaryText: '#ffffff', accent: '#f472b6' },
    sera: { name: 'Sera', primary: '#0891b2', primaryText: '#ffffff', accent: '#22d3ee' },
    rhea: { name: 'Rhea', primary: '#ea580c', primaryText: '#ffffff', accent: '#fb923c' },
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Render Component Preview in live DOM
  const renderInteractivePreview = () => {
    switch (component.previewType) {
      case 'button':
        return (
          <div className="flex flex-col items-center justify-center gap-6 p-8">
            <div className="flex flex-wrap items-center justify-center gap-4">
              <button
                onClick={() => setIsLoading(!isLoading)}
                className={`inline-flex items-center justify-center rounded-lg font-medium transition-all ${
                  btnSize === 'xs' ? 'h-6 px-2.5 text-xs' :
                  btnSize === 'sm' ? 'h-7 px-3 text-xs' :
                  btnSize === 'lg' ? 'h-9 px-5 text-sm' :
                  'h-8 px-4 text-xs'
                } ${
                  btnVariant === 'secondary' ? 'bg-slate-800 text-slate-100 hover:bg-slate-700' :
                  btnVariant === 'outline' ? 'border border-slate-700 bg-transparent text-slate-200 hover:bg-slate-800' :
                  btnVariant === 'ghost' ? 'bg-transparent text-slate-300 hover:bg-slate-800' :
                  btnVariant === 'destructive' ? 'bg-red-500/10 text-red-400 hover:bg-red-500/20 border border-red-500/20' :
                  btnVariant === 'link' ? 'bg-transparent text-purple-400 hover:underline p-0 h-auto' :
                  'bg-white text-slate-950 hover:bg-slate-200'
                }`}
              >
                {isLoading && (
                  <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin mr-2" />
                )}
                <span>Deploy Service</span>
              </button>
            </div>

            <div className="flex flex-wrap items-center gap-2 pt-4 border-t border-slate-800/80 w-full justify-center text-xs">
              <span className="text-slate-400">Variant:</span>
              {(['defaultVariant', 'secondary', 'outline', 'ghost', 'destructive', 'link'] as const).map((v) => (
                <button
                  key={v}
                  onClick={() => setBtnVariant(v)}
                  className={`px-2 py-1 rounded text-[11px] ${
                    btnVariant === v ? 'bg-purple-600 text-white' : 'bg-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  {v}
                </button>
              ))}
            </div>
          </div>
        );

      case 'input':
      case 'input_group':
      case 'field':
        return (
          <div className="w-full max-w-sm mx-auto space-y-4 p-6">
            <div className="space-y-1.5">
              <div className="flex justify-between">
                <label className="text-xs font-semibold text-slate-200">
                  Project Domain <span className="text-red-400">*</span>
                </label>
              </div>
              <div className="flex rounded-lg border border-slate-700 bg-slate-900 overflow-hidden focus-within:ring-1 focus-within:ring-purple-500">
                <span className="px-3 py-1.5 bg-slate-800/80 text-slate-400 text-xs border-r border-slate-700 flex items-center">
                  https://
                </span>
                <input
                  type="text"
                  placeholder="app.bloom.dev"
                  className="w-full bg-transparent px-3 py-1.5 text-xs text-white placeholder-slate-500 focus:outline-none"
                />
              </div>
              <p className="text-[11px] text-slate-400">Unique address for your live Flutter web build.</p>
            </div>
          </div>
        );

      case 'checkbox':
      case 'switch':
      case 'slider':
      case 'radio':
        return (
          <div className="w-full max-w-xs mx-auto space-y-5 p-6 text-xs">
            <div className="flex items-center justify-between p-3 rounded-lg bg-slate-900 border border-slate-800">
              <div>
                <div className="font-semibold text-white">Over-The-Air Patches</div>
                <div className="text-[11px] text-slate-400">Background patch downloads</div>
              </div>
              <button
                onClick={() => setSwitchVal(!switchVal)}
                className={`w-8 h-4.5 flex items-center rounded-full p-0.5 transition-colors ${
                  switchVal ? 'bg-purple-600 justify-end' : 'bg-slate-700 justify-start'
                }`}
              >
                <div className="w-3.5 h-3.5 rounded-full bg-white shadow-sm" />
              </button>
            </div>

            <div className="flex items-center gap-3">
              <input
                type="checkbox"
                checked={isChecked}
                onChange={() => setIsChecked(!isChecked)}
                className="w-4 h-4 rounded border-slate-700 bg-slate-900 text-purple-600 focus:ring-purple-500"
              />
              <span className="text-slate-300">Enable Shorebird runtime integration</span>
            </div>

            <div className="space-y-2">
              <div className="flex justify-between text-slate-400">
                <span>Bandwidth Cap</span>
                <span className="text-white font-mono">{sliderVal} MB</span>
              </div>
              <input
                type="range"
                min="10"
                max="100"
                value={sliderVal}
                onInput={(e: any) => setSliderVal(e.target.value)}
                className="w-full h-1 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-purple-500"
              />
            </div>
          </div>
        );

      case 'card':
        return (
          <div className="w-full max-w-md mx-auto p-4">
            <div className="rounded-2xl border border-slate-800 bg-slate-950/90 shadow-2xl overflow-hidden">
              <div className="p-5 space-y-1">
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-bold text-white">Production Cluster</h3>
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                    HEALTHY
                  </span>
                </div>
                <p className="text-xs text-slate-400">Global fleet deployment across 14 edge regions.</p>
              </div>
              <div className="px-5 py-3 border-t border-slate-800/60 bg-slate-900/30 text-xs space-y-2">
                <div className="flex justify-between text-slate-300">
                  <span>Current Version:</span>
                  <span className="font-mono text-purple-400">v2.4.1 (OTA-90)</span>
                </div>
                <div className="flex justify-between text-slate-300">
                  <span>Impeller 60fps status:</span>
                  <span className="text-emerald-400">Active</span>
                </div>
              </div>
              <div className="px-5 py-3.5 bg-slate-900/80 border-t border-slate-800 flex justify-end gap-2">
                <button className="px-3 py-1 text-xs rounded-lg border border-slate-700 text-slate-300 hover:bg-slate-800">
                  View Logs
                </button>
                <button className="px-3 py-1 text-xs rounded-lg bg-purple-600 text-white hover:bg-purple-500">
                  Push Patch
                </button>
              </div>
            </div>
          </div>
        );

      case 'chart':
        return (
          <div className="w-full max-w-lg mx-auto p-4 space-y-4">
            <div className="p-4 rounded-xl border border-slate-800 bg-slate-950/90 space-y-3">
              <div className="flex justify-between items-center">
                <div>
                  <div className="text-xs font-bold text-white">Live Requests / Sec</div>
                  <div className="text-[11px] text-slate-400">Aggregated real-time metrics</div>
                </div>
                <span className="text-xs font-mono text-purple-400 font-bold">14,280 rps</span>
              </div>
              <div className="h-32 flex items-end gap-2 pt-4 px-2">
                {[45, 60, 35, 80, 95, 75, 110, 85, 120, 100, 135, 125].map((h, i) => (
                  <div key={i} className="flex-1 flex flex-col items-center gap-1">
                    <div
                      style={{ height: `${(h / 140) * 100}%` }}
                      className="w-full bg-gradient-to-t from-purple-600 to-pink-500 rounded-t-sm hover:brightness-125 transition-all"
                    />
                  </div>
                ))}
              </div>
              <div className="flex justify-between text-[10px] text-slate-500 font-mono">
                <span>00:00</span>
                <span>06:00</span>
                <span>12:00</span>
                <span>18:00</span>
                <span>Now</span>
              </div>
            </div>
          </div>
        );

      default:
        return (
          <div className="flex flex-col items-center justify-center p-8 space-y-4">
            <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl max-w-sm w-full text-center space-y-3">
              <div className="w-10 h-10 rounded-xl bg-purple-500/10 text-purple-400 border border-purple-500/20 flex items-center justify-center mx-auto">
                <Code2 className="w-5 h-5" />
              </div>
              <div className="text-sm font-bold text-white">{component.name}</div>
              <p className="text-xs text-slate-400">{component.description}</p>
              <div className="pt-2">
                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-mono bg-purple-500/10 text-purple-300 border border-purple-500/30">
                  <Sparkles className="w-3 h-3" /> Zero Dependencies
                </span>
              </div>
            </div>
          </div>
        );
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Action Bar */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-xl">
        {/* Viewport Switcher */}
        <div className="flex items-center gap-1 p-1 rounded-xl bg-slate-950 border border-slate-800">
          <button
            onClick={() => setViewport('mobile')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              viewport === 'mobile'
                ? 'bg-purple-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Smartphone className="w-3.5 h-3.5" />
            <span>Mobile (375px)</span>
          </button>
          <button
            onClick={() => setViewport('web')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              viewport === 'web'
                ? 'bg-purple-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Monitor className="w-3.5 h-3.5" />
            <span>Web / Desktop</span>
          </button>
        </div>

        {/* Style Preset Switcher */}
        <div className="flex items-center gap-2">
          <span className="text-xs font-mono text-slate-400">Style:</span>
          <div className="flex gap-1.5">
            {(Object.keys(themeStyles) as (keyof typeof themeStyles)[]).map((style) => (
              <button
                key={style}
                onClick={() => setThemeStyle(style)}
                title={themeStyles[style].name}
                className={`px-2 py-1 rounded text-xs font-mono transition-all ${
                  themeStyle === style
                    ? 'bg-white text-slate-950 font-bold shadow'
                    : 'bg-slate-800 text-slate-400 hover:text-white'
                }`}
              >
                {style}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Interactive Stage */}
      <div className="rounded-3xl border border-slate-800 bg-slate-950/80 backdrop-blur-2xl overflow-hidden shadow-2xl">
        {/* Navigation Tabs */}
        <div className="flex items-center justify-between border-b border-slate-800 px-4">
          <div className="flex gap-2">
            {[
              { id: 'preview', label: 'Live Preview', icon: Sparkles },
              { id: 'code', label: 'Flutter Code', icon: Code2 },
              { id: 'install', label: 'Installation', icon: Terminal },
              { id: 'props', label: 'API & Slots', icon: Layers },
            ].map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as any)}
                  className={`flex items-center gap-2 px-4 py-3 text-xs font-semibold border-b-2 transition-all ${
                    activeTab === tab.id
                      ? 'border-purple-500 text-white'
                      : 'border-transparent text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>

          <button
            onClick={() => copyToClipboard(component.usageCode)}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 text-xs font-mono text-slate-300 hover:text-white hover:border-slate-700 transition"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
            <span>{copied ? 'Copied' : 'Copy Dart Code'}</span>
          </button>
        </div>

        {/* Tab Content */}
        <div className="p-6">
          {activeTab === 'preview' && (
            <div className="flex justify-center items-center min-h-[380px] bg-slate-950/40 rounded-2xl border border-slate-900/60 p-4">
              {viewport === 'mobile' ? (
                /* Mobile Device Mockup Frame */
                <div className="w-[340px] sm:w-[375px] rounded-[40px] border-[6px] border-slate-800 bg-[#090C10] shadow-[0_25px_60px_-15px_rgba(0,0,0,0.9)] overflow-hidden relative">
                  {/* Status Bar */}
                  <div className="h-10 px-6 flex items-center justify-between text-[11px] text-slate-400 bg-black/40">
                    <span className="font-semibold text-white">9:41</span>
                    <div className="w-20 h-4 bg-slate-800 rounded-full mx-auto" />
                    <div className="flex items-center gap-1.5">
                      <div className="w-3 h-2 border border-slate-400 rounded-xs" />
                    </div>
                  </div>

                  {/* App Screen Content */}
                  <div className="min-h-[340px] flex flex-col justify-center">
                    {renderInteractivePreview()}
                  </div>

                  {/* Home Bar */}
                  <div className="h-6 flex items-center justify-center">
                    <div className="w-32 h-1 bg-slate-700 rounded-full" />
                  </div>
                </div>
              ) : (
                /* Web / Desktop Frame */
                <div className="w-full max-w-3xl rounded-2xl border border-slate-800 bg-[#090C10] shadow-2xl overflow-hidden">
                  {/* Browser Bar */}
                  <div className="h-9 px-4 flex items-center gap-2 bg-slate-900 border-b border-slate-800 text-xs text-slate-400">
                    <div className="flex gap-1.5">
                      <div className="w-2.5 h-2.5 rounded-full bg-red-500/80" />
                      <div className="w-2.5 h-2.5 rounded-full bg-amber-500/80" />
                      <div className="w-2.5 h-2.5 rounded-full bg-emerald-500/80" />
                    </div>
                    <div className="flex-1 max-w-sm mx-auto h-5 bg-slate-950 rounded px-3 flex items-center text-[10px] text-slate-500 font-mono">
                      https://app.bloom.dev/components/{component.slug}
                    </div>
                  </div>

                  {/* Web Screen Content */}
                  <div className="min-h-[320px] flex items-center justify-center p-6">
                    {renderInteractivePreview()}
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === 'code' && (
            <div className="space-y-4">
              <div className="relative rounded-2xl bg-[#090D16] border border-slate-800 p-5 font-mono text-xs text-slate-100 overflow-x-auto">
                <pre
                  className="leading-relaxed font-mono"
                  dangerouslySetInnerHTML={{ __html: highlightDart(component.usageCode) }}
                />
              </div>
            </div>
          )}

          {activeTab === 'install' && (
            <div className="space-y-6 max-w-2xl mx-auto py-4">
              {/* CLI Option */}
              <div className="space-y-2">
                <h4 className="text-sm font-bold text-white flex items-center gap-2">
                  <Terminal className="w-4 h-4 text-purple-400" />
                  Option 1: CLI (Copy-paste source code)
                </h4>
                <div className="flex items-center justify-between p-3 rounded-xl bg-black border border-slate-800 font-mono text-xs text-purple-300">
                  <code>{component.cliCommand}</code>
                  <button
                    onClick={() => copyToClipboard(component.cliCommand)}
                    className="p-1 text-slate-400 hover:text-white"
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              {/* Pub.dev Option */}
              <div className="space-y-2">
                <h4 className="text-sm font-bold text-white flex items-center gap-2">
                  <ExternalLink className="w-4 h-4 text-pink-400" />
                  Option 2: Pub.dev Package
                </h4>
                <div className="flex items-center justify-between p-3 rounded-xl bg-black border border-slate-800 font-mono text-xs text-pink-300">
                  <code>flutter pub add bloom_ui</code>
                  <button
                    onClick={() => copyToClipboard('flutter pub add bloom_ui')}
                    className="p-1 text-slate-400 hover:text-white"
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'props' && (
            <div className="space-y-6">
              {/* Properties Table */}
              <div className="space-y-3">
                <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">Properties</h4>
                <div className="rounded-xl border border-slate-800 overflow-hidden">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-slate-900/80 text-slate-400 font-mono border-b border-slate-800">
                      <tr>
                        <th className="p-3">Prop</th>
                        <th className="p-3">Type</th>
                        <th className="p-3">Default</th>
                        <th className="p-3">Description</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60 font-mono">
                      {component.props.map((p) => (
                        <tr key={p.name} className="hover:bg-slate-900/40">
                          <td className="p-3 text-purple-300 font-semibold">{p.name}</td>
                          <td className="p-3 text-pink-300">{p.type}</td>
                          <td className="p-3 text-slate-400">{p.defaultVal || '—'}</td>
                          <td className="p-3 text-slate-300 font-sans">{p.description}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Sub-components / Slots */}
              {component.slots && component.slots.length > 0 && (
                <div className="space-y-3">
                  <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">Compound Slots</h4>
                  <div className="rounded-xl border border-slate-800 overflow-hidden">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-900/80 text-slate-400 font-mono border-b border-slate-800">
                        <tr>
                          <th className="p-3">Slot Component</th>
                          <th className="p-3">Description</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-800/60 font-mono">
                        {component.slots.map((s) => (
                          <tr key={s.name} className="hover:bg-slate-900/40">
                            <td className="p-3 text-purple-300 font-semibold">{s.name}</td>
                            <td className="p-3 text-slate-300 font-sans">{s.description}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
