# Popover - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/aria/popover

- [Introduction](/docs)
- [Components](/docs/components)
- [Installation](/docs/installation)
- [Theming](/docs/theming)
- [CLI](/docs/cli)
- [Typeset](/docs/typeset)
- [Skills](/docs/skills)
- [Registry](/docs/registry)
- [Changelog](/docs/changelog)
- [Accordion](/docs/components/aria/accordion)
- [Alert](/docs/components/aria/alert)
- [Alert Dialog](/docs/components/aria/alert-dialog)
- [Aspect Ratio](/docs/components/aria/aspect-ratio)
- [Attachment](/docs/components/aria/attachment)
- [Avatar](/docs/components/aria/avatar)
- [Badge](/docs/components/aria/badge)
- [Breadcrumb](/docs/components/aria/breadcrumb)
- [Bubble](/docs/components/aria/bubble)
- [Button](/docs/components/aria/button)
- [Button Group](/docs/components/aria/button-group)
- [Calendar](/docs/components/aria/calendar)
- [Card](/docs/components/aria/card)
- [Carousel](/docs/components/aria/carousel)
- [Chart](/docs/components/aria/chart)
- [Checkbox](/docs/components/aria/checkbox)
- [Collapsible](/docs/components/aria/collapsible)
- [Combobox](/docs/components/aria/combobox)
- [Command](/docs/components/aria/command)
- [Context Menu](/docs/components/aria/context-menu)
- [Data Table](/docs/components/aria/data-table)
- [Date Picker](/docs/components/aria/date-picker)
- [Dialog](/docs/components/aria/dialog)
- [Direction](/docs/components/aria/direction)
- [Drawer](/docs/components/aria/drawer)
- [Dropdown Menu](/docs/components/aria/dropdown-menu)
- [Empty](/docs/components/aria/empty)
- [Field](/docs/components/aria/field)
- [Hover Card](/docs/components/aria/hover-card)
- [Input](/docs/components/aria/input)
- [Input Group](/docs/components/aria/input-group)
- [Input OTP](/docs/components/aria/input-otp)
- [Item](/docs/components/aria/item)
- [Kbd](/docs/components/aria/kbd)
- [Label](/docs/components/aria/label)
- [Marker](/docs/components/aria/marker)
- [Message](/docs/components/aria/message)
- [Message Scroller](/docs/components/aria/message-scroller)
- [Native Select](/docs/components/aria/native-select)
- [Pagination](/docs/components/aria/pagination)
- [Popover](/docs/components/aria/popover)
- [Progress](/docs/components/aria/progress)
- [Questionnaire](/docs/components/aria/questionnaire)
- [Radio Group](/docs/components/aria/radio-group)
- [Resizable](/docs/components/aria/resizable)
- [Scroll Area](/docs/components/aria/scroll-area)
- [Select](/docs/components/aria/select)
- [Separator](/docs/components/aria/separator)
- [Sheet](/docs/components/aria/sheet)
- [Sidebar](/docs/components/aria/sidebar)
- [Skeleton](/docs/components/aria/skeleton)
- [Slider](/docs/components/aria/slider)
- [Sonner](/docs/components/aria/sonner)
- [Spinner](/docs/components/aria/spinner)
- [Switch](/docs/components/aria/switch)
- [Table](/docs/components/aria/table)
- [Tabs](/docs/components/aria/tabs)
- [Textarea](/docs/components/aria/textarea)
- [Toast](/docs/components/aria/toast)
- [Toggle](/docs/components/aria/toggle)
- [Toggle Group](/docs/components/aria/toggle-group)
- [Tooltip](/docs/components/aria/tooltip)
- [Typography](/docs/components/aria/typography)
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
# Popover
Displays rich content in a portal, triggered by a button.

```
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"```

```
pnpm dlx shadcn@latest add popover```

```
```

```
Copyimport {
  Popover,
  PopoverDescription,
  PopoverHeader,
  PopoverTitle,
  PopoverTrigger,
} from "@/components/ui/popover"```

```
Copy<PopoverTrigger>
  <Button variant="outline">Open Popover</Button>
  <Popover>
    <PopoverHeader>
      <PopoverTitle>Title</PopoverTitle>
      <PopoverDescription>Description text here.</PopoverDescription>
    </PopoverHeader>
  </Popover>
</PopoverTrigger>```

Use the following composition to build a `Popover`:

```
CopyPopoverTrigger
├── Button
└── Popover```

A simple popover with a header, title, and description.

```
import { Button } from "@/components/ui/button"
import {
  Popover,```

Use the `placement` prop on `Popover` to control the horizontal alignment.

```
import { Button } from "@/components/ui/button"
import { Popover, PopoverTrigger } from "@/components/ui/popover"
```

A popover with form fields inside.

```
import { Button } from "@/components/ui/button"
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"```

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

```
"use client"

import {```

See the [React Aria Popover](https://react-aria.adobe.com/Popover#api) documentation.

On This Page

