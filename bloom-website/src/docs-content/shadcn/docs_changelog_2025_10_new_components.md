# October 2025 - New Components - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2025-10-new-components

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
# October 2025 - New Components
Spinner, Kbd, Button Group, Input Group, Field, Item, and Empty components.

For this round of components, I looked at what we build every day, the boring stuff we rebuild over and over, and made reusable abstractions you can actually use.

**These components work with every component library, Radix, Base UI, React Aria, you name it. Copy and paste to your projects.**

- Spinner: An indicator to show a loading state.
- Kbd: Display a keyboard key or group of keys.
- Button Group: A group of buttons for actions and split buttons.
- Input Group: Input with icons, buttons, labels and more.
- Field: One component. All your forms.
- Item: Display lists of items, cards, and more.
- Empty: Use this one for empty states.
Okay let's start with the easiest ones: **Spinner** and **Kbd**. Pretty basic. We all know what they do.

Here's how you render a spinner:

```
Copyimport { Spinner } from "@/components/ui/spinner"```

```
Copy<Spinner />```

Here's what it looks like:

```
import { Spinner } from "@/components/ui/spinner"

export function SpinnerBasic() {```

Here's what it looks like in a button:

```
import { Button } from "@/components/ui/button"
import { Spinner } from "@/components/ui/spinner"
```

You can edit the code and replace it with your own spinner.

```
import { LoaderIcon } from "lucide-react"

import { cn } from "@/lib/utils"```

Kbd is a component that renders a keyboard key.

```
Copyimport { Kbd, KbdGroup } from "@/components/ui/kbd"```

```
Copy<Kbd>Ctrl</Kbd>```

Use `KbdGroup` to group keyboard keys together.

```
Copy<KbdGroup>
  <Kbd>Ctrl</Kbd>
  <Kbd>B</Kbd>
</KbdGroup>```

```
import { Kbd, KbdGroup } from "@/components/ui/kbd"

export function KbdDemo() {```

You can add it to buttons, tooltips, input groups, and more.

I got a lot of requests for this one: Button Group. It's a container that groups related buttons together with consistent styling. Great for action groups, split buttons, and more.

```
"use client"

import * as React from "react"```

Here's the code:

```
Copyimport { ButtonGroup } from "@/components/ui/button-group"```

```
Copy<ButtonGroup>
  <Button>Button 1</Button>
  <Button>Button 2</Button>
</ButtonGroup>```

You can nest button groups to create more complex layouts with spacing.

```
Copy<ButtonGroup>
  <ButtonGroup>
    <Button>Button 1</Button>
    <Button>Button 2</Button>
  </ButtonGroup>
  <ButtonGroup>
    <Button>Button 3</Button>
    <Button>Button 4</Button>
  </ButtonGroup>
</ButtonGroup>```

Use `ButtonGroupSeparator` to create split buttons. Classic dropdown pattern.

```
"use client"

import {```

You can also use it to add prefix or suffix buttons and text to inputs.

```
"use client"

import * as React from "react"```

```
Copy<ButtonGroup>
  <ButtonGroupText>Prefix</ButtonGroupText>
  <Input placeholder="Type something here..." />
  <Button>Button</Button>
</ButtonGroup>```

Input Group lets you add icons, buttons, and more to your inputs. You know, all those little bits you always need around your inputs.

```
Copyimport {
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
} from "@/components/ui/input-group"```

```
Copy<InputGroup>
  <InputGroupInput placeholder="Search..." />
  <InputGroupAddon>
    <SearchIcon />
  </InputGroupAddon>
</InputGroup>```

Here's a preview with icons:

```
import {
  CheckIcon,
  CreditCardIcon,```

You can also add buttons to the input group.

```
"use client"

import * as React from "react"```

Or text, labels, tooltips, ...

```
import {
  InputGroup,
  InputGroupAddon,```

It also works with textareas so you can build really complex components with lots of knobs and dials or yet another prompt form.

```
import {
  IconBrandJavascript,
  IconCopy,```

Oh here are some cool ones with spinners:

```
import { LoaderIcon } from "lucide-react"

import {```

Introducing **Field**, a component for building really complex forms. The abstraction here is beautiful.

It took me a long time to get it right but I made it work with all your form libraries: Server Actions, React Hook Form, TanStack Form, Bring Your Own Form.

```
Copyimport {
  Field,
  FieldDescription,
  FieldError,
  FieldLabel,
} from "@/components/ui/field"```

