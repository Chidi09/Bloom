import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { Terminal, Copy, Check, Play, Sparkles, Cpu, Layers } from 'lucide-preact';

interface Command {
  id: string;
  cmd: string;
  shortDesc: string;
  description: string;
  outputLines: string[];
}

const commands: Command[] = [
  {
    id: 'create',
    cmd: '$ bloom create my_app',
    shortDesc: 'Scaffold Project Structure',
    description: 'Scaffolds opinionated project structure, bloom.yaml, boot sequence, and initial file-system routes.',
    outputLines: [
      '✔ Creating Bloom app in ./my_app',
      '✔ Initializing bloom.yaml configuration',
      '✔ Generating route table (index.dart, _layout.dart)',
      '✔ Setting up thin DI container & signals state',
      '🚀 Done in 240ms! Run "cd my_app && bloom dev" to start.',
    ],
  },
  {
    id: 'dev',
    cmd: '$ bloom dev',
    shortDesc: 'Expo-Style Dev Orchestration',
    description: 'Expo-style dev orchestration with wireless pairing, device selection, hot reload, and diagnostics.',
    outputLines: [
      '✔ Target: iPhone 16 Pro Simulator & Connected Pixel 9',
      '✔ Hot reload active on port 4321',
      '✔ Signals dependency graph initialized (60fps)',
      '✔ Watching /lib/app/routes for AST changes...',
      '⚡ Ready! Press [r] to hot reload, [q] to quit.',
    ],
  },
  {
    id: 'doctor',
    cmd: '$ bloom doctor',
    shortDesc: 'System Diagnostics',
    description: 'Diagnostics check for Flutter, Dart, Android SDK, Xcode, CocoaPods, and native configurations.',
    outputLines: [
      '✔ [✓] Flutter 3.29.0 • channel stable',
      '✔ [✓] Dart 3.7.0',
      '✔ [✓] Android toolchain - develop for Android devices (SDK 34.0.0)',
      '✔ [✓] Xcode 16.2 - develop for iOS (iOS SDK 18.2)',
      '✔ [✓] Shorebird OTA CLI v1.2.0 active',
      '🎉 All systems operational! Zero issues found.',
    ],
  },
  {
    id: 'generate',
    cmd: '$ bloom generate',
    shortDesc: 'Deterministic AST Code Gen',
    description: 'Generates pages, routes, controllers, query models, and service abstractions deterministically.',
    outputLines: [
      '✔ Scanning /lib/app/routes (14 files found)',
      '✔ Parsing controller signal dependencies',
      '✔ Generated lib/bloom.g.dart (1,240 lines)',
      '✔ Route table re-compiled in 34ms',
      '✨ Code generation complete.',
    ],
  },
];

export function CLIToolingExplorer() {
  const [activeCmdId, setActiveCmdId] = useState<string>('create');
  const [copied, setCopied] = useState<boolean>(false);

  const activeCmd = commands.find((c) => c.id === activeCmdId) || commands[0];

  const handleCopy = () => {
    navigator.clipboard?.writeText(activeCmd.cmd);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* Command Selector Tabs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {commands.map((c) => {
          const isActive = c.id === activeCmdId;

          return (
            <button
              key={c.id}
              onClick={() => setActiveCmdId(c.id)}
              className={`p-4 rounded-2xl text-left transition-all duration-200 border ${
                isActive
                  ? 'bg-white text-slate-950 border-white shadow-xl font-black scale-[1.02]'
                  : 'bg-slate-950/90 dark:bg-black text-slate-300 hover:text-white hover:border-zinc-700 border-slate-800 dark:border-zinc-800'
              }`}
            >
              <div className="text-[11px] font-mono font-bold tracking-tight mb-1 text-purple-400">
                {c.cmd.split(' ')[0]} {c.cmd.split(' ')[1]}
              </div>
              <div className="text-xs font-black truncate">
                {c.shortDesc}
              </div>
            </button>
          );
        })}
      </div>

      {/* Terminal Sandbox Display */}
      <div className="rounded-3xl overflow-hidden bg-black border border-zinc-800 shadow-2xl font-mono text-xs">
        {/* Terminal Header */}
        <div className="flex items-center justify-between px-5 py-4 bg-zinc-900/90 border-b border-zinc-800">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-rose-500/80" />
            <div className="w-3 h-3 rounded-full bg-amber-500/80" />
            <div className="w-3 h-3 rounded-full bg-emerald-500/80" />
            <span className="ml-2 text-xs font-bold text-slate-400">bloom-cli — zsh</span>
          </div>

          <button
            onClick={handleCopy}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[11px] font-bold transition-colors border border-slate-700"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5 text-slate-400" />}
            <span>{copied ? 'Copied!' : 'Copy'}</span>
          </button>
        </div>

        {/* Terminal Content Body */}
        <div className="p-6 sm:p-8 space-y-4 text-slate-200 leading-relaxed">
          <div className="flex items-center gap-2 text-purple-400 font-bold text-sm">
            <Terminal className="w-4 h-4 text-teal-400" />
            <span>{activeCmd.cmd}</span>
          </div>

          <div className="p-3 rounded-xl bg-slate-900/80 text-slate-400 text-xs border border-slate-800">
            {activeCmd.description}
          </div>

          <div className="space-y-2 pt-2 text-xs font-mono">
            {activeCmd.outputLines.map((line, idx) => (
              <div key={idx} className="flex items-start gap-2 text-emerald-400">
                <span className="text-slate-500 select-none">&gt;</span>
                <span className={line.startsWith('🚀') || line.startsWith('✨') ? 'text-amber-300 font-bold' : 'text-slate-300'}>
                  {line}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
