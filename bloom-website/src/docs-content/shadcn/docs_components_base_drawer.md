# Drawer - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/base/drawer

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
# Drawer
A drawer component for React.

```
"use client"

import * as React from "react"```

The drawer component now uses [Base
UI](https://base-ui.com/react/components/drawer) instead of Vaul. If you
installed the previous version, see the migration
guide.

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

The base drawer now uses [Base UI](https://base-ui.com/react/components/drawer)
instead of Vaul. If you installed the previous base drawer, update your usage
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
`shouldScaleBackground` do not have one-to-one replacements in the base drawer
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

