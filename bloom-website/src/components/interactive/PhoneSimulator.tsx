import { useState } from 'preact/hooks';
import {
  Terminal,
  Plus,
  ArrowUpRight,
  TrendingUp,
  Zap,
  Activity,
  Layers,
  Sparkles,
  Bell,
  Code2,
  RefreshCw
} from 'lucide-preact';
import { showToast } from '../common/ToastSystem';
import { highlightDart } from '../../lib/dart-highlighter';

interface PhoneSimulatorProps {
  initialRevenue?: number;
}

export function PhoneSimulator({ initialRevenue = 24500 }: PhoneSimulatorProps) {
  const [revenue, setRevenue] = useState(initialRevenue);
  const [salesCount, setSalesCount] = useState(142);
  const [chartBoost, setChartBoost] = useState(false);
  const [activeTab, setActiveTab] = useState<'revenue' | 'activity'>('revenue');

  const [activities, setActivities] = useState([
    { id: 1, name: 'Enterprise License', amount: '+$1,200', time: 'Just now', type: 'sale' },
    { id: 2, name: 'Pro Subscription', amount: '+$490', time: '2m ago', type: 'sale' },
    { id: 3, name: 'Shorebird OTA Patch v2.5.1', amount: 'Propagated', time: '5m ago', type: 'ota' },
  ]);

  const handleSimulateSale = () => {
    setRevenue((prev) => prev + 1200);
    setSalesCount((prev) => prev + 1);

    // Chart bar pop animation
    setChartBoost(true);
    setTimeout(() => setChartBoost(false), 600);

    // Append to live activity feed
    setActivities((prev) => [
      { id: Date.now(), name: 'Simulated Sale', amount: '+$1,200', time: 'Just now', type: 'sale' },
      ...prev.slice(0, 3),
    ]);

    showToast('Signal State Mutated', 'revenue.value += $1,200 (Rebuilt 1 subscriber leaf)', 'emerald');
  };

  const dartCode = `import 'package:bloom/bloom.dart';
import 'package:bloom_ui/bloom_ui.dart';

@Route('/dashboard')
class DashboardPage extends BloomPage {
  // Zero-boilerplate reactive signals
  final revenue = signal(${revenue});
  final sales = signal(${salesCount});
  late final formatted = computed(() => '\${revenue.value}');

  @override
  Widget build(BuildContext context) {
    return BloomScaffold(
      body: BloomMetricCard(
        title: 'Monthly Recurring Revenue',
        value: formatted.value, // Auto-rebuilds instantly!
      ),
    );
  }
}`;

  return (
    <div className="bg-white/90 dark:bg-[#090C14] backdrop-blur-2xl rounded-3xl overflow-hidden border border-slate-200/60 dark:border-slate-800/80 shadow-2xl relative">
      {/* Top Bar */}
      <div className="px-5 py-3.5 bg-slate-100/70 dark:bg-[#0D121F] border-b border-slate-200/60 dark:border-slate-800/80 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-full bg-red-500/80 shadow-sm" />
          <div className="w-3 h-3 rounded-full bg-amber-500/80 shadow-sm" />
          <div className="w-3 h-3 rounded-full bg-emerald-500/80 shadow-sm" />
          <div className="h-4 w-px bg-slate-700/50 mx-1.5" />
          <div className="flex items-center gap-2 text-xs font-mono font-bold text-slate-300">
            <Terminal className="w-3.5 h-3.5 text-purple-400" />
            <span>bloom_reactive_sandbox</span>
          </div>
        </div>

        <div className="flex items-center gap-2 text-xs text-emerald-400 font-mono font-bold">
          <span className="w-2 h-2 rounded-full bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)] animate-pulse" />
          <span className="hidden sm:inline">Impeller 60fps Reactive</span>
        </div>
      </div>

      {/* Split Pane: Code Editor + Live UI Canvas */}
      <div className="grid grid-cols-1 lg:grid-cols-12 min-h-[480px]">
        {/* Left: Reactive Code Editor */}
        <div className="lg:col-span-6 bg-[#FAFAFA]/60 dark:bg-[#070A10] p-6 font-mono text-[12px] leading-relaxed overflow-x-auto relative select-none border-b lg:border-b-0 lg:border-r border-slate-200 dark:border-slate-800">
          <pre
            className="text-slate-200 leading-relaxed font-mono"
            dangerouslySetInnerHTML={{ __html: highlightDart(dartCode) }}
          />
        </div>

        {/* Right: Live Interactive Canvas Workbench */}
        <div className="lg:col-span-6 bg-slate-100/40 dark:bg-[#0B0F19] p-6 flex flex-col justify-between space-y-6">
          {/* Header Controls */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-purple-600 to-pink-500 flex items-center justify-center text-white font-bold text-xs shadow-md">
                B
              </div>
              <div>
                <h4 className="font-bold text-xs text-slate-900 dark:text-white">Live Flutter Canvas</h4>
                <span className="text-[10px] font-mono text-slate-400">Zero rebuild boilerplate</span>
              </div>
            </div>

            {/* Segmented Screen Tabs */}
            <div className="flex p-0.5 bg-slate-200 dark:bg-slate-900 rounded-xl text-[11px] font-mono font-bold border border-slate-800">
              <button
                onClick={() => setActiveTab('revenue')}
                className={`px-3 py-1 rounded-lg transition-all ${
                  activeTab === 'revenue' ? 'bg-purple-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
                }`}
              >
                Revenue
              </button>
              <button
                onClick={() => setActiveTab('activity')}
                className={`px-3 py-1 rounded-lg transition-all ${
                  activeTab === 'activity' ? 'bg-purple-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
                }`}
              >
                Activity
              </button>
            </div>
          </div>

          {/* Main Dashboard Widget */}
          {activeTab === 'revenue' ? (
            <div className="space-y-4">
              <div className="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-5 rounded-2xl shadow-xl relative overflow-hidden">
                <p className="text-[10px] text-slate-500 dark:text-slate-400 font-bold uppercase tracking-wider mb-1 font-mono">
                  Monthly Recurring Revenue (Signal)
                </p>
                <div className="flex items-end justify-between">
                  <h3 className="text-3xl font-black text-slate-900 dark:text-white font-mono tracking-tight">
                    ${revenue.toLocaleString()}
                  </h3>
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-2 py-0.5 rounded-full">
                    <ArrowUpRight className="w-3.5 h-3.5" />
                    +14.2%
                  </span>
                </div>

                {/* Animated Chart Bars */}
                <div className="flex items-end gap-2 h-20 mt-6 px-1">
                  <div className="w-full bg-purple-900/40 rounded-t-md h-[40%] transition-all" />
                  <div className="w-full bg-purple-800/50 rounded-t-md h-[55%] transition-all" />
                  <div className="w-full bg-purple-700/60 rounded-t-md h-[35%] transition-all" />
                  <div className="w-full bg-purple-600/70 rounded-t-md h-[70%] transition-all" />
                  <div
                    className={`w-full bg-gradient-to-t from-purple-600 to-pink-500 rounded-t-md transition-all duration-300 shadow-[0_0_15px_rgba(168,85,247,0.7)] ${
                      chartBoost ? 'h-[100%]' : 'h-[75%]'
                    }`}
                  />
                </div>
              </div>

              {/* Stats Grid */}
              <div className="grid grid-cols-2 gap-3 text-xs font-mono">
                <div className="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-3.5 rounded-xl">
                  <span className="text-[10px] text-slate-400 uppercase font-bold block mb-0.5">Active Subscribers</span>
                  <span className="text-lg font-black text-slate-900 dark:text-white">{salesCount}</span>
                </div>
                <div className="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-3.5 rounded-xl">
                  <span className="text-[10px] text-slate-400 uppercase font-bold block mb-0.5">Frame Latency</span>
                  <span className="text-lg font-black text-emerald-400">0.8ms</span>
                </div>
              </div>
            </div>
          ) : (
            <div className="space-y-2.5">
              <span className="text-[10px] font-mono font-bold text-slate-400 uppercase tracking-wider block mb-1">
                Real-Time State Log
              </span>
              {activities.map((act) => (
                <div
                  key={act.id}
                  className="bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 p-3 rounded-xl flex items-center justify-between text-xs animate-in fade-in"
                >
                  <div className="flex items-center gap-2.5">
                    <div className={`w-6 h-6 rounded-full flex items-center justify-center text-white ${act.type === 'sale' ? 'bg-emerald-500' : 'bg-purple-600'}`}>
                      {act.type === 'sale' ? <TrendingUp className="w-3.5 h-3.5" /> : <Zap className="w-3.5 h-3.5" />}
                    </div>
                    <div>
                      <p className="font-bold text-slate-900 dark:text-white text-xs">{act.name}</p>
                      <p className="text-[10px] text-slate-400 font-mono">{act.time}</p>
                    </div>
                  </div>
                  <span className="font-mono font-bold text-emerald-400 text-xs">{act.amount}</span>
                </div>
              ))}
            </div>
          )}

          {/* Simulate Action Button */}
          <button
            onClick={handleSimulateSale}
            className="w-full py-3 bg-purple-600 hover:bg-purple-500 active:scale-[0.98] text-white rounded-xl text-xs font-bold shadow-lg transition flex items-center justify-center gap-2"
          >
            <Plus className="w-4 h-4" />
            <span>Mutate Signal (+ $1,200)</span>
          </button>
        </div>
      </div>
    </div>
  );
}
