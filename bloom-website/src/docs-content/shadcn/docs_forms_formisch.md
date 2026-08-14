# Formisch - shadcn/ui

> Source: https://ui.shadcn.com/docs/forms/formisch

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
# Formisch
Build forms in React using Formisch and Valibot.

This guide covers building forms with [Formisch](https://formisch.dev), the lightweight, schema-first, and fully type-safe form library for React. We'll create forms with the `<Field />` component, validate them with Valibot schemas, handle errors, and ensure accessibility.

We'll build the following form. It has a simple text input and a textarea. On submit, we'll validate the form data and display any errors.

**Note:** For the purpose of this demo, we have intentionally disabled browser
validation to show how schema validation and form errors work in Formisch. It
is recommended to add basic browser validation in your production code.

Include steps to reproduce, expected behavior, and what actually happened.

```
"use client"

import * as React from "react"```

This form leverages Formisch for headless, schema-first form handling. We'll build our form using the `<Field />` component, which gives you **complete flexibility over the markup and styling**.

- Uses Formisch's `useForm` hook for form state management.
- `<Form />` component to wrap the native `<form>` element with submit handling.
- `<Field />` render-prop component for controlled inputs.
- Schema validation using [Valibot](https://valibot.dev).
- Type-safe field paths inferred from the schema.
Formisch exposes form operations as **top-level functions** rather than methods on a form object. Import only what you need:

```
Copyimport { getInput, insert, reset, submit } from "@formisch/react"```

Every method follows the same signature: the **first parameter is always the form store**, and the **second parameter (if necessary) is always a config object**.

```
Copy// Read a field value
const email = getInput(form, { path: ["email"] })
 
// Reset the form with new initial values
reset(form, { initialInput: { email: "", password: "" } })
 
// Move an item in a field array
move(form, { path: ["items"], from: 0, to: 3 })```

This design keeps the API flexible and consistent across all methods. You'll see the same `(form, config)` shape used throughout this guide for reading state (`getInput`, `getErrors`), writing state (`setInput`, `setErrors`), form control (`submit`, `validate`, `focus`), and array operations (`insert`, `remove`, `move`, `swap`, `replace`). See the [full methods reference](https://formisch.dev/react/guides/form-methods) for details.

Here's a basic example of a form using the `<Field />` component from Formisch and the shadcn `<Field />` component.

```
Copy<Form of={form} onSubmit={handleSubmit}>
  <FieldGroup>
    <FormischField of={form} path={["title"]}>
      {(field) => (
        <Field data-invalid={field.errors !== null}>
          <FieldLabel htmlFor="form-title">Bug Title</FieldLabel>
          <Input
            {...field.props}
            id="form-title"
            value={field.input}
            aria-invalid={field.errors !== null}
            placeholder="Login button not working on mobile"
            autoComplete="off"
          />
          <FieldDescription>
            Provide a concise title for your bug report.
          </FieldDescription>
          {field.errors && (
            <FieldError errors={field.errors.map((message) => ({ message }))} />
          )}
        </Field>
      )}
    </FormischField>
  </FieldGroup>
</Form>```

**Note:** Formisch ships its own `Field` component. To avoid a name clash with
the shadcn `Field`, the examples below import the Formisch one as
`FormischField` and keep the shadcn `Field` under its original name. In your
own code you can alias either side — just be consistent.

We'll start by defining the shape of our form using a Valibot schema. Formisch infers all input and output types directly from this schema.

```
Copyimport * as v from "valibot"
 
const FormSchema = v.object({
  title: v.pipe(
    v.string(),
    v.minLength(5, "Bug title must be at least 5 characters."),
    v.maxLength(32, "Bug title must be at most 32 characters.")
  ),
  description: v.pipe(
    v.string(),
    v.minLength(20, "Description must be at least 20 characters."),
    v.maxLength(100, "Description must be at most 100 characters.")
  ),
})```

Next, we'll use the `useForm` hook from Formisch to create our form instance. The schema is passed directly to `useForm` — there is no resolver step.

```
Copyimport { Form, Field as FormischField, useForm } from "@formisch/react"
import type { SubmitHandler } from "@formisch/react"
import * as v from "valibot"
 
const FormSchema = v.object({
  title: v.pipe(
    v.string(),
    v.minLength(5, "Bug title must be at least 5 characters."),
    v.maxLength(32, "Bug title must be at most 32 characters.")
  ),
  description: v.pipe(
    v.string(),
    v.minLength(20, "Description must be at least 20 characters."),
    v.maxLength(100, "Description must be at most 100 characters.")
  ),
})
 
export function BugReportForm() {
  const form = useForm({
    schema: FormSchema,
    initialInput: {
      title: "",
      description: "",
    },
  })
 
  const handleSubmit: SubmitHandler<typeof FormSchema> = (output) => {
    // Do something with the validated form values.
    console.log(output)
  }
 
  return (
    <Form of={form} onSubmit={handleSubmit}>
      {/* ... */}
      {/* Build the form here */}
      {/* ... */}
    </Form>
  )
}```

The `<Form />` component wraps a native `<form>` element. It calls `event.preventDefault()`, runs validation, and only invokes `onSubmit` when the data is valid. The `output` you receive is fully typed from the schema.

We can now build the form using the `<Field />` component from Formisch and the shadcn `<Field />` component.

```
"use client"

import * as React from "react"
import { Form, Field as FormischField, reset, useForm } from "@formisch/react"
import type { SubmitHandler } from "@formisch/react"
import { toast } from "sonner"
import * as v from "valibot"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupText,
  InputGroupTextarea,
} from "@/components/ui/input-group"

const FormSchema = v.object({
  title: v.pipe(
    v.string(),
    v.minLength(5, "Bug title must be at least 5 characters."),
    v.maxLength(32, "Bug title must be at most 32 characters.")
  ),
  description: v.pipe(
    v.string(),
    v.minLength(20, "Description must be at least 20 characters."),
    v.maxLength(100, "Description must be at most 100 characters.")
  ),
})

export function BugReportForm() {
  const form = useForm({
    schema: FormSchema,
    initialInput: {
      title: "",
      description: "",
    },
  })

  const handleSubmit: SubmitHandler<typeof FormSchema> = (output) => {
    toast("You submitted the following values:", {
      description: (
        <pre className="mt-2 w-[320px] overflow-x-auto rounded-md bg-code p-4 text-code-foreground">
          <code>{JSON.stringify(output, null, 2)}</code>
        </pre>
      ),
      position: "bottom-right",
      classNames: {
        content: "flex flex-col gap-2",
      },
      style: {
        "--border-radius": "calc(var(--radius)  + 4px)",
      } as React.CSSProperties,
    })
  }

  return (
    <Card className="w-full sm:max-w-md">
      <CardHeader>
        <CardTitle>Bug Report</CardTitle>
        <CardDescription>
          Help us improve by reporting bugs you encounter.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Form of={form} id="form-formisch-demo" onSubmit={handleSubmit}>
          <FieldGroup>
            <FormischField of={form} path={["title"]}>
              {(field) => (
                <Field data-invalid={field.errors !== null}>
                  <FieldLabel htmlFor="form-formisch-demo-title">
                    Bug Title
                  </FieldLabel>
                  <Input
                    {...field.props}
                    id="form-formisch-demo-title"
                    value={field.input ?? ""}
                    aria-invalid={field.errors !== null}
                    placeholder="Login button not working on mobile"
                    autoComplete="off"
                  />
                  {field.errors && (
                    <FieldError
                      errors={field.errors.map((message) => ({ message }))}
                    />
                  )}
                </Field>
              )}
            </FormischField>
            <FormischField of={form} path={["description"]}>
              {(field) => (
                <Field data-invalid={field.errors !== null}>
                  <FieldLabel htmlFor="form-formisch-demo-description">
                    Description
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupTextarea
                      {...field.props}
                      id="form-formisch-demo-description"
                      value={field.input ?? ""}
                      placeholder="I'm having an issue with the login button on mobile."
                      rows={6}
                      className="min-h-24 resize-none"
                      aria-invalid={field.errors !== null}
                    />
                    <InputGroupAddon align="block-end">
                      <InputGroupText className="tabular-nums">
                        {(field.input ?? "").length}/100 characters
                      </InputGroupText>
                    </InputGroupAddon>
                  </InputGroup>
                  <FieldDescription>
                    Include steps to reproduce, expected behavior, and what
                    actually happened.
                  </FieldDescription>
                  {field.errors && (
                    <FieldError
                      errors={field.errors.map((message) => ({ message }))}
                    />
                  )}
                </Field>
              )}
            </FormischField>
          </FieldGroup>
        </Form>
      </CardContent>
      <CardFooter>
        <Field orientation="horizontal">
          <Button type="button" variant="outline" onClick={() => reset(form)}>
            Reset
          </Button>
          <Button type="submit" form="form-formisch-demo">
            Submit
          </Button>
        </Field>
      </CardFooter>
    </Card>
  )
}
```

That's it. You now have a fully accessible form with client-side validation.

When you submit the form, the `handleSubmit` function will be called with the validated form data. If the form data is invalid, Formisch will populate `field.errors` for each invalid field and the UI will display them.

Formisch validates your form data using the Valibot schema you pass to `useForm`. There is no resolver — the schema is the single source of truth for both runtime validation and static types.

```
Copyimport { useForm } from "@formisch/react"
 
const FormSchema = v.object({
  title: v.string(),
  description: v.optional(v.string()),
})
 
export function ExampleForm() {
  const form = useForm({
    schema: FormSchema,
    initialInput: {
      title: "",
      description: "",
    },
  })
}```

Formisch separates the **first** validation from **subsequent** validations. You configure them with the `validate` and `revalidate` options on `useForm`.

```
Copyconst form = useForm({
  schema: FormSchema,
  validate: "blur",
  revalidate: "input",
})```

Display errors next to the field using `<FieldError />`. Formisch returns errors as an array of strings, so map them to the shape `<FieldError />` expects. For styling and accessibility:

- Add the `data-invalid` prop to the `<Field />` component.
- Add the `aria-invalid` prop to the form control such as `<Input />`, `<SelectTrigger />`, `<Checkbox />`, etc.
```
Copy<FormischField of={form} path={["email"]}>
  {(field) => (
    <Field data-invalid={field.errors !== null}>
      <FieldLabel htmlFor="form-email">Email</FieldLabel>
      <Input
        {...field.props}
        id="form-email"
        value={field.input}
        type="email"
        aria-invalid={field.errors !== null}
      />
      {field.errors && (
        <FieldError errors={field.errors.map((message) => ({ message }))} />
      )}
    </Field>
  )}
</FormischField>```

Formisch exposes two ways to bind a field to an element:

- **Native HTML elements** (like `<Input />` and `<Textarea />`) — spread `field.props` and provide `value={field.input}`. Formisch wires up `name`, `ref`, `onChange`, `onBlur`, and `onFocus` for you.
- **Component-library inputs** (like Radix-based `<Select />`, `<Checkbox />`, `<RadioGroup />`, `<Switch />`) — read the value from `field.input` and call `field.onChange(value)` to update it.
- For input fields, spread `field.props` and provide `value={field.input}`.
- To show errors, add the `aria-invalid` prop to the `<Input />` component and the `data-invalid` prop to the `<Field />` component.
This is your public display name. Must be between 3 and 10 characters. Must only contain letters, numbers, and underscores.

```
"use client"

import * as React from "react"```

```
Copy<FormischField of={form} path={["username"]}>
  {(field) => (
    <Field data-invalid={field.errors !== null}>
      <FieldLabel htmlFor="form-username">Username</FieldLabel>
      <Input
        {...field.props}
        id="form-username"
        value={field.input}
        aria-invalid={field.errors !== null}
      />
      {field.errors && (
        <FieldError errors={field.errors.map((message) => ({ message }))} />
      )}
    </Field>
  )}
</FormischField>```

- For textarea fields, spread `field.props` and provide `value={field.input}`.
- To show errors, add the `aria-invalid` prop to the `<Textarea />` component and the `data-invalid` prop to the `<Field />` component.
Tell us more about yourself. This will be used to help us personalize your experience.

```
"use client"

import * as React from "react"```

```
Copy<FormischField of={form} path={["about"]}>
  {(field) => (
    <Field data-invalid={field.errors !== null}>
      <FieldLabel htmlFor="form-about">More about you</FieldLabel>
      <Textarea
        {...field.props}
        id="form-about"
        value={field.input}
        aria-invalid={field.errors !== null}
        placeholder="I'm a software engineer..."
        className="min-h-[120px]"
      />
      <FieldDescription>
        Tell us more about yourself. This will be used to help us personalize
        your experience.
      </FieldDescription>
      {field.errors && (
        <FieldError errors={field.errors.map((message) => ({ message }))} />
      )}
    </Field>
  )}
</FormischField>```

- For select components, read `field.input` and call `field.onChange` from `<Select />`'s `onValueChange`.
- To show errors, add the `aria-invalid` prop to the `<SelectTrigger />` component and the `data-invalid` prop to the `<Field />` component.
For best results, select the language you speak.

```
"use client"

import * as React from "react"```

```
Copy<FormischField of={form} path={["language"]}>
  {(field) => (
    <Field orientation="responsive" data-invalid={field.errors !== null}>
      <FieldContent>
        <FieldLabel htmlFor="form-language">Spoken Language</FieldLabel>
        <FieldDescription>
          For best results, select the language you speak.
        </FieldDescription>
        {field.errors && (
          <FieldError errors={field.errors.map((message) => ({ message }))} />
        )}
      </FieldContent>
      <Select value={field.input} onValueChange={field.onChange}>
        <SelectTrigger
          id="form-language"
          aria-invalid={field.errors !== null}
          className="min-w-[120px]"
        >
          <SelectValue placeholder="Select" />
        </SelectTrigger>
        <SelectContent position="item-aligned">
          <SelectItem value="auto">Auto</SelectItem>
          <SelectItem value="en">English</SelectItem>
        </SelectContent>
      </Select>
    </Field>
  )}
</FormischField>```

- For checkbox arrays, read `field.input` and update it from `onCheckedChange` using `field.onChange`.
- To show errors, add the `aria-invalid` prop to the `<Checkbox />` component and the `data-invalid` prop to the `<Field />` component.
- Remember to add `data-slot="checkbox-group"` to the `<FieldGroup />` component for proper styling and spacing.
Get notified for requests that take time, like research or image generation.

Get notified when tasks you've created have updates.

```
"use client"

import * as React from "react"```

```
Copy<FormischField of={form} path={["tasks"]}>
  {(field) => (
    <FieldSet>
      <FieldLegend variant="label">Tasks</FieldLegend>
      <FieldDescription>
        Get notified when tasks you&apos;ve created have updates.
      </FieldDescription>
      <FieldGroup data-slot="checkbox-group">
        {tasks.map((task) => (
          <Field
            key={task.id}
            orientation="horizontal"
            data-invalid={field.errors !== null}
          >
            <Checkbox
              id={`form-checkbox-${task.id}`}
              aria-invalid={field.errors !== null}
              checked={field.input?.includes(task.id) ?? false}
              onCheckedChange={(checked) => {
                const current = field.input ?? []
                field.onChange(
                  checked === true
                    ? [...current, task.id]
                    : current.filter((value) => value !== task.id)
                )
              }}
            />
            <FieldLabel
              htmlFor={`form-checkbox-${task.id}`}
              className="font-normal"
            >
              {task.label}
            </FieldLabel>
          </Field>
        ))}
      </FieldGroup>
      {field.errors && (
        <FieldError errors={field.errors.map((message) => ({ message }))} />
      )}
    </FieldSet>
  )}
</FormischField>```

- For radio groups, read `field.input` and call `field.onChange` from `onValueChange`.
- To show errors, add the `aria-invalid` prop to the `<RadioGroupItem />` component and the `data-invalid` prop to the `<Field />` component.
You can upgrade or downgrade your plan at any time.

For everyday use with basic features.

For advanced AI usage with more features.

For large teams and heavy usage.

```
"use client"

import * as React from "react"```

```
Copy<FormischField of={form} path={["plan"]}>
  {(field) => (
    <FieldSet>
      <FieldLegend>Plan</FieldLegend>
      <FieldDescription>
        You can upgrade or downgrade your plan at any time.
      </FieldDescription>
      <RadioGroup value={field.input} onValueChange={field.onChange}>
        {plans.map((plan) => (
          <FieldLabel key={plan.id} htmlFor={`form-radiogroup-${plan.id}`}>
            <Field
              orientation="horizontal"
              data-invalid={field.errors !== null}
            >
              <FieldContent>
                <FieldTitle>{plan.title}</FieldTitle>
                <FieldDescription>{plan.description}</FieldDescription>
              </FieldContent>
              <RadioGroupItem
                value={plan.id}
                id={`form-radiogroup-${plan.id}`}
                aria-invalid={field.errors !== null}
              />
            </Field>
          </FieldLabel>
        ))}
      </RadioGroup>
      {field.errors && (
        <FieldError errors={field.errors.map((message) => ({ message }))} />
      )}
    </FieldSet>
  )}
</FormischField>```

- For switches, read `field.input` and call `field.onChange` from `onCheckedChange`.
- To show errors, add the `aria-invalid` prop to the `<Switch />` component and the `data-invalid` prop to the `<Field />` component.
Enable multi-factor authentication to secure your account.

```
"use client"

import * as React from "react"```

```
Copy<FormischField of={form} path={["twoFactor"]}>
  {(field) => (
    <Field orientation="horizontal" data-invalid={field.errors !== null}>
      <FieldContent>
        <FieldLabel htmlFor="form-twoFactor">
          Multi-factor authentication
        </FieldLabel>
        <FieldDescription>
          Enable multi-factor authentication to secure your account.
        </FieldDescription>
        {field.errors && (
          <FieldError errors={field.errors.map((message) => ({ message }))} />
        )}
      </FieldContent>
      <Switch
        id="form-twoFactor"
        checked={field.input ?? false}
        onCheckedChange={field.onChange}
        aria-invalid={field.errors !== null}
      />
    </Field>
  )}
</FormischField>```

Here is an example of a more complex form with multiple fields and validation.

Choose your subscription plan.

For individuals and small teams

For businesses with higher demands

Choose how often you want to be billed.

Select additional features you'd like to include.

Advanced analytics and reporting

Automated daily backups

24/7 premium customer support

Receive email updates about your subscription

```
"use client"

import * as React from "react"```

Formisch exposes a top-level `reset` function. Pass the form store to reset it to its initial input.

```
Copy<Button type="button" variant="outline" onClick={() => reset(form)}>
  Reset
</Button>```

You can also reset to new initial values, or reset while keeping the user's current input:

```
Copy// Reset to a fresh set of initial values
reset(form, { initialInput: { title: "", description: "" } })
 
// Sync the baseline to new server data, but keep the user's edits
reset(form, { initialInput: serverData, keepInput: true })```

Formisch provides a `<FieldArray />` component and a set of helper functions for managing dynamic array fields. Use it whenever you need to add, remove, or reorder items.

Add up to 5 email addresses where we can contact you.

```
"use client"

import * as React from "react"```

`<FieldArray />` follows the same render-prop pattern as `<Field />`. Its `items` array contains a stable key per item that you should use as the React `key`.

```
Copyimport {
  Field as FormischField,
  FieldArray,
  insert,
  remove,
} from "@formisch/react"
 
export function ExampleForm() {
  // ... form config
 
  return (
    <FieldArray of={form} path={["emails"]}>
      {(fieldArray) => (
        <FieldGroup className="gap-4">
          {fieldArray.items.map((item, index) => (
            <FormischField
              key={item}
              of={form}
              path={["emails", index, "address"]}
            >
              {(field) => /* ... */}
            </FormischField>
          ))}
        </FieldGroup>
      )}
    </FieldArray>
  )
}```

Wrap your array fields in a `<FieldSet />` with a `<FieldLegend />` and `<FieldDescription />`.

```
Copy<FieldSet className="gap-4">
  <FieldLegend variant="label">Email Addresses</FieldLegend>
  <FieldDescription>
    Add up to 5 email addresses where we can contact you.
  </FieldDescription>
  <FieldGroup className="gap-4">{/* Array items go here */}</FieldGroup>
</FieldSet>```

Use the `insert` function to add new items to the array. By default new items are appended to the end. You can also pass an `at` index to insert at a specific position.

```
Copy<Button
  type="button"
  variant="outline"
  size="sm"
  onClick={() =>
    insert(form, { path: ["emails"], initialInput: { address: "" } })
  }
  disabled={fieldArray.items.length >= 5}
>
  Add Email Address
</Button>```

Use the `remove` function with an `at` index to remove items from the array.

```
Copyimport { remove } from "@formisch/react"
 
{
  fieldArray.items.length > 1 && (
    <InputGroupAddon align="inline-end">
      <InputGroupButton
        type="button"
        variant="ghost"
        size="icon-xs"
        onClick={() => remove(form, { path: ["emails"], at: index })}
        aria-label={`Remove email ${index + 1}`}
      >
        <XIcon />
      </InputGroupButton>
    </InputGroupAddon>
  )
}```

Formisch also exposes `move`, `swap`, and `replace` for reordering and replacing items. They follow the same `(form, config)` signature.

Use Valibot's `array` and pipeline validators to constrain array fields.

```
Copyconst FormSchema = v.object({
  emails: v.pipe(
    v.array(
      v.object({
        address: v.pipe(
          v.string(),
          v.nonEmpty("Enter an email address."),
          v.email("Enter a valid email address.")
        ),
      })
    ),
    v.minLength(1, "Add at least one email address."),
    v.maxLength(5, "You can add up to 5 email addresses.")
  ),
})```

On This Page

