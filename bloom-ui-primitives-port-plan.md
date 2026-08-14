# Bloom UI — Port shadcn/ui Primitives to Flutter

**The complete specification for bringing every shadcn/ui primitive into Bloom UI as reusable, copy-pasteable Flutter widgets.**

Last updated: 2026-08-14 · Status: source of truth for Bloom UI Phase 1 → 4.

Rules that govern every component: one primitive per file, fully typed, theme-token-driven, accessible, tested, copy-pasteable into any Bloom Flutter project, and implemented for **Flutter only**.

---

## 1. Executive direction

Bloom UI adopts the **shadcn/ui ownership model**:

> You own the components. They live in *your* codebase. You can customize them.

But instead of React + Tailwind, Bloom UI is **Dart + Flutter**. Every shadcn primitive is ported to a Flutter widget that:

- Lives in `lib/bloom_ui/primitives/<name>.dart` (or wherever the developer pastes it).
- Uses Bloom design tokens exclusively.
- Exposes a clean, predictable API.
- Works on Android, iOS, Web, and Desktop from day one.
- Is not published as a package dependency; it is scaffolded/copied into the project.

### Why copy-pasteable?

Because Flutter teams often need to customize deeply — native behavior, platform-specific adaptions, custom animations. A black-box package fights them. Copy-pasteable widgets win the way shadcn wins for web.

### Scope

- **Primary target:** Flutter (Dart).
- **No React Native.**
- **No web-only implementation.** Web behavior comes from Flutter's renderer.
- **Source of truth:** shadcn/ui primitives + Radix UI behaviors, reimagined in Flutter idioms.

---

## 2. Design system backbone

Every primitive consumes the Bloom token system. No hardcoded values.

### 2.1 Dart token classes

```dart
// packages/bloom_ui/lib/src/theme/tokens.dart
import 'package:flutter/material.dart';

class BloomColors {
  static const Color petalPink = Color(0xFFFF4B8B);
  static const Color petalOrange = Color(0xFFFF884D);
  static const Color petalCyan = Color(0xFF20C9B0);
  static const Color petalBlue = Color(0xFF3B82F6);
  static const Color petalPurple = Color(0xFF8B5CF6);

  static const Color surface0Light = Color(0xFFFAFAFA);
  static const Color surface1Light = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0x99FFFFFF);
  static const Color borderSubtleLight = Color(0x80E2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const Color surface0Dark = Color(0xFF030509);
  static const Color surface1Dark = Color(0xFF0D1117);
  static const Color surface2Dark = Color(0x990D1117);
  static const Color borderSubtleDark = Color(0x80334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF3B82F6);
}

class BloomSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
}

class BloomRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class BloomTypography {
  static const String sans = 'PlusJakartaSans';
  static const String mono = 'JetBrainsMono';

  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double xl2 = 25;
  static const double xl3 = 31;
}
```

### 2.2 Theme extension

Use Flutter's `ThemeExtension` so `Theme.of(context)` carries Bloom tokens:

```dart
// packages/bloom_ui/lib/src/theme/bloom_theme.dart
@immutable
class BloomTheme extends ThemeExtension<BloomTheme> {
  const BloomTheme({
    required this.colors,
    required this.spacing,
    required this.radius,
    required this.typography,
  });

  final BloomColorScheme colors;
  final BloomSpacing spacing;
  final BloomRadius radius;
  final BloomTypography typography;

  @override
  BloomTheme copyWith({...}) => ...;

  @override
  BloomTheme lerp(BloomTheme? other, double t) => ...;
}
```

Access in widgets:

```dart
final bloom = Theme.of(context).extension<BloomTheme>()!;
bloom.colors.primary;
bloom.radius.md;
```

---

## 3. Full primitive inventory

Every shadcn/ui primitive gets a Flutter widget.

### 3.1 Form primitives

```text
button
icon_button
text_button
floating_action_button
input
textarea
label
checkbox
radio
radio_group
switch
slider
select
dropdown_button
combobox
autocomplete
date_picker
date_range_picker
time_picker
otp_input
pin_input
form
form_field
form_label
form_message
```

### 3.2 Layout primitives

