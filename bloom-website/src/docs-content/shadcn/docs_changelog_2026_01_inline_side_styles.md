# January 2026 - Inline Start and End Styles - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2026-01-inline-side-styles

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
# January 2026 - Inline Start and End Styles
We've updated the styles for Base UI components to support inline-start and inline-end side values.

We've updated the styles for Base UI components to support `inline-start` and `inline-end` side values. The following components now support these values:

- Tooltip
- Popover
- Combobox
- Context Menu
- Dropdown Menu
- Hover Card
- Menubar
- Select
We added new Tailwind classes to handle the logical side values:

```
Copy<PopoverPrimitive.Popup
  className={cn(
    "... data-[side=bottom]:slide-in-from-top-2
    data-[side=left]:slide-in-from-right-2
    data-[side=right]:slide-in-from-left-2
    data-[side=top]:slide-in-from-bottom-2
+   data-[side=inline-start]:slide-in-from-right-2
+   data-[side=inline-end]:slide-in-from-left-2 ...",
    className
  )}
/>```

```
Copy<Popover>
  <PopoverTrigger>Open</PopoverTrigger>
  <PopoverContent side="inline-start">
    {/* Opens on the left in LTR, right in RTL */}
  </PopoverContent>
</Popover>```

Ask your LLM to update your components by running the following prompt:

```
CopyAdd inline-start and inline-end support to my shadcn/ui components. Add the following Tailwind classes to each component:
 
| File | Component | Add Classes |
|------|-----------|-------------|
| tooltip.tsx | TooltipContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2` |
| tooltip.tsx | TooltipArrow | `data-[side=inline-start]:top-1/2! data-[side=inline-start]:-right-1 data-[side=inline-start]:-translate-y-1/2
data-[side=inline-end]:top-1/2! data-[side=inline-end]:-left-1 data-[side=inline-end]:-translate-y-1/2` |
| popover.tsx | PopoverContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2` |
| hover-card.tsx | HoverCardContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2` |
| select.tsx | SelectContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2
data-[align-trigger=true]:animate-none` and add `data-align-trigger={alignItemWithTrigger}` attribute |
| combobox.tsx | ComboboxContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2` |
| dropdown-menu.tsx | DropdownMenuContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2` |
| context-menu.tsx | ContextMenuContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2` |
| menubar.tsx | MenubarContent | `data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2` |
 
Add these classes next to the existing `data-[side=top]`, `data-[side=bottom]`, `data-[side=left]`, `data-[side=right]` classes.```

On This Page

