# Drawer - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/aria/drawer

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
# Drawer
A drawer component for React.

```
"use client"

import * as React from "react"```

The drawer component uses [Base
UI](https://base-ui.com/react/components/drawer).

```
pnpm dlx shadcn@latest add drawer```

```
```

Add the following to your global styles. On iOS Safari, the drawer overlay is absolutely positioned and requires a positioned `body` to cover the viewport after the page is scrolled. See the [Base UI docs](https://base-ui.com/react/overview/quick-start#ios-26-safari) for details.

```
Copybody {
  position: relative;
}```

```
Copyimport {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from "@/components/ui/drawer"```

```
Copy<Drawer>
  <DrawerTrigger render={<Button variant="outline" />}>Open</DrawerTrigger>
  <DrawerContent>
    <DrawerHeader>
      <DrawerTitle>Are you absolutely sure?</DrawerTitle>
      <DrawerDescription>This action cannot be undone.</DrawerDescription>
    </DrawerHeader>
    <div className="p-4">{/* Content here */}</div>
    <DrawerFooter>
      <Button>Submit</Button>
      <DrawerClose render={<Button variant="outline" />}>Cancel</DrawerClose>
    </DrawerFooter>
  </DrawerContent>
</Drawer>```

Use the following composition to build a `Drawer`:

```
CopyDrawer
├── DrawerTrigger
└── DrawerContent
    ├── DrawerHeader
    │   ├── DrawerTitle
    │   └── DrawerDescription
    └── DrawerFooter```

`DrawerContent` composes the portal, overlay, viewport, and popup from Base UI. For lower-level control, `DrawerPortal`, `DrawerOverlay`, and `DrawerSwipeHandle` are also exported.

A vertical drawer sizes itself to its content and is capped at `calc(100dvh - 6rem)` by default. A side drawer spans `75%` of the viewport width, or `24rem` on larger screens.

To customize the height of a vertical drawer, use the `h-*` and `max-h-*` utilities on `DrawerContent`.

```
Copy<DrawerContent className="h-[50vh]">```

To customize the width of a side drawer, use the `w-*` and `max-w-*` utilities on `DrawerContent`.

```
Copy<DrawerContent className="w-96">```

When the same component renders in multiple directions, scope an override to one axis using the `data-[swipe-axis=*]` variants.

```
Copy<DrawerContent className="data-[swipe-axis=y]:max-h-[50vh] data-[swipe-axis=x]:w-96">```

To make a region of the drawer scrollable, make the scroll container a flex item. Avoid `h-full`, which does not resolve inside a content-sized drawer.

```
Copy<DrawerContent>
  <DrawerHeader>...</DrawerHeader>
  <div className="flex-1 overflow-y-auto p-4">{/* Scrollable content */}</div>
  <DrawerFooter>...</DrawerFooter>
</DrawerContent>```

The drawer exposes CSS variables for style-level customization. Set the sizing variables on `DrawerContent`. Set the overlay variable on `[data-slot=drawer-overlay]` in your CSS.

The drawer also sets data attributes you can target with variants such as `data-[swipe-direction=down]:` on `DrawerContent`, or `group-data-[swipe-axis=y]/drawer-popup:` on its descendants.

Use the `swipeDirection` prop to set the side of the drawer.

Available options are `up`, `right`, `down`, and `left`.

```
import { Button } from "@/components/ui/button"
import {
  Drawer,```

Use `showSwipeHandle` on `Drawer` to render a swipe handle.

```
"use client"

import { Button } from "@/components/ui/button"```

Open drawers from inside another drawer. Parent drawers stay mounted and stack behind the frontmost drawer.

```
"use client"

import { useIsMobile } from "@/hooks/use-mobile"```

Set `modal={false}` to allow interaction with the rest of the page while the drawer is open. Combine with `disablePointerDismissal` to prevent the drawer from closing on outside presses. Use `modal="trap-focus"` to keep focus inside the drawer while leaving scroll and pointer interaction unrestricted.

```
import { Button } from "@/components/ui/button"
import {
  Drawer,```

Use `snapPoints` to snap a drawer to preset heights. Numbers between `0` and `1` represent fractions of the viewport. Numbers greater than `1` are treated as pixel values. String values support `px` and `rem` units. Snap points apply to vertical drawers.

Track the active snap point with the controlled `snapPoint` and `onSnapPointChange` props. At the full snap point, the drawer gets a `data-expanded` attribute you can style with the `data-expanded:` variant.

```
"use client"

import { Button } from "@/components/ui/button"```

You can combine the `Dialog` and `Drawer` components to create a responsive dialog. This renders a `Dialog` component on desktop and a `Drawer` on mobile.

```
"use client"

import * as React from "react"```

The Aria drawer now uses [Base UI](https://base-ui.com/react/components/drawer)
instead of Vaul. If you installed the previous Aria drawer, update your usage
to the Base UI API.

### Update the dependency.
```
Copy- npm install vaul
+ npm install @base-ui/react```

### Replace direction with swipeDirection.
Use `down` instead of `bottom`, and `up` instead of `top`. `left` and `right`
stay the same.

```
Copy- <Drawer direction="bottom">
+ <Drawer swipeDirection="down">```

### Replace asChild with render.
For `DrawerTrigger`, pass the trigger element to the `render` prop.

```
Copy- <DrawerTrigger asChild>
-   <Button variant="outline">Open</Button>
- </DrawerTrigger>
+ <DrawerTrigger render={<Button variant="outline" />}>
+   Open
+ </DrawerTrigger>```

For `DrawerClose`, pass the close element to the `render` prop.

```
Copy- <DrawerClose asChild>
-   <Button variant="outline">Cancel</Button>
- </DrawerClose>
+ <DrawerClose render={<Button variant="outline" />}>
+   Cancel
+ </DrawerClose>```

### Update snap point props.
If you use snap points, rename the controlled snap point props and the sequential
snap point prop.

```
Copy  <Drawer
    snapPoints={[0.25, 0.5, 1]}
-   activeSnapPoint={snapPoint}
-   setActiveSnapPoint={setSnapPoint}
-   snapToSequentialPoint
+   snapPoint={snapPoint}
+   onSnapPointChange={setSnapPoint}
+   snapToSequentialPoints
  >```

### Update animation and focus props.
```
Copy- <Drawer onAnimationEnd={(open) => setDone(open)}>
+ <Drawer onOpenChangeComplete={(open) => setDone(open)}>```

```
Copy- <DrawerContent onOpenAutoFocus={(event) => event.preventDefault()}>
+ <DrawerContent initialFocus={false}>```

### Review Vaul-only props.
Vaul props like `handleOnly`, `repositionInputs`, and
`shouldScaleBackground` do not have one-to-one replacements in the Base UI drawer
API. Use Base UI props such as `disablePointerDismissal`, `modal`, `snapPoints`,
or controlled `open` state for the behavior you need.

```
Copy- <Drawer handleOnly repositionInputs={false} shouldScaleBackground>
+ <Drawer>```

```
Copy- <Drawer dismissible={false}>
+ <Drawer disablePointerDismissal>```

### Update custom data attribute selectors.
Replace Vaul's `data-vaul-drawer-direction` selectors with Base UI's
`data-swipe-direction` selectors.

```
Copy- <DrawerContent className="data-[vaul-drawer-direction=bottom]:max-h-[50vh]">
+ <DrawerContent className="data-[swipe-direction=down]:max-h-[50vh]">```

Base UI also exposes attributes like `data-swiping`, `data-starting-style`, and
`data-ending-style` for swipe and transition states. Descendants inside
`DrawerContent` can use `group-data-[swipe-axis=x]/drawer-popup` and
`group-data-[swipe-axis=y]/drawer-popup` for axis-specific styling.

See the [Base UI documentation](https://base-ui.com/react/components/drawer) for the full API reference.

On This Page

