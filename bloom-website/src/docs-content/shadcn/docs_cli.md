# shadcn - shadcn/ui

> Source: https://ui.shadcn.com/docs/cli

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
# shadcn
Use the shadcn CLI to add components to your project.

Use the `init` command to initialize configuration and dependencies for an existing project, or create a new project with `--name`.

The `init` command installs dependencies, adds the `cn` util and configures CSS variables for the project.

```
pnpm dlx shadcn@latest init```

```
```

**Options**

```
CopyUsage: shadcn init [options] [components...]
 
initialize your project and install dependencies
 
Arguments:
  components                 names, url or local path to component
 
Options:
  -t, --template <template>  the template to use. (next, vite, start, react-router, laravel, astro)
  -b, --base <base>          the component library to use. (base, radix, aria)
  -p, --preset [name]        use a preset configuration
  -y, --yes                  skip confirmation prompt. (default: true)
  -d, --defaults             use default configuration: --template=next --preset=nova (default: false)
  -f, --force                force overwrite of existing configuration. (default: false)
  -c, --cwd <cwd>            the working directory. defaults to the current directory.
  -n, --name <name>          the name for the new project.
  -s, --silent               mute output. (default: false)
  --css-variables            use css variables for theming. (default: true)
  --no-css-variables         do not use css variables for theming.
  --monorepo                 scaffold a monorepo project.
  --no-monorepo              skip the monorepo prompt.
  --rtl                      enable RTL support.
  --no-rtl                   disable RTL support.
  --pointer                  enable pointer cursor for buttons.
  --no-pointer               disable pointer cursor for buttons.
  --reinstall                re-install existing UI components.
  --no-reinstall             do not re-install existing UI components.
  -h, --help                 display help for command```

The `create` command is an alias for `init`:

```
pnpm dlx shadcn@latest create```

```
```

---
Use the `add` command to add components and dependencies to your project.

```
pnpm dlx shadcn@latest add [component]```

```
```

**Options**

```
CopyUsage: shadcn add [options] [components...]
 
add a component to your project
 
Arguments:
  components           name, url or local path to component
 
Options:
  -y, --yes            skip confirmation prompt. (default: false)
  -o, --overwrite      overwrite existing files. (default: false)
  -c, --cwd <cwd>      the working directory. defaults to the current directory.
  -a, --all            add all available components (default: false)
  -p, --path <path>    the path to add the component to.
  -s, --silent         mute output. (default: false)
  --dry-run            preview changes without writing files. (default: false)
  --diff [path]        show diff for a file.
  --view [path]        show file contents.
  -h, --help           display help for command```

---
Use the `apply` command to apply a preset to an existing project.

```
pnpm dlx shadcn@latest apply a2r6bw```

```
```

You can apply only the theme or fonts from a preset without reinstalling UI components:

```
pnpm dlx shadcn@latest apply a2r6bw --only theme```

```
```

Supported values for `--only` are `theme` and `font`.

**Options**

```
CopyUsage: shadcn apply [options] [preset]
 
apply a preset to an existing project
 
Arguments:
  preset             the preset to apply
 
Options:
  --preset <preset>  preset configuration to apply
  --only [parts]     apply only parts of a preset: theme, font
  -y, --yes          skip confirmation prompt. (default: false)
  -c, --cwd <cwd>    the working directory. defaults to the current directory.
  -s, --silent       mute output. (default: false)
  -h, --help         display help for command```

---
Use the `preset` command to inspect preset codes and resolve the preset for an existing project.

```
pnpm dlx shadcn@latest preset decode a2r6bw```

```
```

Use `preset decode` to decode a preset code.

```
pnpm dlx shadcn@latest preset decode a2r6bw```

```
```

**Options**

```
CopyUsage: shadcn preset decode [options] <code>
 
decode a preset code
 
Arguments:
  code        the preset code to decode
 
Options:
  --json      output as JSON. (default: false)
  -h, --help  display help for command```

Use `preset resolve` to resolve the preset from the current project.

```
pnpm dlx shadcn@latest preset resolve```

```
```

The `preset info` command is an alias for `preset resolve`:

```
pnpm dlx shadcn@latest preset info```

```
```

**Options**

```
CopyUsage: shadcn preset resolve|info [options]
 
resolve a preset from your project
 
Options:
  -c, --cwd <cwd>  the working directory. defaults to the current directory.
  --json            output as JSON. (default: false)
  -h, --help        display help for command```

Use `preset url` to print the create URL for a preset code.

```
pnpm dlx shadcn@latest preset url a2r6bw```