Here's a basic field with an input:

```
Copy<Field>
  <FieldLabel htmlFor="username">Username</FieldLabel>
  <Input id="username" placeholder="Max Leiter" />
  <FieldDescription>
    Choose a unique username for your account.
  </FieldDescription>
</Field>```

Choose a unique username for your account.

Must be at least 8 characters long.

```
import {
  Field,
  FieldDescription,```

It works with all form controls. Inputs, textareas, selects, checkboxes, radios, switches, sliders, you name it. Here's a full example:

All transactions are secure and encrypted

Enter your 16-digit card number

The billing address associated with your payment method

```
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import {```

Here are some checkbox fields:

Select the items you want to show on the desktop.

Your Desktop & Documents folders are being synced with iCloud Drive. You can access them from other devices.

```
import { Checkbox } from "@/components/ui/checkbox"
import {
  Field,```

You can group fields together using `FieldGroup` and `FieldSet`. Perfect for
multi-section forms.

```
Copy<FieldSet>
  <FieldLegend />
  <FieldGroup>
    <Field />
    <Field />
  </FieldGroup>
</FieldSet>```

We need your address to deliver your order.

```
import {
  Field,
  FieldDescription,```

Making it responsive is easy. Use `orientation="responsive"` and it switches
between vertical and horizontal layouts based on container width. Done.

Fill in your profile information.

Provide your full name for identification

You can write your message here. Keep it short, preferably under 100 characters.

```
import { Button } from "@/components/ui/button"
import {
  Field,```

Wait, here's more. Wrap your fields in `FieldLabel` to create a selectable field group. Really easy. And it looks great.

Select the compute environment for your cluster.

Run GPU workloads on a K8s configured cluster.

Access a VM configured cluster to run GPU workloads.

```
import {
  Field,
  FieldContent,```

This one is a straightforward flex container that can house nearly any type of content.

I've built this so many times that I decided to create a component for it. Now I use it all the time. I use it to display lists of items, cards, and more.

```
Copyimport {
  Item,
  ItemContent,
  ItemDescription,
  ItemMedia,
  ItemTitle,
} from "@/components/ui/item"```

Here's a basic item:

```
Copy<Item>
  <ItemMedia variant="icon">
    <HomeIcon />
  </ItemMedia>
  <ItemContent>
    <ItemTitle>Dashboard</ItemTitle>
    <ItemDescription>Overview of your account and activity.</ItemDescription>
  </ItemContent>
</Item>```

A simple item with title and description.

```
import { BadgeCheckIcon, ChevronRightIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

You can add icons, avatars, or images to the item.

New login detected from unknown device.

```
import { ShieldAlertIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

Last seen 5 months ago

Invite your team to collaborate on this project.

```
import { Plus } from "lucide-react"

import {```

And here's what a list of items looks like with `ItemGroup`:

shadcn@vercel.com

maxleiter@vercel.com

evilrabbit@vercel.com

```
import * as React from "react"
import { PlusIcon } from "lucide-react"
```

Need it as a link? Use the `asChild` prop:

```
Copy<Item asChild>
  <a href="/dashboard">
    <ItemMedia variant="icon">
      <HomeIcon />
    </ItemMedia>
    <ItemContent>
      <ItemTitle>Dashboard</ItemTitle>
      <ItemDescription>Overview of your account and activity.</ItemDescription>
    </ItemContent>
  </a>
</Item>```

```
import { ChevronRightIcon, ExternalLinkIcon } from "lucide-react"

import {```

Okay last one: **Empty**. Use this to display empty states in your app.

```
Copyimport {
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"```

Here's how you use it:

```
Copy<Empty>
  <EmptyMedia variant="icon">
    <InboxIcon />
  </EmptyMedia>
  <EmptyTitle>No messages</EmptyTitle>
  <EmptyDescription>You don't have any messages yet.</EmptyDescription>
  <EmptyContent>
    <Button>Send a message</Button>
  </EmptyContent>
</Empty>```

```
import { IconFolderCode } from "@tabler/icons-react"
import { ArrowUpRightIcon } from "lucide-react"
```

You can use it with avatars:

```
import {
  Avatar,
  AvatarFallback,```

Or with input groups for things like search results or email subscriptions:

```
import { SearchIcon } from "lucide-react"

import {```

That's it. Seven new components. Works with all your libraries. Ready for your projects.

On This Page

