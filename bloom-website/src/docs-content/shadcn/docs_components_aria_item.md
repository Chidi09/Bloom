# Item - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/aria/item

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
# Item
A versatile component for displaying content with media, title, description, and actions.

A simple item with title and description.

```
import { BadgeCheckIcon, ChevronRightIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

The `Item` component is a straightforward flex container that can house nearly any type of content. Use it to display a title, description, and actions. Group it with the `ItemGroup` component to create a list of items.

```
pnpm dlx shadcn@latest add item```

```
```

```
Copyimport {
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemMedia,
  ItemTitle,
} from "@/components/ui/item"```

```
Copy<Item>
  <ItemMedia variant="icon">
    <Icon />
  </ItemMedia>
  <ItemContent>
    <ItemTitle>Title</ItemTitle>
    <ItemDescription>Description</ItemDescription>
  </ItemContent>
  <ItemActions>
    <Button>Action</Button>
  </ItemActions>
</Item>```

Use the following composition to build an `Item`:

```
CopyItemGroup
└── Item
    ├── ItemHeader
    ├── ItemMedia
    ├── ItemContent
    │   ├── ItemTitle
    │   └── ItemDescription
    ├── ItemActions
    └── ItemFooter```

Use `Field` if you need to display a form input such as a checkbox, input, radio, or select.

If you only need to display content such as a title, description, and actions, use `Item`.

Use the `variant` prop to change the visual style of the item.

Transparent background with no border.

Outlined style with a visible border.

Muted background for secondary content.

```
import { InboxIcon } from "lucide-react"

import {```

Use the `size` prop to change the size of the item. Available sizes are `default`, `sm`, and `xs`.

The standard size for most use cases.

A compact size for dense layouts.

The most compact size available.

```
import { InboxIcon } from "lucide-react"

import {```

Use `ItemMedia` with `variant="icon"` to display an icon.

New login detected from unknown device.

```
import { ShieldAlertIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

You can use `ItemMedia` with `variant="avatar"` to display an avatar.

Last seen 5 months ago

Invite your team to collaborate on this project.

```
import { Plus } from "lucide-react"

import {```

Use `ItemMedia` with `variant="image"` to display an image.

```
import Image from "next/image"

import {```

Use `ItemGroup` to group related items together.

alex@example.com

jamie@example.com

taylor@example.com

```
import * as React from "react"
import { PlusIcon } from "lucide-react"
```

Use `ItemHeader` to add a header above the item content.

Everyday tasks and UI generation.

Advanced thinking or reasoning.

Open Source model for everyone.

```
import Image from "next/image"

import {```

Use the `render` prop to render the item as a link. The hover and focus states will be applied to the anchor element.

```
import { ChevronRightIcon, ExternalLinkIcon } from "lucide-react"

import {```

```
Copy<Item href="/dashboard">
  <ItemMedia variant="icon">
    <HomeIcon />
  </ItemMedia>
  <ItemContent>
    <ItemTitle>Dashboard</ItemTitle>
    <ItemDescription>Overview of your account and activity.</ItemDescription>
  </ItemContent>
</Item>```

```
"use client"

import { ChevronDownIcon } from "lucide-react"```

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

عنصر بسيط يحتوي على عنوان ووصف.

```
"use client"

import * as React from "react"```

The main component for displaying content with media, title, description, and actions.

A container that groups related items together with consistent styling.

```
Copy<ItemGroup>
  <Item />
  <Item />
</ItemGroup>```

A separator between items in a group.

```
Copy<ItemGroup>
  <Item />
  <ItemSeparator />
  <Item />
</ItemGroup>```

Use `ItemMedia` to display media content such as icons, images, or avatars.

```
Copy<ItemMedia variant="icon">
  <Icon />
</ItemMedia>```

```
Copy<ItemMedia variant="image">
  <img src="..." alt="..." />
</ItemMedia>```

Wraps the title and description of the item.

```
Copy<ItemContent>
  <ItemTitle>Title</ItemTitle>
  <ItemDescription>Description</ItemDescription>
</ItemContent>```

Displays the title of the item.

```
Copy<ItemTitle>Item Title</ItemTitle>```

Displays the description of the item.

```
Copy<ItemDescription>Item description</ItemDescription>```

Container for action buttons or other interactive elements.

```
Copy<ItemActions>
  <Button>Action</Button>
</ItemActions>```

Displays a header above the item content.

```
Copy<Item>
  <ItemHeader>Header</ItemHeader>
  <ItemContent>...</ItemContent>
</Item>```

Displays a footer below the item content.

```
Copy<Item>
  <ItemContent>...</ItemContent>
  <ItemFooter>Footer</ItemFooter>
</Item>```

On This Page

