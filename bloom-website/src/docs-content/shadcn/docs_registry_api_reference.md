# API Reference - shadcn/ui

> Source: https://ui.shadcn.com/docs/registry/api-reference

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
# API Reference
Programmatic API for working with registries, schemas and presets.

The `shadcn` package exposes a set of programmatic APIs in addition to the CLI.
You can use these to fetch, resolve, and install registry items, validate
registry JSON, and build custom tooling on top of the registry.

Each API is available under a dedicated subpath import.

```
Copyimport { getRegistryItems } from "shadcn/registry"
import { registryItemSchema } from "shadcn/schema"```

The CLI commands themselves are not part of the public API. Only the imports
documented below are considered stable.

Fetch and resolve items from configured registries.

Most functions accept an options object. The two options below are common to all
of them. In the examples that follow, `config` refers to this optional value —
omit it to use the built-in registries.

- **Type:** `Partial<Config>`
- **Default:** built-in registries only
The registry configuration to use. Its `registries` field maps a namespace
(e.g. `@acme`) to a URL and any authentication headers or environment
variables required to reach it. Use
``getRegistriesConfig to load it from your project.

```
Copyimport { getRegistryItems } from "shadcn/registry"
 
const items = await getRegistryItems(["@acme/login-form"], {
  config: {
    registries: {
      "@acme": "https://acme.com/r/{name}.json",
    },
  },
})```

- **Type:** `boolean`
- **Default:** `true`
Registry responses are cached **in memory for the lifetime of the process**,
keyed by the resolved URL. Because the in-flight promise is cached, concurrent
requests for the same URL are de-duplicated into a single fetch.

Leave this enabled for one-off scripts and CLI runs. Set it to `false` in
long-running processes (servers, watchers, the MCP server) where the registry
can change between requests and you need fresh data each time.

```
Copyconst fresh = await getRegistry("@shadcn", { useCache: false })```

Load registry configuration from a project directory. The function reads
`components.json` when present; otherwise it reads the top-level `registries`
field from `package.json`.

```
Copyimport { getRegistriesConfig } from "shadcn/registry"
 
const config = await getRegistriesConfig(process.cwd())```

Fetch a single registry by name.

```
Copyimport { getRegistry } from "shadcn/registry"
 
const registry = await getRegistry("@acme", {
  config, // optional Partial<Config>
  useCache: true,
})```

Fetch one or more registry items by their qualified names.

```
Copyimport { getRegistryItems } from "shadcn/registry"
 
const items = await getRegistryItems(["@acme/button", "@acme/card"], {
  config,
  useCache: true,
})```

Returns an array of registry items:

```
Copy[
  {
    "name": "button",
    "type": "registry:ui",
    "dependencies": ["@radix-ui/react-slot"],
    "files": [
      {
        "path": "ui/button.tsx",
        "type": "registry:ui",
        "content": "..."
      }
    ]
  }
]```

Resolve multiple items together with their registry dependencies, merged into a
single tree. Unlike ``getRegistryItems, which returns the
items as a list, this walks each item's `registryDependencies` and flattens
everything — files, dependencies, CSS variables — into one installable object.

```
Copyimport { resolveRegistryItems } from "shadcn/registry"
 
const tree = await resolveRegistryItems(
  ["@acme/button", "@acme/card", "@acme/dialog"],
  { config }
)```

Returns a single merged tree:

```
Copy{
  "dependencies": ["@radix-ui/react-slot", "@radix-ui/react-dialog"],
  "files": [
    { "path": "ui/button.tsx", "type": "registry:ui", "content": "..." },
    { "path": "ui/card.tsx", "type": "registry:ui", "content": "..." },
    { "path": "ui/dialog.tsx", "type": "registry:ui", "content": "..." }
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
  },
  "docs": ""
}```

Resolve and install registry items into an existing project. This is the
programmatic equivalent of `shadcn add` and applies files, package dependencies,
environment variables, CSS, and Tailwind configuration declared by the items.

```
Copyimport { addRegistryItems, getRegistriesConfig } from "shadcn/registry"
 
const cwd = process.cwd()
const config = await getRegistriesConfig(cwd)
 
await addRegistryItems(["@acme/agent"], {
  cwd,
  config,
  overwrite: false,
  silent: true,
})```

`addRegistryItems` does not read project configuration files itself. Pass the
result of ``getRegistriesConfig, or provide `config`
directly. A config containing only `registries` is enough when every requested
item and dependency is universal: a `registry:item` or `registry:file` whose
files all declare explicit targets. Other items require a full resolved project
config, including its aliases and `resolvedPaths`. Every custom registry
namespace referenced by an item or dependency must be present in `config`.

The function throws errors instead of exiting the process and never prompts.
Existing files are skipped unless `overwrite` is enabled, and npm uses
`--force` for React 19 peer dependency conflicts.

Fetch the registry directory.

```
Copyimport { getRegistries } from "shadcn/registry"
 
const registries = await getRegistries({ useCache: true })```

Returns an array of registry entries:

```
Copy[
  {
    "name": "@shadcn",
    "url": "https://ui.shadcn.com/r/{name}.json",
    "homepage": "https://ui.shadcn.com"
  }
]```

Search across one or more registries with fuzzy matching.

```
Copyimport { searchRegistries } from "shadcn/registry"
 
const results = await searchRegistries(["@shadcn"], {
  query: "button",
  types: ["registry:component"],
  limit: 100,
  offset: 0,
  config,
  continueOnError: true, // skip (don't throw on) registries that fail to load
})```

