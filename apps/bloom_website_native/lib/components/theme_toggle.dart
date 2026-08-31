import 'package:bloom_js_native/bloom_js_native.dart';
import 'huge_icons.dart';

/// Single source of truth for the current theme. Defaults to dark, matching
/// `class="dark"` on `<html>` in `web/index.html`.
final isDarkTheme = signal(true);

/// DOM/localStorage hook. Assigned in `lib/main.dart` (the only file allowed
/// to touch real browser APIs); a no-op under SSR / VM tests.
void Function(bool dark) applyThemeToDocument = (_) {};

void setTheme(bool dark) {
  isDarkTheme.value = dark;
  applyThemeToDocument(dark);
}

void toggleTheme() => setTheme(!isDarkTheme.value);

BloomNode themeToggle() {
  // Rebuilt from the `isDarkTheme` signal so the icon and aria state always
  // reflect real theme state (mirrors ThemeToggle.tsx in the Astro source).
  return Live(() {
    final dark = isDarkTheme.value;
    return Button(
      attrs: {
        'id': 'theme-toggle-btn',
        'type': 'button',
        'aria-label': 'Toggle light and dark mode',
        'aria-pressed': dark ? 'true' : 'false',
      },
      onClick: (_) => toggleTheme(),
      className:
          'p-2.5 text-slate-500 hover:text-slate-900 '
          'dark:text-slate-400 dark:hover:text-white rounded-xl '
          'hover:bg-slate-100 dark:hover:bg-zinc-800 transition '
          'focus:outline-none focus:ring-2 focus:ring-purple-500',
      children: [
        Span(
          className: 'inline-flex',
          children: [
            hugeIcon(
              dark ? 'sun' : 'moon',
              className:
                  dark ? 'w-4 h-4 text-amber-400' : 'w-4 h-4 text-slate-700',
            ),
          ],
        ),
      ],
    );
  });
}
