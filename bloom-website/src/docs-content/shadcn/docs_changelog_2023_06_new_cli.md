# June 2023 - New CLI, Styles and more - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2023-06-new-cli

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
# June 2023 - New CLI, Styles and more
Complete CLI rewrite with new styles, theming options, and more.

I have a lot of updates to share with you today:

- ****New CLI - Rewrote the CLI from scratch. You can now add components, dependencies and configure import paths.
- ****Theming - Choose between using CSS variables or Tailwind CSS utility classes for theming.
- ****Base color - Configure the base color for your project. This will be used to generate the default color palette for your components.
- ****React Server Components - Opt out of using React Server Components. The CLI will automatically append or remove the `use client` directive.
- ****Styles - Introducing a new concept called *Style*. A style comes with its own set of components, animations, icons and more.
- ****Exit animations - Added exit animations to all components.
- ****Other updates - New `icon` button size, updated `sheet` component and more.
- ****Updating your project - How to update your project to get the latest changes.
---
I've been working on a new CLI for the past few weeks. It's a complete rewrite. It comes with a lot of new features and improvements.

```
pnpm dlx shadcn@latest init```

```
```

When you run the `init` command, you will be asked a few questions to configure `components.json`:

```
CopyWhich style would you like to use? › Default
Which color would you like to use as base color? › Slate
Where is your global CSS file? › › app/globals.css
Do you want to use CSS variables for colors? › no / yes
Where is your tailwind.config.js located? › tailwind.config.js
Configure the import alias for components: › @/components
Configure the import alias for utils: › @/lib/utils
Are you using React Server Components? › no / yes```

This file contains all the information about your components: where to install them, the import paths, how they are styled...etc.

You can use this file to change the import path of a component, set a baseColor or change the styling method.

```
Copy{
  "style": "default",
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/app/globals.css",
    "baseColor": "zinc",
    "cssVariables": true
  },
  "rsc": false,
  "aliases": {
    "utils": "~/lib/utils",
    "components": "~/components"
  }
}```

This means you can now use the CLI with any directory structure including `src` and `app` directories.

```
pnpm dlx shadcn@latest add```

```
```

The `add` command is now much more capable. You can now add UI components but also import more complex components (coming soon).

The CLI will automatically resolve all components and dependencies, format them based on your custom config and add them to your project.

```
pnpm dlx shadcn diff```

```
```

We're also introducing a new `diff` command to help you keep track of upstream updates.

You can use this command to see what has changed in the upstream repository and update your project accordingly.

Run the `diff` command to get a list of components that have updates available:

```
pnpm dlx shadcn diff```

```
```

```
CopyThe following components have updates available:
- button
  - /path/to/my-app/components/ui/button.tsx
- toast
  - /path/to/my-app/components/ui/use-toast.ts
  - /path/to/my-app/components/ui/toaster.tsx```

Then run `diff [component]` to see the changes:

```
pnpm dlx shadcn diff alert```

```
```

```
Copyconst alertVariants = cva(
- "relative w-full rounded-lg border",
+ "relative w-full pl-12 rounded-lg border"
)```

---
You can choose between using CSS variables or Tailwind CSS utility classes for theming.

When you add new components, the CLI will automatically use the correct theming methods based on your `components.json` configuration.

```
Copy<div className="bg-zinc-950 dark:bg-white" />```

To use utility classes for theming set `tailwind.cssVariables` to `false` in your `components.json` file.

```
Copy{
  "tailwind": {
    "config": "tailwind.config.js",
    "css": "app/globals.css",
    "baseColor": "slate",
    "cssVariables": false
  }
}```

```
Copy<div className="bg-background text-foreground" />```

To use CSS variables classes for theming set `tailwind.cssVariables` to `true` in your `components.json` file.

```
Copy{
  "tailwind": {
    "config": "tailwind.config.js",
    "css": "app/globals.css",
    "baseColor": "slate",
    "cssVariables": true
  }
}```

