# Questionnaire - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/radix/questionnaire

- [Introduction](/docs)
- [Components](/docs/components)
- [Installation](/docs/installation)
- [Theming](/docs/theming)
- [CLI](/docs/cli)
- [Typeset](/docs/typeset)
- [Skills](/docs/skills)
- [Registry](/docs/registry)
- [Changelog](/docs/changelog)
- [Accordion](/docs/components/radix/accordion)
- [Alert](/docs/components/radix/alert)
- [Alert Dialog](/docs/components/radix/alert-dialog)
- [Aspect Ratio](/docs/components/radix/aspect-ratio)
- [Attachment](/docs/components/radix/attachment)
- [Avatar](/docs/components/radix/avatar)
- [Badge](/docs/components/radix/badge)
- [Breadcrumb](/docs/components/radix/breadcrumb)
- [Bubble](/docs/components/radix/bubble)
- [Button](/docs/components/radix/button)
- [Button Group](/docs/components/radix/button-group)
- [Calendar](/docs/components/radix/calendar)
- [Card](/docs/components/radix/card)
- [Carousel](/docs/components/radix/carousel)
- [Chart](/docs/components/radix/chart)
- [Checkbox](/docs/components/radix/checkbox)
- [Collapsible](/docs/components/radix/collapsible)
- [Combobox](/docs/components/radix/combobox)
- [Command](/docs/components/radix/command)
- [Context Menu](/docs/components/radix/context-menu)
- [Data Table](/docs/components/radix/data-table)
- [Date Picker](/docs/components/radix/date-picker)
- [Dialog](/docs/components/radix/dialog)
- [Direction](/docs/components/radix/direction)
- [Drawer](/docs/components/radix/drawer)
- [Dropdown Menu](/docs/components/radix/dropdown-menu)
- [Empty](/docs/components/radix/empty)
- [Field](/docs/components/radix/field)
- [Hover Card](/docs/components/radix/hover-card)
- [Input](/docs/components/radix/input)
- [Input Group](/docs/components/radix/input-group)
- [Input OTP](/docs/components/radix/input-otp)
- [Item](/docs/components/radix/item)
- [Kbd](/docs/components/radix/kbd)
- [Label](/docs/components/radix/label)
- [Marker](/docs/components/radix/marker)
- [Menubar](/docs/components/radix/menubar)
- [Message](/docs/components/radix/message)
- [Message Scroller](/docs/components/radix/message-scroller)
- [Native Select](/docs/components/radix/native-select)
- [Navigation Menu](/docs/components/radix/navigation-menu)
- [Pagination](/docs/components/radix/pagination)
- [Popover](/docs/components/radix/popover)
- [Progress](/docs/components/radix/progress)
- [Questionnaire](/docs/components/radix/questionnaire)
- [Radio Group](/docs/components/radix/radio-group)
- [Resizable](/docs/components/radix/resizable)
- [Scroll Area](/docs/components/radix/scroll-area)
- [Select](/docs/components/radix/select)
- [Separator](/docs/components/radix/separator)
- [Sheet](/docs/components/radix/sheet)
- [Sidebar](/docs/components/radix/sidebar)
- [Skeleton](/docs/components/radix/skeleton)
- [Slider](/docs/components/radix/slider)
- [Sonner](/docs/components/radix/sonner)
- [Spinner](/docs/components/radix/spinner)
- [Switch](/docs/components/radix/switch)
- [Table](/docs/components/radix/table)
- [Tabs](/docs/components/radix/tabs)
- [Textarea](/docs/components/radix/textarea)
- [Toast](/docs/components/radix/toast)
- [Toggle](/docs/components/radix/toggle)
- [Toggle Group](/docs/components/radix/toggle-group)
- [Tooltip](/docs/components/radix/tooltip)
- [Typography](/docs/components/radix/typography)
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
A multi-step questionnaire with single-choice, multiple-choice, freeform, and skippable questions.

Choose a direction or describe another task.

Choose an answer to continue.

Select all that apply, or skip this question.

Choose an answer or skip this question.

Choose when the agent should begin the work.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

```
pnpm dlx shadcn@latest add questionnaire```

```
```

```
Copyimport {
  Questionnaire,
  QuestionnaireActions,
  QuestionnaireChoice,
  QuestionnaireChoices,
  QuestionnaireDescription,
  QuestionnaireError,
  QuestionnaireInput,
  QuestionnaireItem,
  QuestionnaireNext,
  QuestionnairePrevious,
  QuestionnaireProgress,
  QuestionnaireSkip,
  QuestionnaireSubmit,
  QuestionnaireTitle,
} from "@/components/ui/questionnaire"```

