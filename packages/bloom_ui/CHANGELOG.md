# Changelog

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
