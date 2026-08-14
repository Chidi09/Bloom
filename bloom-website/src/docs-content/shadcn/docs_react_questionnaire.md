# Questionnaire - shadcn/ui

> Source: https://ui.shadcn.com/docs/react/questionnaire

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
# Questionnaire
Build accessible, multi-step questionnaires with single, multiple, freeform, and intentionally skipped answers.

`Questionnaire` is an unstyled form primitive for presenting one question at a
time. It manages answers, progress, validation, and navigation.

It works well for agent clarification prompts, onboarding, surveys, intake
forms, and configuration.

The unstyled package gives you full control over markup and styles. For the
styled version and themed examples, see
[Questionnaire](/docs/components/base/questionnaire).

```
pnpm add @shadcn/react```

```
```

```
Copyimport { Questionnaire } from "@shadcn/react/questionnaire"```

`Questionnaire` exports its parts from one namespace. Each part accepts the
native props for its default element.

```
Copy<Questionnaire.Root>
  <Questionnaire.Progress />
  <Questionnaire.Item name="question">
    <Questionnaire.Title />
    <Questionnaire.Description />
    <Questionnaire.Choices>
      <Questionnaire.Choice>
        <Questionnaire.ChoiceInput />
        <Questionnaire.ChoiceLabel />
        <Questionnaire.ChoiceShortcut />
      </Questionnaire.Choice>
      <Questionnaire.Input />
    </Questionnaire.Choices>
    <Questionnaire.Error />
  </Questionnaire.Item>
  <Questionnaire.Previous />
  <Questionnaire.Skip />
  <Questionnaire.Next />
  <Questionnaire.Submit />
</Questionnaire.Root>```

`Root` renders a form. Each `Item` is a fieldset, with `Title` as its legend.
`ChoiceInput` renders a native radio or checkbox.

The styled registry component uses flat component names:

The styled `QuestionnaireChoice` composes the input, label, shortcut, and visual
indicator for you. With the unstyled package, compose those parts yourself.

Each `Item` is one step. Its `name` identifies the step and becomes the form
field name for its answers. `Choice.value` is the submitted answer.

Choose a direction or describe another task.

Choose an answer to continue.

Select all that apply, or skip this question.

Choose an answer or skip this question.

Choose when the agent should begin the work.

Choose an answer to continue.

```
Copyconst items = [
  {
    name: "prototype",
    required: true,
    prompt: "What should we prototype next?",
    description: "Choose a direction or write your own.",
    choices: [
      {
        value: "delegation",
        label: "Delegation",
        description: "Show how work moves to a specialist.",
      },
      {
        value: "questions",
        label: "Question prompts",
        description: "Show choices while the interface waits.",
      },
      { value: "both", label: "Both together" },
    ],
    input: { label: "Another answer", placeholder: "Type another answer…" },
  },
  {
    name: "detail",
    required: false,
    prompt: "How much detail should it include?",
    description: "Skip this if you are not sure yet.",
    choices: [
      { value: "focused", label: "Focused" },
      { value: "complete", label: "Complete flow" },
    ],
  },
] as const```

```
Copy"use client"
 
import * as React from "react"
import { Questionnaire } from "@shadcn/react/questionnaire"
 
export function ProjectQuestionnaire() {
  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
 
    const formData = new FormData(event.currentTarget)
 
    console.log({
      prototype: formData.get("prototype"),
      detail: formData.get("detail"),
    })
  }
 
  return (
    <Questionnaire.Root items={items} onSubmit={handleSubmit}>
      <Questionnaire.Progress />
      {items.map((question) => (
        <Questionnaire.Item
          key={question.name}
          name={question.name}
          required={question.required}
        >
          <Questionnaire.Title>{question.prompt}</Questionnaire.Title>
          <Questionnaire.Description>
            {question.description}
          </Questionnaire.Description>
          <Questionnaire.Choices>
            {question.choices.map((choice) => (
              <Questionnaire.Choice key={choice.value} value={choice.value}>
                <Questionnaire.ChoiceInput />
                <Questionnaire.ChoiceLabel>
                  <span>{choice.label}</span>
                  {"description" in choice ? (
                    <span>{choice.description}</span>
                  ) : null}
                </Questionnaire.ChoiceLabel>
                <Questionnaire.ChoiceShortcut />
              </Questionnaire.Choice>
            ))}
            {"input" in question ? (
              <Questionnaire.Input
                aria-label={question.input.label}
                placeholder={question.input.placeholder}
              />
            ) : null}
          </Questionnaire.Choices>
          <Questionnaire.Error />
        </Questionnaire.Item>
      ))}
      <Questionnaire.Previous />
      <Questionnaire.Skip />
      <Questionnaire.Next />
      <Questionnaire.Submit />
    </Questionnaire.Root>
  )
}```

