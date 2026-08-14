# 🌸 Bloom UI

**Reusable, accessible, token-driven Flutter UI primitives inspired by [shadcn/ui](https://ui.shadcn.com).**

Built with **zero runtime dependencies** beyond Flutter itself. Use as a package or copy-paste directly into your apps with the `bloom ui` CLI.

---

## ✨ Features

- 🎯 **1-to-1 shadcn/ui Parity**: Every component, variant, slot, and sizing scale calibrated to exact specifications.
- 🪶 **Zero Dependencies**: Pure Flutter canvas, render objects, and widgets — no third-party runtime bloat.
- 🎨 **Multi-Theme Engine**: 8 out-of-the-box style themes (*Nova, Vega, Maia, Lyra, Mira, Luma, Sera, Rhea*) and full dark mode support.
- 📐 **Design Token System**: Modular 4px spacing grid, typography scale, elevation shadows, and spring motion curves.
- 📊 **Pure Dart Chart Suite**: Area, Bar, Line, Pie, Radar, and Radial charts with responsive drag tooltips.
- 📋 **Copy-Paste or Package**: Use `bloom_ui` from pub.dev or copy individual components with `bloom ui add <name>`.

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_ui: ^0.1.0
```

Or install via Flutter CLI:

```bash
flutter pub add bloom_ui
```

---

## 🚀 Quick Start

### 1. Setup Theme

Wrap your `MaterialApp` with the `BloomTheme`:

```dart
import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom App',
      theme: ThemeData(
        brightness: Brightness.light,
        extensions: const [BloomTheme.light], // or BloomTheme.novaLight, etc.
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        extensions: const [BloomTheme.dark],
      ),
      home: const MyHomePage(),
    );
  }
}
```

### 2. Use Primitives

```dart
import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: BloomCard(
          header: const BloomCardHeader(
            title: BloomCardTitle('Create Project'),
            description: BloomCardDescription('Deploy your new Flutter app in one click.'),
          ),
          content: Column(
            children: [
              BloomField(
                label: const BloomFieldLabel('Project Name', required: true),
                child: BloomInput(
                  placeholder: 'my-awesome-app',
                  leading: const Icon(Icons.folder_outlined, size: 16),
                ),
              ),
              const SizedBox(height: 12),
              BloomField(
                label: const BloomFieldLabel('Framework Style'),
                child: BloomSelect<String>(
                  value: 'nova',
                  items: const [
                    BloomSelectItem(value: 'nova', label: 'Nova (Neutral & Crisp)'),
                    BloomSelectItem(value: 'vega', label: 'Vega (Warm Amber)'),
                    BloomSelectItem(value: 'lyra', label: 'Lyra (Tech Violet)'),
                  ],
                  onChanged: (val) {},
                ),
              ),
            ],
          ),
          footer: BloomCardFooter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BloomButton(
                  variant: BloomButtonVariant.outline,
                  size: BloomButtonSize.sm,
                  onPressed: () {},
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                BloomButton(
                  variant: BloomButtonVariant.defaultVariant,
                  size: BloomButtonSize.sm,
                  onPressed: () {
                    BloomSonner.success(context, 'Project created successfully!');
                  },
                  child: const Text('Deploy'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 🛠️ CLI Copy-Paste Workflow

If you prefer copying components directly into your codebase (shadcn-style):

```bash
# List all available primitives
bloom ui list

# Copy a single primitive + tokens to lib/bloom_ui/
bloom ui add button
bloom ui add chart
bloom ui add dialog

# Copy the entire component library
bloom ui add all

# Initialize theme tokens only
bloom ui init
```

---

## 🧩 Component Suite

| Category | Primitives |
|---|---|
| **Form Controls** | `BloomButton`, `BloomButtonGroup`, `BloomInput`, `BloomInputGroup`, `BloomInputOtp`, `BloomTextarea`, `BloomLabel`, `BloomCheckbox`, `BloomRadio`, `BloomSwitch`, `BloomSlider`, `BloomSelect`, `BloomNativeSelect`, `BloomCombobox`, `BloomToggle`, `BloomToggleGroup`, `BloomCalendar`, `BloomField`, `BloomForm` |
| **Layout & Structure** | `BloomAccordion`, `BloomCollapsible`, `BloomTabs`, `BloomSeparator`, `BloomScrollArea`, `BloomResizable`, `BloomAspectRatio`, `BloomSkeleton`, `BloomProgress`, `BloomSpinner` |
| **Feedback & Overlays** | `BloomAlert`, `BloomAlertDialog`, `BloomDialog`, `BloomSheet`, `BloomDrawer`, `BloomPopover`, `BloomTooltip`, `BloomHoverCard`, `BloomDropdownMenu`, `BloomContextMenu`, `BloomMenubar`, `BloomToast`, `BloomSonner`, `BloomDirection` |
| **Data Display & AI** | `BloomAvatar`, `BloomBadge`, `BloomCard`, `BloomEmpty`, `BloomItem`, `BloomKbd`, `BloomMarker`, `BloomTable`, `BloomDataTable`, `BloomPagination`, `BloomBreadcrumb`, `BloomNavigationMenu`, `BloomSidebar`, `BloomCarousel`, `BloomMessage`, `BloomBubble`, `BloomAttachment`, `BloomMessageScroller`, `BloomQuestionnaire` |
| **Pure Dart Charts** | `BloomChart` (Area, Bar, Line, Pie, Radar, Radial) with interactive tooltip tracking |
| **Composites & Shells** | `BloomCommandPalette`, `BloomMultiSelect`, `BloomTagsInput`, `BloomPhoneInput`, `BloomSearchBar`, `BloomFilterBar`, `BloomSettingsList`, `BloomPricingCard`, `BloomAuthForm`, `BloomAppShell`, `BloomDashboardShell` |

---

## 📄 License

MIT © Bloom Framework Authors
