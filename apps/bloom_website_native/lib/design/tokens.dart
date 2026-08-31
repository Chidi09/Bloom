/// Design tokens and global styles faithfully ported from bloom-website/src/styles/
const String designTokensCss = r'''@import url('/generated/fonts/fonts.g.css');

/* Design Tokens for Bloom */

:root {
  /* Brand Swatches */
  --petal-pink: #FF4B8B;
  --petal-orange: #FF884D;
  --petal-cyan: #20C9B0;
  --petal-blue: #3B82F6;
  --petal-purple: #8B5CF6;
  /* Surfaces (Light Mode) */
  --surface-0: #FAFAFA;
  --surface-1: #FFFFFF;
  --surface-2: rgba(255, 255, 255, 0.6);
  --border-subtle: rgba(226, 232, 240, 0.8);
  /* Typography Colors */
  --text-primary: #0F172A;
  --text-secondary: #475569;
  --text-tertiary: #94A3B8;
  /* Spacing & Radii */
  --r-sm: 8px;
  --r-md: 12px;
  --r-lg: 16px;
  --r-xl: 24px;
  --r-full: 9999px;
  /* Shadows (Enhanced for Light Mode) */
  --shadow-1: 0 2px 6px rgba(15, 23, 42, 0.08), 0 1px 2px rgba(15, 23, 42, 0.04);
  --shadow-2: 0 14px 30px -8px rgba(15, 23, 42, 0.14), 0 6px 16px -4px rgba(15, 23, 42, 0.1);
  --shadow-3: 0 20px 40px -10px rgba(15, 23, 42, 0.18), 0 10px 20px -6px rgba(15, 23, 42, 0.12);
  --shadow-4: 0 28px 60px -14px rgba(15, 23, 42, 0.3), 0 14px 28px -8px rgba(15, 23, 42, 0.2);
  --shadow-glass-inset: inset 0 1px 1px rgba(255, 255, 255, 0.6);
  /* Motion */
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-spring: cubic-bezier(0.175, 0.885, 0.32, 1.275);
  --dur-instant: 120ms;
  --dur-fast: 200ms;
  --dur-base: 400ms;
  --dur-slow: 800ms;
  /* Z-Index */
  --z-bg: -2;
  --z-grid: -1;
  --z-base: 0;
  --z-sticky: 50;
  --z-modal: 100;
  --z-toast: 110;
  /* Dark Theme Default Tokens (AMOLED Black) */
  --bg: #000000;
  --surface: #050505;
  --elevated: #0F0F12;
  --border: rgba(255, 255, 255, 0.08);
  --border-prominent: rgba(255, 255, 255, 0.15);
  --brand: #8B5CF6;
  --brand-hover: #7C3AED;
  --cyan: #20C9B0;
  --emerald: #10B981;
  --amber: #F59E0B;
  --text: #F8FAFC;
  --text-muted: #94A3B8;
  --text-dim: #64748B;
  --font-sans: 'Plus Jakarta Sans', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}

.dark,:root {
  /* Surfaces (Dark Mode - Pure AMOLED Black) */
  --surface-0: #000000;
  --surface-1: #000000;
  --surface-2: #050505;
  --border-subtle: rgba(255, 255, 255, 0.08);
  /* Typography Colors */
  --text-primary: #F8FAFC;
  --text-secondary: #94A3B8;
  --text-tertiary: #64748B;
  /* Shadows */
  --shadow-2: 0 8px 32px 0 rgba(0, 0, 0, 0.8);
  --shadow-glass-inset: inset 0 1px 1px rgba(255, 255, 255, 0.04);
}

/* Scrollbar Styling */

::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

.light::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: var(--r-full);
}

.dark::-webkit-scrollbar-thumb,::-webkit-scrollbar-thumb {
  background: #262626;
  border-radius: var(--r-full);
}

/* Base resets & typography */

*, ::before, ::after {
  font-family: var(--font-sans);
}

code, pre, kbd, samp, .font-mono {
  font-family: var(--font-mono) !important;
}

html {
  scroll-behavior: smooth;
  font-family: var(--font-sans);
  overflow-x: hidden;
  background-color: var(--surface-0);
}

body {
  background-color: var(--surface-0);
  color: var(--text-primary);
  overflow-x: hidden;
  max-width: 100vw;
  font-family: var(--font-sans);
}

::selection {
  background-color: var(--petal-purple);
  color: #FFFFFF;
}

/* Glassmorphism Primitives */

.glass-panel {
  background: var(--surface-2);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-subtle);
  box-shadow: var(--shadow-2), var(--shadow-glass-inset);
}

/* Mouse Glow Cards */

.mouse-glow-card {
  position: relative;
  overflow: hidden;
  background: var(--surface-2);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid var(--border-subtle);
  box-shadow: var(--shadow-2), var(--shadow-glass-inset);
  transition: transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out);
}

.mouse-glow-card::before {
  content: '';
  position: absolute;
  top: var(--mouse-y, 0);
  left: var(--mouse-x, 0);
  width: 450px;
  height: 450px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.05) 0%, transparent 60%);
  transform: translate(-50%, -50%);
  pointer-events: none;
  opacity: 0;
  transition: opacity var(--dur-base) var(--ease-out);
  z-index: 0;
}

.mouse-glow-card:hover::before {
  opacity: 1;
}

.mouse-glow-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-3);
}

.mouse-glow-card > * {
  position: relative;
  z-index: 1;
}

/* Grid Overlay */

.grid-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--z-grid);
  pointer-events: none;
  opacity: 0.5;
  background-image: linear-gradient(to right, rgba(148, 163, 184, 0.12) 1px, transparent 1px), linear-gradient(to bottom, rgba(148, 163, 184, 0.12) 1px, transparent 1px);
  background-size: 40px 40px;
  mask-image: radial-gradient(circle at center, black 30%, transparent 80%);
  -webkit-mask-image: radial-gradient(circle at center, black 30%, transparent 80%);
}

.dark.grid-overlay,.dark.grid-overlay {
  background-image: linear-gradient(to right, rgba(255, 255, 255, 0.04) 1px, transparent 1px), linear-gradient(to bottom, rgba(255, 255, 255, 0.04) 1px, transparent 1px);
}

/* Text Enhancers */

.text-gradient-silver {
  background: linear-gradient(135deg, #0F172A 0%, #475569 45%, #94A3B8 75%, #0F172A 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  background-size: 200% 200%;
}

.dark.text-gradient-silver,.dark.text-gradient-silver {
  background: linear-gradient(135deg, #FFFFFF 0%, #E2E8F0 45%, #94A3B8 75%, #FFFFFF 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.text-gradient-flower {
  background: linear-gradient(135deg, var(--petal-pink) 0%, var(--petal-orange) 25%, var(--petal-purple) 50%, var(--petal-blue) 75%, var(--petal-cyan) 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  background-size: 200% 200%;
  animation: gradientX 8s ease infinite;
}

.text-sweep {
  background: linear-gradient(90deg, #0f172a 0%, #0f172a 40%, #64748b 50%, #0f172a 60%, #0f172a 100%);
  background-size: 200% auto;
  color: transparent;
  -webkit-background-clip: text;
  background-clip: text;
  animation: sweep 4s linear infinite;
}

.dark .text-sweep {
  background: linear-gradient(90deg, #ffffff 0%, #ffffff 40%, #94A3B8 50%, #ffffff 60%, #ffffff 100%);
  background-size: 200% auto;
  color: transparent;
  -webkit-background-clip: text;
  background-clip: text;
  animation: sweep 4s linear infinite;
}

@keyframes sweep {
  0% {
    background-position: 200% center;
  }
  100% {
    background-position: -200% center;
  }
}

@keyframes gradientX {
  0%, 100% {
    background-position: left center;
  }
  50% {
    background-position: right center;
  }
}

/* Typing Cursor */

.typing-cursor::after {
  content: '|';
  animation: blink 1s step-start infinite;
  color: var(--petal-purple);
}

@keyframes blink {
  50% {
    opacity: 0;
  }
}

/* Falling Petals Animation */

.falling-petal {
  position: absolute;
  top: -5%;
  will-change: transform, opacity;
  animation: fall-and-sway linear infinite;
  pointer-events: none;
}

@keyframes fall-and-sway {
  0% {
    transform: translate3d(var(--start-x), -5vh, 0) rotate(0deg);
    opacity: 0;
  }
  10% {
    opacity: var(--max-opacity);
  }
  90% {
    opacity: var(--max-opacity);
  }
  100% {
    transform: translate3d(var(--end-x), 105vh, 0) rotate(var(--rot));
    opacity: 0;
  }
}

/* Petal Burst & Breathing Animation (Hardware Accelerated) */

.petal-group {
  transform-origin: 100px 100px;
  opacity: 0;
  transform: scale(0) translate3d(0, 0, 0);
  transition: opacity 1.2s var(--ease-spring), transform 1.2s var(--ease-spring);
  will-change: transform, opacity;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}

.petal-burst.active.petal-group:nth-child(1) {
  opacity: 0.7;
  transform: translate3d(0, -50px, 0) scale(1.6) rotate(-10deg);
  transition-delay: 0.1s;
}

.petal-burst.active.petal-group:nth-child(2) {
  opacity: 0.7;
  transform: translate3d(45px, -15px, 0) scale(1.6) rotate(25deg);
  transition-delay: 0.2s;
}

.petal-burst.active.petal-group:nth-child(3) {
  opacity: 0.7;
  transform: translate3d(30px, 45px, 0) scale(1.6) rotate(70deg);
  transition-delay: 0.3s;
}

.petal-burst.active.petal-group:nth-child(4) {
  opacity: 0.7;
  transform: translate3d(-30px, 45px, 0) scale(1.6) rotate(115deg);
  transition-delay: 0.4s;
}

.petal-burst.active.petal-group:nth-child(5) {
  opacity: 0.7;
  transform: translate3d(-45px, -15px, 0) scale(1.6) rotate(160deg);
  transition-delay: 0.5s;
}

.petal-burst.active {
  animation: float 10s ease-in-out infinite 1.5s;
}

.petal-burst.active.petal-group path {
  transform-origin: 100px 100px;
  will-change: transform;
  backface-visibility: hidden;
}

.petal-burst.active.petal-group:nth-child(1) path {
  animation: p-breathe1 6s ease-in-out infinite 1.3s;
}

.petal-burst.active.petal-group:nth-child(2) path {
  animation: p-breathe2 7.5s ease-in-out infinite 1.4s;
}

.petal-burst.active.petal-group:nth-child(3) path {
  animation: p-breathe3 5.5s ease-in-out infinite 1.5s;
}

.petal-burst.active.petal-group:nth-child(4) path {
  animation: p-breathe4 8s ease-in-out infinite 1.6s;
}

.petal-burst.active.petal-group:nth-child(5) path {
  animation: p-breathe5 6.5s ease-in-out infinite 1.7s;
}

@keyframes float {
  0%, 100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-10px);
  }
}

@keyframes p-breathe1 {
  0%, 100% {
    transform: rotate(0deg) scale(1) translate(0, 0);
  }
  50% {
    transform: rotate(4deg) scale(1.05) translate(0, -6px);
  }
}

@keyframes p-breathe2 {
  0%, 100% {
    transform: rotate(0deg) scale(1) translate(0, 0);
  }
  50% {
    transform: rotate(-5deg) scale(1.04) translate(4px, -4px);
  }
}

@keyframes p-breathe3 {
  0%, 100% {
    transform: rotate(0deg) scale(1) translate(0, 0);
  }
  50% {
    transform: rotate(6deg) scale(1.06) translate(4px, 4px);
  }
}

@keyframes p-breathe4 {
  0%, 100% {
    transform: rotate(0deg) scale(1) translate(0, 0);
  }
  50% {
    transform: rotate(-4deg) scale(1.03) translate(-4px, 4px);
  }
}

@keyframes p-breathe5 {
  0%, 100% {
    transform: rotate(0deg) scale(1) translate(0, 0);
  }
  50% {
    transform: rotate(5deg) scale(1.05) translate(-4px, -4px);
  }
}

/* Dynamic Island */

.dynamic-island {
  position: absolute;
  top: 12px;
  left: 50%;
  transform: translateX(-50%);
  width: 100px;
  height: 28px;
  background: #000;
  border-radius: 20px;
  transition: all 0.4s var(--ease-out);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  z-index: 20;
  color: white;
  font-size: 10px;
  font-weight: bold;
}

.dynamic-island.expanded {
  width: 220px;
  height: 50px;
  background: #0a0a0a;
  border: 1px solid #262626;
  box-shadow: 0 10px 25px -5px rgba(0,0,0,0.8);
}

.di-content {
  opacity: 0;
  transition: opacity 0.2s;
  white-space: nowrap;
}

.dynamic-island.expanded.di-content {
  opacity: 1;
  transition-delay: 0.2s;
}

/* Ultra-Smooth Blur-Fade Scroll Reveal System (Hardware Accelerated) */

.scroll-reveal {
  opacity: 0;
  filter: blur(10px);
  transform: translate3d(0, 28px, 0);
  transition: opacity 0.75s cubic-bezier(0.16, 1, 0.3, 1), filter 0.75s cubic-bezier(0.16, 1, 0.3, 1), transform 0.75s cubic-bezier(0.16, 1, 0.3, 1);
  will-change: opacity, filter, transform;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}

.scroll-reveal.is-visible {
  opacity: 1;
  filter: blur(0px);
  transform: translate3d(0, 0, 0);
}

/* Stagger delay helpers for sequential card reveals */

.reveal-delay-1 {
  transition-delay: 0.1s;
}

.reveal-delay-2 {
  transition-delay: 0.2s;
}

.reveal-delay-3 {
  transition-delay: 0.3s;
}

.reveal-delay-4 {
  transition-delay: 0.4s;
}

/* Infinite Marquee */

@keyframes marquee {
  0% {
    transform: translateX(0%);
  }
  100% {
    transform: translateX(-50%);
  }
}

.animate-marquee {
  display: flex;
  width: max-content;
  animation: marquee 30s linear infinite;
}

.animate-marquee:hover {
  animation-play-state: paused;
}

/* Gentle Sway for Petal Logo */

@keyframes sway-subtle {
  0%, 100% {
    transform: rotate(-8deg);
  }
  50% {
    transform: rotate(8deg);
  }
}

.animate-sway {
  animation: sway-subtle 8s ease-in-out infinite;
}

/* Falling Petals Animation (Hub Hero) */

.falling-petal {
  position: absolute;
  top: -5%;
  will-change: transform, opacity;
  animation: fall-and-sway linear infinite;
  pointer-events: none;
}

@keyframes fall-and-sway {
  0% {
    transform: translate3d(var(--start-x), -5vh, 0) rotate(0deg);
    opacity: 0;
  }
  10% {
    opacity: var(--max-opacity);
  }
  90% {
    opacity: var(--max-opacity);
  }
  100% {
    transform: translate3d(var(--end-x), 105vh, 0) rotate(var(--rot));
    opacity: 0;
  }
}

/* Reduced Motion Guardrail */

@media (prefers-reduced-motion: reduce) {
  .bg-mesh-animated,.petal-burst.active,.animate-marquee,.animate-pulse,.text-sweep,.text-gradient-flower,.falling-petal {
    animation: none !important;
  }
  .scroll-reveal {
    opacity: 1 !important;
    transform: none !important;
    filter: none !important;
    transition: none !important;
  }
}

/* Code block styles */

pre {
  max-width: 100% !important;
  overflow-x: auto !important;
  -webkit-overflow-scrolling: touch;
}

code:not(pre code) {
  word-break: break-word;
  overflow-wrap: anywhere;
}

pre code {
  white-space: pre !important;
  word-break: normal !important;
}
''';
