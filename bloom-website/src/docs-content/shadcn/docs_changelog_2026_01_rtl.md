# January 2026 - RTL Support - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2026-01-rtl

- [Introduction](/docs)
- [Components](/docs/components)
- [Installation](/docs/installation)
- [Theming](/docs/theming)
- [CLI](/docs/cli)
- [Typeset](/docs/typeset)
- [Skills](/docs/skills)
- [Registry](/docs/registry)
- [Changelog](/docs/changelog)
- [Accordion](/docs/components/base/accordion)
- [Alert](/docs/components/base/alert)
- [Alert Dialog](/docs/components/base/alert-dialog)
- [Aspect Ratio](/docs/components/base/aspect-ratio)
- [Attachment](/docs/components/base/attachment)
- [Avatar](/docs/components/base/avatar)
- [Badge](/docs/components/base/badge)
- [Breadcrumb](/docs/components/base/breadcrumb)
- [Bubble](/docs/components/base/bubble)
- [Button](/docs/components/base/button)
- [Button Group](/docs/components/base/button-group)
- [Calendar](/docs/components/base/calendar)
- [Card](/docs/components/base/card)
- [Carousel](/docs/components/base/carousel)
- [Chart](/docs/components/base/chart)
- [Checkbox](/docs/components/base/checkbox)
- [Collapsible](/docs/components/base/collapsible)
- [Combobox](/docs/components/base/combobox)
- [Command](/docs/components/base/command)
- [Context Menu](/docs/components/base/context-menu)
- [Data Table](/docs/components/base/data-table)
- [Date Picker](/docs/components/base/date-picker)
- [Dialog](/docs/components/base/dialog)
- [Direction](/docs/components/base/direction)
- [Drawer](/docs/components/base/drawer)
- [Dropdown Menu](/docs/components/base/dropdown-menu)
- [Empty](/docs/components/base/empty)
- [Field](/docs/components/base/field)
- [Hover Card](/docs/components/base/hover-card)
- [Input](/docs/components/base/input)
- [Input Group](/docs/components/base/input-group)
- [Input OTP](/docs/components/base/input-otp)
- [Item](/docs/components/base/item)
- [Kbd](/docs/components/base/kbd)
- [Label](/docs/components/base/label)
- [Marker](/docs/components/base/marker)
- [Menubar](/docs/components/base/menubar)
- [Message](/docs/components/base/message)
- [Message Scroller](/docs/components/base/message-scroller)
- [Native Select](/docs/components/base/native-select)
- [Navigation Menu](/docs/components/base/navigation-menu)
- [Pagination](/docs/components/base/pagination)
- [Popover](/docs/components/base/popover)
- [Progress](/docs/components/base/progress)
- [Questionnaire](/docs/components/base/questionnaire)
- [Radio Group](/docs/components/base/radio-group)
- [Resizable](/docs/components/base/resizable)
- [Scroll Area](/docs/components/base/scroll-area)
- [Select](/docs/components/base/select)
- [Separator](/docs/components/base/separator)
- [Sheet](/docs/components/base/sheet)
- [Sidebar](/docs/components/base/sidebar)
- [Skeleton](/docs/components/base/skeleton)
- [Slider](/docs/components/base/slider)
- [Spinner](/docs/components/base/spinner)
- [Switch](/docs/components/base/switch)
- [Table](/docs/components/base/table)
- [Tabs](/docs/components/base/tabs)
- [Textarea](/docs/components/base/textarea)
- [Toast](/docs/components/base/toast)
- [Toggle](/docs/components/base/toggle)
- [Toggle Group](/docs/components/base/toggle-group)
- [Tooltip](/docs/components/base/tooltip)
- [Typography](/docs/components/base/typography)
- [Installation](/docs/installation)
- [components.json](/docs/components-json)
- [Package Imports](/docs/package-imports)
- [Theming](/docs/theming)
- [Typeset](/docs/typeset)
- [Dark Mode](/docs/dark-mode)
- [CLI](/docs/cli)
- [Monorepo](/docs/monorepo)
- [Skills](/docs/skills)
- [JavaScript](/docs/javascript)
- [Figma](/docs/figma)
- [llms.txt](/llms.txt)
- [Legacy Docs](/docs/legacy)
- [Message Scroller](/docs/react/message-scroller)
- [Questionnaire](/docs/react/questionnaire)
- [AI SDK](/docs/helpers/ai-sdk)
- [TanStack AI](/docs/helpers/tanstack-ai)
- [React Hook Form](/docs/forms/react-hook-form)
- [TanStack Form](/docs/forms/tanstack-form)
- [Formisch](/docs/forms/formisch)
- [scroll-fade](/docs/utils/scroll-fade)
- [shimmer](/docs/utils/shimmer)
- [Introduction](/docs/registry)
- [Getting Started](/docs/registry/getting-started)
- [GitHub Registries](/docs/registry/github)
- [Registry Directory](/docs/registry/registry-index)
- [Examples](/docs/registry/examples)
- [Namespaces](/docs/registry/namespace)
- [Authentication](/docs/registry/authentication)
- [Dynamic Search](/docs/registry/dynamic-search)
- [MCP Server](/docs/registry/mcp)
- [Open in v0](/docs/registry/open-in-v0)
- [API Reference](/docs/registry/api-reference)
- [registry.json](/docs/registry/registry-json)
- [registry-item.json](/docs/registry/registry-item-json)
# January 2026 - RTL Support
The shadcn CLI now supports RTL (right-to-left) layouts by automatically converting physical CSS classes to logical equivalents.

