# Message Scroller - shadcn/ui

> Source: https://ui.shadcn.com/docs/react/message-scroller#api-reference

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
# Message Scroller
Use the MessageScroller behavior directly from the @shadcn/react package with your own markup and styles.

`MessageScroller` ships as a headless primitive in the `@shadcn/react` package.
The package owns all of the scroll behavior, anchoring turns, following streamed
output, preserving the reader's place as history loads, and tracking visibility,
and renders no styles of its own.

The `message-scroller.tsx` component in the registry is a thin wrapper that adds
Tailwind classes on top. Use the package directly when you want full control over
the markup and styles, or when you are not using the registry.

For the behavior guide and live examples, see the
[Message Scroller](/docs/components/base/message-scroller) component.

```
pnpm add @shadcn/react```

```
```

```
Copyimport {
  MessageScroller,
  useMessageScroller,
} from "@shadcn/react/message-scroller"```

The package exports a namespace object instead of flat components. The parts and
behavior are the same as the styled component, just unstyled.

```
Copy<MessageScroller.Provider>
  <MessageScroller.Root>
    <MessageScroller.Viewport>
      <MessageScroller.Content>
        {messages.map((message) => (
          <MessageScroller.Item
            key={message.id}
            messageId={message.id}
            scrollAnchor={message.role === "user"}
          >
            {/* your message UI */}
          </MessageScroller.Item>
        ))}
      </MessageScroller.Content>
    </MessageScroller.Viewport>
    <MessageScroller.Button />
  </MessageScroller.Root>
</MessageScroller.Provider>```

If you are coming from the styled component, the flat parts map to the namespace
object like this.

The hooks are imported the same way and behave identically, since they read from
`MessageScroller.Provider`.

```
Copyimport {
  useMessageScroller,
  useMessageScrollerScrollable,
  useMessageScrollerVisibility,
} from "@shadcn/react/message-scroller"```

Here is a complete example that brings its own styles and wires the scroller to
the AI SDK.

```
Copy"use client"
 
import { useChat } from "@ai-sdk/react"
import { MessageScroller } from "@shadcn/react/message-scroller"
import { DefaultChatTransport } from "ai"
 
import { ChatInput } from "@/components/chat-input"
 
export function Chat() {
  const { messages, sendMessage, status } = useChat({
    transport: new DefaultChatTransport({ api: "/api/chat" }),
  })
 
  return (
    <div className="flex h-svh w-full flex-col">
      <MessageScroller.Provider>
        <MessageScroller.Root className="relative flex flex-1 flex-col overflow-hidden">
          <MessageScroller.Viewport className="flex flex-1 flex-col overflow-y-auto">
            <MessageScroller.Content className="flex flex-col gap-4 p-6 text-base">
              {messages.map((message, index) => (
                <MessageScroller.Item
                  key={message.id}
                  messageId={`message-${index}`}
                  scrollAnchor={message.role === "user"}
                >
                  <div className="rounded-lg bg-muted p-4">
                    {message.parts.map((part, i) =>
                      part.type === "text" ? (
                        <span key={i}>{part.text}</span>
                      ) : null
                    )}
                  </div>
                </MessageScroller.Item>
              ))}
            </MessageScroller.Content>
          </MessageScroller.Viewport>
          <MessageScroller.Button className="absolute bottom-2 left-1/2 z-10 -translate-x-1/2 rounded-full border bg-background px-3 py-1 text-sm font-medium inert:opacity-0">
            Jump to latest
          </MessageScroller.Button>
        </MessageScroller.Root>
      </MessageScroller.Provider>
      <ChatInput onSend={sendMessage} disabled={status !== "ready"} />
    </div>
  )
}```

The headless root. It owns scroll state and the behavior props, and provides
them to the parts and the hooks. It renders no DOM of its own.

The frame and layout container. It fills its parent, so use it inside a
height-constrained layout, within a `MessageScroller.Provider`.

The root mirrors the scroll-state attributes below (the viewport carries them
too), so you can style the container by scroll state, such as edge fades on the
frame.

The scrollable viewport.

The transcript content element. Every direct child should be a
`MessageScroller.Item`.

One transcript row: a message, marker, typing row, separator, or load-more row.

A button that scrolls to the start or end of the transcript. It is inert and
removed from the tab order when there is nothing to scroll toward.

Imperative transcript controls.

All commands return `false` when the command could not be applied.
`scrollToStart` and `scrollToEnd` return `false` only when the viewport is not
mounted yet. `scrollToMessage` returns `false` when the target is not mounted and
cannot be queued.

Command options:

Which edges the viewport can scroll toward, for sibling UI that needs the values
in JavaScript. Prefer the `data-scrollable` attribute for styling the scroller
itself.

Visibility state for outline, search, and active-turn UI. It subscribes
separately from `useMessageScrollerScrollable`, so visibility work is only paid for
when a consumer needs it.

Filter `visibleMessageIds` in your app when you need a narrower outline, such as
user messages, anchored turns, or search hits.

On This Page

