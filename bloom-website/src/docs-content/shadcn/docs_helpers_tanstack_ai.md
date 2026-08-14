# TanStack AI - shadcn/ui

> Source: https://ui.shadcn.com/docs/helpers/tanstack-ai

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
# TanStack AI
Create TanStack AI messages and stream predefined conversations through useChat without a model, API route, network request, or API key.

`@shadcn/helpers/tanstack-ai` lets you write an AI conversation in code and
stream it through TanStack AI's `useChat`, with no model, API route, network
request, or API key.

It creates native TanStack `UIMessage[]` values and replays each assistant
response through a local connection adapter as real AG-UI events, so your
components behave exactly as they would in production: text and reasoning
stream word by word, and tool calls move from input to result.

```
Copyimport { createChat } from "@shadcn/helpers/tanstack-ai"
 
const chat = createChat()
  .user("What changed in this release?")
  .assistant("The release adds keyboard shortcuts and faster search.")
  .user("Can you show me the shortcuts?")
  .assistant("Press ⌘K to search and ⌘Enter to submit.")```

Pass the chat to `useChat` with its initial messages and local connection.
TanStack AI receives the same AG-UI events it would receive from a server.

```
Copyimport { useChat } from "@tanstack/ai-react"
 
function Chat() {
  const { messages, append } = useChat({
    initialMessages: chat.get(0), // starts with no messages.
    connection: chat.transport(),
  })
 
  const nextMessage = chat.next(messages)
 
  return (
    <button
      disabled={!nextMessage}
      onClick={() => {
        if (nextMessage) {
          void append(nextMessage)
        }
      }}
    >
      Send next message
    </button>
  )
}```

`get(0)` starts with no messages. `append(nextMessage)` adds the next
predefined user message; the connection then streams its assistant response
as AG-UI events.

---
The helper decouples your chat UI from the model and the backend, so you can
work on the frontend on its own. It runs offline, instantly, and the same way every time.

- **Build components.** Develop message bubbles, tool cards, and reasoning
panels against realistic streaming output, without wiring up a model first.
- **Preview and demo.** Ship reproducible previews, screenshots, and videos
that never depend on a live model.
- **Write docs.** Power documentation examples with conversations that render
the same way on every load.
- **Test.** Assert against a deterministic stream in CI, with no network calls,
token spend, or flaky model output.
---
```
pnpm add @shadcn/helpers```

```
```

---
Create a conversation, pass its messages and connection to `useChat`, then
send each predefined user message with `next()`.

```
Copy"use client"
 
import { createChat } from "@shadcn/helpers/tanstack-ai"
import { useChat } from "@tanstack/ai-react"
 
const chat = createChat()
  .user("What changed in this release?")
  .assistant("The release adds keyboard shortcuts and faster search.")
  .user("Can you show me the shortcuts?")
  .assistant("Press ⌘K to search and ⌘Enter to submit.")
 
const initialMessages = chat.get(0)
const connection = chat.transport()
 
export function Chat() {
  const { messages, append, status } = useChat({
    initialMessages,
    connection,
  })
  const nextMessage = chat.next(messages)
  const isBusy = status === "submitted" || status === "streaming"
 
  return (
    <div>
      {messages.map((message) => (
        <div key={message.id}>{/* Render the message */}</div>
      ))}
      <button
        disabled={!nextMessage || isBusy}
        onClick={() => {
          if (nextMessage && !isBusy) {
            void append(nextMessage)
          }
        }}
      >
        Send
      </button>
    </div>
  )
}```

```
"use client"

import { createChat } from "@shadcn/helpers/tanstack-ai"```

---
Messages added with this helper use the `user` and `assistant` roles. Use
`user()` to add a user message. Existing TanStack messages are preserved when
you start with `createChat({ messages })`.

```
Copyconst chat = createChat().user("What changed in this release?")
 
const [message] = chat.get()
 
message.role // "user"
message.parts // [{ type: "text", content: "What changed in this release?" }]```