shadcn/ui now has first-class support for right-to-left (RTL) layouts. Your components automatically adapt for languages like Arabic, Hebrew, and Persian.

**This works with the [shadcn/ui components](/docs/components) as well as any component distributed on the shadcn registry.**

```
"use client"

import * as React from "react"```

Traditionally, component libraries that support RTL ship with logical classes baked in. This means everyone has to work with classes like `ms-4` and `start-2`, even if they're only building for LTR layouts.

We took a different approach. The shadcn CLI transforms classes at install time, so you only see logical classes when you actually need them. If you're not building for RTL, you work with familiar classes like `ml-4` and `left-2`. When you enable RTL, the CLI handles the conversion for you.

**You don't have to learn RTL until you need it.**

When you add components with `rtl: true` set in your `components.json`, the CLI automatically converts physical CSS classes like `ml-4` and `text-left` to their logical equivalents like `ms-4` and `text-start`.

- Physical positioning classes like `left-*` and `right-*` become `start-*` and `end-*`.
- Margin and padding classes like `ml-*` and `pr-*` become `ms-*` and `pe-*`.
- Text alignment classes like `text-left` become `text-start`.
- Directional props are updated to use logical values.
- Supported icons are automatically flipped using `rtl:rotate-180`.
- Animations like `slide-in-from-left` become `slide-in-from-start`.
We've added RTL examples for every component. You'll find live previews and code on each [component page](/docs/components).

```
"use client"

import * as React from "react"```

**New projects**: Use the `--rtl` flag with `init` or `create` to enable RTL from the start.

```
pnpm dlx shadcn@latest init --rtl```

```
```

```
pnpm dlx shadcn@latest create --rtl```

```
```

**Existing projects**: Migrate your components with the `migrate rtl` command.

```
pnpm dlx shadcn@latest migrate rtl```

```
```

This transforms all components in your `ui` directory to use logical classes. You can also pass a specific path or glob pattern.

Click the link below to open a Next.js project with RTL support in v0.

- [RTL Documentation](/docs/rtl)
- [Font Recommendations](/docs/rtl#font-recommendations)
- [Animations](/docs/rtl#animations)
- [Migrating Existing Components](/docs/rtl#migrating-existing-components)
- [Next.js Setup](/docs/rtl/next)
- [Vite Setup](/docs/rtl/vite)
- [TanStack Start Setup](/docs/rtl/start)
On This Page

