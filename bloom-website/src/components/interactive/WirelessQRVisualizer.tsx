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
    <div className="p-8 sm:p-10 rounded-3xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header Tabs */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800 dark:border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Wifi className="w-5 h-5 text-blue-400" />
            <h3 className="text-xl font-bold text-white tracking-tight">
              Wireless Pairing &amp; Instant QR Preview Engine
            </h3>
          </div>
          <p className="text-xs text-slate-400">
            Eliminate USB cable tethering. Pair iOS &amp; Android devices over Wi-Fi with instant QR scanning.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setActiveTab('wireless')}
            className={`px-4 py-2 rounded-xl text-xs font-mono font-bold transition-all border ${
              activeTab === 'wireless'
                ? 'bg-white text-slate-950 border-white shadow-md'
                : 'bg-zinc-900 text-slate-400 border-zinc-800 hover:text-white'
            }`}
          >
            $ bloom dev --wireless
          </button>
          <button
            onClick={() => setActiveTab('qr')}
            className={`px-4 py-2 rounded-xl text-xs font-mono font-bold transition-all border ${
              activeTab === 'qr'
                ? 'bg-white text-slate-950 border-white shadow-md'
                : 'bg-zinc-900 text-slate-400 border-zinc-800 hover:text-white'
            }`}
          >
            $ bloom build --dev
          </button>
        </div>
      </div>

      {/* Main Content View */}
      {activeTab === 'wireless' ? (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
          {/* Terminal Console View */}
          <div className="lg:col-span-7 p-6 rounded-2xl bg-black border border-zinc-800 font-mono text-xs space-y-4">
            <div className="flex items-center justify-between text-[11px] text-slate-400 pb-2 border-b border-zinc-800">
              <span>Wireless Dev Server Log</span>
              <button
                onClick={handlePair}
                className="text-blue-400 font-bold hover:underline flex items-center gap-1"
              >
                <RefreshCw className="w-3 h-3" /> Re-scan Wi-Fi
              </button>
            </div>

            <div className="space-y-2 text-slate-300 leading-relaxed text-[11px]">
              <div className="flex items-center gap-2 text-emerald-400 font-bold">
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>Wi-Fi Network: Bloom-Studio-5G (192.168.1.0/24)</span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-900 border border-zinc-800 space-y-1.5">
                <div className="flex items-center justify-between text-white font-bold">
                  <span>📱 iPhone 16 Pro (iOS 18.2)</span>
                  <span className="text-emerald-400 text-[10px]">PAIRED (192.168.1.42:5555)</span>
                </div>
                <div className="flex items-center justify-between text-white font-bold">
                  <span>🤖 Pixel 9 Pro (Android 15)</span>
                  <span className="text-emerald-400 text-[10px]">PAIRED (192.168.1.88:5555)</span>
                </div>
              </div>
              <p className="text-slate-400">
                [HMR] Hot reload listening on port 4321. State preserved across wireless reloads.
              </p>
            </div>
          </div>

          {/* Interactive Mobile Device Status Card */}
          <div className="lg:col-span-5 p-6 rounded-2xl bg-black border border-zinc-800 flex flex-col justify-between">
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-xs font-mono font-bold text-slate-400">Wi-Fi Device Mesh</span>
                <span className="px-2.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 font-mono text-[10px] font-bold border border-emerald-500/30">
                  2 DEVICES ACTIVE
                </span>
              </div>

              <div className="space-y-2">
                <div className="p-3 rounded-xl bg-zinc-900 border border-zinc-800 flex items-center justify-between text-xs">
                  <span className="text-white font-bold">Wireless Latency</span>
                  <span className="text-emerald-400 font-mono font-bold">1.2ms</span>
                </div>
                <div className="p-3 rounded-xl bg-zinc-900 border border-zinc-800 flex items-center justify-between text-xs">
                  <span className="text-white font-bold">State Preservation</span>
                  <span className="text-teal-400 font-mono font-bold">ACTIVE</span>
                </div>
              </div>
            </div>

            <p className="text-[11px] text-slate-400 mt-4">
              Zero USB tethering required. Changes hot reload simultaneously to all paired test devices over Wi-Fi.
            </p>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          {/* QR Terminal Code Display */}
          <div className="lg:col-span-6 p-6 rounded-2xl bg-black border border-zinc-800 font-mono text-xs space-y-4 text-center">
            <div className="text-xs font-bold text-white mb-2">
              Terminal QR Code Generator ($ bloom build --dev)
            </div>

            {/* ASCII QR Code Art */}
            <div className="inline-block p-4 rounded-xl bg-white text-black font-mono text-[10px] leading-none tracking-tighter">
              █████████████████████████████<br />
              ██  ████████  ██  ████████  ██<br />
              ██  ██    ██  ██  ██    ██  ██<br />
              ██  ████████  ██  ████████  ██<br />
              █████████████████████████████<br />
              ██  ██  ██  ██████  ██  ██  ██<br />
              ██████  ████  ██  ████  ██████<br />
              ██  ████████  ██  ████████  ██<br />
              █████████████████████████████
            </div>

            <p className="text-[11px] text-slate-400 pt-2">
              Scan with device camera to side-load development build directly.
            </p>
          </div>

          {/* Instant Artifact Details */}
          <div className="lg:col-span-6 space-y-4">
            <div className="p-5 rounded-2xl bg-black border border-zinc-800 space-y-3 font-mono text-xs">
              <div className="flex items-center justify-between">
                <span className="text-slate-400">Development Artifact</span>
                <span className="text-purple-400 font-bold">IPA / APK</span>
              </div>
              <div className="text-sm font-bold text-white">bloom-dev-v2.4.1.apk</div>
              <div className="text-[11px] text-slate-400">Build Time: 1.4s · Impeller 60FPS Enabled</div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
