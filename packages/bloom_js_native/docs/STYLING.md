# STYLING — Bloom JS Native

Real DOM = real CSS. Nothing intercepts the browser’s rendering.

## Day-one support

### 1. Plain CSS files

```html
<link rel="stylesheet" href="/app.css">
```

### 2. Tailwind

Works because `className:` is a real `class` attribute on real DOM:

```dart
Div(className: 'flex h-screen bg-zinc-950 text-white', children: [...])
Button(className: 'px-4 py-2 bg-indigo-600 rounded', text: 'Click')
```

Standard Tailwind CDN or build works unmodified.

### 3. Inline styles

```dart
Div(style: 'color: red; display:flex; gap: 8px', children: [...])
```

Use for dynamic one-offs; prefer classes for everything else.

### 4. Scoped styles (phase 5)

```dart
Style('''
  .card { border: 1px solid #1E1E24; background: #14141A; }
  .card-title { color: #6366F1; }
''')
```

Combined with generated class-name hashing (M5) to avoid collisions.

### 5. CSS-in-Dart theme object

Mirror the `GEMINI.md` palette in Dart for shared tokens:

```dart
abstract class BloomTheme {
  static const carbon = '#09090B';
  static const surface = '#14141A';
  static const border = '#1E1E24';
  static const indigo = '#6366F1';
}
```

Use directly: `Div(style: 'background: ${BloomTheme.carbon}')` or generate classes.

## Why this looks as good as JS frameworks

No rendering engine sits between your CSS and the browser. No canvas fallback, no Skia, no CSS subset. If it works in Chrome, it works in Bloom JS Native.

## Conventions (from GEMINI.md §1)

- Dark, Linear/Vercel-inspired engineering aesthetics.
- Deep carbon backgrounds (`#09090B`), elevated surfaces (`#14141A`), crisp borders (`#1E1E24`/`#27272A`), indigo accents (`#6366F1`), semantic status colors.
- No toy emojis in production UI — use Material/Lucide vector icons via npm (`lucide` + import map) or inline SVG.
- Prefer Bloom UI primitives; for web target these are real DOM primitives, not Flutter widgets.

## Do not

- Do not invent a CSS-in-JS runtime that reimplements the browser.
- Do not ship a CSS reset that breaks native form controls.
- Do not use Flutter `ThemeData` on web — it’s a canvas theming system, irrelevant here.
