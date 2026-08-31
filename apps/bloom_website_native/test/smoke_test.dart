import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

import 'package:bloom_website_native/components/command_palette.dart'
    as palette;
import 'package:bloom_website_native/components/theme_toggle.dart' as theme;

void main() {
  test('command palette renders nothing while closed', () {
    palette.closePalette();
    final html = renderToHtml(palette.commandPaletteViewport());
    expect(html.contains('command-palette-modal'), isFalse);
  });

  test('command palette renders a dialog with search input when opened', () {
    palette.openPalette();
    final html = renderToHtml(palette.commandPaletteViewport());
    expect(html.contains('command-palette-modal'), isTrue);
    expect(html.contains('role="dialog"'), isTrue);
    expect(html.contains('cmd-palette-input'), isTrue);
    expect(html.contains('Copy CLI Install Command'), isTrue);
    palette.closePalette();
  });

  test('palette filtering hides non-matching commands', () {
    palette.openPalette();
    palette.searchQuery.value = 'cloud';
    final html = renderToHtml(palette.commandPaletteViewport());
    // "Cloud & CLI" matches; "Copy CLI Install Command" does not.
    expect(html.contains('Cloud &amp; CLI'), isTrue);
    expect(html.contains('Copy CLI Install Command'), isFalse);
    palette.searchQuery.value = 'zzzz-no-match';
    final empty = renderToHtml(palette.commandPaletteViewport());
    expect(empty.contains('No matching commands found'), isTrue);
    palette.closePalette();
  });

  test('theme signal flips and toggle output follows it', () {
    theme.setTheme(true);
    expect(theme.isDarkTheme.value, isTrue);
    var html = renderToHtml(theme.themeToggle());
    expect(html.contains('aria-pressed="true"'), isTrue);
    expect(html.contains('text-amber-400'), isTrue);

    theme.setTheme(false);
    expect(theme.isDarkTheme.value, isFalse);
    html = renderToHtml(theme.themeToggle());
    expect(html.contains('aria-pressed="false"'), isTrue);
    expect(html.contains('text-slate-700'), isTrue);
    expect(html.toLowerCase().contains('onclick'), isFalse);
    theme.setTheme(true);
  });
}
