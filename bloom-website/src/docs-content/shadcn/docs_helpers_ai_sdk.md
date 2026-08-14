# AI SDK - shadcn/ui

> Source: https://ui.shadcn.com/docs/helpers/ai-sdk

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
# AI SDK
Create AI SDK messages and stream predefined conversations through useChat without a model, API route, network request, or API key.

`@shadcn/helpers/ai-sdk` lets you write an AI conversation in code and stream it
through `useChat`, with no model, API route, network request, or API key.

Because the conversation streams through the real `useChat` lifecycle, your
components behave exactly as they would in production.

It supports every part type the AI SDK does: reasoning, tools, data, files,
sources, and custom parts. Tool calls can also pause for real user input,
including approvals. See Human in the Loop.

```
Copyimport { createChat } from "@shadcn/helpers/ai-sdk"
 
const chat = createChat()
  .user("What changed in this release?")
  .assistant("The release adds keyboard shortcuts and faster search.")
  .user("Can you show me the shortcuts?")
  .assistant("Press ⌘K to search and ⌘Enter to submit.")```

Pass the chat to `useChat` with its initial messages and local transport.
`useChat` receives the same typed `UIMessage[]` it would get from a streamed
response.

```
Copyimport { useChat } from "@ai-sdk/react"
 
function Chat() {
  const { messages, sendMessage } = useChat({
    messages: chat.get(0), // starts with no messages.
    transport: chat.transport(),
  })
 
  const nextMessage = chat.next(messages)
 
  return (
    <button
      disabled={!nextMessage}
      onClick={() => {
        if (nextMessage) {
          void sendMessage(nextMessage)
        }
      }}
    >
      Send next message
    </button>
  )
}```

`get(0)` starts with no messages. `sendMessage(nextMessage)` sends the next
predefined user message; the transport then streams its assistant response.

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

This helper works alongside your existing AI SDK setup (`ai` and
`@ai-sdk/react`). Import the helpers from `@shadcn/helpers/ai-sdk`.

---
Create a conversation, pass its messages and transport to `useChat`, then send
each predefined user message with `next()`.

```
Copy"use client"
 
import { useChat } from "@ai-sdk/react"
import { createChat } from "@shadcn/helpers/ai-sdk"
 
const chat = createChat()
  .user("What changed in this release?")
  .assistant("The release adds keyboard shortcuts and faster search.")
  .user("Can you show me the shortcuts?")
  .assistant("Press ⌘K to search and ⌘Enter to submit.")
 
const initialMessages = chat.get(0)
const transport = chat.transport()
 
export function Chat() {
  const { messages, sendMessage, status } = useChat({
    messages: initialMessages,
    transport,
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
            void sendMessage(nextMessage)
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

import { useChat } from "@ai-sdk/react"```

---
Messages added with this helper use the `user` and `assistant` roles. Use
`user()` to add a user message. Existing AI SDK messages are preserved when
you start with `createChat({ messages })`.

```
Copyconst chat = createChat().user("What changed in this release?")
 
const [message] = chat.get()
 
message.role // "user"
message.parts // [{ type: "text", text: "What changed in this release?" }]```

Pass an `id` or metadata as the second argument when you need them.

```
Copychat.user("What changed in this release?", {
  id: "user-release-question",
  metadata: {
    source: "docs",
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
message.parts // [{ type: "text", text: "The release adds...", state: "done" }]```

A string creates one text part. You can also pass an array of AI SDK message
parts.

```
Copychat.assistant([
  { type: "text", text: "The release adds keyboard shortcuts." },
  { type: "text", text: "Search is faster too." },
])```

Use the writer callback when the message has more than plain text.

```
Copychat.assistant(({ writer }) => {
  writer.reasoning("I should summarize the release.")
  writer.text("The release adds keyboard shortcuts and faster search.")
})```

The writer adds parts in the order you call them.

---
An assistant message can contain many part types. Add them with the `writer`
passed to `assistant()`, in the order you call them:

- Text and Reasoning
- Tool Calls
- Data
- Files and Sources
- Step Starts and Custom Parts
```
Copychat.assistant(({ writer }) => {
  writer.reasoning("Let me check the weather.")
  writer
    .tool("getWeather", { input: { city: "San Francisco" } })
    .output({ city: "San Francisco", temperature: 18, condition: "Breezy" })
  writer.text("It is 18°C and breezy in San Francisco.")
})```

---
Use `text()` to add a text part.

```
Copychat.assistant(({ writer }) => {
  writer.text("The release adds keyboard shortcuts.")
  writer.text(" Search is faster too.")
})```

Each call creates a separate text part. Text streams word by word when the chat
is used with `chat.transport()`.

Use `mode: "instant"` to send the whole part at once, or `delayMs` to change the
delay between its text deltas.

