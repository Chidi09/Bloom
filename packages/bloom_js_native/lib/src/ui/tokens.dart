/// Bloom UI Design Tokens.
///
/// Provides default CSS custom properties for Bloom UI component primitives.
/// Consuming applications can override any token by redefining the corresponding
/// CSS variable in their own global stylesheet or `:root` / `[data-theme]` block.
///
/// Example:
/// ```css
/// :root {
///   --primary: #4f46e5;
///   --radius: 12px;
/// }
/// ```
const uiTokensCss = r'''
/* Bloom UI Core Design Tokens — Default Slate/Indigo Theme */
:root {
  /* Neutral palette */
  --n-0: #ffffff;
  --n-50: #fafafa;
  --n-100: #f4f4f5;
  --n-200: #e4e4e7;
  --n-300: #d4d4d8;
  --n-400: #a1a1aa;
  --n-500: #71717a;
  --n-600: #52525b;
  --n-700: #3f3f46;
  --n-800: #27272a;
  --n-900: #18181b;
  --n-950: #09090b;

  /* Brand / Primary */
  --brand-50: #eef2ff;
  --brand-100: #e0e7ff;
  --brand-200: #c7d2fe;
  --brand-500: #6366f1;
  --brand-600: #4f46e5;
  --brand-700: #4338ca;
  --brand-900: #312e81;

  --primary: #4f46e5;
  --primary-foreground: #ffffff;
  --primary-hover: #4338ca;

  --secondary: #f4f4f5;
  --secondary-foreground: #18181b;
  --secondary-hover: #e4e4e7;

  --muted: #f4f4f5;
  --muted-foreground: #71717a;

  --accent: #f4f4f5;
  --accent-foreground: #18181b;

  --danger: #ef4444;
  --destructive: #ef4444;
  --danger-foreground: #ffffff;
  --destructive-foreground: #ffffff;
  --danger-hover: #dc2626;

  --success: #16a34a;
  --success-foreground: #ffffff;
  --warning: #d97706;
  --warning-foreground: #ffffff;
  --info: #0ea5e9;
  --info-foreground: #ffffff;

  /* Surfaces & Borders (Light) */
  --bg: #ffffff;
  --bg-soft: #fafafa;
  --bg-muted: #f4f4f5;
  --border: #e4e4e7;
  --border-muted: #f4f4f5;
  --text: #09090b;
  --text-muted: #71717a;
  --text-faint: #a1a1aa;
  --card: #ffffff;
  --card-foreground: #09090b;
  --popover: #ffffff;
  --popover-foreground: #09090b;

  --ring: #6366f1;

  /* Radii */
  --radius-sm: 6px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius: 8px;

  /* Shadows */
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
  --shadow-card: 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1);
  --shadow-overlay: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);

  /* Typography */
  --font-sans: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;

  color-scheme: light;
}

/* Dark theme overrides */
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #09090b;
    --bg-soft: #14141a;
    --bg-muted: #1e1e24;
    --border: #27272a;
    --border-muted: #1e1e24;
    --text: #fafafa;
    --text-muted: #a1a1aa;
    --text-faint: #71717a;
    --card: #14141a;
    --card-foreground: #fafafa;
    --popover: #14141a;
    --popover-foreground: #fafafa;

    --secondary: #27272a;
    --secondary-foreground: #fafafa;
    --secondary-hover: #3f3f46;

    --muted: #27272a;
    --muted-foreground: #a1a1aa;

    --accent: #27272a;
    --accent-foreground: #fafafa;

    --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.3);
    --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.4), 0 2px 4px -2px rgb(0 0 0 / 0.3);
    --shadow-card: 0 1px 3px 0 rgb(0 0 0 / 0.3), 0 1px 2px -1px rgb(0 0 0 / 0.2);
    --shadow-overlay: 0 10px 15px -3px rgb(0 0 0 / 0.4), 0 4px 6px -4px rgb(0 0 0 / 0.3);

    color-scheme: dark;
  }
}

[data-theme="dark"] {
  --bg: #09090b;
  --bg-soft: #14141a;
  --bg-muted: #1e1e24;
  --border: #27272a;
  --border-muted: #1e1e24;
  --text: #fafafa;
  --text-muted: #a1a1aa;
  --text-faint: #71717a;
  --card: #14141a;
  --card-foreground: #fafafa;
  --popover: #14141a;
  --popover-foreground: #fafafa;

  --secondary: #27272a;
  --secondary-foreground: #fafafa;
  --secondary-hover: #3f3f46;

  --muted: #27272a;
  --muted-foreground: #a1a1aa;

  --accent: #27272a;
  --accent-foreground: #fafafa;

  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.3);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.4), 0 2px 4px -2px rgb(0 0 0 / 0.3);
  --shadow-card: 0 1px 3px 0 rgb(0 0 0 / 0.3), 0 1px 2px -1px rgb(0 0 0 / 0.2);
  --shadow-overlay: 0 10px 15px -3px rgb(0 0 0 / 0.4), 0 4px 6px -4px rgb(0 0 0 / 0.3);

  color-scheme: dark;
}

[data-theme="light"] {
  --bg: #ffffff;
  --bg-soft: #fafafa;
  --bg-muted: #f4f4f5;
  --border: #e4e4e7;
  --border-muted: #f4f4f5;
  --text: #09090b;
  --text-muted: #71717a;
  --text-faint: #a1a1aa;
  --card: #ffffff;
  --card-foreground: #09090b;
  --popover: #ffffff;
  --popover-foreground: #09090b;

  --secondary: #f4f4f5;
  --secondary-foreground: #18181b;
  --secondary-hover: #e4e4e7;

  --muted: #f4f4f5;
  --muted-foreground: #71717a;

  --accent: #f4f4f5;
  --accent-foreground: #18181b;

  color-scheme: light;
}
''';
