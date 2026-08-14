# shimmer - shadcn/ui

> Source: https://ui.shadcn.com/docs/utils/shimmer

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
# shimmer
Utilities for adding a shimmer effect to text elements.

Generating response…

```
export function ShimmerDemo() {
  return (
    <p className="shimmer text-sm text-muted-foreground">```

If your project was set up with `npx shadcn@latest init`, you already have `shimmer`. It ships with the `shadcn` package, which the CLI imports in your global CSS file.

Otherwise, install the `shadcn` package:

```
pnpm add shadcn```

```
```

Then import the shared utilities in your global CSS file:

```
Copy@import "tailwindcss";
@import "shadcn/tailwind.css";```

Add `shimmer` to a text element.

```
Copy<p className="shimmer text-muted-foreground">Generating response&hellip;</p>```

The shimmer is built on `currentColor`, so it adapts to the element:

- The highlight is derived from the text color, with no configuration needed.
- It works on any color, from `text-muted-foreground` to brand colors.
- In dark mode, the highlight automatically brightens to stay visible.
The effect is pure CSS. The text is painted with `background-clip: text`, and the highlight sweeps across it in a seamless loop.

The shimmer composes with any component that renders text. A common pattern is a [Marker](/docs/components/marker) showing a live status while the assistant is working:

```
import { Marker, MarkerContent, MarkerIcon } from "@/components/ui/marker"
import { Spinner } from "@/components/ui/spinner"
```

```
Copy<Marker role="status">
  <MarkerIcon>
    <Spinner />
  </MarkerIcon>
  <MarkerContent className="shimmer">Thinking&hellip;</MarkerContent>
</Marker>```

Use `shimmer-color-<color>` to set the highlight color explicitly. It accepts theme colors with an optional opacity modifier, or any arbitrary color value.

Generating response…

Generating response…

```
export function ShimmerColor() {
  return (
    <div className="flex flex-col items-center gap-2 text-sm text-muted-foreground">```

```
Copy<p className="shimmer shimmer-color-blue-500/60">Generating response&hellip;</p>
<p className="shimmer shimmer-color-[#378ADD]">Generating response&hellip;</p>```

Use `shimmer-duration-<number>` to set the duration of one sweep in milliseconds. The default is `2000`, i.e. `2s`.

Generating response…

shimmer

Generating response…

shimmer-duration-1000

```
export function ShimmerDuration() {
  return (
    <div className="mx-auto grid w-full max-w-lg gap-6 text-center text-sm text-muted-foreground sm:grid-cols-2">```

```
Copy<p className="shimmer shimmer-duration-1000">Generating response&hellip;</p>```

Use `shimmer-spread-<number>` to set the width of the highlight band using the spacing scale. The default is `calc(3ch + 40px)`: a fixed base plus a `3ch` term that scales with the font size.

Generating response…

shimmer-spread-4

Generating response…

shimmer-spread-24

```
export function ShimmerSpread() {
  return (
    <div className="mx-auto grid w-full max-w-lg gap-6 text-center text-sm text-muted-foreground sm:grid-cols-2">```

```
Copy<p className="shimmer shimmer-spread-24">Generating response&hellip;</p>```

For one-off values, use an arbitrary length or percentage:

```
Copy<p className="shimmer shimmer-spread-[5rem]">Generating response&hellip;</p>```

Use `shimmer-angle-<number>` to set the tilt of the highlight band in degrees. The default is `20`.

Generating response…

shimmer

Generating response…

shimmer-angle-45

```
export function ShimmerAngle() {
  return (
    <div className="mx-auto grid w-full max-w-lg gap-6 text-center text-sm text-muted-foreground sm:grid-cols-2">```

```
Copy<p className="shimmer shimmer-angle-45">Generating response&hellip;</p>```

Use `shimmer-reverse` to sweep the highlight in the opposite direction. In RTL layouts the sweep already follows the reading direction. See RTL.

```
Copy<p className="shimmer shimmer-reverse">Generating response&hellip;</p>```

Use `shimmer-once` to play a single sweep instead of looping, useful as a reveal when streaming completes. Pair it with `shimmer-duration-<number>` to control how long the sweep takes.

Generating response…

```
"use client"

import * as React from "react"```

```
Copy<p className="shimmer shimmer-duration-1100 shimmer-once">
  Response generated.
</p>```

Use `shimmer-none` to turn the effect off and render the text normally. It works in any class order, so the typical use is responsive or stateful:

Generating response…

shimmer md:shimmer-none

```
export function ShimmerNone() {
  return (
    <div className="flex flex-col items-center gap-3 text-sm text-muted-foreground">```

```
Copy<p className="shimmer md:shimmer-none">Generating response&hellip;</p>```

The shimmer is built on modern color features, [relative color syntax](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_colors/Relative_colors) and `color-mix()`, which are available in all current browsers. In older browsers without support, the highlight gradient is dropped and the text can render transparent. If you target older browsers, apply `shimmer` conditionally with a `supports-*` variant:

```
Copy<p className="supports-[color:oklch(from_white_l_c_h)]:shimmer">
  Generating response&hellip;
</p>```

When the user prefers reduced motion, the animation is disabled automatically and the text renders normally. There is nothing to configure.

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

The sweep follows the reading direction, left to right in LTR and right to left in RTL, with no extra classes. Use `shimmer-reverse` to flip the direction manually.

Generating response…

dir="ltr"

جارٍ إنشاء الرد…

dir="rtl"

```
export function ShimmerRtl() {
  return (
    <div className="mx-auto grid w-full max-w-lg gap-6 text-center text-sm text-muted-foreground sm:grid-cols-2">```

On This Page