---
You can now configure the base color for your project. This will be used to generate the default color palette for your components.

```
Copy{
  "tailwind": {
    "config": "tailwind.config.js",
    "css": "app/globals.css",
    "baseColor": "zinc",
    "cssVariables": false
  }
}```

Choose between `gray`, `neutral`, `slate`, `stone` or `zinc`.

If you have `cssVariables` set to `true`, we will set the base colors as CSS variables in your `globals.css` file. If you have `cssVariables` set to `false`, we will inline the Tailwind CSS utility classes in your components.

---
If you're using a framework that does not support React Server Components, you can now opt out by setting `rsc` to `false`. We will automatically append or remove the `use client` directive when adding components.

```
Copy{
  "rsc": false
}```

---
We are introducing a new concept called *Style*.

*You can think of style as the visual foundation: shapes, icons, animations & typography.* A style comes with its own set of components, animations, icons and more.

We are shipping two styles: `default` and `new-york` (with more coming soon).

The `default` style is the one you are used to. It's the one we've been using since the beginning of this project. It uses `lucide-react` for icons and `tailwindcss-animate` for animations.

The `new-york` style is a new style. It ships with smaller buttons, cards with shadows and a new set of icons from [Radix Icons](https://icons.radix-ui.com).

When you run the `init` command, you will be asked which style you would like to use. This is saved in your `components.json` file.

```
Copy{
  "style": "new-york"
}```

Start with a style as the base then theme using CSS variables or Tailwind CSS utility classes to completely change the look of your components.

---
I added exit animations to all components. Click on the combobox below to see the subtle exit animation.

```
"use client"

import * as React from "react"```

The animations can be customized using utility classes.

---
- Added a new button size `icon`:
```
import { CircleFadingArrowUpIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

- Renamed `position` to `side` to match the other elements.
```
"use client"

import { Button } from "@/components/ui/button"```

- Removed the `size` props. Use `className="w-[200px] md:w-[450px]"` for responsive sizing.
---
Since we follow a copy and paste approach, you will need to manually update your project to get the latest changes.

Note: we are working on a ``diff command to help you
keep track of upstream updates.

Creating a `components.json` file at the root:

```
Copy{
  "style": "default",
  "rsc": true,
  "tailwind": {
    "config": "tailwind.config.js",
    "css": "app/globals.css",
    "baseColor": "slate",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils"
  }
}```

Update the values for `tailwind.css` and `aliases` to match your project structure.

Add the `icon` size to the `buttonVariants`:

```
Copyconst buttonVariants = cva({
  variants: {
    size: {
      default: "h-10 px-4 py-2",
      sm: "h-9 rounded-md px-3",
      lg: "h-11 rounded-md px-8",
      icon: "h-10 w-10",
    },
  },
})```

1. Replace the content of `sheet.tsx` with the following:
```
Copy"use client"
 
import * as React from "react"
import * as SheetPrimitive from "@radix-ui/react-dialog"
import { cva, type VariantProps } from "class-variance-authority"
import { X } from "lucide-react"
 
import { cn } from "@/lib/utils"
 
const Sheet = SheetPrimitive.Root
 
const SheetTrigger = SheetPrimitive.Trigger
 
const SheetClose = SheetPrimitive.Close
 
const SheetPortal = ({
  className,
  ...props
}: SheetPrimitive.DialogPortalProps) => (
  <SheetPrimitive.Portal className={cn(className)} {...props} />
)
SheetPortal.displayName = SheetPrimitive.Portal.displayName
 
const SheetOverlay = React.forwardRef<
  React.ElementRef<typeof SheetPrimitive.Overlay>,
  React.ComponentPropsWithoutRef<typeof SheetPrimitive.Overlay>
>(({ className, ...props }, ref) => (
  <SheetPrimitive.Overlay
    className={cn(
      "fixed inset-0 z-50 bg-background/80 backdrop-blur-sm data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0",
      className
    )}
    {...props}
    ref={ref}
  />
))
SheetOverlay.displayName = SheetPrimitive.Overlay.displayName
 
const sheetVariants = cva(
  "fixed z-50 gap-4 bg-background p-6 shadow-lg transition ease-in-out data-[state=closed]:animate-out data-[state=closed]:duration-300 data-[state=open]:animate-in data-[state=open]:duration-500",
  {
    variants: {
      side: {
        top: "inset-x-0 top-0 border-b data-[state=closed]:slide-out-to-top data-[state=open]:slide-in-from-top",
        bottom:
          "inset-x-0 bottom-0 border-t data-[state=closed]:slide-out-to-bottom data-[state=open]:slide-in-from-bottom",
        left: "inset-y-0 left-0 h-full w-3/4 border-r data-[state=closed]:slide-out-to-left data-[state=open]:slide-in-from-left sm:max-w-sm",
        right:
          "inset-y-0 right-0 h-full w-3/4 border-l data-[state=closed]:slide-out-to-right data-[state=open]:slide-in-from-right sm:max-w-sm",
      },
    },
    defaultVariants: {
      side: "right",
    },
  }
)
 
interface SheetContentProps
  extends React.ComponentPropsWithoutRef<typeof SheetPrimitive.Content>,
    VariantProps<typeof sheetVariants> {}
 
const SheetContent = React.forwardRef<
  React.ElementRef<typeof SheetPrimitive.Content>,
  SheetContentProps
>(({ side = "right", className, children, ...props }, ref) => (
  <SheetPortal>
    <SheetOverlay />
    <SheetPrimitive.Content
      ref={ref}
      className={cn(sheetVariants({ side }), className)}
      {...props}
    >
      {children}
      <SheetPrimitive.Close className="absolute top-4 right-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:outline-none disabled:pointer-events-none data-[state=open]:bg-secondary">
        <X className="h-4 w-4" />
        <span className="sr-only">Close</span>
      </SheetPrimitive.Close>
    </SheetPrimitive.Content>
  </SheetPortal>
))
SheetContent.displayName = SheetPrimitive.Content.displayName
 
const SheetHeader = ({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn(
      "flex flex-col space-y-2 text-center sm:text-left",
      className
    )}
    {...props}
  />
)
SheetHeader.displayName = "SheetHeader"
 
const SheetFooter = ({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn(
      "flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2",
      className
    )}
    {...props}
  />
)
SheetFooter.displayName = "SheetFooter"
 
const SheetTitle = React.forwardRef<
  React.ElementRef<typeof SheetPrimitive.Title>,
  React.ComponentPropsWithoutRef<typeof SheetPrimitive.Title>
>(({ className, ...props }, ref) => (
  <SheetPrimitive.Title
    ref={ref}
    className={cn("text-lg font-semibold text-foreground", className)}
    {...props}
  />
))
SheetTitle.displayName = SheetPrimitive.Title.displayName
 
const SheetDescription = React.forwardRef<
  React.ElementRef<typeof SheetPrimitive.Description>,
  React.ComponentPropsWithoutRef<typeof SheetPrimitive.Description>
>(({ className, ...props }, ref) => (
  <SheetPrimitive.Description
    ref={ref}
    className={cn("text-sm text-muted-foreground", className)}
    {...props}
  />
))
SheetDescription.displayName = SheetPrimitive.Description.displayName
 
export {
  Sheet,
  SheetTrigger,
  SheetClose,
  SheetContent,
  SheetHeader,
  SheetFooter,
  SheetTitle,
  SheetDescription,
}```

1. Rename `position` to `side`
```
Copy- <Sheet position="right" />
+ <Sheet side="right" />```

I'd like to thank everyone who has been using this project, providing feedback and contributing to it. I really appreciate it. Thank you.

On This Page