Pass an `id`, or a `createdAt` timestamp via `metadata`, as the second argument
when you need them.

```
Copychat.user("What changed in this release?", {
  id: "user-release-question",
  metadata: {
    createdAt: "2026-01-01T10:00:00.000Z",
  },
})```

User messages can also include files. See Files.

---
Use `assistant()` to add an assistant message.

```
Copyconst chat = createChat().assistant(
  "The release adds keyboard shortcuts and faster search."
)
 
const [message] = chat.get()
 
message.role // "assistant"
message.parts // [{ type: "text", content: "The release adds..." }]```

A string creates one text part. You can also pass an array of TanStack message
parts.

```
Copychat.assistant([
  { type: "thinking", content: "I should summarize the release." },
  { type: "text", content: "The release adds keyboard shortcuts." },
])```

Use the writer callback when the message should stream in smaller steps.

```
Copychat.assistant(({ writer }) => {
  writer.reasoning("I should summarize the release.")
  writer.text("The release adds keyboard shortcuts and faster search.")
})```

The writer adds parts in the order you call them.

---
The TanStack writer supports the parts that can round-trip through its AG-UI
connection: text, reasoning, and tool calls. It also supports timing and
errors.

```
Copychat.assistant(({ writer }) => {
  writer.reasoning("I should answer directly.")
  writer.text("Hello.")
})```

See Adapter Differences for parts that do not have an
equivalent in this connection.

---
Use `text()` to add text.

```
Copychat.assistant(({ writer }) => {
  writer.text("The release adds keyboard shortcuts.")
  writer.text(" Search is faster too.")
})```

Text streams word by word when the chat is used with `chat.transport()`.
Consecutive text calls materialize as separate parts in `get()`, but TanStack's
stream processor combines them into one text part during playback.

Use `mode: "instant"` to send the whole value at once, or `delayMs` to change
the delay between text deltas.

```
Copywriter.text("Done.", { mode: "instant" })
writer.text("This part streams more slowly.", { delayMs: 100 })```

---
Use `reasoning()` to add reasoning. It becomes a TanStack `thinking` part.

```
Copychat.assistant(({ writer }) => {
  writer.reasoning("I should check the latest conditions first.")
  writer.text("Let me check the weather.")
})```

Reasoning uses the same `delayMs` and `mode` options as text.

```
Copywriter.reasoning("Checking the forecast.", { mode: "instant" })```

---
Use `tool()` to add a tool call. It returns a handle that follows the tool from
input to output.

```
Copychat.assistant(({ writer }) => {
  writer
    .tool("getWeather", {
      input: { city: "San Francisco" },
    })
    .sleep(900)
    .output({
      city: "San Francisco",
      temperature: 18,
      condition: "Breezy",
    })
 
  writer.text("It is 18°C and breezy in San Francisco.")
})```

The tool can finish with `output()` or `error()`.

```
Copywriter.tool("getWeather", { input: { city: "San Francisco" } }).error()```

The completed TanStack message contains a `tool-call` part and a sibling
`tool-result` part.

Pass the same client-tool tuple used by your app to type the tool name, input,
and output.

```
Copyimport { clientTools } from "@tanstack/ai-client"
 
import { getWeatherTool } from "@/lib/tools"
 
const tools = clientTools(getWeatherTool.client())
const chat = createChat<typeof tools>()
 
chat.assistant(({ writer }) => {
  writer
    .tool("getWeather", {
      input: { city: "San Francisco" },
    })
    .output({
      city: "San Francisco",
      temperature: 18,
      condition: "Breezy",
    })
})```

---
Add files to a user message with the `files` option.

```
Copychat.user("Describe this image.", {
  files: [
    {
      mediaType: "image/png",
      url: "https://example.com/screenshot.png",
    },
  ],
})```

The helper converts each file into a TanStack media part based on its media
type:

