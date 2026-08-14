# Button - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/base/button

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
# Button
Displays a button or a component that looks like a button.

```
import { ArrowUpIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

```
pnpm dlx shadcn@latest add button```

```
```

```
Copyimport { Button } from "@/components/ui/button"```

```
Copy<Button variant="outline">Button</Button>```

Tailwind v4 [switched](https://tailwindcss.com/docs/upgrade-guide#buttons-use-the-default-cursor) from `cursor: pointer` to `cursor: default` for the button component.

If you want to keep the `cursor: pointer` behavior, add the following code to your CSS file:

You can also enable this during project setup with `npx shadcn@latest init --pointer`.

```
Copy@layer base {
  button:not(:disabled),
  [role="button"]:not(:disabled) {
    cursor: pointer;
  }
}```

Use the `size` prop to change the size of the button.

```
import { ArrowUpRightIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

```
import { Button } from "@/components/ui/button"

export function ButtonDefault() {```

```
import { Button } from "@/components/ui/button"

export function ButtonOutline() {```

```
import { Button } from "@/components/ui/button"

export function ButtonSecondary() {```

```
import { Button } from "@/components/ui/button"

export function ButtonGhost() {```

```
import { Button } from "@/components/ui/button"

export function ButtonDestructive() {```

```
import { Button } from "@/components/ui/button"

export function ButtonLink() {```

```
import { CircleFadingArrowUpIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

Remember to add the `data-icon="inline-start"` or `data-icon="inline-end"` attribute to the icon for the correct spacing.

```
import { IconGitBranch, IconGitFork } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"```

Use the `rounded-full` class to make the button rounded.

```
import { ArrowUpIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

Render a `<Spinner />` component inside the button to show a loading state. Remember to add the `data-icon="inline-start"` or `data-icon="inline-end"` attribute to the spinner for the correct spacing.

```
import { Button } from "@/components/ui/button"
import { Spinner } from "@/components/ui/spinner"
```

To create a button group, use the `ButtonGroup` component. See the [Button Group](/docs/components/base/button-group) documentation for more details.

```
"use client"

import * as React from "react"```

You can use the `buttonVariants` helper to make a link look like a button.

**Do not use `<Button render={<a />} nativeButton={false} />` for links.** The Base UI `Button` component always applies `role="button"`, which overrides the semantic link role on `<a>` elements. Use `buttonVariants` with a plain `<a>` tag instead.

```
import { buttonVariants } from "@/components/ui/button"

export function ButtonRender() {```

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

```
"use client"

import { ArrowRightIcon, PlusIcon } from "lucide-react"```

The `Button` component is a wrapper around the `button` element that adds a variety of styles and functionality.

On This Page

