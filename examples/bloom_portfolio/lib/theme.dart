/// Theme controller managing dark/light mode state, DOM classes, and localStorage persistence.
library;

// Reach the reactive primitives through bloom_js_native, which re-exports them.
// Importing package:signals directly would be an undeclared dependency here --
// it is not in this example's pubspec and would only resolve transitively.
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:web/web.dart' as web;

/// Manages active visual theme (dark vs. light), syncing with HTML classes
/// and browser localStorage.
class ThemeManager {
  ThemeManager._() {
    _init();
  }

  static final ThemeManager instance = ThemeManager._();

  static const String _storageKey = 'bloom_portfolio_theme';

  /// Reactive signal indicating whether dark mode is currently active.
  final Signal<bool> isDark = signal(true);

  void _init() {
    try {
      final stored = web.window.localStorage.getItem(_storageKey);
      if (stored != null) {
        final dark = stored == 'dark';
        isDark.value = dark;
        _applyDom(dark);
      } else {
        // Fall back to viewer's operating system / browser preference
        final prefersDark =
            web.window.matchMedia('(prefers-color-scheme: dark)').matches;
        isDark.value = prefersDark;
        _applyDom(prefersDark);
      }
    } catch (_) {
      // Default to dark theme in headless / restricted environments
      isDark.value = true;
    }
  }

  /// Toggles between dark and light themes.
  void toggle() {
    final next = !isDark.value;
    isDark.value = next;
    try {
      web.window.localStorage.setItem(_storageKey, next ? 'dark' : 'light');
      _applyDom(next);
    } catch (_) {}
  }

  /// Sets theme explicitly.
  void setTheme(bool dark) {
    isDark.value = dark;
    try {
      web.window.localStorage.setItem(_storageKey, dark ? 'dark' : 'light');
      _applyDom(dark);
    } catch (_) {}
  }

  void _applyDom(bool dark) {
    try {
      final root = web.document.documentElement;
      if (root != null) {
        if (dark) {
          root.classList.add('dark');
        } else {
          root.classList.remove('dark');
        }
      }
    } catch (_) {}
  }
}