These parts are available from `get()`. Because `next()` returns the complete
user `UIMessage`, `append()` preserves its text and media parts.

```
Copyconst nextMessage = chat.next(messages)
 
if (nextMessage) {
  void append(nextMessage)
}```

Assistant media parts can be included in a static parts array and read with
`get()`, but the AG-UI connection does not stream assistant files.

---
TanStack AI and the AI SDK use different message and streaming models. This
adapter exposes only the operations it can represent end to end.

Use the [AI SDK helper](/docs/helpers/ai-sdk) when a preview needs the AI SDK's
full message-part model.

---
Use `get()` to return messages from the start of the conversation.

```
Copychat.get() // Every message.
chat.get(2) // The first two messages.
chat.get(0) // An empty initial conversation.```

`get()` returns cloned TanStack `UIMessage[]` values and does not change the
chat.

Use `next()` to find the next predefined user message after the messages
already shown.

```
Copyconst initialMessages = chat.get(2)
const nextMessage = chat.next(initialMessages)```

`next()` always accepts a message transcript, not an index. It returns the next
user message or `null` when none remain.

---
Pass `messages` to continue from a saved conversation or fixture.

```
Copyimport { createChat } from "@shadcn/helpers/tanstack-ai"
import type { UIMessage } from "@tanstack/ai-client"
 
declare const savedMessages: UIMessage[]
 
const chat = createChat({ messages: savedMessages })
  .user("What should we do next?")
  .assistant("Turn the open questions into a checklist.")```

Existing IDs, timestamps, and parts are preserved.

---
`transport()` creates a TanStack `ConnectConnectionAdapter` that you pass to
`useChat` as its `connection`.

```
Copyconst connection = chat.transport()
 
const { messages, append, sendMessage } = useChat({
  initialMessages: chat.get(0),
  connection,
})
 
const nextMessage = chat.next(messages)
 
// Replay the next predefined user message.
if (nextMessage) {
  void append(nextMessage)
}
 
// Or send ordinary user input as text or multimodal content.
void sendMessage("Tell me more.")```

When `append()` or `sendMessage()` starts a run, the connection finds the
assistant message that follows the current transcript and emits AG-UI events
through TanStack's normal stream processor. It matches message IDs first and
falls back to the role and text of the latest message.

Use `append(nextMessage)` to replay a predefined user message. It preserves
that message's ID and media parts. Use `sendMessage()` for ordinary user input;
it accepts a string or multimodal content rather than a complete `UIMessage`.

A response can emit the following sequence:

```
CopyRUN_STARTED
REASONING_MESSAGE_START → REASONING_MESSAGE_CONTENT → REASONING_MESSAGE_END
TOOL_CALL_START → TOOL_CALL_ARGS → TOOL_CALL_END → TOOL_CALL_RESULT
TEXT_MESSAGE_START → TEXT_MESSAGE_CONTENT → TEXT_MESSAGE_END
RUN_FINISHED```

Predefined errors emit `RUN_ERROR`. TanStack supplies the `threadId` and
`runId` used by each run.

The connection-level `delayMs` is the default for every streamed text and
reasoning part. Override it for one part with `writer.text(..., { delayMs })`
or `writer.reasoning(..., { delayMs })`.

```
Copyconst connection = chat.transport({
  delayMs: 25,
})```

Use `fallback` when the conversation has no predefined assistant response
left. This keeps a demo usable after its predefined replies are exhausted.

```
Copyconst connection = chat.transport({
  fallback: "This demo has no more predefined replies.",
})```

A fallback can also be an array of TanStack message parts or a writer callback.
The callback receives the incoming transcript, so it can create a response from
the current state.

```
Copyconst connection = chat.transport({
  fallback: ({ writer, messages }) => {
    writer.text(`This example already has ${messages.length} messages.`, {
      mode: "instant",
    })
  },
})```

Fallback responses stream like assistant responses but are not added to the
predefined conversation. Without one, the connection throws
`"No assistant response found for this transcript."` when the conversation is
exhausted.

