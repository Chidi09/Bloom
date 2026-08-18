import * as React from 'preact/compat';
import { useState, useEffect } from 'preact/hooks';
import { Play, CheckCircle2, Cpu, ShieldCheck, Terminal, RefreshCw, Zap } from 'lucide-preact';

interface BootStep {
  step: number;
  label: string;
  action: string;
  duration: string;
  status: 'PENDING' | 'RUNNING' | 'COMPLETE';
  log: string;
}

export function BootDIVisualizer() {
  const [isRunning, setIsRunning] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);

  const initialSteps: BootStep[] = [
    {
      step: 1,
      label: '1. Load bloom.yaml',
      action: 'Parsing environment vars, channels & logging levels',
      duration: '4ms',
      status: 'COMPLETE',
      log: '[BOOT] Environment initialized: production (bloom.yaml)',
    },
    {
      step: 2,
      label: '2. Register DI Singletons',
      action: 'Injecting AuthService, ApiClient & StorageService',
      duration: '12ms',
      status: 'COMPLETE',
      log: '[DI] Containers registered: AuthService, ApiClient, StorageService',
    },
    {
      step: 3,
      label: '3. Attach Signals Router',
      action: 'Compiling AST route table and state dependencies',
      duration: '8ms',
      status: 'COMPLETE',
      log: '[ROUTER] 14 typed routes compiled over go_router',
    },
    {
      step: 4,
      label: '4. Execute runApp(MyApp())',
      action: 'Mounting Flutter root widget with Impeller 60fps',
      duration: '16ms',
      status: 'COMPLETE',
      log: '[RUN_APP] Flutter Engine running cleanly on metal graphics thread',
    },
  ];

  const handleRunSequence = () => {
    setIsRunning(true);
    setCurrentStep(1);

    const timer1 = setTimeout(() => setCurrentStep(2), 600);
    const timer2 = setTimeout(() => setCurrentStep(3), 1200);
    const timer3 = setTimeout(() => setCurrentStep(4), 1800);
    const timer4 = setTimeout(() => {
      setCurrentStep(5);
      setIsRunning(false);
    }, 2400);

    return () => {
      clearTimeout(timer1);
      clearTimeout(timer2);
      clearTimeout(timer3);
      clearTimeout(timer4);
    };
  };

  return (
    <div className="p-5 sm:p-8 lg:p-10 rounded-3xl bg-white dark:bg-black backdrop-blur border border-slate-200 dark:border-zinc-800 shadow-2xl max-w-5xl mx-auto space-y-8">
      {/* Header & Interactive Control */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Cpu className="w-5 h-5 text-purple-600 dark:text-purple-400" />
            <h3 className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              Interactive Boot &amp; DI Execution Pipeline
            </h3>
          </div>
          <p className="text-xs text-slate-600 dark:text-slate-400">
            Click run to simulate Bloom’s sub-40ms boot sequence before Flutter mounts <code className="font-mono text-purple-600 dark:text-purple-400 font-bold">runApp()</code>.
          </p>
        </div>

        <button
          onClick={handleRunSequence}
          disabled={isRunning}
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-slate-900 dark:bg-white text-white dark:text-slate-950 font-black text-xs shadow-lg hover:bg-slate-800 dark:hover:bg-slate-200 transition-all active:scale-95 disabled:opacity-50"
        >
          <Play className={`w-3.5 h-3.5 ${isRunning ? 'animate-spin' : ''}`} />
          <span>{isRunning ? 'Executing Boot...' : 'Run Boot Sequence'}</span>
        </button>
      </div>

      {/* Grid: 4 Boot Sequence Nodes */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {initialSteps.map((s) => {
          const isDone = currentStep === 0 || currentStep > s.step;
          const isCurrent = currentStep === s.step;

          return (
            <div
              key={s.step}
              className={`p-5 rounded-2xl border transition-all duration-300 ${
                isCurrent
                  ? 'bg-slate-900 text-white dark:bg-zinc-900 dark:border-white shadow-xl scale-105'
                  : isDone
                  ? 'bg-slate-50 dark:bg-zinc-950 border-slate-200 dark:border-zinc-800 text-slate-900 dark:text-white'
                  : 'bg-slate-50/60 dark:bg-zinc-950/60 border-slate-200 dark:border-zinc-900 opacity-60 text-slate-500'
              }`}
            >
              <div className="flex items-center justify-between mb-3">
                <span className="text-[10px] font-mono font-bold text-slate-500 dark:text-slate-400">
                  {s.duration}
                </span>
                {isDone ? (
                  <CheckCircle2 className="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
                ) : isCurrent ? (
                  <RefreshCw className="w-4 h-4 text-amber-500 dark:text-amber-400 animate-spin" />
                ) : (
                  <div className="w-2.5 h-2.5 rounded-full bg-slate-300 dark:bg-zinc-800" />
                )}
              </div>

              <div className="text-xs font-bold text-slate-900 dark:text-white mb-1">
                {s.label}
              </div>

              <div className="text-[11px] text-slate-600 dark:text-slate-400 leading-snug">
                {s.action}
              </div>
            </div>
          );
        })}
      </div>

      {/* Terminal Log Console Output */}
      <div className="p-5 rounded-2xl bg-slate-950 dark:bg-black border border-slate-800 dark:border-zinc-800 font-mono text-xs space-y-2 text-white shadow-xl">
        <div className="flex items-center justify-between text-[11px] text-slate-400 pb-2 border-b border-slate-800 dark:border-zinc-800">
          <span>Execution Log Console</span>
          <span className="text-emerald-400 font-bold">TOTAL: 40ms</span>
        </div>

        <div className="space-y-1.5 pt-1 text-slate-300">
          {initialSteps.slice(0, currentStep === 0 ? 4 : Math.min(currentStep, 4)).map((s) => (
            <div key={s.step} className="flex items-center gap-2 text-[11px]">
              <span className="text-emerald-400 font-bold">✔</span>
              <span>{s.log}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
