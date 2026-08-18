import { useEffect, useState } from 'preact/hooks';
import { Sun, Moon } from 'lucide-preact';

export function ThemeToggle() {
  const [theme, setTheme] = useState<'light' | 'dark'>('dark');

  useEffect(() => {
    // Sync with DOM / localStorage on mount
    const isDark = document.documentElement.classList.contains('dark');
    setTheme(isDark ? 'dark' : 'light');
  }, []);

  const toggle = () => {
    const nextTheme = theme === 'dark' ? 'light' : 'dark';
    setTheme(nextTheme);

    if (nextTheme === 'dark') {
      document.documentElement.classList.remove('light');
      document.documentElement.classList.add('dark');
      localStorage.setItem('bloom-theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      document.documentElement.classList.add('light');
      localStorage.setItem('bloom-theme', 'light');
    }
  };

  return (
    <button
      onClick={toggle}
      aria-label="Toggle light and dark mode"
      aria-pressed={theme === 'dark'}
      className="p-2.5 text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white rounded-xl hover:bg-slate-100 dark:hover:bg-zinc-800 transition focus:outline-none focus:ring-2 focus:ring-purple-500"
    >
      {theme === 'dark' ? (
        <Sun className="w-4 h-4 text-amber-400" strokeWidth={1.75} />
      ) : (
        <Moon className="w-4 h-4 text-slate-700" strokeWidth={1.75} />
      )}
    </button>
  );
}
