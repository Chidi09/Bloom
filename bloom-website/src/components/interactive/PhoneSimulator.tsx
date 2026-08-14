import { useState } from 'preact/hooks';
import {
  Smartphone,
  Check,
  Plus,
  ArrowUpRight,
  RefreshCw,
  Zap,
  Wifi,
  Battery,
  Signal,
  CreditCard,
  Bell,
  TrendingUp,
  Activity,
  Layers,
  Sparkles,
  Search
} from 'lucide-preact';
import { showToast } from '../common/ToastSystem';

interface PhoneSimulatorProps {
  initialRevenue?: number;
}

export function PhoneSimulator({ initialRevenue = 24500 }: PhoneSimulatorProps) {
  const [revenue, setRevenue] = useState(initialRevenue);
  const [salesCount, setSalesCount] = useState(142);
  const [isExpanding, setIsExpanding] = useState(false);
  const [isFlashing, setIsFlashing] = useState(false);
  const [chartBoost, setChartBoost] = useState(false);
  const [activeTab, setActiveTab] = useState<'revenue' | 'activity' | 'code'>('revenue');

  const [activities, setActivities] = useState([
    { id: 1, name: 'Enterprise Sub', amount: '+$1,200', time: 'Just now', type: 'sale' },
    { id: 2, name: 'Pro Annual', amount: '+$490', time: '2m ago', type: 'sale' },
    { id: 3, name: 'OTA Patch v2.5.1', amount: 'Propagated', time: '5m ago', type: 'ota' },
  ]);

  const handleSimulateSale = () => {
    setRevenue((prev) => prev + 1200);
    setSalesCount((prev) => prev + 1);

    // Flash phone screen
    setIsFlashing(true);
    setTimeout(() => setIsFlashing(false), 200);

    // Dynamic island notification pop
    setIsExpanding(true);
    setTimeout(() => setIsExpanding(false), 2600);

    // Chart bar pop
    setChartBoost(true);
    setTimeout(() => setChartBoost(false), 500);

    // Append to live feed
    setActivities((prev) => [
      { id: Date.now(), name: 'Simulated Sale', amount: '+$1,200', time: 'Just now', type: 'sale' },
      ...prev.slice(0, 4),
    ]);

    showToast('Sale Processed', 'Signal state mutated: revenue += $1,200', 'emerald');
  };

  return (
    <div className="bg-white/90 dark:bg-[#0B0F19]/95 backdrop-blur-2xl rounded-3xl overflow-hidden border border-slate-200/60 dark:border-slate-800/80 shadow-2xl relative">
      {/* Window Top Bar */}
      <div className="px-5 py-3.5 bg-slate-100/60 dark:bg-[#05080F]/70 border-b border-slate-200/60 dark:border-slate-800/80 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-full bg-[#ff5f56] shadow-sm" />
          <div className="w-3 h-3 rounded-full bg-[#ffbd2e] shadow-sm" />
          <div className="w-3 h-3 rounded-full bg-[#27c93f] shadow-sm" />
        </div>
        <div className="flex items-center gap-2 text-xs font-mono font-medium text-slate-600 dark:text-slate-400">
          <Smartphone className="w-4 h-4 text-purple-500" strokeWidth={1.75} />
          <span>bloom_app / lib / routes / dashboard.dart</span>
        </div>
        <div className="flex items-center gap-2 text-xs text-emerald-500 font-mono font-bold">
          <span className="w-2 h-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.8)] animate-pulse" />
          <span className="hidden sm:inline">Bloom Engine Reactive</span>
        </div>
      </div>

      {/* Split Pane: Code Editor + Realistic iPhone Chassis */}
      <div className="grid grid-cols-1 lg:grid-cols-12 min-h-[520px]">
        {/* Left: Interactive Code Pane - hidden on mobile */}
        <div className="hidden lg:block lg:col-span-7 bg-[#FAFAFA]/60 dark:bg-[#0D1117]/60 p-6 lg:p-8 font-mono text-[13px] leading-relaxed overflow-x-auto relative select-none">
          <div className="absolute left-0 top-0 bottom-0 w-12 bg-slate-100/60 dark:bg-[#090C10]/60 border-r border-slate-200/50 dark:border-slate-800/80 flex flex-col items-center py-8 text-slate-400 dark:text-slate-600 text-[11px] space-y-[6px]">
            <span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6</span><span>7</span><span>8</span><span>9</span><span>10</span><span>11</span><span>12</span><span>13</span><span>14</span><span>15</span><span>16</span><span>17</span>
          </div>

          <pre className="pl-8 text-slate-800 dark:text-slate-300">
<span className="text-purple-600 dark:text-purple-400 font-semibold">import</span> <span className="text-teal-600 dark:text-teal-400">'package:bloom/bloom.dart'</span>;{'\n'}
<span className="text-purple-600 dark:text-purple-400 font-semibold">import</span> <span className="text-teal-600 dark:text-teal-400">'package:bloom_ui/bloom_ui.dart'</span>;{'\n\n'}
<span className="text-amber-600 dark:text-amber-400">@Route</span>(<span className="text-teal-600 dark:text-teal-400">'/dashboard'</span>){'\n'}
<span className="text-purple-600 dark:text-purple-400 font-semibold">class</span> <span className="text-pink-600 dark:text-pink-400 font-bold">DashboardPage</span> <span className="text-purple-600 dark:text-purple-400 font-semibold">extends</span> BloomPage {'{'}{'\n'}
{'  '}<span className="text-slate-400 italic">// ⚡️ Zero-boilerplate reactive signal</span>{'\n'}
{'  '}<span className="text-purple-600 dark:text-purple-400 font-semibold">final</span> revenue = signal(<span className="text-orange-600 dark:text-orange-400 font-bold">{revenue}</span>);{'\n'}
{'  '}<span className="text-purple-600 dark:text-purple-400 font-semibold">final</span> sales = signal(<span className="text-orange-600 dark:text-orange-400 font-bold">{salesCount}</span>);{'\n'}
{'  '}<span className="text-purple-600 dark:text-purple-400 font-semibold">late final</span> formatted = computed(() =&gt; <span className="text-teal-600 dark:text-teal-400">'\${'{'}revenue.value{'}'}'</span>);{'\n\n'}
{'  '}<span className="text-amber-600 dark:text-amber-400">@override</span>{'\n'}
{'  '}Widget <span className="text-blue-600 dark:text-blue-400">build</span>(BuildContext context) {'{'}{'\n'}
{'    '}<span className="text-purple-600 dark:text-purple-400 font-semibold">return</span> BloomScaffold({'\n'}
{'      '}body: BloomMetricCard({'\n'}
{'        '}title: <span className="text-teal-600 dark:text-teal-400">'Monthly Recurring Revenue'</span>,{'\n'}
{'        '}value: formatted.value, <span className="text-slate-400 italic">// Auto-rebuilds instantly!</span>{'\n'}
{'      '}),{'\n'}
{'    '});{'\n'}
{'  '}{'}'}{'\n'}
{'}'}
          </pre>
        </div>

        {/* Right: Highly Detailed iPhone Chassis */}
        <div className="col-span-1 lg:col-span-5 bg-slate-200/50 dark:bg-[#161B22]/50 border-t-0 lg:border-t-0 lg:border-l border-slate-200/60 dark:border-slate-800/80 p-6 lg:p-8 flex flex-col items-center justify-center relative shadow-inner min-h-[500px] lg:min-h-0">
          
          {/* Outer Titanium Phone Shell */}
          <div className="w-full max-w-[290px] bg-slate-900 dark:bg-black border-[7px] border-slate-300 dark:border-[#2A303C] rounded-[48px] shadow-[0_25px_60px_-15px_rgba(0,0,0,0.5)] relative overflow-hidden transition-transform duration-300">
            
            {/* Side Hardware Buttons */}
            <div className="absolute left-[-11px] top-24 w-[4px] h-8 bg-slate-400 dark:bg-slate-700 rounded-l-sm" />
            <div className="absolute left-[-11px] top-36 w-[4px] h-12 bg-slate-400 dark:bg-slate-700 rounded-l-sm" />
            <div className="absolute right-[-11px] top-28 w-[4px] h-16 bg-slate-400 dark:bg-slate-700 rounded-r-sm" />

            {/* Dynamic Island Notch */}
            <div
              className={`absolute top-2.5 left-1/2 -translate-x-1/2 bg-black rounded-full flex items-center justify-center text-white overflow-hidden transition-all duration-400 z-30 ${
                isExpanding ? 'w-[230px] h-[50px] bg-slate-900 shadow-2xl border border-slate-800' : 'w-[96px] h-[28px]'
              }`}
            >
              {isExpanding ? (
                <div className="flex items-center justify-between w-full px-3.5 text-xs font-sans animate-in fade-in">
                  <div className="flex items-center gap-2">
                    <div className="w-5 h-5 rounded-full bg-emerald-500 flex items-center justify-center">
                      <Check className="w-3 h-3 text-white" strokeWidth={3} />
                    </div>
                    <div>
                      <p className="font-bold text-white text-[11px] leading-none">Sale Processed</p>
                      <p className="text-[9px] text-slate-400">Bloom Signal Updated</p>
                    </div>
                  </div>
                  <span className="text-emerald-400 font-mono font-black text-xs">+$1,200</span>
                </div>
              ) : (
                <div className="flex items-center justify-between w-full px-2">
                  <div className="w-3.5 h-3.5 rounded-full bg-[#111] border border-slate-800" />
                  <div className="w-2.5 h-2.5 rounded-full bg-[#0a0a0a]" />
                </div>
              )}
            </div>

            {/* Glass Screen Frame */}
            <div className="h-[520px] bg-slate-50 dark:bg-[#0A0D14] flex flex-col pt-10 px-4 relative select-none">
              
              {/* Screen Reflection Glare */}
              <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-white/5 to-white/10 pointer-events-none z-20" />

              {/* Status Bar */}
              <div className="flex items-center justify-between text-[11px] font-semibold text-slate-800 dark:text-slate-200 px-2 pt-1 mb-4 z-10">
                <span>9:41</span>
                <div className="flex items-center gap-1.5 text-slate-600 dark:text-slate-400">
                  <Signal className="w-3 h-3" strokeWidth={2} />
                  <Wifi className="w-3 h-3" strokeWidth={2} />
                  <Battery className="w-3.5 h-3.5" strokeWidth={2} />
                </div>
              </div>

              {/* Screen Flash Overlay on Mutation */}
              <div
                className={`absolute inset-0 bg-purple-500/20 backdrop-blur-sm z-40 transition-opacity duration-200 pointer-events-none ${
                  isFlashing ? 'opacity-100' : 'opacity-0'
                }`}
              />

              {/* App Header */}
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white font-bold text-xs shadow-md">
                    B
                  </div>
                  <div>
                    <h4 className="font-black text-xs text-slate-900 dark:text-white leading-none">Bloom OS</h4>
                    <span className="text-[9px] font-mono text-slate-500 dark:text-slate-400">v2.5 Production</span>
                  </div>
                </div>
                <button className="p-1.5 rounded-full bg-slate-200/60 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
                  <Bell className="w-3.5 h-3.5" strokeWidth={2} />
                </button>
              </div>

              {/* Segmented Screen Tabs */}
              <div className="flex p-0.5 bg-slate-200/60 dark:bg-slate-900/80 rounded-xl mb-4 text-[10px] font-mono font-bold">
                <button
                  onClick={() => setActiveTab('revenue')}
                  className={`flex-1 py-1 rounded-lg transition-all ${
                    activeTab === 'revenue' ? 'bg-white dark:bg-slate-800 text-slate-900 dark:text-white shadow-sm' : 'text-slate-500'
                  }`}
                >
                  Revenue
                </button>
                <button
                  onClick={() => setActiveTab('activity')}
                  className={`flex-1 py-1 rounded-lg transition-all ${
                    activeTab === 'activity' ? 'bg-white dark:bg-slate-800 text-slate-900 dark:text-white shadow-sm' : 'text-slate-500'
                  }`}
                >
                  Activity
                </button>
              </div>

              {/* Main Content Area */}
              {activeTab === 'revenue' ? (
                <div className="space-y-4">
                  {/* Revenue Card */}
                  <div className="bg-white dark:bg-[#161B22] border border-slate-200 dark:border-slate-800 p-4 rounded-2xl shadow-sm relative overflow-hidden">
                    <p className="text-[10px] text-slate-500 dark:text-slate-400 font-bold uppercase tracking-wider mb-1 font-mono">
                      Monthly Recurring Revenue
                    </p>
                    <div className="flex items-end justify-between">
                      <h3 className="text-2xl font-black text-slate-900 dark:text-white font-mono tracking-tight">
                        ${revenue.toLocaleString()}
                      </h3>
                      <span className="inline-flex items-center gap-0.5 text-[10px] font-bold text-emerald-600 bg-emerald-50 dark:text-emerald-400 dark:bg-emerald-500/10 px-1.5 py-0.5 rounded">
                        <ArrowUpRight className="w-3 h-3" strokeWidth={2.5} />
                        +14%
                      </span>
                    </div>

                    {/* Chart Bars */}
                    <div className="flex items-end gap-1.5 h-14 mt-4">
                      <div className="w-full bg-purple-200 dark:bg-purple-900/40 rounded-t-md h-[40%] transition-all" />
                      <div className="w-full bg-purple-300 dark:bg-purple-800/50 rounded-t-md h-[55%] transition-all" />
                      <div className="w-full bg-purple-400 dark:bg-purple-700/60 rounded-t-md h-[35%] transition-all" />
                      <div className="w-full bg-purple-500 dark:bg-purple-600/70 rounded-t-md h-[70%] transition-all" />
                      <div
                        className={`w-full bg-purple-600 dark:bg-purple-500 rounded-t-md transition-all duration-300 shadow-[0_0_12px_rgba(139,92,246,0.6)] ${
                          chartBoost ? 'h-[100%]' : 'h-[65%]'
                        }`}
                      />
                    </div>
                  </div>

                  {/* Secondary Stat Card */}
                  <div className="grid grid-cols-2 gap-2 text-xs font-mono">
                    <div className="bg-white dark:bg-[#161B22] border border-slate-200 dark:border-slate-800 p-3 rounded-xl">
                      <span className="text-[9px] text-slate-400 uppercase font-bold block">Active Sales</span>
                      <span className="text-base font-black text-slate-900 dark:text-white">{salesCount}</span>
                    </div>
                    <div className="bg-white dark:bg-[#161B22] border border-slate-200 dark:border-slate-800 p-3 rounded-xl">
                      <span className="text-[9px] text-slate-400 uppercase font-bold block">App Latency</span>
                      <span className="text-base font-black text-emerald-500">1.2ms</span>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="space-y-2">
                  <span className="text-[10px] font-mono font-bold text-slate-400 uppercase tracking-wider block mb-1">
                    Live Stream Feed
                  </span>
                  {activities.map((act) => (
                    <div
                      key={act.id}
                      className="bg-white dark:bg-[#161B22] border border-slate-200 dark:border-slate-800 p-2.5 rounded-xl flex items-center justify-between text-xs animate-in fade-in"
                    >
                      <div className="flex items-center gap-2">
                        <div className={`w-6 h-6 rounded-full flex items-center justify-center text-white ${act.type === 'sale' ? 'bg-emerald-500' : 'bg-blue-500'}`}>
                          {act.type === 'sale' ? <TrendingUp className="w-3 h-3" /> : <Zap className="w-3 h-3" />}
                        </div>
                        <div>
                          <p className="font-bold text-slate-900 dark:text-white text-[11px]">{act.name}</p>
                          <p className="text-[9px] text-slate-400 font-mono">{act.time}</p>
                        </div>
                      </div>
                      <span className="font-mono font-bold text-emerald-500 text-xs">{act.amount}</span>
                    </div>
                  ))}
                </div>
              )}

              {/* Primary Action Button */}
              <button
                onClick={handleSimulateSale}
                className="w-full py-3 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-xs font-bold shadow-lg transition-transform active:scale-95 flex items-center justify-center gap-2 mt-auto mb-4"
              >
                <Plus className="w-4 h-4" strokeWidth={2.5} />
                <span>Simulate Sale (+ $1,200)</span>
              </button>
            </div>

            {/* iPhone Bottom Home Bar */}
            <div className="absolute bottom-2 left-1/2 -translate-x-1/2 w-24 h-1 bg-slate-400 dark:bg-slate-600 rounded-full" />
          </div>

        </div>
      </div>
    </div>
  );
}