Pass the same `items` collection to `Root` that you render as `Item` and
`Choice` parts. This makes item order, progress, action visibility, and answer
shortcuts available in the server-rendered HTML.

`multiple` turns an item's fixed choices into native checkboxes. Read the answers with
`FormData.getAll()`. Keep `multiple` in your application data and pass it to
the rendered `Item`.

Select every source that may affect the implementation.

Choose an answer to continue.

```
Copyconst items = [
  {
    name: "signals",
    required: true,
    multiple: true,
    prompt: "What should every update include?",
    description: "Select all that apply.",
    choices: [
      { value: "progress", label: "Progress" },
      { value: "decisions", label: "Decisions" },
      { value: "risks", label: "Risks" },
    ],
  },
] as const```

```
Copyitems.map((question) => (
  <Questionnaire.Item
    key={question.name}
    name={question.name}
    multiple={question.multiple}
    required={question.required}
  >
    <Questionnaire.Title>{question.prompt}</Questionnaire.Title>
    <Questionnaire.Description>
      {question.description}
    </Questionnaire.Description>
    <Questionnaire.Choices>
      {question.choices.map((choice) => (
        <Questionnaire.Choice key={choice.value} value={choice.value}>
          <Questionnaire.ChoiceInput />
          <Questionnaire.ChoiceLabel>{choice.label}</Questionnaire.ChoiceLabel>
          <Questionnaire.ChoiceShortcut />
        </Questionnaire.Choice>
      ))}
    </Questionnaire.Choices>
    <Questionnaire.Error />
  </Questionnaire.Item>
))```

```
Copyconst signals = new FormData(form).getAll("signals").map(String)```

`Input` adds a freeform answer and renders a native text input.

Choose a strategy or write a more specific instruction.

Choose an answer to continue.

```
Copyconst items = [
  {
    name: "prototype",
    required: true,
    prompt: "What should we prototype next?",
    choices: [
      { value: "delegation", label: "Delegation" },
      { value: "questions", label: "Question prompts" },
    ],
    input: {
      label: "Another prototype direction",
      placeholder: "Type another direction…",
    },
  },
] as const```

```
Copyitems.map((question) => (
  <Questionnaire.Item
    key={question.name}
    name={question.name}
    required={question.required}
  >
    <Questionnaire.Title>{question.prompt}</Questionnaire.Title>
    <Questionnaire.Choices>
      {question.choices.map((choice) => (
        <Questionnaire.Choice key={choice.value} value={choice.value}>
          <Questionnaire.ChoiceInput />
          <Questionnaire.ChoiceLabel>{choice.label}</Questionnaire.ChoiceLabel>
          <Questionnaire.ChoiceShortcut />
        </Questionnaire.Choice>
      ))}
      <Questionnaire.Input
        aria-label={question.input.label}
        placeholder={question.input.placeholder}
      />
    </Questionnaire.Choices>
    <Questionnaire.Error />
  </Questionnaire.Item>
))```

`Skip` records that an optional item was intentionally left unanswered. Use
`onStatusChange` when your application needs to distinguish a skipped answer
from a missing one.

Choose the category that best describes the work.

Choose an answer to continue.

Answer if needed, or intentionally skip this question.

Choose the checks the agent should complete before handoff.

Choose an answer to continue.