```text
accordion
collapsible
tabs
tab_bar
separator
divider
resizable
scroll_area
aspect_ratio
skeleton
progress
spinner
refresh_indicator
safe_area
```

### 3.3 Overlay primitives

```text
alert_dialog
dialog
modal_barrier
sheet
bottom_sheet
drawer
popover
tooltip
dropdown_menu
context_menu
toast
snack_bar
banner
```

### 3.4 Data display primitives

```text
avatar
badge
chip
card
list_tile
table
data_table
paginated_data_table
pagination
breadcrumb
navigation_menu
navigation_bar
navigation_rail
sidebar
carousel
chart
```

### 3.5 Feedback primitives

```text
alert
banner
empty_state
error_state
loading_state
skeleton
progress_indicator
circular_progress_indicator
linear_progress_indicator
```

### 3.6 Advanced / composite primitives

```text
command_palette
command_dialog
multi_select
tags_input
phone_input
file_upload
dropzone
rich_text_editor
code_block
markdown_view
image_upload
signature_pad
search_bar
filter_bar
app_shell
dashboard_shell
settings_list
pricing_card
auth_form
```

---

## 4. Repository structure

Bloom UI primitives live inside the Bloom monorepo but are consumed by copy-paste, not package import.

```text
packages/bloom_ui/
├── lib/
│   ├── src/
│   │   ├── theme/
│   │   │   ├── tokens.dart
│   │   │   ├── bloom_theme.dart
│   │   │   ├── bloom_color_scheme.dart
│   │   │   └── theme_provider.dart
│   │   ├── primitives/
│   │   │   ├── button.dart
│   │   │   ├── icon_button.dart
│   │   │   ├── input.dart
│   │   │   ├── textarea.dart
│   │   │   ├── checkbox.dart
│   │   │   ├── radio.dart
│   │   │   ├── switch.dart
│   │   │   ├── select.dart
│   │   │   ├── dialog.dart
│   │   │   ├── sheet.dart
│   │   │   ├── bottom_sheet.dart
│   │   │   ├── card.dart
│   │   │   ├── badge.dart
│   │   │   ├── avatar.dart
│   │   │   ├── table.dart
│   │   │   ├── data_table.dart
│   │   │   ├── toast.dart
│   │   │   ├── tooltip.dart
│   │   │   └── ... (one file per primitive)
│   │   ├── utils/
│   │   │   ├── cn.dart            # conditional class-like helpers
│   │   │   ├── extensions.dart    # BuildContext, Color, etc.
│   │   │   └── focus_utils.dart
│   │   └── bloom_ui.dart
│   └── bloom_ui.dart
├── test/
│   ├── primitives/
│   │   ├── button_test.dart
│   │   ├── input_test.dart
│   │   └── ...
│   └── theme_test.dart
├── example/
│   └── lib/
│       └── main.dart              # primitive gallery
├── pubspec.yaml
└── README.md
```

When a developer runs:

```bash
bloom ui add button
```

The CLI copies `packages/bloom_ui/lib/src/primitives/button.dart` (and any dependencies) into their project's `lib/bloom_ui/primitives/button.dart`.

---

## 5. Widget contract template

Every primitive follows this structure.

### 5.1 File header

```dart
// primitives/button.dart
import 'package:flutter/material.dart';
import '../theme/bloom_theme.dart';
import '../utils/extensions.dart';
```

### 5.2 Public types

