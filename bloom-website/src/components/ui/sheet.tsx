import * as React from 'preact/compat';
import { cn } from '../../lib/utils';

export function Sheet({
  isOpen,
  onClose,
  title,
  description,
  children,
  accentColorHex,
  radiusPx,
}: {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children?: React.ReactNode;
  accentColorHex?: string;
  radiusPx?: number;
}) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div
        className="fixed inset-0"
        onClick={onClose}
      />
      <div
        className="relative z-10 w-full max-w-lg bg-white dark:bg-black border border-slate-200 dark:border-zinc-800 p-6 shadow-2xl transition-transform transform translate-y-0 sm:rounded-2xl"
        style={{
          borderTopLeftRadius: `${radiusPx ?? 16}px`,
          borderTopRightRadius: `${radiusPx ?? 16}px`,
          borderBottomLeftRadius: radiusPx !== undefined ? `${radiusPx}px` : undefined,
          borderBottomRightRadius: radiusPx !== undefined ? `${radiusPx}px` : undefined,
        }}
      >
        {/* Mobile Pull Handle */}
        <div className="w-12 h-1.5 bg-slate-300 dark:bg-zinc-700 rounded-full mx-auto mb-4 sm:hidden" />
        
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-base font-bold text-slate-900 dark:text-white">{title}</h3>
            {description && <p className="text-xs text-slate-500 dark:text-zinc-400 mt-0.5">{description}</p>}
          </div>
          <button
            onClick={onClose}
            className="w-7 h-7 rounded-full bg-slate-100 dark:bg-zinc-900 flex items-center justify-center text-slate-500 hover:text-slate-900 dark:hover:text-white"
          >
            ✕
          </button>
        </div>

        <div className="py-2">{children}</div>
      </div>
    </div>
  );
}
