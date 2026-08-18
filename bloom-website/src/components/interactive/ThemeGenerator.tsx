import { useState } from 'preact/hooks';
import { Palette, Copy, Check, Sparkles, Sliders, RefreshCw, Sun, Moon } from 'lucide-preact';
import { highlightDart } from '../../lib/dart-highlighter';

export function ThemeGenerator() {
  const [selectedStyle, setSelectedStyle] = useState<'nova' | 'vega' | 'maia' | 'lyra' | 'mira' | 'luma' | 'sera' | 'rhea'>('maia');
  const [radius, setRadius] = useState<number>(10);
  const [isDark, setIsDark] = useState<boolean>(true);
  const [copied, setCopied] = useState<boolean>(false);

  const styleConfigs = {
    nova: {
      name: 'Nova',
      defaultRadius: 8,
      primaryHex: '#18181b',
      accentHex: '#8b5cf6',
      primaryRgb: '24, 24, 27',
      accentRgb: '139, 92, 246',
      description: 'Neutral, crisp, high-contrast monochrome with violet micro-accents.',
    },
    vega: {
      name: 'Vega',
      defaultRadius: 6,
      primaryHex: '#d97706',
      accentHex: '#f59e0b',
      primaryRgb: '217, 119, 6',
      accentRgb: '245, 158, 11',
      description: 'Warm golden amber hues with radiant highlights.',
    },
    maia: {
      name: 'Maia',
      defaultRadius: 10,
      primaryHex: '#059669',
      accentHex: '#10b981',
      primaryRgb: '5, 150, 105',
      accentRgb: '16, 185, 129',
      description: 'Emerald forest green for clean enterprise platforms.',
    },
    lyra: {
      name: 'Lyra',
      defaultRadius: 16,
      primaryHex: '#7c3aed',
      accentHex: '#a78bfa',
      primaryRgb: '124, 58, 237',
      accentRgb: '167, 139, 250',
      description: 'Tech violet and neon indigo cyber style.',
    },
    mira: {
      name: 'Mira',
      defaultRadius: 4,
      primaryHex: '#2563eb',
      accentHex: '#60a5fa',
      primaryRgb: '37, 99, 235',
      accentRgb: '96, 165, 250',
      description: 'Deep royal blue for fintech and corporate tools.',
    },
    luma: {
      name: 'Luma',
      defaultRadius: 12,
      primaryHex: '#db2777',
      accentHex: '#f472b6',
      primaryRgb: '219, 39, 119',
      accentRgb: '244, 114, 182',
      description: 'High-energy magenta pink for consumer apps.',
    },
    sera: {
      name: 'Sera',
      defaultRadius: 8,
      primaryHex: '#0891b2',
      accentHex: '#22d3ee',
      primaryRgb: '8, 145, 178',
      accentRgb: '34, 211, 238',
      description: 'Teal & cyan oceanic palette with high legibility.',
    },
    rhea: {
      name: 'Rhea',
      defaultRadius: 14,
      primaryHex: '#ea580c',
      accentHex: '#fb923c',
      primaryRgb: '234, 88, 12',
      accentRgb: '251, 146, 60',
      description: 'Sunset orange for vibrant and engaging workflows.',
    },
  };

  const active = styleConfigs[selectedStyle];

  const handleSelectStyle = (st: keyof typeof styleConfigs) => {
    setSelectedStyle(st);
    setRadius(styleConfigs[st].defaultRadius);
  };

  const generatedDartCode = `// lib/bloom_ui/theme/custom_theme.dart
import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

final customBloomTheme = BloomTheme(
  colors: BloomColorScheme(
    primary: const Color(0xFF${active.accentHex.replace('#', '')}),
    destructive: const Color(0xFFEF4444),
    surface0: const Color(${isDark ? '0xFF090C10' : '0xFFF8FAFC'}),
    surface1: const Color(${isDark ? '0xFF0D1117' : '0xFFFFFFFF'}),
    surface2: const Color(${isDark ? '0xFF161B22' : '0xFFF1F5F9'}),
    border: const Color(${isDark ? '0xFF30363D' : '0xFFE2E8F0'}),
    ring: const Color(0xFF${active.accentHex.replace('#', '')}),
    textPrimary: const Color(${isDark ? '0xFFF0F6FC' : '0xFF0F172A'}),
    textSecondary: const Color(${isDark ? '0xFF8B949E' : '0xFF64748B'}),
    textTertiary: const Color(${isDark ? '0xFF6E7681' : '0xFF94A3B8'}),
  ),
  radius: const BloomRadius(
    sm: ${Math.max(2, radius / 2)},
    md: ${radius},
    lg: ${radius * 1.5},
    xl: ${radius * 2},
  ),
);`;

  const copyCode = () => {
    navigator.clipboard.writeText(generatedDartCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="space-y-10">
      {/* Controls Bar */}
      <div className="p-6 sm:p-8 rounded-3xl bg-white/90 dark:bg-zinc-950/90 border border-slate-200 dark:border-zinc-800 backdrop-blur-xl shadow-xl space-y-6">
        
        {/* Top Header & Toggles */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200 dark:border-zinc-800">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <span className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                Style Preset
              </span>
              <span
                style={{
                  backgroundColor: `${active.accentHex}20`,
                  color: active.accentHex,
                  borderColor: `${active.accentHex}40`,
                }}
                className="px-2.5 py-0.5 rounded-full text-xs font-mono font-bold border"
              >
                {active.name}
              </span>
            </div>
            <div className="text-sm font-semibold text-slate-900 dark:text-white flex items-center gap-2">
              <span
                style={{ backgroundColor: active.accentHex }}
                className="w-2.5 h-2.5 rounded-full inline-block shrink-0 shadow-sm"
              />
              <span>{active.name} — {active.description}</span>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={() => setIsDark(!isDark)}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-100 dark:bg-black border border-slate-200 dark:border-zinc-800 text-xs font-bold text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white transition cursor-pointer"
            >
              {isDark ? <Moon className="w-3.5 h-3.5 text-purple-400" /> : <Sun className="w-3.5 h-3.5 text-amber-500" />}
              <span>{isDark ? 'Dark Mode' : 'Light Mode'}</span>
            </button>

            <button
              onClick={copyCode}
              style={{ backgroundColor: active.accentHex }}
              className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold text-white hover:brightness-110 shadow-md transition active:scale-95 cursor-pointer"
            >
              {copied ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
              <span>{copied ? 'Copied' : 'Copy Theme Dart'}</span>
            </button>
          </div>
        </div>

        {/* Preset Selection Grid */}
        <div className="space-y-2">
          <div className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
            Select Preset
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-2.5">
            {(Object.keys(styleConfigs) as (keyof typeof styleConfigs)[]).map((st) => {
              const cfg = styleConfigs[st];
              const isSelected = selectedStyle === st;
              return (
                <button
                  key={st}
                  onClick={() => handleSelectStyle(st)}
                  style={{
                    borderColor: isSelected ? cfg.accentHex : undefined,
                    backgroundColor: isSelected ? `${cfg.accentHex}15` : undefined,
                    boxShadow: isSelected ? `0 0 16px ${cfg.accentHex}30` : undefined,
                  }}
                  className={`p-3 rounded-2xl border text-left transition-all flex flex-col gap-2 cursor-pointer ${
                    isSelected
                      ? 'ring-1'
                      : 'border-slate-200 dark:border-zinc-800 bg-slate-50/60 dark:bg-black/60 hover:border-slate-300 dark:hover:border-zinc-700'
                  }`}
                >
                  <div
                    style={{ backgroundColor: cfg.accentHex }}
                    className="w-5 h-5 rounded-full shadow-md"
                  />
                  <div className="flex justify-between items-center w-full">
                    <span className="text-xs font-bold text-slate-900 dark:text-white capitalize">{st}</span>
                    <span className="text-[10px] font-mono text-slate-500">{cfg.defaultRadius}px</span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Radius Controls (Clean Responsive Bar) */}
        <div className="space-y-3 pt-4 border-t border-slate-200 dark:border-zinc-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Corner Radius: <span style={{ color: active.accentHex }} className="font-bold">{radius}px</span>
            </span>
          </div>

          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            {/* Quick Step Pills */}
            <div className="flex flex-wrap items-center gap-1.5">
              {[0, 4, 6, 8, 10, 12, 14, 16, 20].map((r) => {
                const isSelected = radius === r;
                return (
                  <button
                    key={r}
                    onClick={() => setRadius(r)}
                    style={{
                      backgroundColor: isSelected ? active.accentHex : undefined,
                      borderColor: isSelected ? active.accentHex : undefined,
                    }}
                    className={`px-3 py-1.5 rounded-lg text-xs font-mono font-bold transition-all cursor-pointer ${
                      isSelected
                        ? 'text-white shadow'
                        : 'bg-slate-100 dark:bg-black text-slate-600 dark:text-slate-400 border border-slate-200 dark:border-zinc-800 hover:text-slate-900 dark:hover:text-white hover:border-slate-300 dark:hover:border-zinc-700'
                    }`}
                  >
                    {r}px
                  </button>
                );
              })}
            </div>

            {/* Continuous Slider */}
            <div className="flex items-center gap-3 w-full sm:w-56 shrink-0">
              <input
                type="range"
                min="0"
                max="24"
                value={radius}
                style={{ accentColor: active.accentHex }}
                onInput={(e: any) => setRadius(Number(e.target.value))}
                onChange={(e: any) => setRadius(Number(e.target.value))}
                className="w-full h-2 bg-slate-200 dark:bg-zinc-900 rounded-lg appearance-none cursor-pointer"
              />
              <span
                style={{ color: active.accentHex }}
                className="text-xs font-mono font-bold w-12 text-right shrink-0"
              >
                {radius}px
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Live Preview Canvas */}
      <div
        style={{
          backgroundColor: isDark ? '#000000' : '#FFFFFF',
          borderColor: isDark ? '#262626' : '#E2E8F0',
        }}
        className="p-6 sm:p-8 rounded-3xl border shadow-2xl transition-all space-y-8"
      >
        <div className="flex items-center justify-between">
          <h3 style={{ color: isDark ? '#FFFFFF' : '#0F172A' }} className="text-lg font-bold">
            Live Component Showcase
          </h3>
          <span
            style={{
              backgroundColor: `${active.accentHex}20`,
              color: active.accentHex,
              borderRadius: `${radius}px`,
              borderColor: `${active.accentHex}40`,
            }}
            className="px-3 py-1 text-xs font-mono font-bold border"
          >
            {active.name} • r={radius}px
          </span>
        </div>

        {/* Buttons Row */}
        <div className="flex flex-wrap items-center gap-3">
          <button
            style={{
              backgroundColor: active.accentHex,
              borderRadius: `${radius}px`,
            }}
            className="px-4 py-2 text-xs font-bold text-white shadow-lg hover:brightness-110 transition cursor-pointer"
          >
            Primary Action
          </button>
          <button
            style={{
              backgroundColor: isDark ? '#0A0A0A' : '#F1F5F9',
              color: isDark ? '#FFFFFF' : '#0F172A',
              borderRadius: `${radius}px`,
              borderColor: isDark ? '#262626' : '#E2E8F0',
            }}
            className="px-4 py-2 text-xs font-bold border hover:brightness-110 transition cursor-pointer"
          >
            Secondary
          </button>
          <button
            style={{
              borderColor: isDark ? '#262626' : '#CBD5E1',
              borderRadius: `${radius}px`,
              color: isDark ? '#FFFFFF' : '#0F172A',
            }}
            className="px-4 py-2 text-xs font-bold border hover:bg-black/5 dark:hover:bg-white/5 transition cursor-pointer"
          >
            Outline
          </button>
        </div>

        {/* Card Component */}
        <div
          style={{
            backgroundColor: isDark ? '#050505' : '#F8FAFC',
            borderColor: isDark ? '#262626' : '#E2E8F0',
            borderRadius: `${radius * 1.5}px`,
          }}
          className="p-6 border shadow-xl max-w-md space-y-4"
        >
          <div className="flex items-center justify-between">
            <h4 style={{ color: isDark ? '#FFFFFF' : '#0F172A' }} className="font-bold text-sm">
              Adaptive Card Component
            </h4>
            <span
              style={{
                backgroundColor: `${active.accentHex}20`,
                color: active.accentHex,
                borderRadius: `${radius}px`,
              }}
              className="px-2 py-0.5 text-[10px] font-mono font-bold"
            >
              Preset Active
            </span>
          </div>
          <p style={{ color: isDark ? '#A1A1AA' : '#64748B' }} className="text-xs leading-relaxed">
            Every button, input, dialog, and card adapts instantly to your active style preset and corner radius settings.
          </p>
          <div className="pt-2">
            <input
              type="text"
              placeholder="Interactive input with adaptive radius..."
              style={{
                borderRadius: `${radius}px`,
                backgroundColor: isDark ? '#000000' : '#FFFFFF',
                borderColor: isDark ? '#262626' : '#E2E8F0',
                color: isDark ? '#FFFFFF' : '#0F172A',
              }}
              className="w-full px-3 py-2 text-xs border focus:outline-none"
            />
          </div>
        </div>
      </div>

      {/* Generated Dart Code Block */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h4 className="text-sm font-bold text-slate-900 dark:text-white font-mono flex items-center gap-2">
            <span>Dart Theme Configuration</span>
          </h4>
          <button
            onClick={copyCode}
            style={{ color: active.accentHex }}
            className="text-xs font-mono font-bold hover:underline flex items-center gap-1 cursor-pointer"
          >
            <Copy className="w-3 h-3" />
            <span>Copy to Clipboard</span>
          </button>
        </div>
        <div className="rounded-2xl bg-black border border-zinc-800 p-5 font-mono text-xs text-slate-100 overflow-x-auto">
          <pre
            className="leading-relaxed font-mono"
            dangerouslySetInnerHTML={{ __html: highlightDart(generatedDartCode) }}
          />
        </div>
      </div>
    </div>
  );
}