```
Copywriter.text("Done.", { mode: "instant" })
writer.text("This part streams more slowly.", { delayMs: 100 })```

Pass an `id` when the text part needs a stable identifier.

```
Copywriter.text("The final answer.", { id: "answer" })```

---
Use `reasoning()` to add a reasoning part.

```
Copychat.assistant(({ writer }) => {
  writer.reasoning("I should check the latest conditions first.")
  writer.text("Let me check the weather.")
})```

Reasoning uses the same `id`, `delayMs`, and `mode` options as text.

```
Copywriter.reasoning("Checking the forecast.", { mode: "instant" })```

---
Use `tool()` to add a tool call. It returns a handle that follows the tool from
input to output.

```
Copychat.assistant(({ writer }) => {
  writer
    .tool("getWeather", {
      title: "Checking weather",
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

The tool can finish with `output()`, `error()`, or `denied()`.

```
Copywriter.tool("getWeather", { input: { city: "San Francisco" } }).error()
 
writer.tool("getWeather", { input: { city: "San Francisco" } }).denied()```

Pass `dynamic: true` to create an AI SDK `dynamic-tool` part instead of a typed
`tool-<name>` part.

```
Copywriter.tool("getWeather", {
  dynamic: true,
  input: { city: "San Francisco" },
  output: { city: "San Francisco", temperature: 18, condition: "Breezy" },
})```

Type the tool name, input, and output by passing your message type to
`createChat`. It takes the same type parameter as `useChat`.

```
Copyimport type { UIMessage } from "ai"
 
type Tools = {
  getWeather: {
    input: { city: string }
    output: { city: string; temperature: number; condition: string }
  }
}
 
type ChatMessage = UIMessage<unknown, Record<string, never>, Tools>
 
const chat = createChat<ChatMessage>()```

Define the message type once and use it for both `createChat` and `useChat`.

```
Copyconst { messages } = useChat<ChatMessage>({
  messages: chat.get(0),
  transport: chat.transport(),
})```

A tool call can also wait for the user instead of finishing in the script.
See Human in the Loop.

---
A tool call can pause and hand control to the real user. The helper supports
both AI SDK human-in-the-loop flows: client-executed tools, where the user
supplies the output, and approval-gated tools, where the user approves or
denies before a scripted output streams.

Leave a tool call unresolved to pause the turn. The input streams, the turn
finishes, and the part stays in the `input-available` state until the client
supplies its output with `addToolOutput`.

```
Copychat.assistant(({ writer }) => {
  writer.text("Answer these and I'll tailor the prototype.")
  writer.tool("askQuestions", { input: { questions } })
})```

Pass `needsApproval: true` to pause behind the user's decision. `output` then
means "stream this after approval" instead of "resolve immediately". Denial
streams `tool-output-denied` automatically, and `errorText` with
`needsApproval` scripts a tool that fails after approval.

```
Copychat.assistant(({ writer }) => {
  writer.text("That will archive 3 drafts. I need your approval.")
  writer.tool("archiveDrafts", {
    input: { count: 3 },
    needsApproval: true,
    output: { archived: 3 },
  })
})```

Calling `output()`, `error()`, or `denied()` on the handle of a
`needsApproval` call throws. The user's decision resolves it.

A callback turn scripted immediately after a paused turn becomes a
continuation. It does not materialize when the script is built. It runs when
the follow-up request arrives, and its context includes `toolCall`: the
paused call joined with what the user did.

```
Copychat
  .assistant(({ writer }) => {
    writer.tool("askQuestions", { input: { questions } })
  })
  .assistant(({ writer, toolCall }) => {
    writer.text(
      toolCall?.name === "askQuestions" && toolCall.output
        ? `Starting with ${toolCall.output.answers.direction}.`
        : "Starting now."
    )
  })```

For a client-executed tool, `toolCall.output` is the output the user
submitted. For an approval, `toolCall.approved` and `toolCall.denied` carry
the decision, and the scripted output streams before the callback's content.

Continuation context also includes `messages`, the live transcript, and
`toolCalls`, every paused call when a turn has more than one.

Continuations must stay pure. Regenerating re-resolves them against the
current transcript, so a changed decision produces the other branch.

The client side uses the AI SDK as-is. Submit a client-executed tool's output
with `addToolOutput`, answer an approval with `addToolApprovalResponse`, and
let `sendAutomaticallyWhen` send the follow-up request.

```
Copyimport {
  lastAssistantMessageIsCompleteWithApprovalResponses,
  lastAssistantMessageIsCompleteWithToolCalls,
} from "ai"
 
