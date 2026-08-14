# Bubble - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/aria/bubble

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
# Bubble
Displays conversational content in a message bubble. Supports variants, alignment, grouping, reactions, and collapsible content.

```
import {
  Bubble,
  BubbleContent,```

The `Bubble` component displays framed conversational content. Use it for chat text, short structured output, quoted replies, suggestions, and reactions.

For full-featured chat interfaces, use the ``[Message](/docs/components/aria/message) component. `Bubble` is intentionally scoped to the bubble surface. Place avatars, names, timestamps, metadata, and message-level actions in ``[Message](/docs/components/aria/message).

```
pnpm dlx shadcn@latest add bubble```

```
```

```
Copyimport { Bubble, BubbleContent, BubbleReactions } from "@/components/ui/bubble"```

```
Copy<Bubble>
  <BubbleContent>
    I checked the registry output and removed the stale route.
  </BubbleContent>
  <BubbleReactions>
    <span>👍</span>
  </BubbleReactions>
</Bubble>```

Use the following composition to build a bubble:

```
CopyBubble
├── BubbleContent
└── BubbleReactions```

Use `BubbleGroup` to group consecutive bubbles from the same sender:

```
CopyBubbleGroup
├── Bubble
│   └── BubbleContent
└── Bubble
    └── BubbleContent```

- Seven visual variants, from a strong primary bubble to unframed ghost content
- Start and end alignment for sender and receiver bubbles
- Reactions that anchor to the bubble edge with configurable side and alignment
- Bubbles size to their content, up to 80% of the container width
- Polymorphic content via `render` for link and button bubbles
- Customizable styling through the `className` prop on every part
Use `variant` to change the visual treatment of the bubble.

Ghost bubbles work for assistant text, markdown, and other content that should not be framed.

This is perfect for assistant messages that should not have a frame and can take the full width of the container. You can also render `code` in it.

Ghost bubbles are full width and can take the full width of the container.

```
import { Markdown } from "@/components/markdown"
import {
  Bubble,```

A bubble sizes to its content, up to 80% of the container width. The `ghost` variant removes the max-width so assistant text and rich content can span the full row.

Use `align` on `Bubble` to align the bubble to the start or end of the conversation.

```
import { Bubble, BubbleContent } from "@/components/ui/bubble"

export function BubbleAlignmentDemo() {```

**Note:** When building chat interfaces, you probably want to use alignment on the `Message` component itself, not the `Bubble` component. You can use the `role` prop on the `Message` component to automatically align the bubble to the start or end of the conversation.

Use `BubbleGroup` to group consecutive bubbles from the same sender. Note the `align` prop should be set on the `Bubble` component itself, not the `BubbleGroup` component.

```
CopyBubbleGroup
├── Bubble
│   └── BubbleContent
└── Bubble
    └── BubbleContent```

```
import {
  Bubble,
  BubbleContent,```

You can turn a bubble into a link or button by using the `render` prop on `BubbleContent`.

```
"use client"

import { toast } from "sonner"```

```
Copyimport { Bubble, BubbleContent } from "@/components/ui/bubble"
 
export function BubbleLinkDemo() {
  return (
    <Bubble variant="muted">
      <BubbleContent render={(props) => <button {...props} type="button" />}>
        Click here
      </BubbleContent>
    </Bubble>
  )
}```

Use `BubbleReactions` for bubble reactions. You can use it to display reactions or quick action buttons. Use `side` and `align` to position the row — `side="top"` anchors it to the upper edge. Reactions overlap the bubble edge, so leave vertical space between rows — the examples below use a larger `gap` for this reason.

```
"use client"

import { toast } from "sonner"```

Long bubble content can be composed with ``[Collapsible](/docs/components/aria/collapsible) to allow for a show more or show less interaction. Use the `CollapsibleTrigger` component to trigger the collapsible content.

```
"use client"

import * as React from "react"```

Wrap a bubble in a ``[Tooltip](/docs/components/aria/tooltip) to reveal metadata on hover, such as when a message was read.

```
import { CheckIcon } from "lucide-react"

import {```

Pair a bubble with a ``[Popover](/docs/components/aria/popover) to surface more information on demand, such as the full error message for a failed action.

```
import { InfoIcon } from "lucide-react"

import {```

`Bubble` renders the presentational message surface. Keep conversation-level semantics on the surrounding container and follow the guidelines below.

Reactions render as a row of emoji. A screen reader reads each glyph with no context, and counters like `+8` are announced as "plus eight". Group the row as a single image with a descriptive `aria-label` so it announces once. `role="img"` also hides the individual emoji from assistive tech, so no `aria-hidden` is needed.

```
Copy<BubbleReactions role="img" aria-label="Reactions: thumbs up, fire, and 8 more">
  <span>👍</span>
  <span>🔥</span>
  <span>+8</span>
</BubbleReactions>```

When reactions are interactive, render buttons instead and give icon-only buttons an `aria-label`.

```
Copy<BubbleReactions>
  <Button aria-label="Thumbs up" variant="secondary" size="icon-xs">
    <ThumbsUpIcon />
  </Button>
</BubbleReactions>```

When a bubble is clickable, render it as a real `<button>` or `<a>` with the `render` prop so it is focusable and exposes the correct role. `BubbleContent` ships a visible focus ring for interactive elements, and the accessible name comes from the bubble text. No extra label is needed.

```
Copy<Bubble variant="muted" align="end">
  <BubbleContent
    render={(props) => <button {...props} type="button" onClick={onReply} />}
  >
    I forgot my password
  </BubbleContent>
</Bubble>```

Bubble variants signal role and tone with color. Pair them with text, alignment, or icons so meaning is not conveyed by color alone. For a `destructive` bubble, keep the error context in the message text rather than relying on the color treatment.

The root bubble wrapper.

The bubble content wrapper.

Displays overlapped reactions for a bubble.

Groups consecutive bubbles from the same sender.

On This Page

