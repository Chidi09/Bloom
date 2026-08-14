import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { cn } from '../../lib/utils';

export function DatePicker({
  accentColorHex = '#8B5CF6',
  radiusPx = 12,
  selectedDay = 14,
  onSelectDay,
}: {
  accentColorHex?: string;
  radiusPx?: number;
  selectedDay?: number;
  onSelectDay?: (day: number) => void;
}) {
  const [activeDay, setActiveDay] = useState(selectedDay);
  const daysInMonth = Array.from({ length: 31 }, (_, i) => i + 1);

  const handleSelect = (day: number) => {
    setActiveDay(day);
    if (onSelectDay) onSelectDay(day);
  };

  return (
    <div
      className="p-4 bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-800 shadow-md max-w-xs"
      style={{ borderRadius: `${radiusPx}px` }}
    >
      <div className="flex items-center justify-between mb-3 text-xs font-mono font-bold text-slate-700 dark:text-slate-300">
        <span>August 2026</span>
        <div className="flex gap-1">
          <button className="px-2 py-0.5 rounded hover:bg-slate-100 dark:hover:bg-slate-800">‹</button>
          <button className="px-2 py-0.5 rounded hover:bg-slate-100 dark:hover:bg-slate-800">›</button>
        </div>
      </div>

      <div className="grid grid-cols-7 gap-1 text-center text-[10px] font-mono text-slate-400 font-semibold mb-1">
        <span>Su</span><span>Mo</span><span>Tu</span><span>We</span><span>Th</span><span>Fr</span><span>Sa</span>
      </div>

      <div className="grid grid-cols-7 gap-1">
        {daysInMonth.slice(0, 28).map((day) => {
          const isSelected = day === activeDay;
          return (
            <button
              key={day}
              onClick={() => handleSelect(day)}
              className={cn(
                'h-7 w-7 text-xs font-mono font-bold rounded-lg transition-colors flex items-center justify-center',
                isSelected
                  ? 'text-white shadow-sm'
                  : 'text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'
              )}
              style={
                isSelected
                  ? { backgroundColor: accentColorHex, borderRadius: `${Math.min(radiusPx, 8)}px` }
                  : undefined
              }
            >
              {day}
            </button>
          );
        })}
      </div>
    </div>
  );
}