Returns matching items wrapped in pagination metadata:

```
Copy{
  "pagination": { "total": 1, "offset": 0, "limit": 100, "hasMore": false },
  "items": [
    {
      "name": "button",
      "title": "Button",
      "type": "registry:ui",
      "description": "A button component.",
      "registry": "@shadcn",
      "addCommandArgument": "@shadcn/button"
    }
  ]
}```

Read and resolve a local `registry.json` file from disk, following any
`include` references, and return the registry catalog.

```
Copyimport { loadRegistry } from "shadcn/registry"
 
const catalog = await loadRegistry({
  cwd: process.cwd(), // defaults to process.cwd()
  registryFile: "registry.json", // defaults to "registry.json"
})```

The returned catalog lists every item but **omits file contents** — like a
built `registry.json` index.

``getRegistry fetches a **remote** registry over the network
(by namespace, URL or GitHub address) and expects the served catalog to
already be flattened — it rejects catalogs that still use `include`.
`loadRegistry` reads a **local** `registry.json` from disk and resolves
`include` references itself.

Read a single item from a local `registry.json` by name, with its file contents
read from disk and inlined.

```
Copyimport { loadRegistryItem } from "shadcn/registry"
 
const item = await loadRegistryItem("login-form", { cwd: process.cwd() })```

Returns a fully resolved registry item with file contents:

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "login-form",
  "type": "registry:component",
  "files": [
    {
      "path": "registry/new-york/login-form.tsx",
      "type": "registry:component",
      "content": "..."
    }
  ]
}```

``getRegistryItems resolves items from a **remote**
registry over the network. `loadRegistryItem` builds a single item on demand
from your **local** source files, reading each file from disk. Use it in a
dynamic route that serves `registry-item.json` responses.

All registry functions throw typed errors that extend `RegistryError`. Use the
`RegistryErrorCode` enum or `instanceof` checks to handle them.

```
Copyimport { RegistryError, RegistryNotFoundError } from "shadcn/registry"
 
try {
  await getRegistry("@unknown")
} catch (error) {
  if (error instanceof RegistryNotFoundError) {
    // handle missing registry
  }
}```

Available error classes:

- `RegistryError`
- `RegistryNotFoundError`
- `RegistryUnauthorizedError`
- `RegistryForbiddenError`
- `RegistryFetchError`
- `RegistryNotConfiguredError`
- `RegistryLocalFileError`
- `RegistryParseError`
- `RegistryValidationError`
- `RegistryItemNotFoundError`
- `RegistriesIndexParseError`
- `RegistryMissingEnvironmentVariablesError`
- `RegistryInvalidNamespaceError`
The Zod schemas used to validate `registry.json`, `registry-item.json` and
`components.json`. Useful for validating registry data in your own tooling.

```
Copyimport { registryItemSchema, registrySchema } from "shadcn/schema"
 
const result = registryItemSchema.safeParse(json)
if (!result.success) {
  console.error(result.error)
}```

Key schemas:

- `registrySchema`
- `registryItemSchema`
- `registryItemFileSchema`
- `registryItemTypeSchema`
- `registryItemCssVarsSchema`
- `registryItemTailwindSchema`
- `registryBaseColorSchema`
- `configSchema`
- `presetSchema`
Inferred types are exported alongside them:

- `Registry`
- `RegistryItem`
- `RegistryBaseItem`
- `RegistryFontItem`
- `Preset`
- `ConfigJson`
Encode, decode and validate theme presets, plus the preset option constants used
by the theme editor.

Encode a `Partial<PresetConfig>` into a short, URL-safe preset code. Any fields
you omit fall back to `DEFAULT_PRESET_CONFIG`.

```
Copyimport { encodePreset } from "shadcn/preset"
 
const code = encodePreset({
  style: "vega",
  baseColor: "stone",
  theme: "blue",
  radius: "large",
  font: "geist",
})```

Returns a version-prefixed string:

```
Copy"bJ4FLU0"```

Decode a preset code back into a full `PresetConfig`. Returns `null` if the code
is missing or invalid.

```
Copyimport { decodePreset } from "shadcn/preset"
 
const config = decodePreset("bJ4FLU0")```

Returns the resolved config (omitted fields are filled with their defaults):

```
Copy{
  "style": "vega",
  "baseColor": "stone",
  "theme": "blue",
  "chartColor": "neutral",
  "iconLibrary": "lucide",
  "font": "geist",
  "fontHeading": "inherit",
  "radius": "large",
  "menuAccent": "subtle",
  "menuColor": "default"
}```

```
CopydecodePreset("not-a-code") // null```

Additional functions for validating codes and generating random presets:

- `isPresetCode`
- `isValidPreset`
- `generateRandomConfig`
- `generateRandomPreset`
- `toBase62`
- `fromBase62`
Constants:

- `PRESET_BASES`
- `PRESET_STYLES`
- `PRESET_BASE_COLORS`
- `PRESET_THEMES`
- `PRESET_ICON_LIBRARIES`
- `PRESET_FONTS`
- `PRESET_FONT_HEADINGS`
- `PRESET_RADII`
- `PRESET_MENU_ACCENTS`
- `PRESET_MENU_COLORS`
- `PRESET_CHART_COLORS`
- `DEFAULT_PRESET_CONFIG`
On This Page

