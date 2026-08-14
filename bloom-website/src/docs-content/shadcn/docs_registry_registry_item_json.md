# registry-item.json - shadcn/ui

> Source: https://ui.shadcn.com/docs/registry/registry-item-json

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
# registry-item.json
Specification for registry items.

The `registry-item.json` schema is used to define your custom registry items.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "hello-world",
  "type": "registry:block",
  "title": "Hello World",
  "description": "A simple hello world component.",
  "registryDependencies": [
    "button",
    "@acme/input-form",
    "https://example.com/r/foo"
  ],
  "dependencies": ["is-even@3.0.0", "motion"],
  "devDependencies": ["tw-animate-css"],
  "files": [
    {
      "path": "registry/new-york/hello-world/hello-world.tsx",
      "type": "registry:component"
    },
    {
      "path": "registry/new-york/hello-world/use-hello-world.ts",
      "type": "registry:hook"
    }
  ],
  "cssVars": {
    "theme": {
      "font-heading": "Poppins, sans-serif"
    },
    "light": {
      "brand": "oklch(0.205 0.015 18)"
    },
    "dark": {
      "brand": "oklch(0.205 0.015 18)"
    }
  }
}```

You can see the JSON Schema for `registry-item.json` [here](https://ui.shadcn.com/schema/registry-item.json).

The `$schema` property is used to specify the schema for the `registry-item.json` file.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json"
}```

The name of the item. This is used to identify the item in the registry. It should be unique for your registry.

```
Copy{
  "name": "hello-world"
}```

A human-readable title for your registry item. Keep it short and descriptive.

```
Copy{
  "title": "Hello World"
}```

A description of your registry item. This can be longer and more detailed than the `title`.

```
Copy{
  "description": "A simple hello world component."
}```

The `type` property is used to specify the type of your registry item. This is used to determine the type and target path of the item when resolved for a project.

```
Copy{
  "type": "registry:block"
}```

The following types are supported:

The `author` property is used to specify the author of the registry item.

It can be unique to the registry item or the same as the author of the registry.

```
Copy{
  "author": "John Doe <john@doe.com>"
}```

The `dependencies` property is used to specify the dependencies of your registry item. This is for `npm` packages.

Use `@version` to specify the version of your registry item.

```
Copy{
  "dependencies": [
    "@radix-ui/react-accordion",
    "zod",
    "lucide-react",
    "name@1.0.2"
  ]
}```

The `devDependencies` property is used to specify the dev dependencies of your registry item. These are `npm` packages that are only needed during development.

Use `@version` to specify the version of the package.

```
Copy{
  "devDependencies": ["tw-animate-css", "name@1.2.0"]
}```

Used for registry dependencies. Each entry is an item address.

- For `shadcn/ui` registry items such as `button`, `input`, `select`, etc use the name eg. `['button', 'input', 'select']`.
- For namespaced registry items, use `@namespace/item-name` eg. `['@acme/input-form']`.
- For GitHub registry items, use `owner/repo/item-name` eg. `['acme/ui/button']`. For published registries, prefer a tag or full commit SHA eg. `['acme/ui/button#v1.2.0']`.
- For custom registry items use the URL of the registry item eg. `['https://example.com/r/hello-world.json']`.
- For local registry item files use a file path eg. `['./hello-world.json']`.
```
Copy{
  "registryDependencies": [
    "button",
    "@acme/input-form",
    "acme/ui/button#v1.2.0",
    "https://example.com/r/editor.json",
    "./editor.json"
  ]
}```

Note: Bare names keep their existing behavior. `button` means the built-in
shadcn `button` item, not an item from the same GitHub repository. For
same-repository GitHub dependencies, use the full GitHub item address.

Refs are not inherited across dependencies. If a GitHub dependency should be
reproducible, pin that dependency to its own tag or full commit SHA.

See the [GitHub registry](/docs/registry/github) docs for more information.

The `files` property is used to specify the files of your registry item. Each file has a `path`, `type` and `target` (optional) property.

**The `target` property is required for `registry:page` and `registry:file` types.**

```
Copy{
  "files": [
    {
      "path": "registry/new-york/hello-world/page.tsx",
      "type": "registry:page",
      "target": "app/hello/page.tsx"
    },
    {
      "path": "registry/new-york/hello-world/hello-world.tsx",
      "type": "registry:component"
    },
    {
      "path": "registry/new-york/hello-world/use-hello-world.ts",
      "type": "registry:hook"
    },
    {
      "path": "registry/new-york/hello-world/.env",
      "type": "registry:file",
      "target": "~/.env"
    }
  ]
}```

The `path` property is used to specify the path to the file in your registry. This path is used by the build script to parse, transform and build the registry JSON payload.

The `type` property is used to specify the type of the file. See the type section for more information.

The `target` property is used to indicate where the file should be placed in a project. This is optional and only required for `registry:page` and `registry:file` types.

By default, the `shadcn` cli will read a project's `components.json` file to determine the target path. For some files, such as routes or config you can specify the target path manually.

Use `~` to refer to the root of the project e.g `~/foo.config.js`.

