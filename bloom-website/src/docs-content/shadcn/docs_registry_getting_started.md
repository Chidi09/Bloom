# Getting Started - shadcn/ui

> Source: https://ui.shadcn.com/docs/registry/getting-started

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
# Getting Started
Learn how to get setup and run your own component registry.

This guide will walk you through the process of setting up your own registry. It assumes you already have a project with components, hooks, utilities or other files you would like to distribute.

**If you have an existing public GitHub repository, you can turn it into a
registry by adding a `registry.json` file at the root.** See
[GitHub Registries](/docs/registry/github) for details.

If you're starting a new registry project, you can use the [registry template](https://github.com/shadcn-ui/registry-template) as a starting point. We have already configured it for you.

You are free to design and publish your custom registry as you see fit. The only requirement is that your registry catalog and registry items must conform to the [registry schema specification](/docs/registry/registry-json) and [registry-item schema specification](/docs/registry/registry-item-json).

Your registry can be a Next.js, Vite, Vue, Svelte, PHP or any other framework as long as it supports serving JSON over HTTP. It can also be a public GitHub repository with a `registry.json` file at the root.

If you'd like to see an example of a registry, we have a [template project](https://github.com/shadcn-ui/registry-template) for you to use as a starting point.

The `registry.json` is the entry point for the registry. It contains the registry's name, homepage, and defines all the items present in the registry.

Your registry must have this file (or JSON payload) present at the root of the registry endpoint. The registry endpoint is the URL where your registry is hosted.

Here's an example `registry.json` file:

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme",
  "homepage": "https://acme.com",
  "items": [
    {
      "name": "button",
      "type": "registry:ui",
      "title": "Button",
      "description": "A simple button component.",
      "files": [
        {
          "path": "components/ui/button.tsx",
          "type": "registry:ui"
        }
      ]
    }
  ]
}```

You can structure your source registry in one of two ways:

- Define all items in a single root `registry.json`.
- Use a root `registry.json` with `include` to compose multiple `registry.json` files.
Create a `registry.json` file in the root of your project. Add all your registry items to the `items` array. This is the simplest way to define a registry.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme",
  "homepage": "https://acme.com",
  "items": [
    {
      "name": "button",
      "type": "registry:ui",
      "title": "Button",
      "description": "A simple button component.",
      "files": [
        {
          "path": "components/ui/button.tsx",
          "type": "registry:ui"
        }
      ]
    },
    {
      "name": "hello-world",
      "type": "registry:block",
      "title": "Hello World",
      "description": "A simple hello world component.",
      "registryDependencies": ["button"],
      "files": [
        {
          "path": "registry/default/hello-world/hello-world.tsx",
          "type": "registry:component"
        }
      ]
    }
  ]
}```

This `registry.json` file must conform to the [registry schema specification](/docs/registry/registry-json).

For larger registries, you can use `include` to compose your source registry
from multiple `registry.json` files.

```
Copyregistry.json
components
└── ui
    ├── button.tsx
    ├── input.tsx
    └── registry.json
hooks
├── registry.json
├── use-media-query.ts
└── use-toggle.ts```

The root `registry.json` defines the registry metadata and includes the nested
registry files.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme",
  "homepage": "https://acme.com",
  "include": [
    "components/ui/registry.json",
    "hooks/registry.json"
  ]
}```

Included `registry.json` files are valid registry files for composition and may
omit `name` and `homepage`. Only the root `registry.json` must define the
registry metadata.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "items": [
    {
      "name": "button",
      "type": "registry:ui",
      "files": [
        {
          "path": "button.tsx",
          "type": "registry:ui"
        }
      ]
    },
    {
      "name": "input",
      "type": "registry:ui",
      "files": [
        {
          "path": "input.tsx",
          "type": "registry:ui"
        }
      ]
    }
  ]
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "items": [
    {
      "name": "use-toggle",
      "type": "registry:hook",
      "files": [
        {
          "path": "use-toggle.ts",
          "type": "registry:hook"
        }
      ]
    },
    {
      "name": "use-media-query",
      "type": "registry:hook",
      "files": [
        {
          "path": "use-media-query.ts",
          "type": "registry:hook"
        }
      ]
    }
  ]
}```

