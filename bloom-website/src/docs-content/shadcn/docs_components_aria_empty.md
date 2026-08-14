# Empty - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/aria/empty

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
# Empty
Use the Empty component to display an empty state.

```
import { IconFolderCode } from "@tabler/icons-react"
import { ArrowUpRightIcon } from "lucide-react"
```

```
pnpm dlx shadcn@latest add empty```

```
```

```
Copyimport {
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"```

```
Copy<Empty>
  <EmptyHeader>
    <EmptyMedia variant="icon">
      <Icon />
    </EmptyMedia>
    <EmptyTitle>No data</EmptyTitle>
    <EmptyDescription>No data found</EmptyDescription>
  </EmptyHeader>
  <EmptyContent>
    <Button>Add data</Button>
  </EmptyContent>
</Empty>```

Use the following composition to build an `Empty` state:

```
CopyEmpty
├── EmptyHeader
│   ├── EmptyMedia
│   ├── EmptyTitle
│   └── EmptyDescription
└── EmptyContent```

Use the `border` utility class to create an outline empty state.

```
import { IconCloud } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"```

Use the `bg-*` and `bg-gradient-*` utilities to add a background to the empty state.

```
import { IconBell } from "@tabler/icons-react"
import { RefreshCcwIcon } from "lucide-react"
```

Use the `EmptyMedia` component to display an avatar in the empty state.

```
import {
  Avatar,
  AvatarFallback,```

Use the `EmptyMedia` component to display an avatar group in the empty state.

```
import { PlusIcon } from "lucide-react"

import {```

You can add an `InputGroup` component to the `EmptyContent` component.

```
import { SearchIcon } from "lucide-react"

import {```

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

```
"use client"

import * as React from "react"```

The main component of the empty state. Wraps the `EmptyHeader` and `EmptyContent` components.

```
Copy<Empty>
  <EmptyHeader />
  <EmptyContent />
</Empty>```

The `EmptyHeader` component wraps the empty media, title, and description.

```
Copy<EmptyHeader>
  <EmptyMedia />
  <EmptyTitle />
  <EmptyDescription />
</EmptyHeader>```

Use the `EmptyMedia` component to display the media of the empty state such as an icon or an image. You can also use it to display other components such as an avatar.

```
Copy<EmptyMedia variant="icon">
  <Icon />
</EmptyMedia>```

```
Copy<EmptyMedia>
  <Avatar>
    <AvatarImage src="..." />
    <AvatarFallback>CN</AvatarFallback>
  </Avatar>
</EmptyMedia>```

Use the `EmptyTitle` component to display the title of the empty state.

```
Copy<EmptyTitle>No data</EmptyTitle>```

Use the `EmptyDescription` component to display the description of the empty state.

```
Copy<EmptyDescription>You do not have any notifications.</EmptyDescription>```

Use the `EmptyContent` component to display the content of the empty state such as a button, input or a link.

```
Copy<EmptyContent>
  <Button>Add Project</Button>
</EmptyContent>```

On This Page

