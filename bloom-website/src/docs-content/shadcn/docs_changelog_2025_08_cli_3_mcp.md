# August 2025 - shadcn CLI 3.0 and MCP Server - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2025-08-cli-3-mcp

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
# August 2025 - shadcn CLI 3.0 and MCP Server
Namespaced registries, advanced authentication, new commands and a completely rewritten registry engine.

We just shipped shadcn CLI 3.0 with support for namespaced registries, advanced authentication, new commands and a completely rewritten registry engine.

- Namespaced Registries - Install components using `@registry/name` format.
- Private Registries - Secure your registry with advanced authentication.
- Search & Discovery - New commands to find and view code before installing.
- MCP Server - MCP server for all registries.
- Faster Everything - Completely rewritten registry resolution.
- Improved Error Handling - Better error messages for users and LLMs.
- Upgrade Guide - Migration notes for existing users.
The biggest change in 3.0 is namespaced registries. You can now install components from registries: a community registry, your company's private registry or internal registry, using the `@registry/name` format.

This makes it easier to distribute code across teams and projects.

Configure registries in your `components.json`:

```
Copy{
  "registries": {
    "@acme": "https://acme.com/r/{name}.json",
    "@internal": {
      "url": "https://registry.company.com/{name}",
      "headers": {
        "Authorization": "Bearer ${REGISTRY_TOKEN}"
      }
    }
  }
}```

Then use the `@registry/name` format to install components:

```
pnpm dlx shadcn add @acme/button @internal/auth-system```

```
```

It's completely decentralized. There's no central registrar. Create any namespace you want and organize components however makes sense for your team.

```
Copy{
  "registries": {
    "@design": "https://registry.company.com/create/{name}.json",
    "@engineering": "https://registry.company.com/eng/{name}.json",
    "@marketing": "https://registry.company.com/marketing/{name}.json"
  }
}```

Components can even depend on resources from different registries. Everything gets resolved and installed automatically from the right sources.

```
Copy{
  "name": "dashboard",
  "type": "registry:block",
  "registryDependencies": [
    "@shadcn/card", // From default registry
    "@v0/chart", // From v0 registry
    "@acme/data-table", // From acme registry
    "@lib/data-fetcher", // Utility library
    "@ai/analytics-prompt" // AI prompt resource
  ]
}```

Need to keep your components private? We've got you covered. Configure authentication with tokens, API keys, or custom headers:

```
Copy{
  "registries": {
    "@private": {
      "url": "https://registry.company.com/{name}.json",
      "headers": {
        "Authorization": "Bearer ${REGISTRY_TOKEN}"
      }
    }
  }
}```

Your private components stay private. Perfect for enterprise teams with proprietary UI libraries.

We support all major authentication methods: basic auth, bearer token, API key query params and custom headers.

See the [authentication docs](/docs/registry/authentication) for more details.

Three new commands make it easy to find exactly what you need:

1. View items from the registry before installing
```
pnpm dlx shadcn view @acme/auth-system```

```
```

1. Search items from registries
```
pnpm dlx shadcn search @tweakcn -q "dark"```

```
```

1. List all items from a registry
```
pnpm dlx shadcn list @acme```

```
```

Preview components before installing them. Search across multiple registries. See the code and all dependencies upfront.

Back in April, we [introduced](https://x.com/shadcn/status/1917597228513853603) the first version of the MCP server. Since then, we've taken everything we learned and built a better MCP server.

Here's what's new:

- Works with all registries. Zero config
- One command to add to your favorite MCP clients
- We improved the underlying tools
- Better integration with the CLI and registries
- Support for multiple registries in the same project
Add the MCP server to your project:

```
pnpm dlx shadcn@latest mcp init```

```
```

See the [docs](/docs/mcp) for more details.

We completely rewrote the registry resolution engine from scratch. It's faster, smarter, and handles even the trickiest dependency trees.

- Up to 3x faster dependency resolution
- Smarter file deduplication and merging
- Better monorepo support out of the box
- Updated `build` command for registry authors
Registry developers can now provide custom error messages to help guide users (and LLMs) when things go wrong. The CLI displays helpful, actionable errors for common issues:

```
CopyUnknown registry "@acme". Make sure it is defined in components.json as follows:
{
  "registries": {
    "@acme": "[URL_TO_REGISTRY]"
  }
}```

Missing environment variables? The CLI tells you exactly what's needed:

```
CopyRegistry "@private" requires the following environment variables:
  • REGISTRY_TOKEN
 
Set the required environment variables in your .env or .env.local file.```

Registry authors can provide custom error messages in their responses to help users and AI agents understand and fix issues quickly.

```
CopyError:
You are not authorized to access the item at http://example.com/r/component.
 
Message:
[Unauthorized] Your API key has expired. Renew it at https://example.com/api/renew-key.```

Here's the best part: there are no breaking changes for users. Your existing `components.json` works exactly the same. All your installed components work exactly the same.

For developers, if you're using the programmatic APIs directly, we've deprecated a few functions in favor of better ones:

- `fetchRegistry` → `getRegistry`
- `resolveRegistryTree` → `resolveRegistryItems`
- Schema moved from `shadcn/registry` to `shadcn/schema` package
```
Copy- import { registryItemSchema } from "shadcn/registry"
+ import { registryItemSchema } from "shadcn/schema"```

That's it. Seriously. Everything else just works.

On This Page

