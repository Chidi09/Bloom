# Item - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/base/item

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

shadcn@vercel.com

maxleiter@vercel.com

evilrabbit@vercel.com

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
Copy<Item render={<a href="/dashboard" />}>
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

