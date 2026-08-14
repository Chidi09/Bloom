# Marker - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/radix/marker

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
# Marker
Displays an inline status, system note, bordered row, or labeled separator in a conversation.

```
import { GitBranchIcon, SearchIcon } from "lucide-react"

import {```

The `Marker` component displays inline conversation markers such as status updates, system notes, bordered rows, and labeled separators. Compose it with ``[Message](/docs/components/message) in a conversation thread.

```
pnpm dlx shadcn@latest add marker```

```
```

```
Copyimport { Marker, MarkerContent, MarkerIcon } from "@/components/ui/marker"```

```
Copy<Marker>
  <MarkerIcon>
    <CheckIcon />
  </MarkerIcon>
  <MarkerContent>Explored 4 files</MarkerContent>
</Marker>```

Use the following composition to build a marker:

```
CopyMarker
├── MarkerIcon
└── MarkerContent```

- Inline marker, bordered row, and labeled separator variants
- Decorative icon slot that is hidden from assistive tech
- Polymorphic root via `asChild` for link and button markers
- Pairs with the ``[shimmer](/docs/utils/shimmer) utility for streaming status text
- Customizable styling through the `className` prop on every part
Use `variant` to switch between an inline marker, bordered row, and labeled separator.

```
import { Marker, MarkerContent } from "@/components/ui/marker"

export function MarkerVariantsDemo() {```

Set `role="status"` and include a ``[Spinner](/docs/components/spinner) for streaming or in-progress markers so updates are announced.

```
import {
  Marker,
  MarkerContent,```

Add the ``[shimmer](/docs/utils/shimmer) utility class to `MarkerContent` for an animated streaming-text effect. The utility ships with the `shadcn` package — see the shimmer docs for installation.

```
import { Marker, MarkerContent } from "@/components/ui/marker"

export function MarkerShimmerDemo() {```

Use the `separator` variant for labeled dividers, such as dates or section breaks, in a conversation.

```
import { Marker, MarkerContent } from "@/components/ui/marker"

export function MarkerSeparatorDemo() {```

Use the `border` variant for status rows that should keep the default marker alignment while separating the next row.

```
import { FileTextIcon, GitBranchIcon, SearchIcon } from "lucide-react"

import {```

Use `MarkerIcon` to render an icon alongside the content. Use `flex-col` to stack the icon above the content.

```
import { BookOpenCheck, GitBranchIcon, SearchIcon } from "lucide-react"

import {```

Turn a marker into a link or button with the `asChild` prop on `Marker`.

```
"use client"

import { GitBranchIcon, RotateCcwIcon } from "lucide-react"```

```
Copyimport { Marker, MarkerContent } from "@/components/ui/marker"
 
export function MarkerLinkDemo() {
  return (
    <Marker asChild>
      <a href="#">
        <MarkerContent>View the pull request</MarkerContent>
      </a>
    </Marker>
  )
}```

`Marker` is presentational by default. The correct semantics depend on how you use it, so choose the role based on intent rather than relying on a single default.

For streaming or progress markers such as "Thinking..." or a running tool, set `role="status"` so assistive tech announces the update as it appears. `Marker` forwards `role` to the underlying element.

```
Copy<Marker role="status">
  <MarkerIcon>
    <Spinner />
  </MarkerIcon>
  <MarkerContent>Compacting conversation</MarkerContent>
</Marker>```

A separator that carries text, such as a date or a section label, needs no role. The divider lines are decorative CSS pseudo-elements, and the text is announced as ordinary content.

```
Copy<Marker variant="separator">
  <MarkerContent>Today</MarkerContent>
</Marker>```

**Note:** Do not add `role="separator"` to a labeled divider. A separator
takes its accessible name from `aria-label`, not from its text, and its
contents are treated as presentational, so the visible label would not be
announced. Reserve `role="separator"` for a divider with no meaningful text.

A bordered marker keeps the same semantics as the default marker. The bottom border is decorative, so choose `role="status"`, `asChild`, or no role based on the marker's purpose.

```
Copy<Marker variant="border">
  <MarkerIcon>
    <FileTextIcon />
  </MarkerIcon>
  <MarkerContent>Opened implementation notes</MarkerContent>
</Marker>```

`MarkerIcon` is decorative and hidden from assistive tech with `aria-hidden`, so the adjacent `MarkerContent` carries the meaning. For an icon-only marker, provide an `aria-label` or visible text so it is not announced as empty.

```
Copy<Marker aria-label="Synced">
  <MarkerIcon>
    <CheckIcon />
  </MarkerIcon>
</Marker>```

When a marker links or triggers an action, render it as a real `<button>` or `<a>` with the `asChild` prop so it is focusable and exposes the correct role. The accessible name comes from the marker text.

```
Copy<Marker asChild>
  <a href="/files">
    <MarkerIcon>
      <FileTextIcon />
    </MarkerIcon>
    <MarkerContent>Explored 4 files</MarkerContent>
  </a>
</Marker>```

The root marker element. The file also exports `markerVariants` for composing the marker styles into custom components.

A decorative icon slot. Hidden from assistive tech with `aria-hidden`.

The marker text content.

On This Page