```
Copy"use client"
 
import * as React from "react"
import {
  Questionnaire,
  type QuestionnaireItemStatus,
} from "@shadcn/react/questionnaire"
 
export function PlanningQuestionnaire() {
  const [timingStatus, setTimingStatus] =
    React.useState<QuestionnaireItemStatus>("unanswered")
 
  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
 
    const formData = new FormData(event.currentTarget)
 
    console.log({
      timing:
        timingStatus === "skipped"
          ? { status: "skipped" }
          : {
              status: "answered",
              value: formData.get("timing"),
            },
    })
  }
 
  return (
    <Questionnaire.Root defaultItem="timing" onSubmit={handleSubmit}>
      <Questionnaire.Item name="timing" onStatusChange={setTimingStatus}>
        <Questionnaire.Title>
          When should this be revisited?
        </Questionnaire.Title>
        <Questionnaire.Description>
          Skip this if timing has not been decided.
        </Questionnaire.Description>
        <Questionnaire.Choices>
          <Questionnaire.Choice value="week">
            <Questionnaire.ChoiceInput />
            <Questionnaire.ChoiceLabel>This week</Questionnaire.ChoiceLabel>
            <Questionnaire.ChoiceShortcut />
          </Questionnaire.Choice>
          <Questionnaire.Choice value="cycle">
            <Questionnaire.ChoiceInput />
            <Questionnaire.ChoiceLabel>Next cycle</Questionnaire.ChoiceLabel>
            <Questionnaire.ChoiceShortcut />
          </Questionnaire.Choice>
        </Questionnaire.Choices>
      </Questionnaire.Item>
      <Questionnaire.Skip />
      <Questionnaire.Submit />
    </Questionnaire.Root>
  )
}```

Use `shortcuts="letters"` or `shortcuts="numbers"` to assign a key to each
enabled fixed choice, following the `items` order when it is provided. Compose
`ChoiceShortcut` wherever its hint should appear.

Use the displayed shortcut or navigate with the keyboard.

Choose an answer to continue.

```
Copy<Questionnaire.Root shortcuts="letters">
  <Questionnaire.Item name="review" required>
    <Questionnaire.Title>What should the agent review?</Questionnaire.Title>
    <Questionnaire.Choices>
      <Questionnaire.Choice value="api">
        <Questionnaire.ChoiceInput />
        <Questionnaire.ChoiceLabel>Public API</Questionnaire.ChoiceLabel>
        <Questionnaire.ChoiceShortcut />
      </Questionnaire.Choice>
      <Questionnaire.Choice value="tests">
        <Questionnaire.ChoiceInput />
        <Questionnaire.ChoiceLabel>Test coverage</Questionnaire.ChoiceLabel>
        <Questionnaire.ChoiceShortcut />
      </Questionnaire.Choice>
    </Questionnaire.Choices>
  </Questionnaire.Item>
</Questionnaire.Root>```

`"letters"` assigns `A` through `Z`; `"numbers"` assigns `1` through `9`.
Disabled choices are skipped. Selecting an answer by shortcut does not advance
to the next item.

Questionnaire validates the active item before moving forward and validates all
enabled items when the form submits.

- A required item is valid after it has an answer.
- An optional item is valid after it has an answer or is explicitly skipped.
- Disabled items and answers are ignored.
`required` does not add visible “Required” text. Say it in the `Title` or
`Description`.

When validation fails, Questionnaire keeps or opens the invalid item and
focuses an answer. Add `Error` to show a message.

```
Copy<Questionnaire.Item name="scope" required>
  <Questionnaire.Title>
    What should the project include? (Required)
  </Questionnaire.Title>
  <Questionnaire.Choices>{/* choices */}</Questionnaire.Choices>
  <Questionnaire.Error />
</Questionnaire.Item>```

`Error` remains hidden until the item is invalid. Pass children to replace its
default message.

```
Copy<Questionnaire.Error>Please choose a project scope.</Questionnaire.Error>```

Validation still works without `Error`. When rendered, the message is announced
to screen readers.

For Zod or another external validator, set `Item.invalid`, render the message in
`Error`, and move `Root.item` to the first invalid item.

Choose the response depth.

Choose an answer to continue.

Public answers require complete context.

Choose an answer to continue.

