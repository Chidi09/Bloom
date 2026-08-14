# Context Menu - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/radix/context-menu

- [Introduction](/docs)
- [Components](/docs/components)
- [Installation](/docs/installation)
- [Theming](/docs/theming)
- [CLI](/docs/cli)
- [Typeset](/docs/typeset)
- [Skills](/docs/skills)
- [Registry](/docs/registry)
- [Changelog](/docs/changelog)
- [Accordion](/docs/components/radix/accordion)
- [Alert](/docs/components/radix/alert)
- [Alert Dialog](/docs/components/radix/alert-dialog)
- [Aspect Ratio](/docs/components/radix/aspect-ratio)
- [Attachment](/docs/components/radix/attachment)
- [Avatar](/docs/components/radix/avatar)
- [Badge](/docs/components/radix/badge)
- [Breadcrumb](/docs/components/radix/breadcrumb)
- [Bubble](/docs/components/radix/bubble)
- [Button](/docs/components/radix/button)
- [Button Group](/docs/components/radix/button-group)
- [Calendar](/docs/components/radix/calendar)
- [Card](/docs/components/radix/card)
- [Carousel](/docs/components/radix/carousel)
- [Chart](/docs/components/radix/chart)
- [Checkbox](/docs/components/radix/checkbox)
- [Collapsible](/docs/components/radix/collapsible)
- [Combobox](/docs/components/radix/combobox)
- [Command](/docs/components/radix/command)
- [Context Menu](/docs/components/radix/context-menu)
- [Data Table](/docs/components/radix/data-table)
- [Date Picker](/docs/components/radix/date-picker)
- [Dialog](/docs/components/radix/dialog)
- [Direction](/docs/components/radix/direction)
- [Drawer](/docs/components/radix/drawer)
- [Dropdown Menu](/docs/components/radix/dropdown-menu)
- [Empty](/docs/components/radix/empty)
- [Field](/docs/components/radix/field)
- [Hover Card](/docs/components/radix/hover-card)
- [Input](/docs/components/radix/input)
- [Input Group](/docs/components/radix/input-group)
- [Input OTP](/docs/components/radix/input-otp)
- [Item](/docs/components/radix/item)
- [Kbd](/docs/components/radix/kbd)
- [Label](/docs/components/radix/label)
- [Marker](/docs/components/radix/marker)
- [Menubar](/docs/components/radix/menubar)
- [Message](/docs/components/radix/message)
- [Message Scroller](/docs/components/radix/message-scroller)
- [Native Select](/docs/components/radix/native-select)
- [Navigation Menu](/docs/components/radix/navigation-menu)
- [Pagination](/docs/components/radix/pagination)
- [Popover](/docs/components/radix/popover)
- [Progress](/docs/components/radix/progress)
- [Questionnaire](/docs/components/radix/questionnaire)
- [Radio Group](/docs/components/radix/radio-group)
- [Resizable](/docs/components/radix/resizable)
- [Scroll Area](/docs/components/radix/scroll-area)
- [Select](/docs/components/radix/select)
- [Separator](/docs/components/radix/separator)
- [Sheet](/docs/components/radix/sheet)
- [Sidebar](/docs/components/radix/sidebar)
- [Skeleton](/docs/components/radix/skeleton)
- [Slider](/docs/components/radix/slider)
- [Sonner](/docs/components/radix/sonner)
- [Spinner](/docs/components/radix/spinner)
- [Switch](/docs/components/radix/switch)
- [Table](/docs/components/radix/table)
- [Tabs](/docs/components/radix/tabs)
- [Textarea](/docs/components/radix/textarea)
- [Toast](/docs/components/radix/toast)
- [Toggle](/docs/components/radix/toggle)
- [Toggle Group](/docs/components/radix/toggle-group)
- [Tooltip](/docs/components/radix/tooltip)
- [Typography](/docs/components/radix/typography)
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
# Context Menu
Displays a menu of actions triggered by a right click.

```
import {
  ContextMenu,
  ContextMenuCheckboxItem,```

```
pnpm dlx shadcn@latest add context-menu```

```
```

```
Copyimport {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
} from "@/components/ui/context-menu"```

```
Copy<ContextMenu>
  <ContextMenuTrigger>Right click here</ContextMenuTrigger>
  <ContextMenuContent>
    <ContextMenuItem>Profile</ContextMenuItem>
    <ContextMenuItem>Billing</ContextMenuItem>
    <ContextMenuItem>Team</ContextMenuItem>
    <ContextMenuItem>Subscription</ContextMenuItem>
  </ContextMenuContent>
</ContextMenu>```

Use the following composition to build a `ContextMenu`:

```
CopyContextMenu
├── ContextMenuTrigger
└── ContextMenuContent
    ├── ContextMenuGroup
    │   ├── ContextMenuLabel
    │   ├── ContextMenuItem
    │   └── ContextMenuItem
    ├── ContextMenuSeparator
    ├── ContextMenuGroup
    │   ├── ContextMenuLabel
    │   ├── ContextMenuCheckboxItem
    │   └── ContextMenuCheckboxItem
    ├── ContextMenuSeparator
    ├── ContextMenuGroup
    │   ├── ContextMenuLabel
    │   └── ContextMenuRadioGroup
    │       ├── ContextMenuRadioItem
    │       └── ContextMenuRadioItem
    └── ContextMenuSub
        ├── ContextMenuSubTrigger
        └── ContextMenuSubContent
            └── ContextMenuGroup
                ├── ContextMenuItem
                └── ContextMenuItem```

A simple context menu with a few actions.

```
import {
  ContextMenu,
  ContextMenuContent,```

Use `ContextMenuSub` to nest secondary actions.

```
import {
  ContextMenu,
  ContextMenuContent,```

Add `ContextMenuShortcut` to show keyboard hints.

```
import {
  ContextMenu,
  ContextMenuContent,```

Group related actions and separate them with dividers.

```
import {
  ContextMenu,
  ContextMenuContent,```

Combine icons with labels for quick scanning.

```
import {
  ClipboardPasteIcon,
  CopyIcon,```

Use `ContextMenuCheckboxItem` for toggles.

```
import {
  ContextMenu,
  ContextMenuCheckboxItem,```

Use `ContextMenuRadioItem` for exclusive choices.

```
"use client"

import * as React from "react"```

Use `variant="destructive"` to style the menu item as destructive.

```
import { PencilIcon, ShareIcon, TrashIcon } from "lucide-react"

import {```

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

```
"use client"

import * as React from "react"```

See the [Radix UI](https://www.radix-ui.com/docs/primitives/components/context-menu#api-reference) documentation for more information.

On This Page

