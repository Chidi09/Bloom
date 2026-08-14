# June 2026 - Components for Chat Interfaces - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2026-06-chat-components

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
# June 2026 - Components for Chat Interfaces
MessageScroller, Message, Bubble, Attachment, and Marker. Components for building chat interfaces.

```
"use client"

import { useChat } from "@ai-sdk/react"```

Today, we’re releasing a new set of components for building chat interfaces:
****[MessageScroller](/docs/components/message-scroller),
****[Message](/docs/components/message), ****[Bubble](/docs/components/bubble),
****[Attachment](/docs/components/attachment), and
****[Marker](/docs/components/marker).

This is the first phase of the chat components work. We’re taking it one piece at a time, reimagining the abstraction behind each part, and shipping them as shadcn/ui components you can copy, compose, and adapt to your product.

We are starting with the conversation layer: scrolling, message rows, bubbles, attachments, and markers.

We asked ourselves: what makes a great streaming chat experience? Then we abstracted the core rules into a set of primitives: `MessageScroller`.

```
pnpm dlx shadcn@latest add message-scroller message bubble attachment marker```

```
```

`MessageScroller` is the scroll container for a conversation. It handles the
parts that are easy to get wrong: anchored turns, streamed replies, saved thread
restore, prepended history, jump-to-message, scroll controls, and visibility
tracking.

`MessageScroller` owns that behavior without owning your messages, AI state,
transport, persistence, or model state. You bring the content renderer.

The `MessageScroller` is also available as an unstyled headless component in `@shadcn/react`.

The rest of the components cover the everyday pieces you need around the
scroller.

- `Message` lays out a row in the conversation with avatar, alignment, header,
content, footer, and grouped messages.
- `Bubble` renders the message surface, with variants, alignment, reactions,
links, buttons, and collapsible content.
- `Attachment` renders files and images with media, metadata, upload state,
actions, and a full-card trigger that keeps actions separately clickable.
- `Marker` renders status updates, system notes, bordered rows, and labeled
separators for things like streaming state, tool activity, and date breaks.
They are intentionally small. Compose them together for AI chats, support
inboxes, team threads, group chats, and product-specific conversations.

We also added two new CSS utilities for the details that make chat interfaces
feel better.

``[scroll-fade](/docs/utils/scroll-fade) adds scroll-aware edge fades to scroll
containers. Use it on `MessageScroller`, `ScrollArea`, attachment rows, and any
long list where you want to hint at more content without adding overlays or
scroll listeners.

```
export function ScrollFadeDemo() {
  return (
    <div className="mx-auto w-full max-w-xs overflow-hidden rounded-2xl border">```

``[shimmer](/docs/utils/shimmer) adds a text shimmer for live status. Use it
for things like "Thinking…", "Generating response…", running tools, and
streaming markers.

Generating response…

```
export function ShimmerDemo() {
  return (
    <p className="shimmer text-sm text-muted-foreground">```

Both utilities ship with `shadcn/tailwind.css`, so projects initialized with
`npx shadcn@latest init` already have them.

We also created `@shadcn/react`, a new package for unstyled, headless React
components.

The first primitive is `@shadcn/react/message-scroller`. The registry component
wraps it with shadcn/ui styles, but the scroll behavior lives in the package:
anchoring, auto-follow, prepend preservation, scroll commands, and visibility.

This lets us ship behavior without locking it to a visual style. You still get
copy-and-paste components that match your project, and the hard interaction
logic stays tested in one place.

Available now for Radix and Base UI.

This does not replace [AI Elements](https://ai-sdk.dev/elements/overview). You
can keep using AI Elements for AI interface components and patterns. This
release is about bringing the core pieces of chat into shadcn/ui, one component
at a time.

If you are already using a component from AI Elements, you do not need to
rewrite your app. Keep what works. Try the shadcn/ui version when you want the
newer abstraction, the updated styling, or support across Radix and Base UI.

The goal is to make these pieces easy to adopt independently. Replace one part,
compose it with what you already have, and keep building.

On This Page