```
Copyconst items = [
  {
    name: "direction",
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

Define the collection once: pass it to `Questionnaire` for server-rendered
progress, actions, and shortcuts, then map it into the parts.

```
Copy<Questionnaire items={items} onSubmit={handleSubmit}>
  <QuestionnaireProgress />
  {items.map((question) => (
    <QuestionnaireItem
      key={question.name}
      name={question.name}
      required={question.required}
    >
      <QuestionnaireTitle>{question.prompt}</QuestionnaireTitle>
      <QuestionnaireDescription>
        {question.description}
      </QuestionnaireDescription>
      <QuestionnaireChoices>
        {question.choices.map((choice) => (
          <QuestionnaireChoice key={choice.value} value={choice.value}>
            <span className="font-medium">{choice.label}</span>
            {"description" in choice ? (
              <span className="text-muted-foreground">
                {choice.description}
              </span>
            ) : null}
          </QuestionnaireChoice>
        ))}
        {"input" in question ? (
          <QuestionnaireInput
            aria-label={question.input.label}
            placeholder={question.input.placeholder}
          />
        ) : null}
      </QuestionnaireChoices>
      <QuestionnaireError />
    </QuestionnaireItem>
  ))}
  <QuestionnaireActions>
    <QuestionnairePrevious />
    <QuestionnaireSkip />
    <QuestionnaireNext />
    <QuestionnaireSubmit />
  </QuestionnaireActions>
</Questionnaire>```

```
Copyfunction handleSubmit(event: React.FormEvent<HTMLFormElement>) {
  event.preventDefault()
  const answers = new FormData(event.currentTarget)
  // answers.get("direction"), answers.getAll(...) for multiple items.
}```

```
CopyQuestionnaire
├── QuestionnaireProgress
├── QuestionnaireItem
│   ├── QuestionnaireTitle
│   ├── QuestionnaireDescription
│   ├── QuestionnaireChoices
│   │   ├── QuestionnaireChoice
│   │   └── QuestionnaireInput
│   └── QuestionnaireError
└── QuestionnaireActions
    ├── QuestionnairePrevious
    ├── QuestionnaireSkip
    ├── QuestionnaireNext
    └── QuestionnaireSubmit```

Questionnaire owns the ordered items, active item, answer state, validation,
progress, and navigation. The containing page, card, dialog, or drawer owns
close and cancellation behavior, persistence, transport, and branching.

Pass `items` to server-render the active item, progress, actions, and answer
shortcuts. See the
[headless Questionnaire](/docs/react/questionnaire) for the complete behavior.

Use `multiple` for an item that accepts more than one fixed answer.

Select every source that may affect the implementation.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Compose `QuestionnaireInput` with fixed choices when the user can provide another answer.

Choose a strategy or write a more specific instruction.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Add `QuestionnaireSkip` when an optional item may be intentionally left unanswered.

Choose the category that best describes the work.

Choose an answer to continue.

Answer if needed, or intentionally skip this question.

Choose the checks the agent should complete before handoff.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Assign a letter or number key to each answer with `shortcuts`.

Use the displayed shortcut or navigate with the keyboard.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Combine controlled navigation with an external schema such as Zod to return to an invalid item and present its error.

Choose the response depth.

Choose an answer to continue.

Public answers require complete context.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Control the active item from host state, such as returning to an invalid step.

Current checkpoint: Change scope

The host stores the active checkpoint while Questionnaire navigates.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Restore a saved active item and default answers, then reset changes back to that saved state.

This answer was saved during the previous session.

Choose an answer to continue.

These checks were selected during the previous session.

Choose an answer to continue.

This note was saved with the draft.

```
"use client"

import * as React from "react"```

Disable items that do not apply to the user's earlier answers.

Cloud runs add an environment question to this flow.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Read item status to opt into disabled navigation and custom action styling.

Next is intentionally disabled until an answer is selected.

Choose an answer to continue.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Use the Progress render state to build a custom progress indicator.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Animate the active item while keeping progress and navigation stationary.

Choose the task for this run.

Choose an answer to continue.

Select the verification depth.

Choose an answer to continue.

Choose the final handoff format.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Compose Questionnaire with Card slots while keeping the question title and description semantic.

Choose an answer to continue.

Choose an answer to continue.

```
"use client"

import * as React from "react"```

Compose Questionnaire inside a Dialog while keeping cancellation and dismissal host-owned.

```
"use client"

import * as React from "react"```

`QuestionnaireItem` renders a `fieldset`, and `QuestionnaireTitle` renders its
`legend`. Descriptions and active errors are associated with the current item,
and invalid items and answer controls expose `aria-invalid`.

Fixed choices preserve native radio and checkbox behavior. Progress is exposed
as a named progressbar, navigation uses real buttons, and inactive items and
actions are hidden and inert. Successful navigation focuses the newly active
item; failed validation focuses an available answer control.

Always give `QuestionnaireInput` an accessible name with a visible label,
`aria-label`, or `aria-labelledby`. A placeholder is not a label. See the
[Questionnaire accessibility guide](/docs/react/questionnaire#accessibility)
for labeling custom compositions and the complete keyboard behavior.

The behavior in `Questionnaire` comes from the `@shadcn/react` package. To use
it directly with your own markup and styles, see
[Questionnaire](/docs/react/questionnaire) under @shadcn/react.

The props, data attributes, and render states for every part are documented on
the [@shadcn/react Questionnaire](/docs/react/questionnaire#api-reference) page.
The styled components inherit the corresponding unstyled props. Navigation
components also accept Button `size` and `variant` props, and
`QuestionnaireActions` is a styled-only layout helper.

On This Page

