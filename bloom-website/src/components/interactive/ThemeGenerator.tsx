import { useState } from 'preact/hooks';
import { Palette, Copy, Check, Sparkles, Sliders, RefreshCw, Sun, Moon } from 'lucide-preact';

export function ThemeGenerator() {
  const [selectedStyle, setSelectedStyle] = useState<'nova' | 'vega' | 'maia' | 'lyra' | 'mira' | 'luma' | 'sera' | 'rhea'>('nova');
  const [radius, setRadius] = useState<number>(8);
  const [isDark, setIsDark] = useState<boolean>(true);
  const [copied, setCopied] = useState<boolean>(false);

  const styleConfigs = {
    nova: {
      name: 'Nova',
      primaryHex: '#18181b',
      accentHex: '#8b5cf6',
      primaryRgb: '24, 24, 27',
      accentRgb: '139, 92, 246',
      description: 'Neutral, crisp, high-contrast monochrome with violet micro-accents.',
    },
    vega: {
      name: 'Vega',
      primaryHex: '#d97706',
      accentHex: '#f59e0b',
      primaryRgb: '217, 119, 6',
      accentRgb: '245, 158, 11',
      description: 'Warm golden amber hues with radiant highlights.',
    },
    maia: {
      name: 'Maia',
      primaryHex: '#059669',
      accentHex: '#10b981',
      primaryRgb: '5, 150, 105',
      accentRgb: '16, 185, 129',
      description: 'Emerald forest green for clean enterprise platforms.',
    },
    lyra: {
      name: 'Lyra',
      primaryHex: '#7c3aed',
      accentHex: '#a78bfa',
      primaryRgb: '124, 58, 237',
      accentRgb: '167, 139, 250',
      description: 'Tech violet and neon indigo cyber style.',
    },
    mira: {
      name: 'Mira',
      primaryHex: '#2563eb',
      accentHex: '#60a5fa',
      primaryRgb: '37, 99, 235',
      accentRgb: '96, 165, 250',
      description: 'Deep royal blue for fintech and corporate tools.',
    },
    luma: {
      name: 'Luma',
      primaryHex: '#db2777',
      accentHex: '#f472b6',
      primaryRgb: '219, 39, 119',
      accentRgb: '244, 114, 182',
      description: 'High-energy magenta pink for consumer apps.',
    },
    sera: {
      name: 'Sera',
      primaryHex: '#0891b2',
      accentHex: '#22d3ee',
      primaryRgb: '8, 145, 178',
      accentRgb: '34, 211, 238',
      description: 'Teal & cyan oceanic palette with high legibility.',
    },
    rhea: {
      name: 'Rhea',
      primaryHex: '#ea580c',
      accentHex: '#fb923c',
      primaryRgb: '234, 88, 12',
      accentRgb: '251, 146, 60',
      description: 'Sunset orange for vibrant and engaging workflows.',
    },
  };

  const active = styleConfigs[selectedStyle];

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
      <div className="p-6 rounded-3xl bg-slate-900/80 border border-slate-800 backdrop-blur-xl shadow-xl space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <div className="text-xs font-mono font-bold text-slate-400 uppercase tracking-wider">
              Style Preset
            </div>
            <div className="text-sm font-bold text-white mt-0.5">{active.name} — {active.description}</div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setIsDark(!isDark)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-950 border border-slate-800 text-xs font-bold text-slate-300 hover:text-white"
            >
              {isDark ? <Moon className="w-3.5 h-3.5 text-purple-400" /> : <Sun className="w-3.5 h-3.5 text-amber-400" />}
              <span>{isDark ? 'Dark Mode' : 'Light Mode'}</span>
            </button>

            <button
              onClick={copyCode}
              className="flex items-center gap-1.5 px-4 py-1.5 rounded-xl bg-purple-600 text-xs font-bold text-white hover:bg-purple-500 shadow-md"
            >
              {copied ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
              <span>{copied ? 'Copied' : 'Copy Theme Dart'}</span>
            </button>
          </div>
        </div>

        {/* Styles Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-2">
          {(Object.keys(styleConfigs) as (keyof typeof styleConfigs)[]).map((st) => (
            <button
              key={st}
              onClick={() => setSelectedStyle(st)}
              className={`p-3 rounded-2xl border text-left transition-all flex flex-col gap-2 ${
                selectedStyle === st
                  ? 'border-purple-500 bg-purple-500/10 shadow-lg scale-105'
                  : 'border-slate-800 bg-slate-950/60 hover:border-slate-700'
              }`}
            >
              <div
                style={{ backgroundColor: styleConfigs[st].accentHex }}
                className="w-5 h-5 rounded-full shadow-md"
              />
              <span className="text-xs font-bold text-white capitalize">{st}</span>
            </button>
          ))}
        </div>

        {/* Radius Controls */}
        <div className="flex flex-wrap items-center gap-4 pt-4 border-t border-slate-800">
          <span className="text-xs font-mono text-slate-400">Corner Radius:</span>
          <div className="flex gap-2">
            {[0, 4, 6, 8, 12, 16].map((r) => (
              <button
                key={r}
                onClick={() => setRadius(r)}
                className={`px-3 py-1 rounded-lg text-xs font-mono font-bold transition-all ${
                  radius === r
                    ? 'bg-purple-600 text-white shadow'
                    : 'bg-slate-950 text-slate-400 border border-slate-800 hover:text-white'
                }`}
              >
                {r}px
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Live Preview Canvas */}
      <div
        style={{
          backgroundColor: isDark ? '#090C10' : '#F8FAFC',
          borderColor: isDark ? '#30363D' : '#E2E8F0',
        }}
        className="p-8 rounded-3xl border shadow-2xl transition-all space-y-8"
      >
        <div className="flex items-center justify-between">
          <h3 style={{ color: isDark ? '#F0F6FC' : '#0F172A' }} className="text-lg font-bold">
            Live Component Showcase
          </h3>
          <span
            style={{
              backgroundColor: `${active.accentHex}20`,
              color: active.accentHex,
              borderRadius: `${radius}px`,
            }}
            className="px-3 py-1 text-xs font-mono font-bold"
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
            className="px-4 py-2 text-xs font-bold text-white shadow-lg hover:brightness-110"
          >
            Primary Action
          </button>
          <button
            style={{
              borderRadius: `${radius}px`,
              borderColor: isDark ? '#30363D' : '#CBD5E1',
              color: isDark ? '#F0F6FC' : '#0F172A',
            }}
            className="px-4 py-2 text-xs font-bold border hover:bg-slate-500/10"
          >
            Outline Button
          </button>
          <button
            style={{
              borderRadius: `${radius}px`,
            }}
            className="px-4 py-2 text-xs font-bold bg-red-500/10 text-red-400 border border-red-500/20"
          >
            Destructive Soft
          </button>
        </div>

        {/* Card & Form */}
        <div
          style={{
            backgroundColor: isDark ? '#0D1117' : '#FFFFFF',
            borderColor: isDark ? '#30363D' : '#E2E8F0',
            borderRadius: `${radius * 1.5}px`,
          }}
          className="p-6 border shadow-xl space-y-4 max-w-md"
        >
          <div>
            <div style={{ color: isDark ? '#F0F6FC' : '#0F172A' }} className="text-sm font-bold">
              Account Security
            </div>
            <div style={{ color: isDark ? '#8B949E' : '#64748B' }} className="text-xs">
              Manage your deployment keys and 2FA settings.
            </div>
          </div>

          <input
            type="text"
            placeholder="api_live_secret_key"
            style={{
              borderRadius: `${radius}px`,
              borderColor: isDark ? '#30363D' : '#CBD5E1',
              backgroundColor: isDark ? '#161B22' : '#F1F5F9',
              color: isDark ? '#F0F6FC' : '#0F172A',
            }}
            className="w-full px-3 py-2 text-xs border font-mono focus:outline-none"
          />

          <div className="flex justify-end pt-2">
            <button
              style={{
                backgroundColor: active.accentHex,
                borderRadius: `${radius}px`,
              }}
              className="px-4 py-1.5 text-xs font-bold text-white shadow"
            >
              Save Keys
            </button>
          </div>
        </div>
      </div>

      {/* Generated Code Snippet */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="text-xs font-mono font-bold text-slate-400 uppercase tracking-wider">
            Generated Theme Dart Code
          </div>
          <button
            onClick={copyCode}
            className="text-xs font-mono text-purple-400 hover:underline flex items-center gap-1"
          >
            <Copy className="w-3 h-3" />
            <span>Copy to Clipboard</span>
          </button>
        </div>
        <div className="rounded-2xl bg-black/90 border border-slate-800 p-5 font-mono text-xs text-slate-200 overflow-x-auto">
          <pre className="leading-relaxed">{generatedDartCode}</pre>
        </div>
      </div>
    </div>
  );
}