```
Copy<Questionnaire.Root item={item} onItemChange={setItem} onSubmit={handleSubmit}>
  <Questionnaire.Item invalid={Boolean(errors.detail)} name="detail" required>
    <Questionnaire.Title>How much detail?</Questionnaire.Title>
    <Questionnaire.Choices>{/* choices */}</Questionnaire.Choices>
    <Questionnaire.Error>{errors.detail}</Questionnaire.Error>
  </Questionnaire.Item>
</Questionnaire.Root>```

Pass `item` and `onItemChange` to control the active item.

Current checkpoint: Change scope

The host stores the active checkpoint while Questionnaire navigates.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

```
Copyconst [item, setItem] = React.useState("scope")
 
<Questionnaire.Root item={item} onItemChange={setItem} onSubmit={handleSubmit}>
  <Questionnaire.Item name="scope" required>
    {/* question and answers */}
  </Questionnaire.Item>
  <Questionnaire.Item name="verification" required>
    {/* question and answers */}
  </Questionnaire.Item>
  <Questionnaire.Previous />
  <Questionnaire.Next>Next</Questionnaire.Next>
  <Questionnaire.Submit>Submit</Questionnaire.Submit>
</Questionnaire.Root>```

Restore a saved draft with `defaultItem`, `defaultChecked`, and `defaultValue`.

This answer was saved during the previous session.

Choose an answer to continue.

These checks were selected during the previous session.

Choose an answer to continue.

This note was saved with the draft.

```
Copy<Questionnaire.Root defaultItem="verification">
  <Questionnaire.Item name="scope" required>
    <Questionnaire.Title>Which files are in scope?</Questionnaire.Title>
    <Questionnaire.Choices>
      <Questionnaire.Choice value="component" defaultChecked>
        <Questionnaire.ChoiceInput />
        <Questionnaire.ChoiceLabel>Component only</Questionnaire.ChoiceLabel>
      </Questionnaire.Choice>
    </Questionnaire.Choices>
  </Questionnaire.Item>
  <Questionnaire.Item name="verification" required>
    <Questionnaire.Title>Any extra instructions?</Questionnaire.Title>
    <Questionnaire.Input
      aria-label="Extra instructions"
      defaultValue="Run the package tests."
    />
  </Questionnaire.Item>
  <button type="reset">Reset draft</button>
</Questionnaire.Root>```

Set `disabled` to remove an item from the current flow. Disabled items are
excluded from progress, navigation, validation, and submission.

Cloud runs add an environment question to this flow.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

```
Copyconst [runtime, setRuntime] = React.useState("local")
 
<Questionnaire.Root>
  <Questionnaire.Item name="runtime" required>
    <Questionnaire.Title>Where should the agent run?</Questionnaire.Title>
    <Questionnaire.Choices>
      <Questionnaire.Choice
        value="local"
        checked={runtime === "local"}
        onChange={() => setRuntime("local")}
      >
        <Questionnaire.ChoiceInput />
        <Questionnaire.ChoiceLabel>Locally</Questionnaire.ChoiceLabel>
      </Questionnaire.Choice>
      <Questionnaire.Choice
        value="remote"
        checked={runtime === "remote"}
        onChange={() => setRuntime("remote")}
      >
        <Questionnaire.ChoiceInput />
        <Questionnaire.ChoiceLabel>
          Remote environment
        </Questionnaire.ChoiceLabel>
      </Questionnaire.Choice>
    </Questionnaire.Choices>
  </Questionnaire.Item>
  <Questionnaire.Item name="region" disabled={runtime !== "remote"} required>
    {/* remote-only question */}
  </Questionnaire.Item>
</Questionnaire.Root>```

Navigation actions stay enabled by default so activating Next or Submit can
show a validation error. Use the render state when you want to disable an
action yourself.

Next is intentionally disabled until an answer is selected.

Choose an answer to continue.

Choose an answer to continue.

```
Copy<Questionnaire.Next
  render={(props, state) => (
    <button {...props} disabled={state.status === "unanswered"} />
  )}
>
  Next
</Questionnaire.Next>```

The render state contains `visible`, `disabled`, `shortcut`, and the active
item's `status`. To change only the appearance, target `data-status` instead:

```
Copy<Questionnaire.Next data-navigation-action>Next</Questionnaire.Next>```

```
Copy[data-navigation-action][data-status="unanswered"] {
  opacity: 0.5;
}```