const { messages, addToolOutput, addToolApprovalResponse } = useChat({
  messages: chat.get(0),
  transport: chat.transport(),
  sendAutomaticallyWhen: (options) =>
    lastAssistantMessageIsCompleteWithToolCalls(options) ||
    lastAssistantMessageIsCompleteWithApprovalResponses(options),
})```

```
Copy// In a pending tool part renderer.
addToolOutput({
  tool: "askQuestions",
  toolCallId: part.toolCallId,
  output: { answers },
})
 
// In an approval-requested part renderer.
addToolApprovalResponse({ id: part.approval.id, approved: true })```

The continuation streams as a new step of the paused assistant message. The
client merges its parts into that message instead of adding a new one, and
the helper emits the step boundary and omits the continuation's message id so
the merge stays in place and the automatic send does not re-trigger.

In development, the helper warns when a `needsApproval` call has no
continuation turn after it, and when a continuation resolves without a
pending tool call.

---
Use `data()` to add a typed `data-*` part.

```
Copytype DataParts = {
  weather: {
    city: string
    status: "loading" | "success"
    temperature?: number
    condition?: string
  }
}
 
const chat = createChat<UIMessage<unknown, DataParts>>().assistant(
  ({ writer }) => {
    writer.data({
      type: "data-weather",
      id: "weather-sf",
      data: { city: "San Francisco", status: "loading" },
    })
  }
)```

Send the same `type` and `id` again to update the part in place. This is useful
for states such as loading to success.

```
Copywriter.data({
  type: "data-weather",
  id: "weather-sf",
  data: {
    city: "San Francisco",
    status: "success",
    temperature: 27,
    condition: "Breezy",
  },
})```

Set `transient: true` for an update that should stream to the client but should
not remain in the final message.

```
Copywriter.data({
  type: "data-weather",
  data: { city: "San Francisco", status: "loading" },
  transient: true,
})```

---
Add files to a user message with the `files` option.

```
Copychat.user("Summarize this report.", {
  files: [
    {
      filename: "report.pdf",
      mediaType: "application/pdf",
      url: "https://example.com/report.pdf",
    },
  ],
})```

Use `file()` to add a file to an assistant message.

```
Copychat.assistant(({ writer }) => {
  writer.file({
    filename: "summary.md",
    mediaType: "text/markdown",
    url: "https://example.com/summary.md",
  })
})```

Use `reasoningFile()` for a file attached to a reasoning part.

```
Copywriter.reasoningFile({
  filename: "notes.txt",
  mediaType: "text/plain",
  url: "https://example.com/notes.txt",
})```

---
Use `sourceUrl()` to add a URL source.

```
Copywriter.sourceUrl({
  sourceId: "source-1",
  title: "Release notes",
  url: "https://example.com/releases",
})```

Use `sourceDocument()` to add a document source.

```
Copywriter.sourceDocument({
  sourceId: "source-2",
  title: "Product brief",
  mediaType: "application/pdf",
  filename: "brief.pdf",
})```

---
Use `stepStart()` to add an AI SDK step boundary.

```
Copychat.assistant(({ writer }) => {
  writer.stepStart()
  writer.reasoning("I should search the release notes.")
  writer.stepStart()
  writer.text("Here is what changed.")
})```

---
Use `custom()` to add a custom part.

```
Copychat.assistant(({ writer }) => {
  writer.custom("app.approval")
})```

The message receives a `custom` part with the given `kind`. The AI SDK expects
kinds in the `{provider}.{provider-type}` format. Calling `custom()` without a
kind uses `"test.output"`.

---
Use `get()` to return messages from the start of the conversation.

```
Copychat.get() // Every message.
chat.get(2) // The first two messages.
chat.get(0) // An empty initial conversation.```

`get()` returns cloned messages and does not change the chat. It stops before
the first continuation turn, since a continuation has no
message without a live transcript, and throws when `count` reaches past one.

Use `next()` to find the next predefined user message after the messages already
shown.

```
Copyconst initialMessages = chat.get(2)
const nextMessage = chat.next(initialMessages)```

`next()` always accepts a message transcript, not an index. It returns the next
user message or `null` when none remain.

---
Pass `messages` to continue from a saved conversation or fixture.

```
Copyimport { createChat } from "@shadcn/helpers/ai-sdk"
import type { UIMessage } from "ai"
 
declare const savedMessages: UIMessage[]
 
const chat = createChat({ messages: savedMessages })
  .user("What should we do next?")
  .assistant("Turn the open questions into a checklist.")```

Existing IDs, metadata, and parts are preserved.

---
`transport()` creates an AI SDK `ChatTransport` that you can pass directly to
`useChat`.

```
Copyconst transport = chat.transport()
 
const { messages, sendMessage } = useChat({
  messages: chat.get(0),
  transport,
})```