```dart
enum BloomButtonVariant {
  defaultVariant,
  destructive,
  outline,
  secondary,
  ghost,
  link,
}

enum BloomButtonSize {
  defaultSize,
  sm,
  lg,
  icon,
}

class BloomButton extends StatelessWidget {
  const BloomButton({
    super.key,
    this.variant = BloomButtonVariant.defaultVariant,
    this.size = BloomButtonSize.defaultSize,
    this.loading = false,
    this.disabled = false,
    this.leftIcon,
    this.rightIcon,
    required this.onPressed,
    required this.child,
  });

  final BloomButtonVariant variant;
  final BloomButtonSize size;
  final bool loading;
  final bool disabled;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    final colors = _resolveColors(theme);
    final dimensions = _resolveDimensions();

    return InkWell(
      onTap: loading || disabled ? null : onPressed,
      borderRadius: BorderRadius.circular(theme.radius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: dimensions.height,
        padding: dimensions.padding,
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(theme.radius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(colors.foreground),
                ),
              )
            else if (leftIcon != null)
              Padding(padding: const EdgeInsets.only(right: 8), child: leftIcon!),
            DefaultTextStyle(
              style: TextStyle(
                color: colors.foreground,
                fontSize: theme.typography.sm,
                fontFamily: theme.typography.sans,
                fontWeight: FontWeight.w500,
              ),
              child: child,
            ),
            if (rightIcon != null)
              Padding(padding: const EdgeInsets.only(left: 8), child: rightIcon!),
          ],
        ),
      ),
    );
  }
}
```

### 5.3 Private helpers

```dart
class _ButtonColors {
  const _ButtonColors({required this.background, required this.foreground, required this.border});
  final Color background;
  final Color foreground;
  final Color border;
}

_ButtonColors _resolveColors(BloomTheme theme) {
  final c = theme.colors;
  return const _ButtonColors(
    background: c.primary,
    foreground: c.primaryForeground,
    border: c.primary,
  );
}

class _ButtonDimensions {
  const _ButtonDimensions({required this.height, required this.padding});
  final double height;
  final EdgeInsetsGeometry padding;
}

_ButtonDimensions _resolveDimensions() {
  return const _ButtonDimensions(
    height: 40,
    padding: EdgeInsets.symmetric(horizontal: 16),
  );
}
```

---

## 6. Port strategy per primitive category

### 6.1 Buttons

| Primitive | Flutter widget base | Notes |
|-----------|---------------------|-------|
| `Button` | `InkWell` + `Container` | All variants, sizes, loading, icons |
| `IconButton` | `IconButton` / custom `InkWell` | Circular press ripple |
| `TextButton` | `TextButton` themed | Minimal styling wrapper |
| `FloatingActionButton` | `FloatingActionButton` | Bloom colors |
| `Toggle` | `GestureDetector` + state | On/off with animation |
| `ToggleGroup` | `Row` of `InkWell` | Single/multi select |

### 6.2 Inputs

| Primitive | Flutter widget base | Notes |
|-----------|---------------------|-------|
| `Input` | `TextField` | Bloom `InputDecoration` |
| `Textarea` | `TextField` with `maxLines` | Same as Input, multiline |
| `Label` | `Text` | Semantics label helper |
| `Form` | `Form` widget | Validation integration |
| `FormField` | `FormField<T>` | Error display |
| `FormMessage` | `Text` | Inline error text |

### 6.3 Selection

| Primitive | Flutter widget base | Notes |
|-----------|---------------------|-------|
| `Checkbox` | `Checkbox` / `CheckboxListTile` | Bloom colors |
| `Radio` | `Radio` | Part of `RadioGroup` |
| `RadioGroup` | `Column` + `Radio` | Controlled group |
| `Switch` | `Switch` | Bloom track/thumb colors |
| `Slider` | `Slider` / `RangeSlider` | Bloom active/inactive colors |
| `Select` | `DropdownButton` / bottom sheet | Native dropdown or sheet |
| `Combobox` | `Autocomplete` | Searchable selection |
| `DatePicker` | `showDatePicker` | Themed dialog |
| `TimePicker` | `showTimePicker` | Themed dialog |
| `OTPInput` | `Row` of `TextField` | Auto-focus, paste support |
| `PinInput` | `Row` of `TextField` | Masked like OTP |

### 6.4 Overlays

| Primitive | Flutter widget base | Notes |
|-----------|---------------------|-------|
| `Dialog` | `AlertDialog` / `Dialog` | Full-screen or centered |
| `AlertDialog` | `AlertDialog` | Destructive actions |
| `Sheet` | custom animated `Container` | Modal sheet from bottom |
| `BottomSheet` | `showModalBottomSheet` | Native bottom sheet |
| `Drawer` | `Drawer` / `EndDrawer` | Side panel |
| `Popover` | `OverlayEntry` | Anchored floating panel |
| `Tooltip` | `Tooltip` | Themed |
| `DropdownMenu` | `PopupMenuButton` | Menu with items |
| `ContextMenu` | long-press `GestureDetector` + overlay | Right-click/long-press |
| `Toast` | `OverlayEntry` | Stacked toast notifications |
| `SnackBar` | `SnackBar` | Material base, Bloom style |
| `Banner` | `MaterialBanner` | Top-level announcement |