When using `include`, file paths are relative to the `registry.json` file that
declares the item.

Add your first item. Here's an example of a simple `<Button />` component:

```
Copyimport * as React from "react"
 
export function Button(props: React.ComponentProps<"button">) {
  return (
    <button
      {...props}
      className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white"
    />
  )
}```

**Note:** This example places the component in the `components/ui` directory.
You can place it anywhere in your project as long as you set the correct path
in the `registry.json` file.

```
Copycomponents
└── ui
    └── button.tsx```

To add your component to the registry, add an item definition to `registry.json`.
If you are using `include`, add the item to the included `registry.json` file
that owns the component. For example, add a UI component to
`components/ui/registry.json`.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme",
  "homepage": "https://acme.com",
  "items": [
    {
      "name": "button",
      "type": "registry:ui",
      "title": "Button",
      "description": "A simple button component.",
      "files": [
        {
          "path": "components/ui/button.tsx",
          "type": "registry:ui"
        }
      ]
    }
  ]
}```

You define your registry item by adding a `name`, `type`, `title`, `description` and `files`.

For every file you add, you must specify the `path` and `type` of the file. In a single-file registry, the `path` is relative to the root of your project. When using `include`, the `path` is relative to the `registry.json` file that declares the item. The `type` is the type of the file.

You can read more about the registry item schema and file types in the [registry item schema docs](/docs/registry/registry-item-json).

You can serve your registry as static JSON files or from dynamic route handlers.

Run the build command to generate static registry JSON files.

```
pnpm dlx shadcn@latest build```

```
```

If your source registry uses `include`, `shadcn build` resolves the included
registries and writes a flattened registry to your output directory. The
generated `registry.json` does not contain `include`.

**Note:** By default, the build command will generate the registry JSON files
in `public/r` e.g `public/r/button.json`. You can change the output directory by passing the `--output` option. See the [shadcn build command](/docs/cli#build) for more information.

If you're running your registry on Next.js, you can serve these files by running
the `next` server. The command might differ for other frameworks.

```
pnpm dev```

```
```

Your files will now be served at `http://localhost:3000/r/[NAME].json` eg. `http://localhost:3000/r/button.json`.

If you want to serve registry JSON from your source `registry.json` at request
time, use the producer-side loader APIs from `shadcn/registry`.

Install `shadcn` as a runtime dependency:

```
pnpm add shadcn```

```
```

Use `loadRegistry` to serve the registry catalog.

```
Copyimport { loadRegistry } from "shadcn/registry"
 
export async function GET() {
  try {
    const registry = await loadRegistry()
 
    return Response.json(registry)
  } catch (error) {
    console.error(error)
 
    return Response.json({ error: "Failed to load registry." }, { status: 500 })
  }
}```

Use `loadRegistryItem` to serve individual registry items.

```
Copyimport { loadRegistryItem, RegistryItemNotFoundError } from "shadcn/registry"
 
export async function GET(
  _request: Request,
  context: {
    params: Promise<{
      name: string
    }>
  }
) {
  const { name } = await context.params
 
  try {
    const item = await loadRegistryItem(name)
 
    return Response.json(item)
  } catch (error) {
    if (error instanceof RegistryItemNotFoundError) {
      return Response.json(
        { error: `Registry item "${name}" was not found.` },
        { status: 404 }
      )
    }
 
    console.error(error)
 
    return Response.json(
      { error: "Failed to load registry item." },
      { status: 500 }
    )
  }
}```

Both loaders resolve `include` before returning JSON, so route handlers can use
the same source `registry.json` structure without running `shadcn build`.

