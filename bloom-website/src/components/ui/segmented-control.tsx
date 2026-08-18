import * as React from 'preact/compat';
import { useState } from 'preact/hooks';

export function SegmentedControl({
  options,
  defaultSelected,
  accentColorHex = '#8B5CF6',
  radiusPx = 12,
}: {
  options: { id: string; label: string }[];
  defaultSelected?: string;
  accentColorHex?: string;
  radiusPx?: number;
}) {
  const [selected, setSelected] = useState(defaultSelected || options[0]?.id);

  return (
    <div
      className="p-1 bg-slate-100 dark:bg-black border border-slate-200 dark:border-zinc-800 flex gap-1 w-full max-w-sm shadow-inner"
      style={{ borderRadius: `${radiusPx}px` }}
    >
      {options.map((opt) => {
        const isSelected = selected === opt.id;
        return (
          <button
            key={opt.id}
            onClick={() => setSelected(opt.id)}
            className={`flex-1 py-1.5 px-3 text-xs font-mono font-bold transition-all ${
              isSelected
                ? 'text-white shadow-sm scale-[1.02]'
                : 'text-slate-600 dark:text-zinc-400 hover:text-slate-900 dark:hover:text-white'
            }`}
            style={
              isSelected
                ? { backgroundColor: accentColorHex, borderRadius: `${Math.max(4, radiusPx - 4)}px` }
                : undefined
            }
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
