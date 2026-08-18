import { useEffect, useState, useRef } from 'preact/hooks';
import { Search, Terminal, Sliders, Code, Box, X, Copy, ChevronRight, Layers, Sparkles, Bot, FileText } from 'lucide-preact';
import { showToast } from './ToastSystem';
import { UI_REGISTRY } from '../../lib/ui-registry';

interface CommandItem {
  id: string;
  title: string;
  category: 'Navigation' | 'Actions' | 'Components';
  icon: any;
  action: () => void;
}

export function CommandPalette() {
  const [isOpen, setIsOpen] = useState(false);
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  const staticCommands: CommandItem[] = [
    {
      id: 'cmd-copy-page-md',
      title: 'Copy Current Page for LLM (Markdown)',
      category: 'Actions',
      icon: Bot,
      action: async () => {
        const path = window.location.pathname.replace(/\/$/, '') || '';
        const mdPath = path === '' ? '/index.md' : `${path}.md`;
        try {
          const res = await fetch(mdPath);
          const text = await res.text();
          await navigator.clipboard.writeText(text);
          showToast('LLM Markdown Copied!', 'Ready to paste into ChatGPT, Claude, or Cursor.', 'emerald');
        } catch {
          await navigator.clipboard.writeText(window.location.origin + mdPath);
          showToast('Markdown URL Copied!', mdPath, 'indigo');
        }
        setIsOpen(false);
      },
    },
    {
      id: 'nav-llms-txt',
      title: 'View /llms.txt (LLM Documentation Index)',
      category: 'Navigation',
      icon: Bot,
      action: () => {
        window.open('/llms.txt', '_blank');
        setIsOpen(false);
      },
    },
    {
      id: 'nav-llms-full',
      title: 'View /llms-full.txt (Consolidated Full Context)',
      category: 'Navigation',
      icon: FileText,
      action: () => {
        window.open('/llms-full.txt', '_blank');
        setIsOpen(false);
      },
    },
    {
      id: 'cmd-copy',
      title: 'Copy CLI Install Command',
      category: 'Actions',
      icon: Terminal,
      action: () => {
        navigator.clipboard.writeText('dart pub global activate bloom_cli');
        showToast('Command Copied', 'Run "dart pub global activate bloom_cli" in your terminal.', 'emerald');
        setIsOpen(false);
      },
    },
    {
      id: 'cmd-ui-add-all',
      title: 'bloom ui add all (Copy source components)',
      category: 'Actions',
      icon: Layers,
      action: () => {
        navigator.clipboard.writeText('bloom ui add all');
        showToast('Command Copied', 'Run "bloom ui add all" to copy the component suite.', 'emerald');
        setIsOpen(false);
      },
    },
    {
      id: 'nav-ui',
      title: 'Bloom UI — Component Library Overview',
      category: 'Navigation',
      icon: Sparkles,
      action: () => {
        window.location.href = '/ui';
        setIsOpen(false);
      },
    },
    {
      id: 'nav-build',
      title: 'BUILD — Framework & DX Deep-dive',
      category: 'Navigation',
      icon: Code,
      action: () => {
        window.location.href = '/build';
        setIsOpen(false);
      },
    },
    {
      id: 'nav-ship',
      title: 'SHIP — Cloud OTA & Deploy Farm',
      category: 'Navigation',
      icon: Box,
      action: () => {
        window.location.href = '/ship';
        setIsOpen(false);
      },
    },
    {
      id: 'nav-bloom',
      title: 'BLOOM — Interactive Design Tokens & UI Studio',
      category: 'Navigation',
      icon: Sliders,
      action: () => {
        window.location.href = '/bloom';
        setIsOpen(false);
      },
    },
    {
      id: 'nav-hub',
      title: 'Hub Overview',
      category: 'Navigation',
      icon: Search,
      action: () => {
        window.location.href = '/';
        setIsOpen(false);
      },
    },
  ];

  const componentCommands: CommandItem[] = UI_REGISTRY.map((c) => ({
    id: `comp-${c.slug}`,
    title: `${c.title} (${c.name}) — ${c.category}`,
    category: 'Components',
    icon: Layers,
    action: () => {
      window.location.href = `/ui/${c.slug}`;
      setIsOpen(false);
    },
  }));

  const commands = [...staticCommands, ...componentCommands];

  const filteredCommands = commands.filter((cmd) =>
    cmd.title.toLowerCase().includes(query.toLowerCase()) ||
    cmd.category.toLowerCase().includes(query.toLowerCase())
  );

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setIsOpen((prev) => !prev);
      }
      if (e.key === 'Escape' && isOpen) {
        setIsOpen(false);
      }
    };

    const handleOpenEvent = () => setIsOpen(true);

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('bloom:open-cmd-palette', handleOpenEvent);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('bloom:open-cmd-palette', handleOpenEvent);
    };
  }, [isOpen]);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 50);
    } else {
      setQuery('');
    }
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 bg-slate-900/40 dark:bg-black/70 backdrop-blur-md z-[100] flex items-start justify-center pt-20 sm:pt-28 px-4 transition-opacity animate-in fade-in"
      onClick={(e) => {
        if (e.target === e.currentTarget) setIsOpen(false);
      }}
      role="dialog"
      aria-modal="true"
      aria-label="Command Palette"
    >
      <div className="bg-white dark:bg-black w-full max-w-xl rounded-2xl border border-slate-200 dark:border-zinc-800 shadow-2xl overflow-hidden transform scale-100 transition-all">
        {/* Input Bar */}
        <div className="p-4 border-b border-slate-200 dark:border-zinc-800 flex items-center gap-3">
          <Search className="w-5 h-5 text-purple-500 shrink-0" strokeWidth={1.75} />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onInput={(e) => setQuery((e.target as HTMLInputElement).value)}
            placeholder="Search commands, landings, or docs..."
            className="w-full bg-transparent text-slate-900 dark:text-white font-mono text-sm focus:outline-none placeholder-slate-400"
          />
          <button
            onClick={() => setIsOpen(false)}
            className="px-2 py-1 bg-slate-100 dark:bg-zinc-900 text-slate-500 text-xs font-mono rounded-lg hover:text-slate-900 dark:hover:text-white transition-colors"
          >
            ESC
          </button>
        </div>

        {/* Command List */}
        <div className="p-2 space-y-1 max-h-80 overflow-y-auto font-mono text-xs">
          {filteredCommands.length === 0 ? (
            <div className="p-6 text-center text-slate-400 font-sans">
              No matching commands found for "{query}"
            </div>
          ) : (
            filteredCommands.map((cmd) => {
              const IconComponent = cmd.icon;
              return (
                <button
                  key={cmd.id}
                  onClick={cmd.action}
                  className="w-full p-3 rounded-xl hover:bg-slate-100 dark:hover:bg-zinc-900 flex justify-between items-center text-slate-700 dark:text-slate-300 transition text-left group"
                >
                  <div className="flex items-center gap-3 font-semibold">
                    <div className="p-1.5 rounded-lg bg-slate-100 dark:bg-zinc-900 text-purple-500 group-hover:bg-purple-500 group-hover:text-white transition-colors">
                      <IconComponent className="w-4 h-4" strokeWidth={1.75} />
                    </div>
                    <span>{cmd.title}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] text-slate-400 bg-slate-100 dark:bg-zinc-900 px-2 py-0.5 rounded">
                      {cmd.category}
                    </span>
                    <ChevronRight className="w-3.5 h-3.5 text-slate-400 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </div>
                </button>
              );
            })
          )}
        </div>

        {/* Footer */}
        <div className="px-4 py-2.5 bg-slate-50 dark:bg-zinc-950 border-t border-slate-200 dark:border-zinc-800 flex items-center justify-between text-[11px] text-slate-400 font-mono">
          <span>Tip: Use ↑ ↓ to navigate</span>
          <span className="flex items-center gap-1">
            <kbd className="px-1.5 py-0.5 bg-slate-200 dark:bg-zinc-800 rounded font-bold">⌘K</kbd> to toggle
          </span>
        </div>
      </div>
    </div>
  );
}

// Global helper to open palette from anywhere
export function openCommandPalette() {
  window.dispatchEvent(new CustomEvent('bloom:open-cmd-palette'));
}