### Content negotiation
After your registry is being served, test it with the same CLI commands that
other developers will use.

Use the catalog URL for commands that discover items, like `list` and `search`.
Use item URLs for commands that read or install a specific item, like `view` and
`add`.

Start by confirming that the registry catalog can be discovered.

```
pnpm dlx shadcn@latest list http://localhost:3000/r/registry.json```

```
```

Search the registry by query.

```
pnpm dlx shadcn@latest search http://localhost:3000/r/registry.json --query button```

```
```

Then view one registry item by name.

```
pnpm dlx shadcn@latest view http://localhost:3000/r/button.json```

```
```

To test the install flow, run `add` from a project where you want to install the
item.

```
pnpm dlx shadcn@latest add http://localhost:3000/r/button.json```

```
```

You can also test your registry with a namespace. From a project with a
`components.json` file, add your registry URL template to the project.

```
pnpm dlx shadcn@latest registry add @acme=http://localhost:3000/r/{name}.json```

```
```

The `{name}` placeholder must resolve to an item JSON file. For example,
`@acme/button` resolves to `http://localhost:3000/r/button.json`. The catalog is
still served separately at `http://localhost:3000/r/registry.json`.

Then list the items in your registry.

```
pnpm dlx shadcn@latest list @acme```

```
```

Search the registry by query.

```
pnpm dlx shadcn@latest search @acme --query button```

```
```

View one registry item by name.

```
pnpm dlx shadcn@latest view @acme/button```

```
```

To test the install flow, run `add` from a project where you want to install the
item.

```
pnpm dlx shadcn@latest add @acme/button```

```
```

See the [Namespaced Registries](/docs/registry/namespace) docs for more
information.

To make your registry available to other developers, publish your project to a
public URL. Once deployed, users can install items directly from item URLs, or
they can add your registry as a namespace in their project.

If you want users to install items with a namespace like `@acme/button`, tell
them to add your registry URL template to their project. The `{name}`
placeholder is replaced by the item name when the CLI resolves the registry
item.

The template must resolve to item JSON files. For example, `@acme/button`
resolves to `https://acme.com/r/button.json`. Your registry catalog should still
be served separately at `https://acme.com/r/registry.json`.

They can add the namespace with the CLI.

```
pnpm dlx shadcn@latest registry add @acme=https://acme.com/r/{name}.json```

```
```

Or they can add it manually under the `registries` field in their
`components.json` file.

```
Copy{
  "registries": {
    "@acme": "https://acme.com/r/{name}.json"
  }
}```

Users can then consume items from your registry by namespace.

```
pnpm dlx shadcn@latest add @acme/button```

```
```

If your registry is open source and publicly available, you can submit your
namespace to the official registry index. This lets users add your namespace by
name instead of pasting the full URL template.

See the [Registry Index](/docs/registry/registry-index) docs for the submission
requirements.

Here are some guidelines to follow when building components for a registry.

- Place your registry item in the `registry/[STYLE]/[NAME]` directory. I'm using `default` as an example. It can be anything you want as long as it's nested under the `registry` directory.
- For blocks, the following properties are required: `name`, `description`, `type` and `files`.
- It is recommended to add a proper name and description to your registry item. This helps LLMs understand the component and its purpose.
- Make sure to list all registry dependencies in `registryDependencies`. A registry dependency is an item address such as `button`, `@acme/input-form`, `acme/ui/button` or `http://localhost:3000/r/editor.json`.
- Make sure to list all dependencies in `dependencies`. A dependency is the name of the package in the registry eg. `zod`, `sonner`, etc. To set a version, you can use the `name@version` format eg. `zod@^3.20.0`.
- **Imports should always use the `@/registry` path.** eg. `import { HelloWorld } from "@/registry/default/hello-world/hello-world"`
- Ideally, place your files within a registry item in `components`, `hooks`, `lib` directories.
On This Page

