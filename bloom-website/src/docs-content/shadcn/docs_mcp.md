# MCP Server - shadcn/ui

> Source: https://ui.shadcn.com/docs/mcp

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
# MCP Server
Use the shadcn MCP server to browse, search, and install components from registries.

The shadcn MCP Server allows AI assistants to interact with items from registries. You can browse available components, search for specific ones, and install them directly into your project using natural language.

For example, you can ask an AI assistant to "Build a landing page using components from the acme registry" or "Find me a login form from the shadcn registry".

Registries are configured in your project's `components.json` file.

```
Copy{
  "registries": {
    "@acme": "https://acme.com/r/{name}.json"
  }
}```

---
Select your MCP client and follow the instructions to configure the shadcn MCP server. If you'd like to do it manually, see the Configuration section.

**Run the following command** in your project:

```
pnpm dlx shadcn@latest mcp init --client claude```

```
```

**Restart Claude Code** and try the following prompts:

- Show me all available components in the shadcn registry
- Add the button, dialog and card components to my project
- Create a contact form using components from the shadcn registry
**Note:** You can use `/mcp` command in Claude Code to debug the MCP server.

---
[Model Context Protocol (MCP)](https://modelcontextprotocol.io) is an open protocol that enables AI assistants to securely connect to external data sources and tools. With the shadcn MCP server, your AI assistant gains direct access to:

- **Browse Components** - List all available components, blocks, and templates from any configured registry
- **Search Across Registries** - Find specific components by name or functionality across multiple sources
- **Install with Natural Language** - Add components using simple conversational prompts like "add a login form"
- **Support for Multiple Registries** - Access public registries, private company libraries, and third-party sources
---
The MCP server acts as a bridge between your AI assistant, component registries and the shadcn CLI.

1. **Registry Connection** - MCP connects to configured registries (shadcn/ui, private registries, third-party sources)
2. **Natural Language** - You describe what you need in plain English
3. **AI Processing** - The assistant translates your request into registry commands
4. **Component Delivery** - Resources are fetched and installed in your project
---
The shadcn MCP server works out of the box with any shadcn-compatible registry.

- **shadcn/ui Registry** - The default registry with all shadcn/ui components
- **Third-Party Registries** - Any registry following the shadcn registry specification
- **Private Registries** - Your company's internal component libraries
- **Namespaced Registries** - Multiple registries configured with `@namespace` syntax
---
You can use any MCP client to interact with the shadcn MCP server. Here are the instructions for the most popular ones.

To use the shadcn MCP server with Claude Code, add the following configuration to your project's `.mcp.json` file:

```
Copy{
  "mcpServers": {
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    }
  }
}```

After adding the configuration, restart Claude Code and run `/mcp` to see the shadcn MCP server in the list. If you see `Connected`, you're good to go.

See the [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp) for more details.

To configure MCP in Cursor, add the shadcn server to your project's `.cursor/mcp.json` configuration file:

```
Copy{
  "mcpServers": {
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    }
  }
}```

After adding the configuration, enable the shadcn MCP server in Cursor Settings.

Once enabled, you should see a green dot next to the shadcn server in the MCP server list and a list of available tools.

See the [Cursor MCP documentation](https://docs.cursor.com/en/context/mcp#using-mcp-json) for more details.

To configure MCP in VS Code with GitHub Copilot, add the shadcn server to your project's `.vscode/mcp.json` configuration file:

```
Copy{
  "servers": {
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    }
  }
}```

After adding the configuration, open `.vscode/mcp.json` and click **Start** next to the shadcn server.

See the [VS Code MCP documentation](https://code.visualstudio.com/docs/copilot/chat/mcp-servers) for more details.

**Note:** The `shadcn` CLI cannot automatically update `~/.codex/config.toml`.
You'll need to add the configuration manually.

To configure MCP in Codex, add the shadcn server to `~/.codex/config.toml`:

```
Copy[mcp_servers.shadcn]
command = "npx"
args = ["shadcn@latest", "mcp"]```

After adding the configuration, restart Codex to load the MCP server.

---
The MCP server supports multiple registries through your project's `components.json` configuration. This allows you to access components from various sources including private registries and third-party providers.

Configure additional registries in your `components.json`:

```
Copy{
  "registries": {
    "@acme": "https://registry.acme.com/{name}.json",
    "@internal": {
      "url": "https://internal.company.com/{name}.json",
      "headers": {
        "Authorization": "Bearer ${REGISTRY_TOKEN}"
      }
    }
  }
}```

**Note:** No configuration is needed to access the standard shadcn/ui
registry.

---
For private registries requiring authentication, set environment variables in your `.env.local`:

```
CopyREGISTRY_TOKEN=your_token_here
API_KEY=your_api_key_here```

For more details on registry authentication, see the [Authentication documentation](/docs/registry/authentication).

---
Once the MCP server is configured, you can use natural language to interact with registries. Try one of the following prompts:

- Show me all available components in the shadcn registry
- Find me a login form from the shadcn registry
- Add the button component to my project
- Create a login form using shadcn components
- Install the Cursor rules from the acme registry
- Show me components from acme registry
- Install @internal/auth-form
- Build me a landing page using hero, features and testimonials sections from the acme registry
---
If the MCP server isn't responding to prompts:

1. **Check Configuration** - Verify the MCP server is properly configured and enabled in your MCP client
2. **Restart MCP Client** - Restart your MCP client after configuration changes
3. **Verify Installation** - Ensure `shadcn` is installed in your project
4. **Check Network** - Confirm you can access the configured registries
If components aren't loading from registries:

1. **Check components.json** - Verify registry URLs are correct
2. **Test Authentication** - Ensure environment variables are set for private registries
3. **Verify Registry** - Confirm the registry is online and accessible
4. **Check Namespace** - Ensure namespace syntax is correct (`@namespace/component`)
If components fail to install:

1. **Check Project Setup** - Ensure you have a valid `components.json` file
2. **Verify Paths** - Confirm the target directories exist
3. **Check Permissions** - Ensure write permissions for component directories
4. **Review Dependencies** - Check that required dependencies are installed
If you see the `No tools or prompts` message, try the following:

1. **Clear the npx cache** - Run `npx clear-npx-cache`
2. **Re-enable the MCP server** - Try to re-enable the MCP server in your MCP client
3. **Check Logs** - In Cursor, you can see the logs under View -> Output and select `MCP: project-*` in the dropdown.
---
- [Registry Documentation](/docs/registry) - Complete guide to shadcn registries
- [Namespaces](/docs/registry/namespace) - Configure multiple registry sources
- [Authentication](/docs/registry/authentication) - Secure your private registries
- [MCP Specification](https://modelcontextprotocol.io) - Learn about Model Context Protocol
On This Page