### 6.5 Layout

| Primitive | Flutter widget base | Notes |
|-----------|---------------------|-------|
| `Accordion` | `ExpansionPanelList` / custom | Expand/collapse sections |
| `Collapsible` | `AnimatedContainer` | Simple show/hide |
| `Tabs` | `TabBar` + `TabBarView` | Themed |
| `Separator` | `Divider` | Themed color |
| `ScrollArea` | `SingleChildScrollView` | With custom scrollbar |
| `AspectRatio` | `AspectRatio` | Themed wrapper |
| `Skeleton` | `Shimmer`-like `Container` | Animated placeholder |
| `Progress` | `LinearProgressIndicator` | Themed |
| `Spinner` | `CircularProgressIndicator` | Themed |

### 6.6 Data display

| Primitive | Flutter widget base | Notes |
|-----------|---------------------|-------|
| `Avatar` | `CircleAvatar` | Fallback initials |
| `Badge` | `Container` + `Text` | Status/count |
| `Chip` | `Chip` / `ActionChip` | Themed |
| `Card` | `Card` | With Bloom elevation |
| `Table` | `Table` | Simple static table |
| `DataTable` | `DataTable` | Sortable, selectable |
| `PaginatedDataTable` | `PaginatedDataTable` | Pagination built-in |
| `Pagination` | `Row` of `InkWell` | Page numbers |
| `Breadcrumb` | `Row` of `InkWell` | Navigation path |
| `NavigationMenu` | `NavigationBar` | Bottom/top nav |
| `Sidebar` | `NavigationRail` / custom | Collapsible side nav |
| `Carousel` | `PageView` | With indicators |
| `Chart` | `fl_chart` | Line/bar/pie charts |

### 6.7 Feedback

| Primitive | Flutter widget base | Notes |
|-----------|---------------------|-------|
| `Alert` | `Container` + `Row` + icon | Callout box |
| `EmptyState` | `Column` + icon + text + CTA | Consistent empty screens |
| `ErrorState` | `Column` + icon + retry | Error retry pattern |
| `LoadingState` | `Center` + `Spinner` / `Skeleton` | Loading screens |

### 6.8 Advanced / composite

| Primitive | Approach |
|-----------|----------|
| `CommandPalette` | `showSearch` + `SearchDelegate` or custom overlay |
| `MultiSelect` | Bottom sheet with checkboxes |
| `TagsInput` | `Wrap` of `Chip` + `TextField` |
| `PhoneInput` | `TextField` + country picker |
| `FileUpload` | `file_picker` + drag-and-drop on desktop/web |
| `Dropzone` | `DropTarget` (desktop/web) / button (mobile) |
| `RichTextEditor` | `flutter_quill` wrapped in Bloom style |
| `CodeBlock` | `flutter_highlight` or custom |
| `MarkdownView` | `flutter_markdown` |
| `ImageUpload` | `image_picker` + cropper |
| `SignaturePad` | `signature` package |
| `SearchBar` | `SearchBar` / `SearchAnchor` (Material 3) |
| `FilterBar` | `Row` of `Chip` + `Select` |
| `AppShell` | `Scaffold` + custom app/nav bars |
| `DashboardShell` | `Scaffold` + `NavigationRail` + content |
| `SettingsList` | `ListView` of `ListTile` groups |
| `PricingCard` | `Card` with feature list + CTA |
| `AuthForm` | pre-built email/password form |

---

## 7. Theming strategy

### 7.1 Material 3 + Bloom tokens

Bloom UI does not fight Material 3; it themes it.

