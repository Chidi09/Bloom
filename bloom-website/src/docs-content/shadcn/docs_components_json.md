# components.json - shadcn/ui

> Source: https://ui.shadcn.com/docs/components-json

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
# components.json
Configuration for your project.

The `components.json` file holds configuration for your project.

We use it to understand how your project is set up and how to generate components customized for your project.

It is **only required if you're using the CLI** to add components to your
project. If you're using the copy and paste method, you don't need this file.

You can create a `components.json` file in your project by running the following command:

```
pnpm dlx shadcn@latest init```

```
```

See the [CLI section](/docs/cli) for more information.

You can see the JSON Schema for `components.json` [here](https://ui.shadcn.com/schema.json).

```
Copy{
  "$schema": "https://ui.shadcn.com/schema.json"
}```

The style for your components. **This cannot be changed after initialization.**

```
Copy{
  "style": "new-york"
}```

The `default` style has been deprecated. Use the `new-york` style instead.

Configuration to help the CLI understand how Tailwind CSS is set up in your project.

See the [installation section](/docs/installation) for how to set up Tailwind CSS.

Path to where your `tailwind.config.js` file is located. **For Tailwind CSS v4, leave this blank.**

```
Copy{
  "tailwind": {
    "config": "tailwind.config.js" | "tailwind.config.ts"
  }
}```

Path to the CSS file that imports Tailwind CSS into your project.

```
Copy{
  "tailwind": {
    "css": "styles/global.css"
  }
}```

This is used to generate the default theme tokens for your components. **This cannot be changed after initialization.**

```
Copy{
  "tailwind": {
    "baseColor": "neutral" | "stone" | "zinc" | "mauve" | "olive" | "mist" | "taupe"
  }
}```

We use and recommend CSS variables for theming.

Set `tailwind.cssVariables` to `true` to generate semantic theme tokens like `background`, `foreground`, and `primary`. Set it to `false` to generate inline Tailwind color utilities instead.

```
Copy{
  "tailwind": {
    "cssVariables": `true` | `false`
  }
}```

For more information, see the [theming docs](/docs/theming).

**This cannot be changed after initialization.** To switch between CSS variables and utility classes, you'll have to delete and re-install your components.

The prefix to use for your Tailwind CSS utility classes. Components will be added with this prefix.

```
Copy{
  "tailwind": {
    "prefix": "tw-"
  }
}```

Whether or not to enable support for React Server Components.

The CLI automatically adds a `use client` directive to client components when set to `true`.

```
Copy{
  "rsc": `true` | `false`
}```

Choose between TypeScript or JavaScript components.

Setting this option to `false` allows components to be added as JavaScript with the `.jsx` file extension.

```
Copy{
  "tsx": `true` | `false`
}```

The CLI uses these values to place generated components in the correct location and rewrite imports.

You can back these aliases with either:

1. `compilerOptions.paths` in your `tsconfig.json` or `jsconfig.json`
2. `package.json#imports` with TypeScript package import resolution enabled
The aliases in `components.json` are still required when using the CLI. They tell the CLI which import roots map to `components`, `ui`, `lib`, `hooks`, and `utils`.

**Important:** If you're using package imports, enable
`resolvePackageJsonImports` and use `moduleResolution: "bundler"` in your
`tsconfig.json`. If you're using `paths`, make sure your aliases include the
`src` directory when applicable.

```
Copy{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}```

Recommended setup for a single-package app:

```
Copy{
  "imports": {
    "#components/*": "./src/components/*.tsx",
    "#lib/*": "./src/lib/*.ts",
    "#hooks/*": "./src/hooks/*.ts"
  }
}```

```
Copy{
  "compilerOptions": {
    "moduleResolution": "bundler",
    "resolvePackageJsonImports": true
  }
}```

```
Copy{
  "aliases": {
    "components": "#components",
    "ui": "#components/ui",
    "lib": "#lib",
    "hooks": "#hooks",
    "utils": "#lib/utils"
  }
}```

The aliases in `components.json` still tell the CLI where to place
`components`, `ui`, `lib`, `hooks`, and `utils`. `package.json#imports`
provides the runtime and TypeScript resolution for those `#...` specifiers.

The matched `imports` target also controls whether generated `#...` imports keep
file extensions:

- `"#components/*": "./src/components/*"` preserves source extensions and can
generate imports like
`#components/button.tsx`
- `"#components/*": "./src/components/*.tsx"` strips source extensions and
generates imports like
`#components/button`
For monorepos, see the [monorepo docs](/docs/monorepo). Local
workspace aliases can use `package.json#imports`, while shared workspace
imports such as `@workspace/ui/components` are resolved from the target
package's `exports`.

For framework-specific setup, see the [package imports guide](/docs/package-imports).

Import alias for your utility functions.

```
Copy{
  "aliases": {
    "utils": "@/lib/utils"
  }
}```

Import alias for your components.

```
Copy{
  "aliases": {
    "components": "@/components"
  }
}```

Import alias for `ui` components.

The CLI will use the `aliases.ui` value to determine where to place your `ui` components. Use this config if you want to customize the installation directory for your `ui` components.

```
Copy{
  "aliases": {
    "ui": "@/app/ui"
  }
}```

Import alias for `lib` functions such as `format-date` or `generate-id`.

```
Copy{
  "aliases": {
    "lib": "@/lib"
  }
}```

Import alias for `hooks` such as `use-media-query` or `use-toast`.

```
Copy{
  "aliases": {
    "hooks": "@/hooks"
  }
}```

Configure multiple resource registries for your project. This allows you to install components, libraries, utilities, and other resources from various sources including private registries.

See the [Namespaced Registries](/docs/registry/namespace) documentation for detailed information.

Configure registries with URL templates:

```
Copy{
  "registries": {
    "@v0": "https://v0.dev/chat/b/{name}",
    "@acme": "https://registry.acme.com/{name}.json",
    "@internal": "https://internal.company.com/{name}.json"
  }
}```

The `{name}` placeholder is replaced with the resource name when installing.

For private registries that require authentication:

```
Copy{
  "registries": {
    "@private": {
      "url": "https://api.company.com/registry/{name}.json",
      "headers": {
        "Authorization": "Bearer ${REGISTRY_TOKEN}",
        "X-API-Key": "${API_KEY}"
      },
      "params": {
        "version": "latest"
      }
    }
  }
}```

Environment variables in the format `${VAR_NAME}` are automatically expanded from your environment.

Once configured, install resources using the namespace syntax:

```
Copy# Install from a configured registry
npx shadcn@latest add @v0/dashboard
 
# Install from private registry
npx shadcn@latest add @private/button
 
# Install multiple resources
npx shadcn@latest add @acme/header @internal/auth-utils```

```
Copy{
  "registries": {
    "@shadcn": "https://ui.shadcn.com/r/{name}.json",
    "@company-ui": {
      "url": "https://registry.company.com/ui/{name}.json",
      "headers": {
        "Authorization": "Bearer ${COMPANY_TOKEN}"
      }
    },
    "@team": {
      "url": "https://team.company.com/{name}.json",
      "params": {
        "team": "frontend",
        "version": "${REGISTRY_VERSION}"
      }
    }
  }
}```

This configuration allows you to:

- Install public components from shadcn/ui
- Access private company UI components with authentication
- Use team-specific resources with versioning
For more information about authentication, see the [Authentication](/docs/registry/authentication) documentation.

On This Page

