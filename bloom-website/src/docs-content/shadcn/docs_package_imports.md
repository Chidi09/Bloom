# Package Imports - shadcn/ui

> Source: https://ui.shadcn.com/docs/package-imports

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
# Package Imports
Configure shadcn/ui with package.json imports.

The `shadcn` CLI supports [package imports](https://nodejs.org/api/packages.html#imports)
for installing components, rewriting imports, and resolving third-party
registries.

Package imports let you use private `#...` import aliases from your
`package.json` instead of `compilerOptions.paths` in `tsconfig.json`.

You configure `imports` in your `package.json`:

```
Copy{
  "imports": {
    "#components/*": "./src/components/*.tsx",
    "#lib/*": "./src/lib/*.ts",
    "#hooks/*": "./src/hooks/*.ts"
  }
}```

Then import generated components using `#...` specifiers:

```
Copyimport { Button } from "#components/ui/button"
import { cn } from "#lib/utils"```

Package import specifiers must start with `#`. Use TypeScript 5 or later with
`moduleResolution: "bundler"` and `resolvePackageJsonImports: true`.

For Next.js, Vite, and TanStack Start apps that install
components into the same workspace.

Add imports for the shadcn/ui install targets.

```
Copy{
  "imports": {
    "#components/*": "./src/components/*.tsx",
    "#lib/*": "./src/lib/*.ts",
    "#hooks/*": "./src/hooks/*.ts"
  }
}```

If your app does not use a `src` directory, remove `src/` from the targets. For
example:

```
Copy{
  "imports": {
    "#components/*": "./components/*.tsx",
    "#lib/*": "./lib/*.ts",
    "#hooks/*": "./hooks/*.ts"
  }
}```

Enable package import resolution.

```
Copy{
  "compilerOptions": {
    "moduleResolution": "bundler",
    "resolvePackageJsonImports": true
  }
}```

You do not need `compilerOptions.paths` for these aliases.

Use the same `#...` roots in `components.json`.

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

The `ui` alias uses `#components/ui`. It is still covered by the
`#components/*` import in `package.json`.

The `utils` alias uses `#lib/utils`. It is covered by `#lib/*`, so you do not
need a separate `#utils` import.

In a monorepo, use package imports for files inside each package and package
exports for files shared across workspaces.

For an app workspace:

```
Copy{
  "name": "web",
  "private": true,
  "imports": {
    "#components/*": "./src/components/*.tsx",
    "#lib/*": "./src/lib/*.ts",
    "#hooks/*": "./src/hooks/*.ts"
  },
  "dependencies": {
    "@workspace/ui": "workspace:*"
  }
}```

```
Copy{
  "aliases": {
    "components": "#components",
    "ui": "@workspace/ui/components",
    "lib": "#lib",
    "hooks": "#hooks",
    "utils": "@workspace/ui/lib/utils"
  }
}```

For the shared UI package:

```
Copy{
  "name": "@workspace/ui",
  "private": true,
  "imports": {
    "#components/*": "./src/components/*.tsx",
    "#lib/*": "./src/lib/*.ts",
    "#hooks/*": "./src/hooks/*.ts"
  },
  "exports": {
    "./globals.css": "./src/styles/globals.css",
    "./components/*": "./src/components/*.tsx",
    "./lib/*": "./src/lib/*.ts",
    "./hooks/*": "./src/hooks/*.ts"
  }
}```

```
Copy{
  "aliases": {
    "components": "#components",
    "ui": "#components",
    "lib": "#lib",
    "hooks": "#hooks",
    "utils": "#lib/utils"
  }
}```

When you run `add` from `apps/web`, app-local files use `#...` imports and
shared UI files are imported from `@workspace/ui`.

```
Copyimport { Button } from "@workspace/ui/components/button"
import { LoginForm } from "#components/login-form"```

The target pattern in `package.json#imports` controls whether generated imports
include file extensions.

```
Copy{
  "imports": {
    "#components/*": "./src/components/*.tsx"
  }
}```

This generates imports without extensions:

```
Copyimport { Button } from "#components/ui/button"```

If you use a target without the extension:

```
Copy{
  "imports": {
    "#components/*": "./src/components/*"
  }
}```

The generated import keeps the source extension:

```
Copyimport { Button } from "#components/ui/button.tsx"```

For most apps, use the extension in the target pattern.

If TypeScript cannot resolve a `#...` import, check that:

- the specifier starts with `#`
- the `imports` entry is in the nearest `package.json`
- `moduleResolution` is set to `bundler`
- `resolvePackageJsonImports` is enabled
- the matching target exists after components are added
If a component is installed but imports still point to `@/...`, check that
`components.json` uses the same `#...` aliases as your package imports.

On This Page

