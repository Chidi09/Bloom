# March 2026 - shadcn/cli v4 - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2026-03-cli-v4

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
# March 2026 - shadcn/cli v4
More capable, easier to use. Built for you and your coding agents. Skills, presets, dry run, new templates, monorepo and more.

We're releasing version 4 of shadcn/cli. More capable, easier to use. Built for you and your coding agents. Here's everything new.

shadcn/skills gives coding agents the context they need to work with your components and registry correctly. It covers both Radix and Base UI primitives, updated APIs, component patterns and registry workflows. The skill also knows how to use the shadcn CLI, when to invoke it and which flags to pass. Agents make fewer mistakes and produce code that actually matches your design system.

You can ask your agent things like:

- "create a new vite monorepo"
- "find me a hero from tailark, add it to the homepage, animate the text using an animation from react-bits"
- "install and configure a sign in page from @clerk"
```
pnpm dlx skills add shadcn/ui```

```
```

A preset packs your entire design system config into a short code. Colors, theme, icon library, fonts, radius. One string, everything included.

Build your preset on [shadcn/create](/create), preview it live and grab the code when you're ready.

```
pnpm dlx shadcn@latest init --preset a1Dg5eFl```

```
```

Use it to scaffold projects from custom config, share with your team or publish in your registry. Drop it in prompts so your agent knows where to start. Use it across Claude, Codex, v0, Replit. Take your preset with you.

When you're working on a new app, it can take a few tries to find something you like so we've made switching presets really easy. Run `init --preset` in your app, and the CLI will take care of reconfiguring everything, including your components.

```
pnpm dlx shadcn@latest init --preset ad3qkJ7```

```
```

Your agent knows how to use presets. Scaffold a project, switch design systems, try something new.

- "create a new next app using --preset adtk27v"
- "let's try --preset adtk27v"
To help you build custom presets, we rebuilt [shadcn/create](/create). It now includes a library of UI components you can use to preview your presets. See how your colors, fonts and radius apply to real components before you start building.

Inspect what a registry will add to your project before anything gets written. Review the payload yourself or pipe it to your coding agent for a second look.

```
pnpm dlx shadcn@latest add button --dry-run
npx shadcn@latest add button --diff
npx shadcn@latest add button --view```

```
```

You can use the `--diff` flag to check for registry updates. Or ask your agent: "check for updates from @shadcn and merge with my local changes".

```
pnpm dlx shadcn@latest add button --diff```

```
```

`shadcn init` now scaffolds full project templates for Next.js, Vite, Laravel, React Router, Astro and TanStack Start. Dark mode included for Next.js and Vite.

```
pnpm dlx shadcn@latest init

Select a template › - Use arrow-keys. Return to submit.
❯ Next.js
  Vite
  TanStack Start
  React Router
  Astro
  Laravel```

```
```

Use `--monorepo` to set up a monorepo.

```
pnpm dlx shadcn@latest init -t next --monorepo```

```
```

Pick your primitives. Use `--base` to start a project with Radix or Base UI.

```
pnpm dlx shadcn@latest init --base radix```

```
```

The `info` command now shows the full picture: framework, version, CSS vars, which components are installed, and where to find docs and examples for every component. Great for giving coding agents the context they need to work with your project.

```
pnpm dlx shadcn@latest info```

```
```

Get docs, code and examples for any UI component right from the CLI. Gives your coding agent the context to use your primitives correctly.

```
pnpm dlx shadcn@latest docs combobox

combobox
  - docs      https://ui.shadcn.com/docs/components/radix/combobox
  - examples  https://ui.shadcn.com/code/apps/v4/registry/bases/radix/examples/combobox-example.tsx
  - api       https://base-ui.com/react/components/combobox```

```
```

Registries can now distribute an entire design system as a single payload using `registry:base`. Components, dependencies, CSS vars, fonts, config. One install, everything set up.

Fonts are now a first-class registry type. Install and configure them the same way you install components.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "font-inter",
  "type": "registry:font",
  "font": {
    "family": "'Inter Variable', sans-serif",
    "provider": "google",
    "import": "Inter",
    "variable": "--font-sans",
    "subsets": ["latin"]
  }
}```

```
pnpm dlx shadcn@latest add font-inter```

```
```

- [shadcn/skills](/skills)
- [shadcn/create](/create)
- [shadcn/cli](/cli)
- [shadcn/registry](/docs/registry)
On This Page

