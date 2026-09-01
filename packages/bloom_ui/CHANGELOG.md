# Changelog

## 0.3.0 - 2026-09-01

Bloom UI no longer depends on Flutter's Material library. Every primitive is now built
on `package:flutter/widgets.dart` alone. The package still has zero runtime dependencies.

### Breaking

* `BloomTheme` no longer extends `ThemeExtension`. Install it with the new
  `BloomThemeProvider` (or `BloomApp`) instead of `ThemeData(extensions: [...])`.
  `context.bloomTheme`, `context.bloomColors`, `context.bloomRadius`,
  `context.bloomSpacing` and `context.bloomTypography` are unchanged, so widget code
  that reads the theme needs no edit.
* `BloomTheme.lerp` now takes a `BloomTheme?` rather than a `ThemeExtension<BloomTheme>?`.

### Added

* `BloomApp` and `BloomScaffold`, Material-free replacements for `MaterialApp` and
  `Scaffold`, built on `WidgetsApp`. `BloomApp.router` supports declarative routing
  (go_router and friends) via `WidgetsApp.router`.
* `BloomThemeProvider`, an `InheritedWidget` carrying the active `BloomTheme`.
* `BloomPressable` (hover/focus/press states without an ink ripple), `BloomSurface`
  (elevated surface on `PhysicalModel`), and `BloomPageRoute`.
* `BloomEditableField`, a text input on core `EditableText`, together with
  `BloomTextSelectionControls` — hand-painted selection handles and a context-menu
  toolbar, replacing the ones Material used to supply.
* `showBloomDialog` and `showBloomSheet` on `PopupRoute`, and `BloomToastHost` in place
  of `ScaffoldMessenger`/`SnackBar`.
* `BloomIcon` and `BloomIcons`, a 40-icon vector set drawn on a 24×24 grid — no icon
  font and no third-party icon package.
* `BloomSpinner.value` for a determinate progress ring; the spinner remains
  indeterminate when `value` is null, with unchanged rendering.
* `BloomEditableField.focusedDecoration`, so a field with a custom `decoration` can
  still show a focus ring. Previously an explicit `decoration` silently suppressed it.

### Changed

* `BloomColors` gained `transparent`, `white` and `black` constants.

## 0.2.0 - 2026-08-23

- Substantial expansion of the component set and token system across 70 files.
  See the repository history for the full component-by-component detail.

## 0.1.0

### Initial Release — 100% shadcn/ui Primitives for Flutter
- **Zero Runtime Dependencies**: All components built exclusively using Flutter foundational rendering & canvas APIs.
- **59+ shadcn Primitives**:
  - **Form**: `BloomButton`, `BloomButtonGroup`, `BloomInput`, `BloomInputGroup`, `BloomInputOtp`, `BloomTextarea`, `BloomLabel`, `BloomCheckbox`, `BloomRadio`, `BloomSwitch`, `BloomSlider`, `BloomSelect`, `BloomNativeSelect`, `BloomCombobox`, `BloomToggle`, `BloomToggleGroup`, `BloomCalendar`, `BloomField`, `BloomForm`.
  - **Layout**: `BloomAccordion`, `BloomCollapsible`, `BloomTabs`, `BloomSeparator`, `BloomScrollArea`, `BloomResizable`, `BloomAspectRatio`, `BloomSkeleton`, `BloomProgress`, `BloomSpinner`.
  - **Feedback & Overlays**: `BloomAlert`, `BloomAlertDialog`, `BloomDialog`, `BloomSheet`, `BloomDrawer`, `BloomPopover`, `BloomTooltip`, `BloomHoverCard`, `BloomDropdownMenu`, `BloomContextMenu`, `BloomMenubar`, `BloomToast`, `BloomSonner`, `BloomDirection`.
  - **Data Display & AI**: `BloomAvatar`, `BloomBadge`, `BloomCard`, `BloomEmpty`, `BloomItem`, `BloomKbd`, `BloomMarker`, `BloomTable`, `BloomDataTable`, `BloomPagination`, `BloomBreadcrumb`, `BloomNavigationMenu`, `BloomSidebar`, `BloomCarousel`, `BloomMessage`, `BloomBubble`, `BloomAttachment`, `BloomMessageScroller`, `BloomQuestionnaire`.
  - **Charts Suite**: Pure Dart implementations of Area, Bar, Line, Pie, Radar, and Radial charts with responsive drag tracking and custom tooltips.
- **Design Tokens & Theme Engine**:
  - Modular scales for Colors (5-petal palette), Spacing (4px grid), Radius, Typography, Shadows, and Motion.
  - 8 style presets (Nova, Vega, Maia, Lyra, Mira, Luma, Sera, Rhea) with `ThemeExtension` integration and `context.bloomColors` accessors.
- **CLI Integration**:
  - `bloom ui add <component>`, `bloom ui add all`, `bloom ui list`, and `bloom ui init`.
