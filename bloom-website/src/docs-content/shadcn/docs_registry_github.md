# GitHub Registries - shadcn/ui

> Source: https://ui.shadcn.com/docs/registry/github

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
# GitHub Registries
Use a public GitHub repository as a registry.

You can now turn **any public GitHub repository into a registry.**

Add a `registry.json` file to the root of the repo, describe the files you want
to share, and users can install them with the `shadcn` CLI.

```
pnpm dlx shadcn@latest add <username>/<repo>/<item>```

```
```

You do not need to set up a registry server or publish generated JSON files. **The GitHub repository becomes the source registry.**

Registry items are **not limited to components or React code.** They can include
any files from your repository: source files, configuration, docs, templates,
workflows, rules or project conventions.

Use a GitHub registry when:

- You already have reusable code in a public GitHub repository.
- You want users to install directly from `owner/repo/item`.
- You want to distribute config files, rules, docs, templates, utilities or
any other files from the same repository.
- You do not need private repo access or custom request authentication.
A GitHub registry must:

- Be a public `github.com` repository.
- Have a `registry.json` file at the repository root.
- Use valid `registry.json` and `registry-item.json` schemas.
- Reference source files that exist in the repository.
Private repositories and GitHub Enterprise hosts are not currently supported by
GitHub addresses. For private or authenticated registries, use a
[namespace](/docs/registry/namespace) with
[authentication](/docs/registry/authentication).

Given an existing public repository:

```
Copy.
├── ...
├── .editorconfig
├── AGENTS.md
└── docs
    └── conventions.md```

Add `registry.json` at the root of the repository.

```
Copy.
├── ...
├── registry.json
├── .editorconfig
├── AGENTS.md
└── docs
    └── conventions.md```

Define the item you want to distribute.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "project-conventions",
      "type": "registry:item",
      "title": "Project Conventions",
      "description": "Shared project conventions, editor settings and agent instructions.",
      "files": [
        {
          "path": "AGENTS.md",
          "type": "registry:file",
          "target": "~/AGENTS.md"
        },
        {
          "path": ".editorconfig",
          "type": "registry:file",
          "target": "~/.editorconfig"
        },
        {
          "path": "docs/conventions.md",
          "type": "registry:file",
          "target": "~/docs/conventions.md"
        }
      ]
    }
  ]
}```

Commit and push the file.

```
Copygit add registry.json```

```
Copygit commit -m "add registry"```

```
Copygit push```

Users can now install the item from GitHub.

```
pnpm dlx shadcn@latest add acme/toolkit/project-conventions```

```
```

A registry item can install one file or many files. Use the `files` array to
declare the files that belong together.

For example, a testing setup can install a Vitest config, a setup file and a
short team guide.

```
Copyregistry.json
config
└── vitest.config.ts
docs
└── testing.md
test
└── setup.ts```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "vitest-setup",
      "type": "registry:item",
      "title": "Vitest Setup",
      "description": "A Vitest setup with project defaults and docs.",
      "files": [
        {
          "path": "config/vitest.config.ts",
          "type": "registry:file",
          "target": "~/vitest.config.ts"
        },
        {
          "path": "test/setup.ts",
          "type": "registry:file",
          "target": "~/test/setup.ts"
        },
        {
          "path": "docs/testing.md",
          "type": "registry:file",
          "target": "~/docs/testing.md"
        }
      ]
    }
  ]
}```

Users install it the same way.

```
pnpm dlx shadcn@latest add acme/toolkit/vitest-setup```

```
```

Use `target` when a file should be written to a specific destination in the
user's project.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "editorconfig",
      "type": "registry:file",
      "files": [
        {
          "path": "config/.editorconfig",
          "type": "registry:file",
          "target": "~/.editorconfig"
        }
      ]
    }
  ]
}```

```
pnpm dlx shadcn@latest add acme/toolkit/editorconfig```

```
```

Before sharing the registry, validate it from the CLI.

```
pnpm dlx shadcn@latest registry validate acme/toolkit```

```
```

The command reads the root `registry.json`, resolves includes, validates the
registry items, and checks that referenced files exist.

You can also validate a branch, tag or commit SHA.

```
pnpm dlx shadcn@latest registry validate acme/toolkit#v1.0.0```

```
```

Use `list` to see every item in the repository registry.

```
pnpm dlx shadcn@latest list acme/toolkit```

```
```

Use `search` to filter the catalog.

```
pnpm dlx shadcn@latest search acme/toolkit --query conventions```

```
```

Use `view` to inspect one item payload.

```
pnpm dlx shadcn@latest view acme/toolkit/project-conventions```

```
```

For larger repositories, keep item definitions close to the source files they
describe.

```
Copyregistry.json
config
├── prettier.config.mjs
└── registry.json
rules
├── agent.md
└── registry.json```

The root `registry.json` can include the nested registry files.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "include": ["config/registry.json", "rules/registry.json"]
}```

The included registry file declares items for that directory.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "items": [
    {
      "name": "agent-rules",
      "type": "registry:file",
      "files": [
        {
          "path": "agent.md",
          "type": "registry:file",
          "target": "~/AGENTS.md"
        }
      ]
    }
  ]
}```