`Progress` renders `Question {current} of {total}` by default. Use `render` to
change its element or format.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

```
Copy<Questionnaire.Progress
  aria-label="Setup progress"
  render={(props, state) => (
    <output {...props}>
      Checkpoint {state.current} of {state.total}
    </output>
  )}
/>```

The render state contains `current`, `total`, `first`, and `last`. Pass a
localized `aria-label` when needed.

Animate the active item while keeping progress and navigation stationary.

Choose the task for this run.

Choose an answer to continue.

Select the verification depth.

Choose an answer to continue.

Choose the final handoff format.

Choose an answer to continue.

```
Copyconst itemClassName =
  "data-active:animate-in data-active:fade-in-0 data-active:slide-in-from-bottom-2 data-active:duration-300 motion-reduce:animate-none"
 
<Questionnaire.Item
  className={itemClassName}
  name="task"
  required
>
  {/* ... */}
</Questionnaire.Item>```

Inactive items hide immediately, so animate the entry only.

Place the root around a card and render `Title` and `Description` into the
card header. Give the title an `id` and connect it with the item's
`aria-labelledby` since it replaces the default legend.

Choose an answer to continue.

Choose an answer to continue.

```
Copyconst titleId = React.useId()
 
<Questionnaire.Root onSubmit={handleSubmit}>
  <Card>
    <Questionnaire.Item aria-labelledby={titleId} name="task" required>
      <CardHeader>
        <Questionnaire.Title id={titleId} render={<CardTitle />}>
          What should the agent work on?
        </Questionnaire.Title>
        <Questionnaire.Description render={<CardDescription />}>
          Choose the task that should be handled next.
        </Questionnaire.Description>
        <CardAction>
          <Questionnaire.Progress />
        </CardAction>
      </CardHeader>
      <CardContent>
        <Questionnaire.Choices>{/* choices */}</Questionnaire.Choices>
        <Questionnaire.Error />
      </CardContent>
    </Questionnaire.Item>
    <CardFooter>
      <Questionnaire.Next>Next</Questionnaire.Next>
      <Questionnaire.Submit>Submit</Questionnaire.Submit>
    </CardFooter>
  </Card>
</Questionnaire.Root>```

Keep dialog dismissal separate from `Skip`: closing cancels the flow, while
skipping records an intentional unanswered item.

```
Copyconst titleId = React.useId()
 
<Dialog>
  <DialogTrigger>Open clarification</DialogTrigger>
  <DialogContent>
    <Questionnaire.Root onSubmit={handleSubmit}>
      <Questionnaire.Item aria-labelledby={titleId} name="scope" required>
        <DialogHeader>
          <Questionnaire.Progress />
          <Questionnaire.Title id={titleId} render={<DialogTitle />}>
            Which files are in scope?
          </Questionnaire.Title>
          <Questionnaire.Description render={<DialogDescription />}>
            Choose how broadly the agent can update the workspace.
          </Questionnaire.Description>
        </DialogHeader>
        <Questionnaire.Choices>{/* choices */}</Questionnaire.Choices>
        <Questionnaire.Error />
      </Questionnaire.Item>
      <DialogFooter>
        <DialogClose>Cancel</DialogClose>
        <Questionnaire.Next>Next</Questionnaire.Next>
        <Questionnaire.Submit>Send answer</Questionnaire.Submit>
      </DialogFooter>
    </Questionnaire.Root>
  </DialogContent>
</Dialog>```

Use `render` to replace a part's default element. Pass an element, or use a
function when you need its state.

```
Copy<Questionnaire.Next render={<Button />}>Next</Questionnaire.Next>```

`Root` and `Item` always render a `form` and `fieldset`. If `Title` no longer
renders a `legend`, give it an `id` and pass that ID to `Item` with
`aria-labelledby`.

The primitive does not emit `data-slot`. Styled wrappers own slots and visual
indicators.

`Root` always renders a native form and supports `onSubmit`, `onReset`, `action`,
and the other form props. Do not nest a Questionnaire inside another form.

Answers serialize through native controls:

- `FormData.get(itemName)` reads a single answer.
- `FormData.getAll(itemName)` reads multiple answers.
- Skipped items are absent from `FormData`.
- Use `Item.onStatusChange` to distinguish a skip from a missing answer.
`Root` sets `noValidate` by default so validation uses `Questionnaire.Error`
instead of the browser's constraint validation UI.

`form.reset()` restores the initial item, default answers, skip state, and
validation state.

Questionnaire builds on native radio, checkbox, input, and button behavior.

Shortcuts and arrow navigation pause while you type in a text field.
Preventing the root `onKeyDown` event turns off questionnaire key handling.

Navigation actions stay enabled by default so an attempted action can reveal
validation feedback. See Navigation state to disable or
restyle an unanswered action.

- `Item` renders a `fieldset`.
- `Title` renders the fieldset `legend` by default. If it uses a custom render
target, connect its `id` to the item with `aria-labelledby`.
- `Description` and the active `Error` are connected with
`aria-describedby`.
- Invalid items and answer controls expose `aria-invalid`.
- `Progress` renders a named progressbar with current, minimum, maximum, and
text values.
- Fixed choices use native radios and checkboxes.
- Assigned shortcut keys and available navigation are exposed with
`aria-keyshortcuts`.
- Inactive items and actions are hidden and inert.
- Navigation focuses the newly active fieldset.
- Validation focuses the first available answer control.
- Disabled items are omitted from progress and navigation.
Always give `Input` an accessible name. Use an explicit `id` with a visible
label:

```
Copy<Label htmlFor="other-answer">Other answer</Label>
<Questionnaire.Input
  id="other-answer"
  placeholder="Type another answer…"
/>```

When the design has no visible label, use `aria-label` or `aria-labelledby`:

```
Copy<Questionnaire.Input
  aria-label="Other answer"
  placeholder="Type another answer…"
/>```

A placeholder is not a label.

Use these attributes for styling. Boolean attributes are present when true and
absent when false.

`Title` and `Description` have no state attributes. The headless parts do not
emit `data-slot`.

The form and coordination root.

Root exposes `current`, `total`, `first`, `last`, and `shortcuts` through data
attributes.

The optional collection types are exported from
`@shadcn/react/questionnaire`:

```
Copytype QuestionnaireChoiceDefinition = {
  value: string
  disabled?: boolean
}
 
type QuestionnaireItemDefinition = {
  name: string
  required?: boolean
  disabled?: boolean
  choices?: readonly QuestionnaireChoiceDefinition[]
}```

Position within the enabled item collection.

The render state contains `current`, `total`, `first`, and `last`.

One questionnaire step.

Item exposes `active`, `disabled`, `invalid`, `multiple`, `required`, and
`status` through data attributes.

Item names must be unique within a Root. The name belongs to the answer
controls, not the fieldset.

The item title. Renders a semantic `legend` by default.

Supporting text connected to the item with `aria-describedby`.

A layout container for fixed and freeform answers.

The render state contains `shortcuts`.

A fixed-answer container. Compose one `ChoiceInput`, one `ChoiceLabel`, and an
optional `ChoiceShortcut` inside it. The default `<label>` keeps the whole row
associated with its native control.

The render state contains `checked`, `disabled`, `invalid`, `shortcut`, and
`type`.

The native radio or checkbox for its containing `Choice`. Questionnaire supplies
the props needed for selection, form submission, validation, and keyboard
interaction. It also accepts `className`, `id`, `ref`, `render`, and other
non-conflicting native input props.

`ChoiceInput` must be used inside `Choice`. Its render state matches `Choice`.

The visible label content for a fixed choice. It renders a `<span>` inside the
`Choice` label and accepts native span props and `render`.

The visible shortcut for a fixed choice. It renders a `<span>` containing the
assigned letter or number and remains hidden when the choice has no shortcut.
It accepts native span props and `render`; its render state contains `shortcut`.

A freeform answer. Its native `name` is managed by the containing item.

The render state contains `disabled`, `filled`, and `invalid`.

The validation message. It is hidden until its item fails validation.

`Previous`, `Skip`, `Next`, and `Submit` render native buttons and stay mounted
while their visibility changes.

Each accepts native button props and:

The render state contains `visible`, `disabled`, `shortcut`, and the active
item's `status`.

On This Page