Calling `stop()` from `useChat` closes the active connection stream.

---
Use delays to reproduce the pace of a real response.

```
Copyconst chat = createChat()
  .user("Give me a project update.")
  .sleep(800)
  .assistant(({ writer }) => {
    writer.reasoning("I should lead with the completed milestone.")
    writer.sleep(500)
    writer.text("The first milestone is complete.", { mode: "instant" })
  })
 
const connection = chat.transport({ delayMs: 50 })```

- `chat.sleep(ms)` waits before the next assistant response starts.
- `writer.sleep(ms)` waits between parts of an assistant response.
- `tool.sleep(ms)` waits between a tool's input and its result.
- `transport({ delayMs })` sets the default delay between text and reasoning
deltas.
- `writer.text(text, { delayMs })` and `writer.reasoning(text, { delayMs })`
override that delay for one part.
- `mode: "instant"` sends a whole text or reasoning value in one delta.
For fast tests, use `chat.transport({ delayMs: 0 })` and instant text.

---
Use `error()` on the chat when the whole assistant response should fail.

```
Copyconst chat = createChat()
  .user("Load the report.")
  .error("The report could not be loaded.")```

This emits a TanStack `RUN_ERROR` event.

Use `writer.error()` to fail after other content has streamed.

```
Copychat.assistant(({ writer }) => {
  writer.text("I found the report.")
  writer.error("The connection closed before it could be read.")
})```

---
TanStack messages support a `createdAt` timestamp. Pass it as message metadata;
it is preserved through `get()` and `next()`. The AG-UI connection does not
stream message metadata.

```
Copyconst chat = createChat()
  .user("Hello", {
    metadata: { createdAt: "2026-01-01T10:00:00.000Z" },
  })
  .assistant("Hi.", {
    id: "assistant-welcome",
    metadata: { createdAt: new Date("2026-01-01T10:00:01.000Z") },
  })```

Use chat options when a fixture needs custom prefixes or a fixed clock.

```
Copyconst chat = createChat({
  messageIdPrefix: "demo-message",
  toolCallIdPrefix: "demo-tool",
  now: "2026-01-01T00:00:00.000Z",
})```

---
The sections above cover the common flows. This reference lists every public
export and option.

Creates a typed conversation and returns the fluent TanStack chat interface.

```
Copyfunction createChat<
  TOOLS extends ReadonlyArray<AnyClientTool> = AnyClientTool[],
  DATA = unknown,
>(options?: CreateChatOptions<TOOLS, DATA>): TanStackChat<TOOLS, DATA>```

The helper writer does not create `structured-output` parts. `DATA` preserves
their type when a chat starts from existing messages.

IDs found in `messages` are reserved, so newly generated IDs continue after
the existing transcript.

Every method that adds content returns the same chat, so calls can be chained.

Calling `user()` or `assistant()` without content uses
`"Summarize the uploaded receipt."`. Calling `error()` without a message uses
`"An error occurred."`. `get(count)` throws when `count` is negative or not an
integer.

A user file has this shape:

```
Copytype FilePayload = {
  type?: "file"
  mediaType: string
  url: string
  filename?: string
  providerMetadata?: Record<string, unknown>
}```

TanStack media parts preserve the URL and media type. Their message shape does
not preserve `filename` or `providerMetadata`.

See Transport for matching, fallback, errors, and AG-UI behavior.

The writer is available inside `assistant(({ writer }) => {})` and fallback
callbacks.

Calling `text()` without content uses `"Summarize the uploaded receipt."`.
Calling `reasoning()` without content uses
`"I need to inspect the available context before answering."`. Calling
`error()` without a message uses `"An error occurred."`.

`tool()` returns a handle with `sleep(delayMs)`, `output(value)`, and
`error(errorText?)`. Use the handle when the tool lifecycle needs events
between its input and result. Calling `tool.error()` without a message uses
`"Tool call failed."`.

On This Page

