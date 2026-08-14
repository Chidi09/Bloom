# Bloom UI — Port Status & Source Reference

## Source of truth for shadcn components
The exact shadcn/ui component source (base-nova style) is cloned at:
**`/tmp/shadcn-ui/apps/v4/registry/bases/base/ui/`** — 59 `.tsx` files
The style CSS (exact token values per style) is at:
**`/tmp/shadcn-src/styles/style-*.css`** — 8 files (nova, vega, maia, lyra, mira, luma, sera, rhea)

The oklch→sRGB conversion script is at:
**`/root/dev/Bloom/scripts/oklch_to_dart.py`**

All docs pages already fetched: **`/root/dev/Bloom/docs/shadcn/`** (~300 markdown files)

## Token system (`packages/bloom_ui/lib/src/theme/`)
- `tokens.dart` — raw scales (BloomColors, BloomSpacing, BloomRadius, BloomTypography, BloomShadows, BloomMotion)
- `bloom_color_scheme.dart` — semantic palette: `BloomColorScheme` with 24 fields (muted, accent, buttonBorder, ring, chart1-5) + light/dark defaults matching shadcn neutral EXACTLY (oklch→sRGB converted) + petalLight/petalDark alt themes
- `bloom_theme.dart` — `BloomThemeStyle` enum (nova/vega/maia/lyra/mira/luma/sera/rhea) + 8 style presets + `BloomTheme.resolve(Brightness)` + global `setStyle()` + legacy `BloomTheme.light/dark` pointing to nova

## Component mapping (shadcn → Bloom)
Key: ✅ = implemented, ⚠️ = exists but missing some variants/features, ❌ = missing

| shadcn file | Bloom file | Status |
|---|---|---|
| accordion.tsx | accordion.dart | ✅ |
| alert.tsx | alert.dart | ✅ |
| alert-dialog.tsx | dialog.dart | ⚠️ covered by BloomDialog, no separate alert-dialog |
| aspect-ratio.tsx | aspect_ratio.dart | ✅ |
| attachment.tsx | attachment.dart | ✅ |
| avatar.tsx | avatar.dart | ✅ |
| badge.tsx | badge.dart | ⚠️ recently added ghost/link variants, verify |
| breadcrumb.tsx | breadcrumb.dart | ✅ |
| bubble.tsx | bubble.dart | ✅ |
| button.tsx | button.dart | ✅ |
| button-group.tsx | button_group.dart | ⚠️ needs orientation (horizontal/vertical) |
| calendar.tsx | calendar.dart | ✅ recently fixed grid layout |
| card.tsx | card.dart | ✅ |
| carousel.tsx | carousel.dart | ✅ |
| chart.tsx | chart.dart | ⚠️ good, but tooltip hover is tap-only, needs drag tracking |
| checkbox.tsx | checkbox.dart | ✅ |
| collapsible.tsx | collapsible.dart | ✅ |
| combobox.tsx | combobox.dart | ⚠️ verify overlay anchoring |
| command.tsx | command_palette.dart | ⚠️ renamed (CommandPalette), verify api match |
| context-menu.tsx | context_menu.dart | ✅ |
| dialog.tsx | dialog.dart | ✅ |
| direction.tsx | direction.dart | ✅ |
| drawer.tsx | drawer.dart | ✅ |
| dropdown-menu.tsx | dropdown_menu.dart | ✅ |
| empty.tsx | empty.dart | ✅ |
| field.tsx | field.dart | ✅ |
| hover-card.tsx | hover_card.dart | ✅ |
| input.tsx | input.dart | ✅ |
| input-group.tsx | input_group.dart | ✅ |
| input-otp.tsx | input_otp.dart | ✅ |
| item.tsx | item.dart | ✅ |
| kbd.tsx | kbd.dart | ✅ |
| label.tsx | label.dart | ✅ |
| marker.tsx | marker.dart | ✅ |
| menubar.tsx | menubar.dart | ✅ |
| message.tsx | message.dart | ✅ |
| message-scroller.tsx | message_scroller.dart | ✅ NEW — auto-scroll chat container |
| native-select.tsx | native_select.dart | ✅ |
| navigation-menu.tsx | navigation_menu.dart | ✅ |
| pagination.tsx | pagination.dart | ✅ |
| popover.tsx | popover.dart | ✅ |
| progress.tsx | progress.dart | ✅ |
| questionnaire.tsx | questionnaire.dart | ✅ NEW — multi-step form |
| radio-group.tsx | radio.dart | ✅ (BloomRadioGroup in radio.dart) |
| resizable.tsx | resizable.dart | ✅ |
| scroll-area.tsx | scroll_area.dart | ✅ |
| select.tsx | select.dart | ✅ |
| separator.tsx | separator.dart | ✅ |
| sheet.tsx | sheet.dart | ✅ |
| sidebar.tsx | sidebar.dart | ✅ |
| skeleton.tsx | skeleton.dart | ✅ |
| slider.tsx | slider.dart | ✅ |
| sonner.tsx | toast.dart | ⚠️ sonner = toast with icon variants (success/info/warning/error/loading) |
| spinner.tsx | spinner.dart | ✅ |
| switch.tsx | switch.dart | ✅ |
| table.tsx | table.dart | ✅ |
| tabs.tsx | tabs.dart | ✅ |
| textarea.tsx | textarea.dart | ✅ |
| toast.tsx | toast.dart | ✅ |
| toggle.tsx | toggle.dart | ✅ — recently fixed variants/sizes |
| toggle-group.tsx | toggle.dart | ✅ (BloomToggleGroup in toggle.dart) |
| tooltip.tsx | tooltip.dart | ✅ |
| typography.tsx | typography.dart | ✅ NEW |

## Bloom extras (not in shadcn)
app_shell, auth_form, banner, data_table, date_picker, empty_state, error_state, filter_bar, form, loading_state, multi_select, otp_input, phone_input, pricing_card, search_bar, settings_list, tags_input

## What still needs work
1. **Chart tooltip** needs proper GestureDetector drag tracking (activeIndex flickers because width isn't known in _updateActive — needs LayoutBuilder or GlobalKey to get actual render width)
2. **button_group** needs orientation (horizontal/vertical) and connected-variant (spacing=0, joined borders)
3. **badge** variants — recently added ghost/link but verify _resolveStyle has them
4. **toggle.dart** bloom_ui.dart should export `BloomToggle`, `BloomToggleVariant`, `BloomToggleSize`
5. **alert_dialog.tsx** isn't a separate dart file — BloomDialog covers it, but check if there's a dedicated `BloomAlertDialog` pattern missing
6. **sonner** toast variants — the web sonner has more built-in icon/duration/action patterns
7. **command** has CommandDialog wrapper + Shortcut + Check indicator — BloomCommandPalette might be missing CommandShortcut

## How to verify
```bash
# analyze
cd /root/dev/Bloom/packages/bloom_ui && flutter analyze

# test all (currently 21 pass)
cd /root/dev/Bloom/packages/bloom_ui && flutter test

# test specific
flutter test test/theme_test.dart
flutter test test/primitives_test.dart
```