When using `include`, file paths are relative to the `registry.json` file that
declares the item.

```
pnpm dlx shadcn@latest add acme/toolkit/project-conventions```

```
```

Use `registryDependencies` when one registry item depends on another registry
item.

For dependencies in the same GitHub repository, use the full GitHub item
address.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "project-setup",
      "type": "registry:item",
      "registryDependencies": [
        "acme/toolkit/agent-rules",
        "acme/toolkit/prettier-config",
        "acme/toolkit/tsconfig"
      ],
      "files": [
        {
          "path": "docs/project-setup.md",
          "type": "registry:file",
          "target": "~/docs/project-setup.md"
        }
      ]
    }
  ]
}```

A docs item can depend on a template item from the same repository.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "contributing-guide",
      "type": "registry:item",
      "registryDependencies": ["acme/toolkit/readme-template"],
      "files": [
        {
          "path": "docs/contributing.md",
          "type": "registry:file",
          "target": "~/docs/contributing.md"
        }
      ]
    }
  ]
}```

A CI setup can depend on the same formatting and testing defaults that users can
install separately.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "ci-setup",
      "type": "registry:item",
      "registryDependencies": [
        "acme/toolkit/prettier-config",
        "acme/toolkit/vitest-setup"
      ],
      "files": [
        {
          "path": ".github/workflows/ci.yml",
          "type": "registry:file",
          "target": "~/.github/workflows/ci.yml"
        }
      ]
    }
  ]
}```

Items can also depend on external registries. Use the full item address for the
registry that owns the dependency.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "workspace-setup",
      "type": "registry:item",
      "registryDependencies": [
        "@acme/tsconfig",
        "contoso/devtools/prettier-config"
      ],
      "files": [
        {
          "path": "docs/workspace.md",
          "type": "registry:file",
          "target": "~/docs/workspace.md"
        }
      ]
    }
  ]
}```

Refs are not inherited across dependencies. If a dependency should be pinned,
include its own ref.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry.json",
  "name": "acme-toolkit",
  "homepage": "https://github.com/acme/toolkit",
  "items": [
    {
      "name": "project-setup",
      "type": "registry:item",
      "registryDependencies": [
        "acme/toolkit/agent-rules#v1.0.0",
        "acme/toolkit/tsconfig#c0ffee254729296a45d6691db565cf707a3fef5d"
      ],
      "files": [
        {
          "path": "docs/project-setup.md",
          "type": "registry:file",
          "target": "~/docs/project-setup.md"
        }
      ]
    }
  ]
}```

List every item in a GitHub registry.

```
pnpm dlx shadcn@latest list acme/toolkit```

```
```

Search a GitHub registry.

```
pnpm dlx shadcn@latest search acme/toolkit -q conventions```

```
```

Validate a GitHub registry.

```
pnpm dlx shadcn@latest registry validate acme/toolkit```

```
```

Install an item from a GitHub registry.

```
pnpm dlx shadcn@latest add acme/toolkit/project-conventions```

```
```

View an item from a GitHub registry.

```
pnpm dlx shadcn@latest view acme/toolkit/project-conventions```

```
```

Install an item whose registry item name contains `/`.

```
pnpm dlx shadcn@latest add acme/toolkit/rules/agent```

```
```

For GitHub item addresses, the first two path segments are the GitHub owner
and repository. Any remaining segments are the registry item name, not a file
path. An address ending in `.json` is treated as a file path.

Install from a tag.

```
pnpm dlx shadcn@latest add acme/toolkit/project-conventions#v1.0.0```

```
```

Install from a full commit SHA.

```
pnpm dlx shadcn@latest add acme/toolkit/project-conventions#c0ffee254729296a45d6691db565cf707a3fef5d```

```
```

Use `#ref` to install from a branch, tag or commit SHA.

```
pnpm dlx shadcn@latest add acme/toolkit/project-conventions#main```

```
```

Refs may contain slashes.

```
pnpm dlx shadcn@latest add acme/toolkit/project-conventions#feature/conventions```

```
```

If no ref is provided, the CLI uses the repository default branch.

The CLI uses Git to resolve branches, tags and short refs into a commit SHA
before reading files. Full 40-character commit SHAs are used directly and do not
require Git.

GitHub registry items install code and project files from public repositories.
Treat a GitHub item address like any other third-party code dependency.

Before installing from a source you do not control:

- Review the repository and the root `registry.json`.
- Review the item definition, especially `files`, `target`, `dependencies`,
`devDependencies`, `registryDependencies` and `envVars`.
- Check any external registry dependencies. They can install files from other
registries.
- Prefer pinned refs for published install commands. A full 40-character commit
SHA is the most reproducible option.
- Use `shadcn view acme/toolkit/project-conventions` to inspect the resolved
item payload before installing.
- Pipe `shadcn view` output to your agent or review tool if you want help
checking the item.
- Use `shadcn add acme/toolkit/project-conventions --dry-run` to preview an
install without writing files.
- Use `--diff` or `--view` with `shadcn add` to inspect file changes or file
contents before applying them.
On This Page

