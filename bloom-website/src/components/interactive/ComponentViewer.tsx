import { useState } from 'preact/hooks';
import {
  Copy,
  Check,
  Sparkles,
  Terminal,
  Layers,
  Code2,
  ExternalLink,
  ChevronDown,
  ChevronRight,
  Info,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Search,
  Calendar as CalendarIcon,
  Bell,
  User,
  Sliders,
  Settings,
  Trash2,
  Folder,
  ArrowRight,
  Zap,
  Activity
} from 'lucide-preact';
import type { UIComponentDoc } from '../../lib/ui-registry';
import { highlightDart } from '../../lib/dart-highlighter';

interface ComponentViewerProps {
  component: UIComponentDoc;
}

export function ComponentViewer({ component }: ComponentViewerProps) {
  const [activeTab, setActiveTab] = useState<'preview' | 'code' | 'install' | 'props'>('preview');
  const [copied, setCopied] = useState(false);
  const [themeStyle, setThemeStyle] = useState<'nova' | 'vega' | 'maia' | 'lyra' | 'mira' | 'luma' | 'sera' | 'rhea'>('nova');

  // Interactive Component State Hooks
  const [btnVariant, setBtnVariant] = useState('defaultVariant');
  const [btnSize, setBtnSize] = useState('defaultSize');
  const [isLoading, setIsLoading] = useState(false);
  const [btnGroupVal, setBtnGroupVal] = useState('week');
  const [inputValue, setInputValue] = useState('');
  const [otpValues, setOtpValues] = useState(['4', '8', '2', '9', '', '']);
  const [textareaVal, setTextareaVal] = useState('Deploying v2.4.0 with Signals state management and OTA bytecode patch.');
  const [isChecked, setIsChecked] = useState(true);
  const [selectedRadio, setSelectedRadio] = useState('pro');
  const [switchVal, setSwitchVal] = useState(true);
  const [sliderVal, setSliderVal] = useState(68);
  const [selectVal, setSelectVal] = useState('Bloom Framework');
  const [isSelectOpen, setIsSelectOpen] = useState(false);
  const [comboboxSearch, setComboboxSearch] = useState('');
  const [comboboxSelected, setComboboxSelected] = useState('signals');
  const [selectedDate, setSelectedDate] = useState(14);
  const [activeAccordion, setActiveAccordion] = useState<number | null>(0);
  const [activeTabKey, setActiveTabKey] = useState('overview');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [alertDialogOpen, setAlertDialogOpen] = useState(false);
  const [alertDismissed, setAlertDismissed] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [toasts, setToasts] = useState<{ id: number; title: string; desc: string }[]>([]);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false);
  const [commandSearch, setCommandSearch] = useState('');
  const [progressVal, setProgressVal] = useState(72);

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const addToast = () => {
    const id = Date.now();
    setToasts((prev) => [...prev, { id, title: 'Changes Deployed', desc: 'Shorebird OTA patch compiled in 1.4s.' }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 3500);
  };

  // Render Interactive Preview for all 34 Primitives
  const renderInteractivePreview = () => {
    switch (component.slug) {
      // 1. BUTTON
      case 'button':
        return (
          <div className="flex flex-col items-center justify-center gap-6 p-8 w-full max-w-md mx-auto">
            <button
              onClick={() => setIsLoading(!isLoading)}
              className={`inline-flex items-center justify-center rounded-xl font-medium transition-all shadow-md active:scale-95 ${
                btnSize === 'xs' ? 'h-7 px-3 text-xs' :
                btnSize === 'sm' ? 'h-8 px-3.5 text-xs' :
                btnSize === 'lg' ? 'h-11 px-6 text-sm' :
                'h-9 px-4 text-xs'
              } ${
                btnVariant === 'secondary' ? 'bg-slate-800 text-slate-100 hover:bg-slate-700 border border-slate-700' :
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
              <span>Deploy Application</span>
            </button>

            <div className="flex flex-wrap items-center gap-1.5 pt-4 border-t border-slate-800/80 w-full justify-center text-xs">
              <span className="text-slate-500 text-[11px] mr-1">Variant:</span>
              {(['defaultVariant', 'secondary', 'outline', 'ghost', 'destructive', 'link'] as const).map((v) => (
                <button
                  key={v}
                  onClick={() => setBtnVariant(v)}
                  className={`px-2 py-1 rounded-lg text-[10px] font-mono transition ${
                    btnVariant === v ? 'bg-purple-600 text-white' : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
                  }`}
                >
                  {v}
                </button>
              ))}
            </div>
          </div>
        );

      // 2. BUTTON GROUP
      case 'button-group':
        return (
          <div className="flex flex-col items-center justify-center gap-4 p-8 w-full max-w-md mx-auto">
            <div className="inline-flex rounded-xl p-1 bg-slate-900 border border-slate-800 shadow-inner">
              {[
                { id: 'day', label: 'Day' },
                { id: 'week', label: 'Week' },
                { id: 'month', label: 'Month' },
                { id: 'year', label: 'Year' },
              ].map((item) => (
                <button
                  key={item.id}
                  onClick={() => setBtnGroupVal(item.id)}
                  className={`px-4 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                    btnGroupVal === item.id
                      ? 'bg-purple-600 text-white shadow-sm'
                      : 'text-slate-400 hover:text-slate-200'
                  }`}
                >
                  {item.label}
                </button>
              ))}
            </div>
            <span className="text-[11px] text-slate-500 font-mono">Selected: {btnGroupVal}</span>
          </div>
        );

      // 3. INPUT
      case 'input':
        return (
          <div className="w-full max-w-sm mx-auto space-y-3 p-6">
            <label className="text-xs font-semibold text-slate-300">Application Name</label>
            <input
              type="text"
              value={inputValue}
              onInput={(e: any) => setInputValue(e.target.value)}
              placeholder="e.g. Bloom Analytics"
              className="w-full h-10 px-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500 transition font-mono"
            />
            <p className="text-[11px] text-slate-500">Live input: <span className="text-purple-400">{inputValue || 'None'}</span></p>
          </div>
        );

      // 4. INPUT GROUP
      case 'input-group':
        return (
          <div className="w-full max-w-sm mx-auto space-y-3 p-6">
            <label className="text-xs font-semibold text-slate-300">Custom Domain</label>
            <div className="flex rounded-xl border border-slate-800 bg-slate-950 overflow-hidden focus-within:border-purple-500 focus-within:ring-1 focus-within:ring-purple-500">
              <span className="px-3.5 bg-slate-900 text-slate-400 text-xs border-r border-slate-800 flex items-center font-mono">
                https://
              </span>
              <input
                type="text"
                placeholder="app.bloom.dev"
                className="w-full bg-transparent px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none font-mono"
              />
              <button className="px-3 bg-purple-600 hover:bg-purple-500 text-white text-xs font-semibold transition">
                Verify
              </button>
            </div>
          </div>
        );

      // 5. INPUT OTP
      case 'input-otp':
        return (
          <div className="flex flex-col items-center justify-center gap-4 p-6 w-full max-w-sm mx-auto">
            <span className="text-xs font-semibold text-slate-300">Two-Factor Authentication Code</span>
            <div className="flex items-center gap-2">
              {otpValues.map((val, idx) => (
                <div
                  key={idx}
                  className={`w-10 h-12 rounded-xl border flex items-center justify-center text-base font-mono font-bold transition ${
                    idx === 4
                      ? 'border-purple-500 bg-purple-500/10 text-purple-300 ring-2 ring-purple-500/30'
                      : 'border-slate-800 bg-slate-950 text-white'
                  }`}
                >
                  {val || (idx === 4 ? <span className="w-0.5 h-5 bg-purple-400 animate-pulse" /> : '')}
                </div>
              ))}
            </div>
            <p className="text-[11px] text-slate-500">Enter the 6-digit security code sent to your device.</p>
          </div>
        );

      // 6. TEXTAREA
      case 'textarea':
        return (
          <div className="w-full max-w-sm mx-auto space-y-2 p-6">
            <label className="text-xs font-semibold text-slate-300">Deployment Release Notes</label>
            <textarea
              rows={3}
              value={textareaVal}
              onInput={(e: any) => setTextareaVal(e.target.value)}
              className="w-full p-3 rounded-xl bg-slate-950 border border-slate-800 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-purple-500 font-mono resize-none leading-relaxed"
            />
            <div className="flex justify-between text-[11px] text-slate-500">
              <span>Markdown supported</span>
              <span>{textareaVal.length}/200 chars</span>
            </div>
          </div>
        );

      // 7. CHECKBOX
      case 'checkbox':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-4">
            <label className="flex items-start gap-3 p-3.5 rounded-xl bg-slate-950 border border-slate-800 cursor-pointer hover:border-slate-700 transition">
              <input
                type="checkbox"
                checked={isChecked}
                onChange={() => setIsChecked(!isChecked)}
                className="w-4 h-4 mt-0.5 rounded border-slate-700 bg-slate-900 text-purple-600 focus:ring-purple-500 accent-purple-600"
              />
              <div className="space-y-0.5">
                <div className="text-xs font-semibold text-white">Enable Shorebird Runtime OTA</div>
                <p className="text-[11px] text-slate-400">Instantly distribute delta bytecode patches over-the-air.</p>
              </div>
            </label>
          </div>
        );

      // 8. RADIO
      case 'radio':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-2.5">
            {[
              { id: 'starter', name: 'Starter Tier', desc: '10k requests/mo', price: '$0' },
              { id: 'pro', name: 'Pro Tier', desc: 'Unlimited requests + OTA', price: '$29/mo' },
              { id: 'ent', name: 'Enterprise', desc: 'Custom SLA & dedicated nodes', price: '$199/mo' },
            ].map((plan) => (
              <div
                key={plan.id}
                onClick={() => setSelectedRadio(plan.id)}
                className={`flex items-center justify-between p-3.5 rounded-xl border cursor-pointer transition ${
                  selectedRadio === plan.id
                    ? 'border-purple-500 bg-purple-500/10 text-white ring-1 ring-purple-500/30'
                    : 'border-slate-800 bg-slate-950 text-slate-300 hover:border-slate-700'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div className={`w-4 h-4 rounded-full border flex items-center justify-center ${
                    selectedRadio === plan.id ? 'border-purple-400 bg-purple-600' : 'border-slate-700 bg-slate-900'
                  }`}>
                    {selectedRadio === plan.id && <div className="w-1.5 h-1.5 rounded-full bg-white" />}
                  </div>
                  <div>
                    <div className="text-xs font-bold">{plan.name}</div>
                    <div className="text-[11px] text-slate-400">{plan.desc}</div>
                  </div>
                </div>
                <span className="text-xs font-mono font-bold text-purple-300">{plan.price}</span>
              </div>
            ))}
          </div>
        );

      // 9. SWITCH
      case 'switch':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-3">
            <div className="flex items-center justify-between p-4 rounded-xl bg-slate-950 border border-slate-800">
              <div>
                <div className="text-xs font-bold text-white">Live Push Notifications</div>
                <div className="text-[11px] text-slate-400">Receive real-time crash and query alerts</div>
              </div>
              <button
                onClick={() => setSwitchVal(!switchVal)}
                className={`w-11 h-6 flex items-center rounded-full p-1 transition-colors duration-200 ease-in-out ${
                  switchVal ? 'bg-purple-600' : 'bg-slate-800'
                }`}
              >
                <div className={`w-4 h-4 rounded-full bg-white shadow-md transform transition-transform duration-200 ${
                  switchVal ? 'translate-x-5' : 'translate-x-0'
                }`} />
              </button>
            </div>
          </div>
        );

      // 10. SLIDER
      case 'slider':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-4">
            <div className="flex justify-between items-center text-xs">
              <span className="font-semibold text-slate-300">Cache Memory Limit</span>
              <span className="px-2 py-0.5 rounded bg-purple-500/10 text-purple-400 font-mono font-bold border border-purple-500/20">
                {sliderVal} MB
              </span>
            </div>
            <input
              type="range"
              min="16"
              max="256"
              value={sliderVal}
              onInput={(e: any) => setSliderVal(e.target.value)}
              className="w-full h-1.5 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-purple-500"
            />
            <div className="flex justify-between text-[10px] text-slate-500 font-mono">
              <span>16 MB (Min)</span>
              <span>256 MB (Max)</span>
            </div>
          </div>
        );

      // 11. SELECT
      case 'select':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-2 relative">
            <label className="text-xs font-semibold text-slate-300">Target Framework</label>
            <div
              onClick={() => setIsSelectOpen(!isSelectOpen)}
              className="flex items-center justify-between p-3 rounded-xl bg-slate-950 border border-slate-800 cursor-pointer hover:border-slate-700 transition text-xs text-white"
            >
              <span className="font-semibold">{selectVal}</span>
              <ChevronDown className="w-4 h-4 text-slate-400" />
            </div>
            {isSelectOpen && (
              <div className="absolute left-6 right-6 top-20 z-20 rounded-xl bg-slate-900 border border-slate-800 shadow-2xl p-1.5 space-y-1">
                {['Bloom Framework', 'Flutter Material', 'Serverpod Client', 'Supabase Realtime'].map((item) => (
                  <div
                    key={item}
                    onClick={() => {
                      setSelectVal(item);
                      setIsSelectOpen(false);
                    }}
                    className={`flex items-center justify-between px-3 py-2 rounded-lg text-xs cursor-pointer ${
                      selectVal === item ? 'bg-purple-600 text-white font-bold' : 'text-slate-300 hover:bg-slate-800'
                    }`}
                  >
                    <span>{item}</span>
                    {selectVal === item && <Check className="w-3.5 h-3.5" />}
                  </div>
                ))}
              </div>
            )}
          </div>
        );

      // 12. COMBOBOX
      case 'combobox':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-3">
            <label className="text-xs font-semibold text-slate-300">Search Bloom Modules</label>
            <div className="rounded-xl border border-slate-800 bg-slate-950 p-2 space-y-2">
              <div className="flex items-center gap-2 px-2 pb-2 border-b border-slate-800/80">
                <Search className="w-3.5 h-3.5 text-slate-400" />
                <input
                  type="text"
                  placeholder="Filter libraries..."
                  value={comboboxSearch}
                  onInput={(e: any) => setComboboxSearch(e.target.value)}
                  className="w-full bg-transparent text-xs text-white placeholder-slate-500 focus:outline-none font-mono"
                />
              </div>
              <div className="space-y-1 max-h-36 overflow-y-auto">
                {[
                  { id: 'signals', label: 'bloom_signals (Fine-grained Reactivity)' },
                  { id: 'router', label: 'bloom_router (Filesystem AST)' },
                  { id: 'data', label: 'bloom_data (Query & SWR Cache)' },
                  { id: 'prebuild', label: 'bloom_prebuild (Native Sync)' },
                ]
                  .filter((i) => i.label.toLowerCase().includes(comboboxSearch.toLowerCase()))
                  .map((item) => (
                    <div
                      key={item.id}
                      onClick={() => setComboboxSelected(item.id)}
                      className={`flex items-center justify-between px-3 py-1.5 rounded-lg text-xs cursor-pointer ${
                        comboboxSelected === item.id
                          ? 'bg-purple-600/20 text-purple-300 border border-purple-500/30'
                          : 'text-slate-300 hover:bg-slate-900'
                      }`}
                    >
                      <span className="font-mono text-[11px]">{item.label}</span>
                      {comboboxSelected === item.id && <Check className="w-3 h-3 text-purple-400" />}
                    </div>
                  ))}
              </div>
            </div>
          </div>
        );

      // 13. CALENDAR
      case 'calendar':
        return (
          <div className="w-full max-w-xs mx-auto p-5 rounded-2xl bg-slate-950 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800 text-xs">
              <span className="font-bold text-white">August 2026</span>
              <div className="flex gap-1 text-slate-400">
                <button className="p-1 rounded hover:bg-slate-800">&lt;</button>
                <button className="p-1 rounded hover:bg-slate-800">&gt;</button>
              </div>
            </div>
            <div className="grid grid-cols-7 gap-1 text-center text-[10px] font-mono text-slate-500">
              {['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) => (
                <div key={d} className="py-1 font-bold">{d}</div>
              ))}
              {Array.from({ length: 31 }).map((_, i) => {
                const day = i + 1;
                const isSel = selectedDate === day;
                return (
                  <button
                    key={day}
                    onClick={() => setSelectedDate(day)}
                    className={`py-1.5 rounded-lg text-xs font-mono transition ${
                      isSel
                        ? 'bg-purple-600 text-white font-bold shadow-sm'
                        : 'text-slate-300 hover:bg-slate-900'
                    }`}
                  >
                    {day}
                  </button>
                );
              })}
            </div>
          </div>
        );

      // 14. FIELD
      case 'field':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-2">
            <div className="flex justify-between text-xs">
              <label className="font-semibold text-slate-200">
                Cluster Hostname <span className="text-red-400">*</span>
              </label>
              <span className="text-slate-500">Required</span>
            </div>
            <input
              type="text"
              defaultValue="node-us-east.bloom.network"
              className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs font-mono text-white focus:outline-none focus:border-purple-500"
            />
            <p className="text-[11px] text-emerald-400 flex items-center gap-1">
              <CheckCircle2 className="w-3 h-3" /> Hostname verified via DNS lookup.
            </p>
          </div>
        );

      // 15. CARD
      case 'card':
        return (
          <div className="w-full max-w-sm mx-auto p-4">
            <div className="rounded-2xl border border-slate-800 bg-slate-950 shadow-2xl overflow-hidden space-y-4 p-5">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-bold text-white">Shorebird OTA Fleet</h3>
                  <p className="text-[11px] text-slate-400">Bytecode patch distribution</p>
                </div>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                  HEALTHY
                </span>
              </div>
              <div className="space-y-1.5 pt-2 border-t border-slate-800/80 font-mono text-xs text-slate-300">
                <div className="flex justify-between">
                  <span className="text-slate-500">Active Patch:</span>
                  <span className="text-purple-400 font-bold">#492-delta</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Impeller 60fps:</span>
                  <span className="text-emerald-400">100% stable</span>
                </div>
              </div>
              <button
                onClick={addToast}
                className="w-full py-2 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold text-xs transition"
              >
                Trigger Rollout
              </button>
            </div>
          </div>
        );

      // 16. ACCORDION
      case 'accordion':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-2">
            {[
              { title: 'Fine-Grained Signals', desc: 'No setState, no full widget tree re-renders. Signals compute dependencies topographically.' },
              { title: 'Filesystem Routing Engine', desc: 'Next.js directory structure compiles automatically to type-safe GoRouter definitions.' },
              { title: 'Zero Reflection DI', desc: 'Pure AOT compatible dependency injection with singletons, factories, and nested scopes.' },
            ].map((item, idx) => (
              <div key={idx} className="rounded-xl border border-slate-800 bg-slate-950 overflow-hidden">
                <button
                  onClick={() => setActiveAccordion(activeAccordion === idx ? null : idx)}
                  className="w-full p-3.5 text-left flex items-center justify-between text-xs font-semibold text-white hover:bg-slate-900 transition"
                >
                  <span>{item.title}</span>
                  <ChevronDown className={`w-3.5 h-3.5 text-slate-400 transition-transform ${activeAccordion === idx ? 'rotate-180 text-purple-400' : ''}`} />
                </button>
                {activeAccordion === idx && (
                  <div className="p-3.5 pt-0 text-xs text-slate-400 border-t border-slate-800/60 bg-slate-900/30 leading-relaxed">
                    {item.desc}
                  </div>
                )}
              </div>
            ))}
          </div>
        );

      // 17. TABS
      case 'tabs':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-4">
            <div className="flex rounded-xl p-1 bg-slate-900 border border-slate-800">
              {['overview', 'analytics', 'settings'].map((tab) => (
                <button
                  key={tab}
                  onClick={() => setActiveTabKey(tab)}
                  className={`flex-1 py-1.5 rounded-lg text-xs font-semibold capitalize transition ${
                    activeTabKey === tab ? 'bg-purple-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
                  }`}
                >
                  {tab}
                </button>
              ))}
            </div>
            <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 font-mono">
              {activeTabKey === 'overview' && 'Overview: 24 active microservices running with zero frame drops.'}
              {activeTabKey === 'analytics' && 'Analytics: 99.98% uptime, 14ms average query latency.'}
              {activeTabKey === 'settings' && 'Settings: Automatic cache garbage collection every 30 minutes.'}
            </div>
          </div>
        );

      // 18. SKELETON
      case 'skeleton':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-full bg-slate-800 animate-pulse" />
              <div className="space-y-2 flex-1">
                <div className="h-4 w-3/4 bg-slate-800 rounded animate-pulse" />
                <div className="h-3 w-1/2 bg-slate-800/60 rounded animate-pulse" />
              </div>
            </div>
            <div className="space-y-2 pt-2">
              <div className="h-16 w-full bg-slate-800/40 rounded-xl animate-pulse" />
            </div>
          </div>
        );

      // 19. PROGRESS
      case 'progress':
        return (
          <div className="w-full max-w-sm mx-auto p-6 space-y-4">
            <div className="flex justify-between items-center text-xs">
              <span className="font-semibold text-slate-300">OTA Download Progress</span>
              <span className="font-mono text-purple-400 font-bold">{progressVal}%</span>
            </div>
            <div className="w-full h-2.5 rounded-full bg-slate-800 overflow-hidden">
              <div
                style={{ width: `${progressVal}%` }}
                className="h-full bg-gradient-to-r from-purple-600 to-pink-500 transition-all duration-300 rounded-full"
              />
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => setProgressVal(Math.max(10, progressVal - 15))}
                className="flex-1 py-1 rounded-lg bg-slate-900 border border-slate-800 text-xs text-slate-300 hover:text-white"
              >
                -15%
              </button>
              <button
                onClick={() => setProgressVal(Math.min(100, progressVal + 15))}
                className="flex-1 py-1 rounded-lg bg-purple-600 text-white font-bold text-xs hover:bg-purple-500"
              >
                +15%
              </button>
            </div>
          </div>
        );

      // 20. DIALOG
      case 'dialog':
        return (
          <div className="flex flex-col items-center justify-center p-8 w-full max-w-sm mx-auto">
            <button
              onClick={() => setDialogOpen(true)}
              className="px-5 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold text-xs shadow-lg transition"
            >
              Open Bloom Dialog
            </button>
            {dialogOpen && (
              <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
                <div className="w-full max-w-md rounded-2xl bg-slate-950 border border-slate-800 p-6 space-y-4 shadow-2xl">
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-bold text-white">Create New Storage Scope</h3>
                    <button onClick={() => setDialogOpen(false)} className="text-slate-400 hover:text-white">&times;</button>
                  </div>
                  <p className="text-xs text-slate-400">Initialize a child container scope with isolated SQLite caching.</p>
                  <input
                    type="text"
                    placeholder="Scope Name (e.g. user_session)"
                    className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-white focus:outline-none focus:border-purple-500 font-mono"
                  />
                  <div className="flex justify-end gap-2 pt-2">
                    <button onClick={() => setDialogOpen(false)} className="px-4 py-2 rounded-xl bg-slate-900 text-xs text-slate-300">
                      Cancel
                    </button>
                    <button onClick={() => setDialogOpen(false)} className="px-4 py-2 rounded-xl bg-purple-600 text-xs text-white font-bold">
                      Create Scope
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        );

      // 21. ALERT DIALOG
      case 'alert-dialog':
        return (
          <div className="flex flex-col items-center justify-center p-8 w-full max-w-sm mx-auto">
            <button
              onClick={() => setAlertDialogOpen(true)}
              className="px-5 py-2.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 hover:bg-red-500/20 font-bold text-xs transition"
            >
              Delete Project Database
            </button>
            {alertDialogOpen && (
              <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
                <div className="w-full max-w-md rounded-2xl bg-slate-950 border border-red-500/30 p-6 space-y-4 shadow-2xl">
                  <div className="flex items-center gap-3 text-red-400">
                    <AlertTriangle className="w-5 h-5" />
                    <h3 className="text-sm font-bold text-white">Are you absolutely sure?</h3>
                  </div>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    This action cannot be undone. This will permanently delete the SQLite database and invalidate all live subscriber caches.
                  </p>
                  <div className="flex justify-end gap-2 pt-2">
                    <button onClick={() => setAlertDialogOpen(false)} className="px-4 py-2 rounded-xl bg-slate-900 text-xs text-slate-300">
                      Cancel
                    </button>
                    <button onClick={() => setAlertDialogOpen(false)} className="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-xs text-white font-bold">
                      Confirm Delete
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        );

      // 22. ALERT
      case 'alert':
        return (
          <div className="w-full max-w-md mx-auto p-6 space-y-3">
            <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-start gap-3 text-emerald-400">
              <CheckCircle2 className="w-4 h-4 mt-0.5 shrink-0" />
              <div className="space-y-0.5 text-xs">
                <div className="font-bold text-emerald-300">All Systems Operational</div>
                <p className="text-slate-400">Impeller Vulkan backend active at steady 60 fps.</p>
              </div>
            </div>
            <div className="p-4 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-start gap-3 text-amber-400">
              <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
              <div className="space-y-0.5 text-xs">
                <div className="font-bold text-amber-300">Cache Invalidation Warning</div>
                <p className="text-slate-400">Stale time exceeded 5 minutes on feed query.</p>
              </div>
            </div>
          </div>
        );

      // 23. SHEET
      case 'sheet':
        return (
          <div className="flex flex-col items-center justify-center p-8 w-full max-w-sm mx-auto">
            <button
              onClick={() => setSheetOpen(true)}
              className="px-5 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold text-xs shadow-lg transition"
            >
              Open Side Sheet
            </button>
            {sheetOpen && (
              <div className="fixed inset-0 z-50 bg-black/70 flex justify-end">
                <div className="w-full max-w-sm h-full bg-slate-950 border-l border-slate-800 p-6 space-y-4 shadow-2xl flex flex-col justify-between">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <h3 className="text-sm font-bold text-white">Environment Config</h3>
                      <button onClick={() => setSheetOpen(false)} className="text-slate-400 hover:text-white">&times;</button>
                    </div>
                    <div className="space-y-2">
                      <label className="text-xs text-slate-400">API Endpoint</label>
                      <input type="text" defaultValue="https://api.bloom.dev/v1" className="w-full p-2.5 rounded-xl bg-slate-900 border border-slate-800 text-xs font-mono text-white" />
                    </div>
                  </div>
                  <button onClick={() => setSheetOpen(false)} className="w-full py-2.5 rounded-xl bg-purple-600 text-white font-bold text-xs">
                    Save Changes
                  </button>
                </div>
              </div>
            )}
          </div>
        );

      // 24. DRAWER
      case 'drawer':
        return (
          <div className="flex flex-col items-center justify-center p-8 w-full max-w-sm mx-auto">
            <button
              onClick={() => setDrawerOpen(true)}
              className="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs transition border border-slate-700"
            >
              Open Bottom Drawer
            </button>
            {drawerOpen && (
              <div className="fixed inset-0 z-50 bg-black/70 flex items-end">
                <div className="w-full max-w-lg mx-auto bg-slate-950 border-t border-slate-800 rounded-t-3xl p-6 space-y-4 shadow-2xl">
                  <div className="w-12 h-1 bg-slate-700 rounded-full mx-auto" />
                  <div className="flex justify-between items-center">
                    <h3 className="text-sm font-bold text-white">Quick Actions</h3>
                    <button onClick={() => setDrawerOpen(false)} className="text-slate-400 hover:text-white">&times;</button>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <button className="p-3 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-200 hover:bg-slate-800">Clear Cache</button>
                    <button className="p-3 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-200 hover:bg-slate-800">Force Hot Reload</button>
                  </div>
                </div>
              </div>
            )}
          </div>
        );

      // 25. SONNER
      case 'sonner':
        return (
          <div className="flex flex-col items-center justify-center p-8 w-full max-w-sm mx-auto space-y-4">
            <button
              onClick={addToast}
              className="px-5 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold text-xs shadow-lg transition"
            >
              Trigger Sonner Toast
            </button>
            <div className="w-full space-y-2">
              {toasts.map((t) => (
                <div key={t.id} className="p-3.5 rounded-xl bg-slate-900 border border-slate-800 flex items-center justify-between text-xs text-white shadow-xl animate-in slide-in-from-bottom">
                  <div>
                    <div className="font-bold text-emerald-400">{t.title}</div>
                    <div className="text-[11px] text-slate-400">{t.desc}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        );

      // 26. DROPDOWN MENU
      case 'dropdown-menu':
        return (
          <div className="flex flex-col items-center justify-center p-8 w-full max-w-sm mx-auto relative">
            <button
              onClick={() => setIsDropdownOpen(!isDropdownOpen)}
              className="px-4 py-2 rounded-xl bg-slate-900 border border-slate-800 text-white text-xs font-semibold flex items-center gap-2"
            >
              <span>Actions Menu</span>
              <ChevronDown className="w-3.5 h-3.5 text-slate-400" />
            </button>
            {isDropdownOpen && (
              <div className="absolute top-20 z-20 w-48 rounded-xl bg-slate-900 border border-slate-800 p-1.5 shadow-2xl space-y-1 text-xs">
                <button className="w-full px-3 py-1.5 text-left rounded-lg text-slate-300 hover:bg-slate-800 flex justify-between">
                  <span>Profile</span>
                  <span className="text-[10px] text-slate-500 font-mono">⇧⌘P</span>
                </button>
                <button className="w-full px-3 py-1.5 text-left rounded-lg text-slate-300 hover:bg-slate-800 flex justify-between">
                  <span>Settings</span>
                  <span className="text-[10px] text-slate-500 font-mono">⌘,</span>
                </button>
                <div className="h-px bg-slate-800" />
                <button className="w-full px-3 py-1.5 text-left rounded-lg text-red-400 hover:bg-red-500/10">
                  Logout
                </button>
              </div>
            )}
          </div>
        );

      // 27. AVATAR
      case 'avatar':
        return (
          <div className="flex items-center justify-center gap-4 p-8 w-full max-w-sm mx-auto">
            <div className="relative">
              <div className="w-12 h-12 rounded-full bg-gradient-to-tr from-purple-600 to-pink-500 flex items-center justify-center text-white font-bold text-sm shadow-lg">
                BF
              </div>
              <span className="absolute bottom-0 right-0 w-3.5 h-3.5 rounded-full bg-emerald-500 border-2 border-slate-950" />
            </div>
            <div className="flex -space-x-3">
              {['A', 'B', 'C', '+3'].map((item, i) => (
                <div key={i} className="w-9 h-9 rounded-full bg-slate-800 border-2 border-slate-950 flex items-center justify-center text-xs font-mono font-bold text-slate-300">
                  {item}
                </div>
              ))}
            </div>
          </div>
        );

      // 28. BADGE
      case 'badge':
        return (
          <div className="flex flex-wrap items-center justify-center gap-2.5 p-8 w-full max-w-md mx-auto">
            <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-purple-500/10 text-purple-400 border border-purple-500/20">Default</span>
            <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-slate-800 text-slate-200">Secondary</span>
            <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">Online</span>
            <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-red-500/10 text-red-400 border border-red-500/20">Destructive</span>
            <span className="px-2.5 py-1 rounded-full text-xs font-bold border border-slate-700 text-slate-300">Outline</span>
          </div>
        );

      // 29. KBD
      case 'kbd':
        return (
          <div className="flex flex-wrap items-center justify-center gap-3 p-8 w-full max-w-sm mx-auto text-xs">
            <div className="flex items-center gap-1">
              <kbd className="px-2 py-1 rounded bg-slate-900 border border-slate-800 font-mono text-purple-400 shadow">⌘</kbd>
              <kbd className="px-2 py-1 rounded bg-slate-900 border border-slate-800 font-mono text-purple-400 shadow">K</kbd>
            </div>
            <div className="flex items-center gap-1">
              <kbd className="px-2 py-1 rounded bg-slate-900 border border-slate-800 font-mono text-slate-300 shadow">Ctrl</kbd>
              <kbd className="px-2 py-1 rounded bg-slate-900 border border-slate-800 font-mono text-slate-300 shadow">Shift</kbd>
              <kbd className="px-2 py-1 rounded bg-slate-900 border border-slate-800 font-mono text-slate-300 shadow">P</kbd>
            </div>
          </div>
        );

      // 30. TABLE
      case 'table':
        return (
          <div className="w-full max-w-lg mx-auto p-4">
            <div className="rounded-xl border border-slate-800 overflow-hidden text-xs">
              <table className="w-full text-left font-mono">
                <thead className="bg-slate-900 text-slate-400 border-b border-slate-800">
                  <tr>
                    <th className="p-3">Route</th>
                    <th className="p-3">Method</th>
                    <th className="p-3">Latency</th>
                    <th className="p-3">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 bg-slate-950">
                  <tr>
                    <td className="p-3 text-white">/api/v1/feed</td>
                    <td className="p-3 text-purple-400">GET</td>
                    <td className="p-3 text-slate-400">12ms</td>
                    <td className="p-3 text-emerald-400">200 OK</td>
                  </tr>
                  <tr>
                    <td className="p-3 text-white">/api/v1/auth</td>
                    <td className="p-3 text-pink-400">POST</td>
                    <td className="p-3 text-slate-400">28ms</td>
                    <td className="p-3 text-emerald-400">201 Created</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        );

      // 31. SIDEBAR
      case 'sidebar':
        return (
          <div className="w-full max-w-sm mx-auto p-4">
            <div className="w-56 rounded-2xl bg-slate-950 border border-slate-800 p-3 space-y-4 shadow-xl mx-auto">
              <div className="flex items-center gap-2 px-2">
                <div className="w-6 h-6 rounded-lg bg-purple-600 flex items-center justify-center text-white font-bold text-xs">B</div>
                <span className="text-xs font-bold text-white">Bloom Studio</span>
              </div>
              <div className="space-y-1 text-xs font-mono">
                <div className="px-3 py-1.5 rounded-lg bg-purple-600/20 text-purple-300 border border-purple-500/30 flex items-center gap-2">
                  <Activity className="w-3.5 h-3.5" />
                  <span>Dashboard</span>
                </div>
                <div className="px-3 py-1.5 rounded-lg text-slate-400 hover:bg-slate-900 flex items-center gap-2">
                  <Layers className="w-3.5 h-3.5" />
                  <span>Primitives</span>
                </div>
                <div className="px-3 py-1.5 rounded-lg text-slate-400 hover:bg-slate-900 flex items-center gap-2">
                  <Settings className="w-3.5 h-3.5" />
                  <span>Settings</span>
                </div>
              </div>
            </div>
          </div>
        );

      // 32. CHART
      case 'chart':
        return (
          <div className="w-full max-w-lg mx-auto p-4 space-y-4">
            <div className="p-4 rounded-xl border border-slate-800 bg-slate-950 space-y-3">
              <div className="flex justify-between items-center">
                <div>
                  <div className="text-xs font-bold text-white">Requests / Sec</div>
                  <div className="text-[11px] text-slate-400">Aggregated real-time metrics</div>
                </div>
                <span className="text-xs font-mono text-purple-400 font-bold">14,280 rps</span>
              </div>
              <div className="h-28 flex items-end gap-2 pt-4 px-2">
                {[45, 60, 35, 80, 95, 75, 110, 85, 120, 100, 135, 125].map((h, i) => (
                  <div key={i} className="flex-1 flex flex-col items-center gap-1">
                    <div
                      style={{ height: `${(h / 140) * 100}%` }}
                      className="w-full bg-gradient-to-t from-purple-600 to-pink-500 rounded-t-sm hover:brightness-125 transition-all"
                    />
                  </div>
                ))}
              </div>
            </div>
          </div>
        );

      // 33. COMMAND PALETTE
      case 'command-palette':
        return (
          <div className="w-full max-w-sm mx-auto p-4">
            <div className="rounded-2xl bg-slate-950 border border-slate-800 p-3 space-y-3 shadow-2xl">
              <div className="flex items-center gap-2 px-2 pb-2 border-b border-slate-800 text-xs">
                <Search className="w-3.5 h-3.5 text-slate-400" />
                <input
                  type="text"
                  placeholder="Type a command or search..."
                  className="w-full bg-transparent text-xs text-white placeholder-slate-500 focus:outline-none"
                />
              </div>
              <div className="space-y-1 text-xs">
                <div className="px-2 py-1 text-[10px] font-mono text-slate-500 uppercase">Navigation</div>
                <div className="px-3 py-1.5 rounded-lg bg-purple-600 text-white font-semibold flex justify-between">
                  <span>Go to Documentation</span>
                  <span className="font-mono text-[10px]">↵</span>
                </div>
                <div className="px-3 py-1.5 rounded-lg text-slate-300 hover:bg-slate-900 flex justify-between">
                  <span>Toggle Dark Mode</span>
                  <span className="font-mono text-[10px] text-slate-500">⌘D</span>
                </div>
              </div>
            </div>
          </div>
        );

      // 34. APP SHELL
      case 'app-shell':
        return (
          <div className="w-full max-w-md mx-auto p-3">
            <div className="rounded-2xl border border-slate-800 bg-slate-950 overflow-hidden shadow-2xl">
              <div className="h-8 bg-slate-900 px-3 flex items-center justify-between border-b border-slate-800 text-[11px]">
                <span className="font-bold text-white">Bloom App Shell</span>
                <span className="text-emerald-400 font-mono">Impeller 60fps</span>
              </div>
              <div className="p-4 space-y-2 text-xs text-slate-300">
                <div className="h-16 rounded-xl bg-slate-900 border border-slate-800/80 p-3 flex items-center justify-between">
                  <span>Active Container Scope</span>
                  <span className="text-purple-400 font-mono font-bold">RootContainer</span>
                </div>
              </div>
            </div>
          </div>
        );

      // Fallback
      default:
        return (
          <div className="flex flex-col items-center justify-center p-8 space-y-3">
            <div className="w-10 h-10 rounded-xl bg-purple-500/10 text-purple-400 border border-purple-500/20 flex items-center justify-center mx-auto">
              <Code2 className="w-5 h-5" />
            </div>
            <div className="text-sm font-bold text-white">{component.name}</div>
            <p className="text-xs text-slate-400">{component.description}</p>
          </div>
        );
    }
  };

  return (
    <div className="space-y-6">
      {/* Interactive Workbench Container */}
      <div className="rounded-3xl border border-slate-800 bg-[#090C12] overflow-hidden shadow-2xl">
        {/* Top Header Bar */}
        <div className="px-5 py-3.5 bg-[#0D121D] border-b border-slate-800/80 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex gap-1.5">
              <div className="w-3 h-3 rounded-full bg-red-500/80" />
              <div className="w-3 h-3 rounded-full bg-amber-500/80" />
              <div className="w-3 h-3 rounded-full bg-emerald-500/80" />
            </div>
            <div className="h-4 w-px bg-slate-800 mx-1" />
            <div className="flex items-center gap-2 font-mono text-xs text-slate-300">
              <Terminal className="w-3.5 h-3.5 text-purple-400" />
              <span className="font-bold">bloom-ui</span>
              <span className="text-slate-500">--preview</span>
              <span className="px-2 py-0.5 rounded bg-purple-500/10 text-purple-300 border border-purple-500/20 text-[10px] font-bold">
                {component.name}
              </span>
            </div>
          </div>

          {/* Action Tabs */}
          <div className="flex items-center gap-1 p-1 rounded-xl bg-slate-950 border border-slate-800">
            {[
              { id: 'preview', label: 'Interactive Preview', icon: Sparkles },
              { id: 'code', label: 'Dart Code', icon: Code2 },
              { id: 'install', label: 'CLI Add', icon: Terminal },
              { id: 'props', label: 'Props API', icon: Layers },
            ].map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as any)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                    activeTab === tab.id
                      ? 'bg-purple-600 text-white shadow-sm'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Tab Body */}
        <div className="p-6">
          {activeTab === 'preview' && (
            <div className="min-h-[340px] rounded-2xl bg-black/40 border border-slate-900 flex items-center justify-center p-6 relative">
              {renderInteractivePreview()}
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
              <div className="space-y-2">
                <h4 className="text-sm font-bold text-white flex items-center gap-2">
                  <Terminal className="w-4 h-4 text-purple-400" />
                  CLI (Zero dependencies, copy source into your project)
                </h4>
                <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950 border border-slate-800 font-mono text-xs text-purple-300">
                  <code>{component.cliCommand}</code>
                  <button
                    onClick={() => copyToClipboard(component.cliCommand)}
                    className="p-1 text-slate-400 hover:text-white"
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              <div className="space-y-2">
                <h4 className="text-sm font-bold text-white flex items-center gap-2">
                  <ExternalLink className="w-4 h-4 text-pink-400" />
                  Pub.dev Package
                </h4>
                <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950 border border-slate-800 font-mono text-xs text-pink-300">
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
            <div className="space-y-4">
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
                        <td className="p-3 text-slate-400">{p.defaultVal || '-'}</td>
                        <td className="p-3 text-slate-300 font-sans">{p.description}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