You can also use registry target placeholders to place files under the
directories configured by the user's `components.json`. These placeholders are
only supported at the start of `target` and are independent of the project's
import prefix. For example, `@ui/button.tsx` works whether the project imports
components with `@/`, `#`, package imports or workspace exports.

Use these placeholders when you want a registry item to install into the
project's configured shadcn directories without hardcoding `components`, `src`
or workspace package paths. Anything after the placeholder is preserved, so
`@ui/ai/prompt-input.tsx` installs under the user's configured `ui` directory
at `ai/prompt-input.tsx`.

```
Copy{
  "files": [
    {
      "path": "registry/new-york/example/button.tsx",
      "type": "registry:ui",
      "target": "@ui/button.tsx"
    },
    {
      "path": "registry/new-york/example/prompt-input.tsx",
      "type": "registry:ui",
      "target": "@ui/ai/prompt-input.tsx"
    },
    {
      "path": "registry/new-york/example/card.tsx",
      "type": "registry:component",
      "target": "@components/card.tsx"
    },
    {
      "path": "registry/new-york/example/helper.ts",
      "type": "registry:lib",
      "target": "@lib/helper.ts"
    },
    {
      "path": "registry/new-york/example/use-demo.ts",
      "type": "registry:hook",
      "target": "@hooks/use-demo.ts"
    }
  ]
}```

The `target` property decides where the file is written. It can point to a
different shadcn directory than the file `type`.

```
Copy{
  "files": [
    {
      "path": "registry/new-york/example/format-date.ts",
      "type": "registry:ui",
      "target": "@lib/format-date.ts"
    }
  ]
}```

Unknown placeholders are treated as regular target paths. For example,
`@foo/bar.ts` is written as `foo/bar.ts`. Embedded placeholders such as
`components/@ui/button.tsx` are also treated as regular paths.

`@utils/` is not supported because `utils` points to a file, not a directory.

**DEPRECATED:** Use `cssVars.theme` instead for Tailwind v4 projects.

The `tailwind` property is used for tailwind configuration such as `theme`, `plugins` and `content`.

You can use the `tailwind.config` property to add colors, animations and plugins to your registry item.

```
Copy{
  "tailwind": {
    "config": {
      "theme": {
        "extend": {
          "colors": {
            "brand": "hsl(var(--brand))"
          },
          "keyframes": {
            "wiggle": {
              "0%, 100%": { "transform": "rotate(-3deg)" },
              "50%": { "transform": "rotate(3deg)" }
            }
          },
          "animation": {
            "wiggle": "wiggle 1s ease-in-out infinite"
          }
        }
      }
    }
  }
}```

Use to define CSS variables for your registry item.

```
Copy{
  "cssVars": {
    "theme": {
      "font-heading": "Poppins, sans-serif"
    },
    "light": {
      "brand": "20 14.3% 4.1%",
      "radius": "0.5rem"
    },
    "dark": {
      "brand": "20 14.3% 4.1%"
    }
  }
}```

Use `css` to add new rules to the project's CSS file eg. `@layer base`, `@layer components`, `@utility`, `@keyframes`, `@plugin`, etc.

```
Copy{
  "css": {
    "@plugin @tailwindcss/typography": {},
    "@plugin foo": {},
    "@layer base": {
      "body": {
        "font-size": "var(--text-base)",
        "line-height": "1.5"
      }
    },
    "@layer components": {
      "button": {
        "background-color": "var(--color-primary)",
        "color": "var(--color-white)"
      }
    },
    "@utility text-magic": {
      "font-size": "var(--text-base)",
      "line-height": "1.5"
    },
    "@keyframes wiggle": {
      "0%, 100%": {
        "transform": "rotate(-3deg)"
      },
      "50%": {
        "transform": "rotate(3deg)"
      }
    }
  }
}```

Use `envVars` to add environment variables to your registry item.

```
Copy{
  "envVars": {
    "NEXT_PUBLIC_APP_URL": "http://localhost:4000",
    "DATABASE_URL": "postgresql://postgres:postgres@localhost:5432/postgres",
    "OPENAI_API_KEY": ""
  }
}```

Environment variables are added to the `.env.local` or `.env` file. Existing variables are not overwritten.

**IMPORTANT:** Use `envVars` to add development or example variables. Do NOT use it to add production variables.

The `font` property is required for `registry:font` items. It configures the font family, provider, import name, CSS variable, and the npm package to install for non-Next.js projects.

```
Copy{
  "font": {
    "family": "'Inter Variable', sans-serif",
    "provider": "google",
    "import": "Inter",
    "variable": "--font-sans",
    "subsets": ["latin"],
    "dependency": "@fontsource-variable/inter"
  }
}```

Use `docs` to show custom documentation or message when installing your registry item via the CLI.

```
Copy{
  "docs": "To get an OPENAI_API_KEY, sign up for an account at https://platform.openai.com."
}```

Use `categories` to organize your registry item.

```
Copy{
  "categories": ["sidebar", "dashboard"]
}```

Use `meta` to add additional metadata to your registry item. You can add any key/value pair that you want to be available to the registry item.

```
Copy{
  "meta": { "foo": "bar" }
}```

On This Page

