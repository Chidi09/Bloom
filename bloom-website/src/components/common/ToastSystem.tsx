import { useEffect, useState } from 'preact/hooks';
import { Zap, CheckCircle2, Info, X } from 'lucide-preact';

interface ToastItem {
  id: string;
  title: string;
  message: string;
  type: 'purple' | 'emerald' | 'blue';
}

export function ToastSystem() {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  useEffect(() => {
    const handleToast = (e: CustomEvent<Omit<ToastItem, 'id'>>) => {
      const newToast: ToastItem = {
        id: Math.random().toString(36).substring(2, 9),
        title: e.detail.title,
        message: e.detail.message,
        type: e.detail.type || 'purple',
      };

      setToasts((prev) => [...prev, newToast]);

      setTimeout(() => {
        setToasts((prev) => prev.filter((t) => t.id !== newToast.id));
      }, 4000);
    };

    window.addEventListener('bloom:toast' as any, handleToast);
    return () => window.removeEventListener('bloom:toast' as any, handleToast);
  }, []);

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const getBorderColor = (type: ToastItem['type']) => {
    switch (type) {
      case 'emerald':
        return 'border-emerald-500 text-emerald-700 dark:text-emerald-300';
      case 'blue':
        return 'border-blue-500 text-blue-700 dark:text-blue-300';
      case 'purple':
      default:
        return 'border-purple-500 text-purple-700 dark:text-purple-300';
    }
  };

  const getIcon = (type: ToastItem['type']) => {
    switch (type) {
      case 'emerald':
        return <CheckCircle2 className="w-5 h-5 text-emerald-500 shrink-0" strokeWidth={1.75} />;
      case 'blue':
        return <Info className="w-5 h-5 text-blue-500 shrink-0" strokeWidth={1.75} />;
      case 'purple':
      default:
        return <Zap className="w-5 h-5 text-purple-500 shrink-0" strokeWidth={1.75} />;
    }
  };

  return (
    <div className="fixed bottom-6 right-6 z-[110] flex flex-col gap-2 pointer-events-none max-w-sm w-full px-4">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={`glass-panel border-l-4 ${getBorderColor(toast.type).split(' ')[0]} border-y border-r shadow-2xl rounded-2xl p-4 transform transition-all duration-300 pointer-events-auto flex gap-3 items-start relative animate-in fade-in slide-in-from-bottom-5`}
        >
          {getIcon(toast.type)}
          <div className="flex-1 min-w-0 pr-6">
            <h4 className={`text-sm font-bold ${getBorderColor(toast.type).split(' ').slice(1).join(' ')}`}>
              {toast.title}
            </h4>
            <p className="text-xs text-slate-600 dark:text-slate-400 mt-1 leading-relaxed">
              {toast.message}
            </p>
          </div>
          <button
            onClick={() => removeToast(toast.id)}
            className="absolute top-3 right-3 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
            aria-label="Close notification"
          >
            <X className="w-4 h-4" strokeWidth={1.75} />
          </button>
        </div>
      ))}
    </div>
  );
}

// Global helper to trigger toast anywhere
export function showToast(title: string, message: string, type: 'purple' | 'emerald' | 'blue' = 'purple') {
  window.dispatchEvent(
    new CustomEvent('bloom:toast', {
      detail: { title, message, type },
    })
  );
}