```
```

**Options**

```
CopyUsage: shadcn preset url [options] <code>
 
get the create URL for a preset code
 
Arguments:
  code        the preset code
 
Options:
  -h, --help  display help for command```

Use `preset open` to open a preset code in the browser.

```
pnpm dlx shadcn@latest preset open a2r6bw```

```
```

**Options**

```
CopyUsage: shadcn preset open [options] <code>
 
open a preset code in the browser
 
Arguments:
  code        the preset code
 
Options:
  -h, --help  display help for command```

---
Use the `view` command to view items from the registry before installing them.

```
pnpm dlx shadcn@latest view [item]```

```
```

You can view multiple items at once:

```
pnpm dlx shadcn@latest view button card dialog```

```
```

Or view items from namespaced registries:

```
pnpm dlx shadcn@latest view @acme/auth @v0/dashboard```

```
```

**Options**

```
CopyUsage: shadcn view [options] <items...>
 
view items from the registry
 
Arguments:
  items            the item names or URLs to view
 
Options:
  -c, --cwd <cwd>  the working directory. defaults to the current directory.
  -h, --help       display help for command```

---
Use the `search` command to search for items from registries.

```
pnpm dlx shadcn@latest search [registry]```

```
```

You can search with a query:

```
pnpm dlx shadcn@latest search @shadcn -q "button"```

```
```

Or search multiple registries at once:

```
pnpm dlx shadcn@latest search @shadcn @v0 @acme```

```
```

The `list` command is an alias for `search`:

```
pnpm dlx shadcn@latest list @acme```

```
```

**Options**

```
CopyUsage: shadcn search|list [options] <registries...>
 
search items from registries
 
Arguments:
  registries             the registry names or urls to search items from. Names
                         must be prefixed with @.
 
Options:
  -c, --cwd <cwd>        the working directory. defaults to the current directory.
  -q, --query <query>    query string
  -l, --limit <number>   maximum number of items to display per registry (default: "100")
  -o, --offset <number>  number of items to skip (default: "0")
  -h, --help             display help for command```

---
Use the `build` command to generate the registry JSON files.

```
pnpm dlx shadcn@latest build```

```
```

This command reads the `registry.json` file and generates the registry JSON files in the `public/r` directory.

**Options**

```
CopyUsage: shadcn build [options] [registry]
 
build components for a shadcn registry
 
Arguments:
  registry             path to registry.json file (default: "./registry.json")
 
Options:
  -o, --output <path>  destination directory for json files (default: "./public/r")
  -c, --cwd <cwd>      the working directory. defaults to the current directory.
  -h, --help           display help for command```

To customize the output directory, use the `--output` option.

```
pnpm dlx shadcn@latest build --output ./public/registry```

```
```

---
Use the `docs` command to fetch documentation and API references for components.

```
pnpm dlx shadcn@latest docs [component]```

```
```

**Options**

```
CopyUsage: shadcn docs [options] [component]
 
fetch documentation and API references for components
 
Arguments:
  component          the component to get docs for
 
Options:
  -c, --cwd <cwd>    the working directory. defaults to the current directory.
  -b, --base <base>  the base to use: base, radix, or aria. defaults to project base.
  --json             output as JSON. (default: false)
  -h, --help         display help for command```

---
Use the `info` command to get information about your project.

```
pnpm dlx shadcn@latest info```

```
```

**Options**

```
CopyUsage: shadcn info [options]
 
get information about your project
 
Options:
  -c, --cwd <cwd>  the working directory. defaults to the current directory.
  --json            output as JSON. (default: false)
  -h, --help        display help for command```

---
Use the `migrate` command to run migrations on your project.

```
pnpm dlx shadcn@latest migrate [migration]```

```
```

**Available Migrations**

**Options**

```
CopyUsage: shadcn migrate [options] [migration] [path]
 
run a migration.
 
Arguments:
  migration        the migration to run.
  path             optional path or glob pattern to migrate.
 
Options:
  -c, --cwd <cwd>       the working directory. defaults to the current directory.
  -l, --list            list all migrations. (default: false)
  -y, --yes             skip confirmation prompt. (default: false)
  -f, --from <library>  the icon library to migrate from (icons migration only).
  -t, --to <library>    the icon library to migrate to (icons migration only).
  -h, --help            display help for command```

---
The `icons` migration moves your components from one icon library to another.

```
pnpm dlx shadcn@latest migrate icons```

```
```

This will prompt you for the source and target libraries, rewrite icon imports and JSX usage in your `ui` directory, install the target library and update `iconLibrary` in your `components.json` so future `npx shadcn add` installs use the new library.

