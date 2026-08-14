# scroll-fade - shadcn/ui

> Source: https://ui.shadcn.com/docs/utils/scroll-fade

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
# scroll-fade
Utilities for adding a fade effect to the edges of a scroll container.

```
export function ScrollFadeDemo() {
  return (
    <div className="mx-auto w-full max-w-xs overflow-hidden rounded-2xl border">```

If your project was set up with `npx shadcn@latest init`, you already have `scroll-fade`. It ships with the `shadcn` package, which the CLI imports in your global CSS file.

Otherwise, install the `shadcn` package:

```
pnpm add shadcn```

```
```

Then import the shared utilities in your global CSS file:

```
Copy@import "tailwindcss";
@import "shadcn/tailwind.css";```

Add `scroll-fade` or `scroll-fade-y` to the scroll container, i.e. the element that has `overflow-y-auto`.

```
Copy<div className="scroll-fade overflow-y-auto">{/* ... */}</div>```

The fade is scroll-aware and tracks the scroll position:

- At rest, the top edge is crisp and the bottom edge fades to hint at more content.
- As you scroll, a fade appears at the top and both edges stay faded mid-scroll.
- At the end, the bottom edge sharpens to show you have reached the last item.
The fade is applied with `mask-image`, so it dissolves the content itself rather than overlaying a color. The mask uses a linear fade from transparent to black, so it adapts to any background without configuration. If your scroll area sits inside a card, put the background and border on a wrapper and `scroll-fade` on the inner scroller, so the fade dissolves the content and not the card.

The ``[ScrollArea](/docs/components/scroll-area) and ``[MessageScroller](/docs/components/message-scroller) components can use `scroll-fade` on their scrollable viewport.

If the content does not overflow, no fade is shown. You can apply `scroll-fade` to any list without checking whether it scrolls.

```
export function ScrollFadeOverflow() {
  return (
    <div className="mx-auto w-full max-w-xs overflow-hidden rounded-2xl border">```

Use `scroll-fade-x` on containers that scroll horizontally, i.e. the element that has `overflow-x-auto`.

```
const tags = [
  "Design",
  "Engineering",```

```
Copy<div className="flex scroll-fade-x overflow-x-auto">{/* ... */}</div>```

The horizontal fade is direction-aware. In RTL layouts, the crisp edge and the fade follow the reading direction with no extra classes needed. `scroll-fade-<number>` and `scroll-fade-none` work the same for both axes.

Use edge utilities when only one edge should track the scroll position.

scroll-fade-t

scroll-fade-b

scroll-fade-s

scroll-fade-e

```
const items = [
  "Inbox triage",
  "Design review",```

```
Copy<div className="scroll-fade-b overflow-y-auto">{/* ... */}</div>```

The edge utilities are scroll-aware. Start edges fade in after you scroll away from the start, and end edges fade out when you reach the end. Use `scroll-fade-t`, `scroll-fade-b`, `scroll-fade-l`, and `scroll-fade-r` for physical edges. Use `scroll-fade-s` and `scroll-fade-e` for logical inline edges that mirror in RTL.

The fade depth defaults to `12%` of the container, capped at `40px` so tall scrollers stay subtle. Use `scroll-fade-<number>` to set a fixed size on the spacing scale instead, the same way `scroll-mt-<number>` works.

scroll-fade-4

scroll-fade-24

```
export function ScrollFadeSize() {
  return (
    <div className="mx-auto flex w-full max-w-xs flex-col gap-6">```

```
Copy<div className="scroll-fade overflow-y-auto scroll-fade-24">{/* ... */}</div>```

For one-off values, use an arbitrary length or percentage:

```
Copy<div className="scroll-fade overflow-y-auto scroll-fade-[15%]">{/* ... */}</div>```

To fade opposite edges by different amounts, use the per-edge modifiers `scroll-fade-t-<number>`, `scroll-fade-b-<number>`, `scroll-fade-s-<number>`, and `scroll-fade-e-<number>`. They override `scroll-fade-<number>` on the edge they target and accept arbitrary values too.

```
Copy<div className="scroll-fade overflow-y-auto scroll-fade-b-8 scroll-fade-t-2">
  {/* ... */}
</div>```

Use the logical `s`/`e` modifiers for horizontal scrollers so the sizes mirror in RTL.

The fade eases in and out over a fixed scroll distance rather than appearing instantly. That distance is the `--scroll-fade-reveal` variable, `96px` by default and independent of the fade depth. Lower it for a snappier reveal or raise it for a more gradual one:

```
Copy<div className="scroll-fade overflow-y-auto [--scroll-fade-reveal:64px]">
  {/* ... */}
</div>```

Use `scroll-fade-none` to remove the fade. It works in any class order, so the typical use is responsive or stateful:

```
Copy<div className="scroll-fade overflow-y-auto md:scroll-fade-none">
  {/* ... */}
</div>```

scroll-fade

scroll-fade scroll-fade-none

```
export function ScrollFadeNone() {
  return (
    <div className="mx-auto flex max-w-xs min-w-0 flex-col gap-6">```

The scroll-aware behavior is implemented with [CSS scroll-driven animations](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_scroll-driven_animations), with no JavaScript and no scroll listeners. In browsers that do not support scroll-driven animations, `scroll-fade` falls back to a static fade on both edges, and edge utilities fall back to a static fade on the selected edge.

Since the mask is applied to the scroll container itself, a visible scrollbar fades with the content at the edges. Pair `scroll-fade` with `no-scrollbar`, which ships in the same package, if you want to hide the scrollbar entirely.

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

`scroll-fade-x` follows the reading direction. At rest, the start edge is crisp and the end edge fades. In RTL layouts that means a crisp right edge and a fade on the left, mirrored from LTR.

```
"use client"

import {```

On This Page

