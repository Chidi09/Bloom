const designTokensCss = r'''
/* Design tokens — marketplace benchmark. Single source of truth. */
:root {
  --brand-50: #F0FDFA;
  --brand-100: #CCFBF1;
  --brand-200: #99F6E4;
  --brand-500: #14B8A6;
  --brand-600: #0D9488;
  --brand-700: #0F766E;
  --brand-900: #134E4A;
  --accent-500: #F59E0B;
  --accent-600: #D97706;
  --success: #16A34A;
  --warning: #D97706;
  --danger: #DC2626;
  --info: #0EA5E9;
  --n-0: #FFFFFF;
  --n-50: #FAFAF9;
  --n-100: #F5F5F4;
  --n-200: #E7E5E4;
  --n-400: #A8A29E;
  --n-500: #78716C;
  --n-700: #44403C;
  --n-900: #1C1917;
  --n-950: #0C0A09;
  /* semantic surfaces for light */
  --bg: var(--n-0);
  --bg-soft: var(--n-50);
  --bg-muted: var(--n-100);
  --border: var(--n-200);
  --text: var(--n-900);
  --text-muted: var(--n-500);
  --text-faint: var(--n-400);
  --card: var(--n-0);
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 14px;
  --shadow-sm: 0 1px 2px rgb(28 25 23 / .06);
  --shadow-md: 0 4px 12px rgb(28 25 23 / .08);
  --font-display: 'Plus Jakarta Sans', system-ui, sans-serif;
  --font-body: 'Inter', system-ui, sans-serif;
  color-scheme: light;
}

/* Dark overrides — both media query and explicit [data-theme] */
@media (prefers-color-scheme: dark) {
  :root {
    --bg: var(--n-950);
    --bg-soft: #1a1918;
    --bg-muted: #292524;
    --border: #2a2a29;
    --text: var(--n-50);
    --text-muted: var(--n-400);
    --card: #1c1b1a;
    color-scheme: dark;
  }
}
[data-theme="dark"] {
  --bg: var(--n-950);
  --bg-soft: #1a1918;
  --bg-muted: #292524;
  --border: #2a2a29;
  --text: var(--n-50);
  --text-muted: var(--n-400);
  --card: #1c1b1a;
  color-scheme: dark;
}

/* Base resets */
* { box-sizing: border-box; }
html { font-family: var(--font-body); background: var(--bg); color: var(--text); }
h1,h2,h3,h4 { font-family: var(--font-display); }
a { color: var(--brand-600); }
a:hover { color: var(--brand-700); }

/* Type scale */
.text-display { font-size: 2.25rem; line-height: 1.15; font-weight: 600; font-family: var(--font-display); }
.text-h1 { font-size: 1.875rem; line-height: 1.2; font-weight: 600; font-family: var(--font-display); }
.text-h2 { font-size: 1.5rem; line-height: 1.25; font-weight: 600; font-family: var(--font-display); }
.text-h3 { font-size: 1.25rem; line-height: 1.3; font-weight: 600; font-family: var(--font-display); }
.text-body { font-size: 1rem; line-height: 1.55; font-weight: 400; }
.text-small { font-size: 0.875rem; line-height: 1.5; }
.text-label { font-size: 0.8125rem; line-height: 1.4; font-weight: 500; letter-spacing: 0.04em; text-transform: uppercase; }

/* Tabular nums for prices */
.price, .tabular { font-variant-numeric: tabular-nums; }

/* Focus ring */
*:focus-visible { outline: 2px solid var(--brand-600); outline-offset: 2px; }

/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}

/* Tailwind mapping helpers (reuse tokens) */
.bg-brand-600 { background: var(--brand-600); }
.text-brand-600 { color: var(--brand-600); }
.border-brand-600 { border-color: var(--brand-600); }
''';