```dart
MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: bloomColorSchemeLight,
    fontFamily: BloomTypography.sans,
    extensions: [bloomThemeLight],
  ),
  darkTheme: ThemeData(
    useMaterial3: true,
    colorScheme: bloomColorSchemeDark,
    fontFamily: BloomTypography.sans,
    extensions: [bloomThemeDark],
  ),
  home: const MyApp(),
);
```

### 7.2 Input decoration

Provide a `BloomInputDecoration` helper:

```dart
InputDecoration bloomInputDecoration(BuildContext context, {String? hintText}) {
  final theme = context.bloomTheme;
  return InputDecoration(
    filled: true,
    fillColor: theme.colors.surface2,
    hintText: hintText,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.radius.md),
      borderSide: BorderSide(color: theme.colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.radius.md),
      borderSide: BorderSide(color: theme.colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.radius.md),
      borderSide: BorderSide(color: theme.colors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.radius.md),
      borderSide: BorderSide(color: theme.colors.error),
    ),
  );
}
```

---

## 8. Composition patterns

### 8.1 Compound widgets

Complex primitives use named constructors or helper widgets:

```dart
BloomCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BloomCardHeader(
        title: const Text('Deployment Status'),
        subtitle: const Text('Track your release across platforms.'),
      ),
      BloomCardContent(
        child: BloomStatusBadge(status: BloomStatus.running, label: 'Processing'),
      ),
      BloomCardFooter(
        child: BloomButton(
          onPressed: () {},
          child: const Text('View Details'),
        ),
      ),
    ],
  ),
)
```

### 8.2 Builder patterns for dynamic content

```dart
BloomDataTable<Release>(
  columns: [
    BloomDataColumn(label: const Text('Version'), value: (r) => r.version),
    BloomDataColumn(label: const Text('Status'), value: (r) => r.status),
  ],
  rows: releases,
)
```

### 8.3 Controlled vs uncontrolled

Every stateful widget supports both:

```dart
// Uncontrolled
BloomCheckbox(
  defaultChecked: true,
  onChanged: (value) {},
)

// Controlled
BloomCheckbox(
  checked: checked,
  onChanged: (value) => setState(() => checked = value),
)
```

Internally use a `BloomControllableValue<T>` helper.

---

## 9. Accessibility

Every interactive primitive must:

- Use `Semantics` widget with correct `label`, `hint`, and `value`.
- Set `excludeSemantics` only when providing a better custom semantics node.
- Support screen readers (TalkBack / VoiceOver) without extra work.
- Respect `MediaQuery.highContrast` and `MediaQuery.boldText`.
- Support focus traversal with `FocusNode`.
- Provide visual focus indicators (outline/ripple).

Example:

```dart
Semantics(
  button: true,
  label: 'Submit form',
  hint: 'Double tap to submit',
  child: BloomButton(...),
)
```

---

## 10. Testing strategy

### 10.1 Unit tests

- Token resolution.
- Color contrast calculations.
- Variant/style helper outputs.
- `BloomControllableValue` behavior.

### 10.2 Widget tests

For every primitive:

- Renders all variants.
- Taps/presses fire callbacks.
- Controlled state updates.
- Error/disabled states.
- Accessibility semantics.

```dart
testWidgets('Button calls onPressed when tapped', (tester) async {
  var pressed = false;
  await tester.pumpWidget(
    MaterialApp(
      home: BloomButton(
        onPressed: () => pressed = true,
        child: const Text('Tap me'),
      ),
    ),
  );
  await tester.tap(find.text('Tap me'));
  expect(pressed, true);
});
```

### 10.3 Golden tests

- Light and dark theme screenshots for each primitive variant.
- Run in CI on every PR.

### 10.4 Integration tests

- Full user flows: open dialog → fill form → submit → show toast.
- Command palette search.
- Data table sorting/filtering.

---

## 11. CLI consumption

The Bloom CLI installs primitives by copy-paste:

```bash
bloom ui add button
bloom ui add card dialog sheet
bloom ui add all
```

The CLI:

1. Reads `packages/bloom_ui/lib/src/primitives/<name>.dart`.
2. Resolves local dependencies (other primitives, theme files, utils).
3. Copies files into the user's project at `lib/bloom_ui/primitives/`.
4. Adds required dependencies to `pubspec.yaml` if missing.
5. Prints usage example.