When `sendMessage()` runs, the transport finds the assistant message that
follows the current transcript and streams it through the normal AI SDK chat
lifecycle. It uses message IDs first and falls back to matching the role and
text of the latest message. Automatic sends after tool results and approval
responses resolve the next continuation; only a
regeneration replays a turn by its message ID.

The transport-level `delayMs` is the default for every streamed text and
reasoning part. Override it for one part with `writer.text(..., { delayMs })`
or `writer.reasoning(..., { delayMs })`.

```
Copyconst transport = chat.transport({
  delayMs: 25,
})```

Use `fallback` when the conversation has no predefined assistant response
left. This keeps a demo usable after its predefined replies are exhausted.

```
Copyconst transport = chat.transport({
  fallback: "This demo has no more predefined replies.",
})```

A fallback can also be an array of AI SDK message parts or a writer callback.
The callback receives the incoming transcript, so it can create a response from
the current state.

```
Copyconst transport = chat.transport({
  fallback: ({ writer, messages }) => {
    writer.text(`This example already has ${messages.length} messages.`, {
      mode: "instant",
    })
  },
})```

Fallback responses stream like assistant responses but are not added to the
predefined conversation. Without one, the transport throws
`"No assistant response found for this transcript."` when the conversation is
exhausted.

Calling `stop()` from `useChat` aborts the active transport stream.
Reconnecting is not supported; `reconnectToStream()` returns `null`.

---
Use delays to reproduce the pace of a real response.

```
Copyconst chat = createChat()
  .user("Give me a project update.")
  .sleep(800)
  .assistant(({ writer }) => {
    writer.text("The first milestone is complete.", { mode: "instant" })
    writer.sleep(500)
    writer.text(" The next one is ready.")
  })
 
const transport = chat.transport({ delayMs: 50 })```

- `chat.sleep(ms)` waits before the next assistant response starts.
- `writer.sleep(ms)` waits between parts of an assistant response.
- `tool.sleep(ms)` waits between a tool's input and its result.
- `transport({ delayMs })` sets the default delay between text and reasoning
deltas.
- `writer.text(text, { delayMs })` and `writer.reasoning(text, { delayMs })`
override that delay for one part.
- `mode: "instant"` sends a whole text or reasoning part in one delta.
For fast tests, use `chat.transport({ delayMs: 0 })` and instant text.

---
Use `error()` on the chat when the whole assistant response should fail.

```
Copyconst chat = createChat()
  .user("Load the report.")
  .error("The report could not be loaded.")```

Use `writer.error()` to fail after other parts have streamed.

```
Copychat.assistant(({ writer }) => {
  writer.text("I found the report.")
  writer.error("The connection closed before it could be read.")
})```

---
Pass metadata on individual messages. Its type is preserved through `get()`,
`next()`, and the transport.

```
Copytype Metadata = {
  model: string
}
 
const chat = createChat<UIMessage<Metadata>>()
  .user("Hello", { metadata: { model: "demo" } })
  .assistant("Hi.", {
    id: "assistant-welcome",
    metadata: { model: "demo" },
  })```

Use chat options when a fixture needs custom prefixes or a fixed clock.

```
Copyconst chat = createChat({
  messageIdPrefix: "demo-message",
  toolCallIdPrefix: "demo-tool",
  sourceIdPrefix: "demo-source",
  now: "2026-01-01T00:00:00.000Z",
})```

---
The sections above cover the common flows. This reference lists every public
export and option.

Creates a typed conversation and returns the fluent chat interface.

```
Copyfunction createChat<UI_MESSAGE extends UIMessage = UIMessage>(
  options?: CreateChatOptions<UI_MESSAGE>
): AiSdkChat<UI_MESSAGE>```

The message type carries the metadata shape, the typed `data-*` parts, and the
tool definitions.

```
Copytype ChatMessage = UIMessage<Metadata, DataParts, Tools>```

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

See Transport for matching, fallback, abort, and streaming
behavior.

The writer is available inside `assistant(({ writer }) => {})` and fallback
callbacks.

Calling `text()` without content uses `"Summarize the uploaded receipt."`.
Calling `reasoning()` without content uses
`"I need to inspect the available context before answering."`. Calling
`error()` without a message uses `"An error occurred."`.

`tool()` returns a handle with `sleep(delayMs)`, `output(value)`,
`error(errorText?)`, and `denied()`. Use the handle when the tool lifecycle
needs events between its input and result. Calling `tool.error()` without a
message uses `"Tool call failed."`. The resolution methods throw on a
`needsApproval` call.

```
Copywriter.data({
  type: "data-name",
  id: "optional-id",
  data: value,
  transient: false,
})```

Repeating the same `type` and `id` replaces the earlier data part. A transient
part streams to the client but is not included in the final message returned by
`get()`.

These methods provide sample defaults for omitted fields. Pass explicit values
when the payload matters to the component or test.

On This Page

