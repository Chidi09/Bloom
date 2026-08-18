import { useEffect, useState } from 'preact/hooks';

interface ScrollProgressRailProps {
  currentRoute?: 'hub' | 'build' | 'ship' | 'bloom';
}

export function ScrollProgressRail({ currentRoute = 'hub' }: ScrollProgressRailProps) {
  const [scrollPercent, setScrollPercent] = useState(0);
  const [activeStep, setActiveStep] = useState<'build' | 'ship' | 'bloom'>('build');

  useEffect(() => {
    const handleScroll = () => {
      const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
      if (totalHeight <= 0) return;
      const currentProgress = (window.scrollY / totalHeight) * 100;
      setScrollPercent(Math.min(100, Math.max(0, currentProgress)));

      if (currentProgress > 66) {
        setActiveStep('bloom');
      } else if (currentProgress > 33) {
        setActiveStep('ship');
      } else {
        setActiveStep('build');
      }
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <aside
      className="hidden xl:flex fixed left-6 top-1/2 -translate-y-1/2 z-40 flex-col items-center gap-6 pointer-events-none select-none"
      aria-label="Story Progress Rail"
    >
      <div className="flex flex-col items-center gap-2">
        <span
          className={`text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 ${
            activeStep === 'build' ? 'text-purple-500 scale-110' : 'text-slate-400 dark:text-slate-600'
          }`}
        >
          BUILD
        </span>
        <span
          className={`text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 ${
            activeStep === 'ship' ? 'text-blue-500 scale-110' : 'text-slate-400 dark:text-slate-600'
          }`}
        >
          SHIP
        </span>
        <span
          className={`text-[9px] font-mono font-bold uppercase tracking-widest transition-colors duration-300 ${
            activeStep === 'bloom' ? 'text-cyan-500 scale-110' : 'text-slate-400 dark:text-slate-600'
          }`}
        >
          BLOOM
        </span>
      </div>

      {/* Progress Track */}
      <div className="w-1.5 h-36 bg-slate-200 dark:bg-zinc-800 rounded-full overflow-hidden relative shadow-inner">
        <div
          className="w-full bg-gradient-to-b from-purple-500 via-blue-500 to-cyan-400 rounded-full transition-all duration-150 ease-out"
          style={{ height: `${scrollPercent}%` }}
        />
      </div>

      <span className="text-[10px] font-mono text-slate-400 font-semibold">
        {Math.round(scrollPercent)}%
      </span>
    </aside>
  );
}
