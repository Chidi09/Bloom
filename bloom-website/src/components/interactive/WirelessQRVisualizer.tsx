import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { Wifi, QrCode, Smartphone, RefreshCw, CheckCircle2, ArrowRight } from 'lucide-preact';

export function WirelessQRVisualizer() {
  const [activeTab, setActiveTab] = useState<'wireless' | 'qr'>('wireless');
  const [isConnected, setIsConnected] = useState<boolean>(true);
  const [deviceCount, setDeviceCount] = useState<number>(2);

  const handlePair = () => {
    setIsConnected(false);
    setTimeout(() => {
      setIsConnected(true);
      setDeviceCount(2);
    }, 600);
  };

  return (
    <div className="p-8 sm:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header Tabs */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Wifi className="w-5 h-5 text-blue-600 dark:text-blue-400" />
            <h3 className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Wireless Pairing &amp; Instant QR Preview Engine
            </h3>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-400">
            Eliminate USB cable tethering. Pair iOS &amp; Android devices over Wi-Fi with instant QR scanning.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setActiveTab('wireless')}
            className={`px-4 py-2 rounded-xl text-xs font-mono font-bold transition-all border ${
              activeTab === 'wireless'
                ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-md'
                : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            $ bloom dev --wireless
          </button>
          <button
            onClick={() => setActiveTab('qr')}
            className={`px-4 py-2 rounded-xl text-xs font-mono font-bold transition-all border ${
              activeTab === 'qr'
                ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-950 border-slate-900 dark:border-white shadow-md'
                : 'bg-slate-100 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            $ bloom build --dev
          </button>
        </div>
      </div>

      {/* Main Content View */}
      {activeTab === 'wireless' ? (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
          {/* Left: Connected Devices List */}
          <div className="lg:col-span-6 p-6 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 space-y-4">
            <div className="flex items-center justify-between text-xs font-mono font-bold text-slate-500 dark:text-slate-400 pb-2 border-b border-slate-200 dark:border-zinc-800">
              <span>Discovered Network Targets</span>
              <span className="text-emerald-600 dark:text-emerald-400">PORT: 5555</span>
            </div>

            <div className="space-y-3">
              <div className="p-3.5 rounded-xl bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 flex items-center justify-between shadow-sm">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-blue-500/10 text-blue-600 dark:text-blue-400">
                    <Smartphone className="w-4 h-4" />
                  </div>
                  <div>
                    <h4 className="text-xs font-bold text-slate-900 dark:text-white">iPhone 16 Pro (Wireless)</h4>
                    <span className="text-[10px] font-mono text-slate-500 dark:text-slate-400">192.168.1.142 · iOS 18.2</span>
                  </div>
                </div>
                <span className="flex items-center gap-1 text-[11px] text-emerald-600 dark:text-emerald-400 font-mono font-bold">
                  <CheckCircle2 className="w-3.5 h-3.5" /> Paired
                </span>
              </div>

              <div className="p-3.5 rounded-xl bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 flex items-center justify-between shadow-sm">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-teal-500/10 text-teal-600 dark:text-teal-400">
                    <Smartphone className="w-4 h-4" />
                  </div>
                  <div>
                    <h4 className="text-xs font-bold text-slate-900 dark:text-white">Pixel 9 Pro (ADB Wi-Fi)</h4>
                    <span className="text-[10px] font-mono text-slate-500 dark:text-slate-400">192.168.1.188 · Android 15</span>
                  </div>
                </div>
                <span className="flex items-center gap-1 text-[11px] text-emerald-600 dark:text-emerald-400 font-mono font-bold">
                  <CheckCircle2 className="w-3.5 h-3.5" /> Paired
                </span>
              </div>
            </div>

            <button
              onClick={handlePair}
              className="w-full py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-950 font-mono text-xs font-bold shadow hover:bg-slate-800 dark:hover:bg-slate-200 transition"
            >
              Scan Local Subnet (mDNS)
            </button>
          </div>

          {/* Right: Real-Time Stream Status */}
          <div className="lg:col-span-6 p-6 rounded-2xl bg-slate-950 dark:bg-black border border-slate-800 dark:border-zinc-800 font-mono text-xs text-slate-300 flex flex-col justify-between shadow-xl">
            <div className="space-y-3">
              <div className="flex items-center justify-between text-[11px] text-slate-400 pb-2 border-b border-slate-800 dark:border-zinc-800">
                <span>Hot Reload Stream Pipeline</span>
                <span className="text-emerald-400 font-bold">ZERO_CABLE</span>
              </div>
              <p className="text-[11px] leading-relaxed text-slate-300">
                [+] Impeller shader cache synced across physical device cluster.<br />
                [+] Hot reload delta broadcast latency: <strong>140ms</strong>.<br />
                [+] State preserved via reactive signals registry.
              </p>
            </div>
            <div className="p-3 bg-slate-900 dark:bg-zinc-950 rounded-xl border border-slate-800 dark:border-zinc-800 text-[11px] text-slate-400">
              ⚡️ Physical devices hot reload in lockstep simultaneously on file save.
            </div>
          </div>
        </div>
      ) : (
        /* QR Code Scanner Workflow */
        <div className="p-8 rounded-2xl bg-slate-50 dark:bg-zinc-950 border border-slate-200 dark:border-zinc-800 flex flex-col sm:flex-row items-center justify-center gap-8">
          <div className="p-4 bg-white rounded-2xl border-2 border-slate-300 shadow-xl">
            <QrCode className="w-32 h-32 text-slate-950" />
          </div>
          <div className="space-y-2 max-w-md text-center sm:text-left">
            <h4 className="text-base font-bold text-slate-900 dark:text-white">Scan with Camera or Bloom App</h4>
            <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              Instant standalone debug runner installation on iOS &amp; Android without provisioning profile friction or TestFlight waiting periods.
            </p>
            <div className="pt-2 font-mono text-[11px] text-purple-600 dark:text-purple-400 font-bold">
              https://preview.bloom.dev/app/dpl_89f2a01
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
