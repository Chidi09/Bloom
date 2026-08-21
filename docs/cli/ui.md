# `bloom ui` CLI Reference Manual

The `bloom ui` command suite provides **Shadcn-style copy-paste UI component management** directly into your project's `lib/ui/` directory.

---

## 1. `bloom ui add` — Add UI Component

Copies zero-dependency, dark-themed Bloom UI primitives directly into your codebase. You own the code; no opaque third-party binary package lock-in.

```bash
bloom ui add <component_name> [options]
```

### Supported Primitives

| Primitive | Target Directory | Description |
| :--- | :--- | :--- |
| `button` | `lib/ui/button.dart` | High-contrast button with default, secondary, outline, ghost, and destructive variants. |
| `badge` | `lib/ui/badge.dart` | Status badge with priority indicators (`p1`, `p2`, `p3`, `p4`) and counter pill styles. |
| `card` | `lib/ui/card.dart` | Elevated surface card with carbon borders (`#1E1E24`) and hover transitions. |
| `input` | `lib/ui/input.dart` | Controlled text input with focus ring and error state borders. |
| `kbd` | `lib/ui/kbd.dart` | Monospace keyboard shortcut keycap badge (<kbd>⌘K</kbd>, <kbd>Q</kbd>). |
| `avatar` | `lib/ui/avatar.dart` | User avatar with image fallback and initials generator. |
| `checkbox` | `lib/ui/checkbox.dart` | Custom vector SVG checkbox with toggle animations. |
| `separator` | `lib/ui/separator.dart` | Horizontal and vertical carbon divider lines. |
| `dialog` | `lib/ui/dialog.dart` | Modal dialog with dark backdrop blur and keyboard escape listener. |
| `dropdown` | `lib/ui/dropdown.dart` | Popover menu with keyboard navigation. |

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--overwrite` | Overwrites existing component file if already present. | `false` |
| `--all` | Installs all available Bloom UI primitives simultaneously. | `false` |

---

## 2. `bloom ui list` — List Available Primitives

Displays all official Bloom UI primitives, their installation status in the current project, and file paths.

```bash
bloom ui list
```

---

## 3. `bloom ui diff` — Component Diff Inspector

Compares your local `lib/ui/` components against upstream Bloom design system definitions to highlight any local customizations or upstream improvements.

```bash
bloom ui diff [component_name]
```