The following libraries are supported: `lucide`, `tabler`, `hugeicons`, `phosphor`, `remixicon` and `radix` (legacy).

**Non-interactive**

Use `--from` and `--to` to skip the prompts:

```
pnpm dlx shadcn@latest migrate icons --from lucide --to phosphor --yes```

```
```

**Migrate specific files**

You can migrate specific files or use glob patterns. Scoped runs do not update `components.json`.

```
Copy# Migrate a specific file.
npx shadcn@latest migrate icons src/components/ui/button.tsx --from lucide --to tabler
 
# Migrate files matching a glob pattern.
npx shadcn@latest migrate icons "src/components/**" --from lucide --to tabler```

Icons without an equivalent in the target library are left untouched and reported at the end of the migration.

---
The `rtl` migration transforms your components to support RTL (right-to-left) languages.

```
pnpm dlx shadcn@latest migrate rtl```

```
```

This will:

1. Update `components.json` to set `rtl: true`
2. Transform physical CSS properties to logical equivalents (e.g., `ml-4` → `ms-4`, `text-left` → `text-start`)
3. Add `rtl:` variants where needed (e.g., `space-x-4` → `space-x-4 rtl:space-x-reverse`)
**Migrate specific files**

You can migrate specific files or use glob patterns:

```
Copy# Migrate a specific file
npx shadcn@latest migrate rtl src/components/ui/button.tsx
 
# Migrate files matching a glob pattern
npx shadcn@latest migrate rtl "src/components/ui/**"```

If no path is provided, the migration will transform all files in your `ui` directory (from `components.json`).

---
The `radix` migration updates your imports from individual `@radix-ui/react-*` packages to the unified `radix-ui` package.

```
pnpm dlx shadcn@latest migrate radix```

```
```

This will:

1. Transform imports from `@radix-ui/react-*` to `radix-ui`
2. Add the `radix-ui` package to your `package.json`
**Before**

```
Copyimport * as DialogPrimitive from "@radix-ui/react-dialog"
import * as SelectPrimitive from "@radix-ui/react-select"```

**After**

```
Copyimport { Dialog as DialogPrimitive, Select as SelectPrimitive } from "radix-ui"```

**Migrate specific files**

You can migrate specific files or use glob patterns:

```
Copy# Migrate a specific file.
npx shadcn@latest migrate radix src/components/ui/dialog.tsx
 
# Migrate files matching a glob pattern.
npx shadcn@latest migrate radix "src/components/ui/**"```

If no path is provided, the migration will transform all files in your `ui` directory (from `components.json`).

Once complete, you can remove any unused `@radix-ui/react-*` packages from your `package.json`.

---
When you run `init`, shadcn adds `@import "shadcn/tailwind.css"` to your global CSS file. This import provides shared Tailwind v4 utilities such as custom variants (`data-open:`, `data-closed:`, etc.) and accordion animations.

Use the `eject` command to inline `shadcn/tailwind.css` into your global CSS file and remove the `shadcn` dependency from your project.

**Note: This action is irreversible.** After ejecting, future shadcn CLI
updates to `shadcn/tailwind.css` will not apply automatically.

```
pnpm dlx shadcn@latest eject```

```
```

**Before**

```
Copy@import "tailwindcss";
@import "tw-animate-css";
@import "shadcn/tailwind.css";```

**After**

```
Copy@import "tailwindcss";
@import "tw-animate-css";
/* ejected from shadcn@4.8.3 */
@theme inline {
  @keyframes accordion-down {
    from {
      height: 0;
    }
    to {
      height: var(
        --radix-accordion-content-height,
        var(--accordion-panel-height, auto)
      );
    }
  }
}
 
@custom-variant data-open {
  &:where([data-state="open"]),
  &:where([data-open]:not([data-open="false"])) {
    @slot;
  }
}
 
@utility no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
 
  &::-webkit-scrollbar {
    display: none;
  }
}```

**Monorepo**

In a monorepo, run the command from the workspace that contains your `components.json` and global CSS file:

```
pnpm dlx shadcn@latest eject -c packages/ui```

```
```

**Options**

```
CopyUsage: shadcn eject [options]
 
inline shadcn/tailwind.css and remove the shadcn dependency
 
Options:
  -c, --cwd <cwd>  the working directory. defaults to the current directory.
  -y, --yes        skip confirmation prompt. (default: false)
  -s, --silent     mute output. (default: false)
  -h, --help       display help for command```

On This Page