---

## 12. Phased implementation

### Phase 0 — Foundation

- Set up `packages/bloom_ui` package.
- Implement full token system (`tokens.dart`, `bloom_theme.dart`, `bloom_color_scheme.dart`).
- Implement helpers: `cn`, `extensions`, `focus_utils`, `controllable_value`.
- Set up testing, example gallery, CI.
- Port `BloomButton`, `BloomIconButton`, `BloomText`.

### Phase 1 — Core form primitives

1. `BloomLabel`
2. `BloomInput`
3. `BloomTextarea`
4. `BloomCheckbox`
5. `BloomSwitch`
6. `BloomRadio` + `BloomRadioGroup`
7. `BloomSlider`
8. `BloomSelect`
9. `BloomForm` + `BloomFormField` + `BloomFormMessage`
10. `BloomDatePicker`
11. `BloomOTPInput`

### Phase 2 — Layout and feedback

1. `BloomCard` + `BloomCardHeader/Content/Footer`
2. `BloomSeparator` / `BloomDivider`
3. `BloomAccordion`
4. `BloomCollapsible`
5. `BloomTabs`
6. `BloomScrollArea`
7. `BloomSkeleton`
8. `BloomProgress`
9. `BloomSpinner`
10. `BloomAspectRatio`

### Phase 3 — Overlays

1. `BloomDialog`
2. `BloomAlertDialog`
3. `BloomSheet`
4. `BloomBottomSheet`
5. `BloomDrawer`
6. `BloomPopover`
7. `BloomTooltip`
8. `BloomDropdownMenu`
9. `BloomContextMenu`
10. `BloomToast` / `BloomSnackBar`
11. `BloomBanner`

### Phase 4 — Data display

1. `BloomAvatar`
2. `BloomBadge` / `BloomChip`
3. `BloomTable`
4. `BloomDataTable`
5. `BloomPagination`
6. `BloomBreadcrumb`
7. `BloomNavigationMenu` / `BloomNavigationBar` / `BloomNavigationRail`
8. `BloomSidebar`
9. `BloomCarousel`
10. `BloomChart`

### Phase 5 — Advanced composites

1. `BloomCommandPalette`
2. `BloomMultiSelect`
3. `BloomTagsInput`
4. `BloomPhoneInput`
5. `BloomFileUpload`
6. `BloomDropzone`
7. `BloomRichTextEditor`
8. `BloomCodeBlock`
9. `BloomMarkdownView`
10. `BloomImageUpload`
11. `BloomSignaturePad`

### Phase 6 — Shell and page-level components

1. `BloomAppShell`
2. `BloomDashboardShell`
3. `BloomSearchBar`
4. `BloomFilterBar`
5. `BloomSettingsList`
6. `BloomPricingCard`
7. `BloomAuthForm`
8. `BloomEmptyState`
9. `BloomErrorState`
10. `BloomLoadingState`

### Phase 7 — Polish and ecosystem

- Theme builder CLI.
- Figma component kit.
- Documentation site (same design system as bloomcloud.dev).
- Marketplace/templates integration.
- Performance audit and bundle analysis.

---

## 13. Verification checklist

Before any primitive ships:

- [ ] Implemented in Dart for Flutter.
- [ ] Works on Android, iOS, Web, and Desktop.
- [ ] Uses Bloom tokens only.
- [ ] All variants/sizes render correctly.
- [ ] Controlled and uncontrolled modes work.
- [ ] Accessibility semantics set.
- [ ] Widget tests pass (`flutter test`).
- [ ] Golden tests pass for light + dark themes.
- [ ] No hardcoded values.
- [ ] README usage example is correct.
- [ ] CLI can install it cleanly.

---

## 14. Definition of done

Bloom UI primitives are done when:

1. Every shadcn/ui primitive exists as a Flutter widget.
2. The token system is the only styling source of truth.
3. Components are copy-pasteable via `bloom ui add <primitive>`.
4. Accessibility works on all platforms.
5. Tests and golden images exist for every primitive.
6. The design language matches the Bloom marketing site.
7. The example gallery demonstrates every primitive in light and dark mode.
