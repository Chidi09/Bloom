# Examples - shadcn/ui

> Source: https://ui.shadcn.com/docs/registry/examples

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
# Examples
Examples of registry items: styles, components, css vars, etc.

The following registry item is a custom style that extends shadcn/ui. On `npx shadcn init`, it will:

- Install `@tabler/icons-react` as a dependency.
- Add the `login-01` block and `calendar` component to the project.
- Add the `editor` from a remote registry.
- Set the `font-sans` variable to `Inter, sans-serif`.
- Install a `brand` color in light and dark mode.
```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "example-style",
  "type": "registry:style",
  "dependencies": ["@tabler/icons-react"],
  "registryDependencies": [
    "login-01",
    "calendar",
    "https://example.com/r/editor.json"
  ],
  "cssVars": {
    "theme": {
      "font-sans": "Inter, sans-serif"
    },
    "light": {
      "brand": "20 14.3% 4.1%"
    },
    "dark": {
      "brand": "20 14.3% 4.1%"
    }
  }
}```

The following registry item is a custom style that doesn't extend shadcn/ui. See the `extends: none` field.

It can be used to create a new style from scratch, i.e. custom components, css vars, dependencies, etc.

On `npx shadcn add`, the following will:

- Install `tailwind-merge` and `clsx` as dependencies.
- Add the `utils` registry item from the shadcn/ui registry.
- Add the `button`, `input`, `label`, and `select` components from a remote registry.
- Install new css vars: `main`, `bg`, `border`, `text`, `ring`.
```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "extends": "none",
  "name": "new-style",
  "type": "registry:style",
  "dependencies": ["tailwind-merge", "clsx"],
  "registryDependencies": [
    "utils",
    "https://example.com/r/button.json",
    "https://example.com/r/input.json",
    "https://example.com/r/label.json",
    "https://example.com/r/select.json"
  ],
  "cssVars": {
    "theme": {
      "font-sans": "Inter, sans-serif"
    },
    "light": {
      "main": "#88aaee",
      "bg": "#dfe5f2",
      "border": "#000",
      "text": "#000",
      "ring": "#000"
    },
    "dark": {
      "main": "#88aaee",
      "bg": "#272933",
      "border": "#000",
      "text": "#e6e6e6",
      "ring": "#fff"
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-theme",
  "type": "registry:theme",
  "cssVars": {
    "light": {
      "background": "oklch(1 0 0)",
      "foreground": "oklch(0.141 0.005 285.823)",
      "primary": "oklch(0.546 0.245 262.881)",
      "primary-foreground": "oklch(0.97 0.014 254.604)",
      "ring": "oklch(0.746 0.16 232.661)",
      "sidebar-primary": "oklch(0.546 0.245 262.881)",
      "sidebar-primary-foreground": "oklch(0.97 0.014 254.604)",
      "sidebar-ring": "oklch(0.746 0.16 232.661)"
    },
    "dark": {
      "background": "oklch(1 0 0)",
      "foreground": "oklch(0.141 0.005 285.823)",
      "primary": "oklch(0.707 0.165 254.624)",
      "primary-foreground": "oklch(0.97 0.014 254.604)",
      "ring": "oklch(0.707 0.165 254.624)",
      "sidebar-primary": "oklch(0.707 0.165 254.624)",
      "sidebar-primary-foreground": "oklch(0.97 0.014 254.604)",
      "sidebar-ring": "oklch(0.707 0.165 254.624)"
    }
  }
}```

The following style will init using shadcn/ui defaults and then add a custom `brand` color.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-style",
  "type": "registry:style",
  "cssVars": {
    "light": {
      "brand": "oklch(0.99 0.00 0)"
    },
    "dark": {
      "brand": "oklch(0.14 0.00 286)"
    }
  }
}```

This block installs the `login-01` block from the shadcn/ui registry.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "login-01",
  "type": "registry:block",
  "description": "A simple login form.",
  "registryDependencies": ["button", "card", "input", "label"],
  "files": [
    {
      "path": "blocks/login-01/page.tsx",
      "content": "import { LoginForm } ...",
      "type": "registry:page",
      "target": "app/login/page.tsx"
    },
    {
      "path": "blocks/login-01/components/login-form.tsx",
      "content": "...",
      "type": "registry:component"
    }
  ]
}```

You can install a block from the shadcn/ui registry and override the primitives using your custom ones.

On `npx shadcn add`, the following will:

- Add the `login-01` block from the shadcn/ui registry.
- Override the `button`, `input`, and `label` primitives with the ones from the remote registry.
```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-login",
  "type": "registry:block",
  "registryDependencies": [
    "login-01",
    "https://example.com/r/button.json",
    "https://example.com/r/input.json",
    "https://example.com/r/label.json"
  ]
}```

A `registry:ui` item is a reusable UI component. It can have dependencies, registry dependencies, and CSS variables.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "button",
  "type": "registry:ui",
  "dependencies": ["radix-ui"],
  "files": [
    {
      "path": "ui/button.tsx",
      "content": "...",
      "type": "registry:ui"
    }
  ]
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "sidebar",
  "type": "registry:ui",
  "dependencies": ["radix-ui"],
  "registryDependencies": ["button", "separator", "sheet", "tooltip"],
  "files": [
    {
      "path": "ui/sidebar.tsx",
      "content": "...",
      "type": "registry:ui"
    }
  ],
  "cssVars": {
    "light": {
      "sidebar-background": "oklch(0.985 0 0)",
      "sidebar-foreground": "oklch(0.141 0.005 285.823)",
      "sidebar-border": "oklch(0.92 0.004 286.32)"
    },
    "dark": {
      "sidebar-background": "oklch(0.141 0.005 285.823)",
      "sidebar-foreground": "oklch(0.985 0 0)",
      "sidebar-border": "oklch(0.274 0.006 286.033)"
    }
  }
}```

A `registry:lib` item is a utility library. Use it to share helper functions, constants, or other non-component code.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "utils",
  "type": "registry:lib",
  "dependencies": ["clsx", "tailwind-merge"],
  "files": [
    {
      "path": "lib/utils.ts",
      "content": "import { clsx, type ClassValue } from \"clsx\"\nimport { twMerge } from \"tailwind-merge\"\n\nexport function cn(...inputs: ClassValue[]) {\n  return twMerge(clsx(inputs))\n}",
      "type": "registry:lib"
    }
  ]
}```

A `registry:hook` item is a custom React hook.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "use-mobile",
  "type": "registry:hook",
  "files": [
    {
      "path": "hooks/use-mobile.ts",
      "content": "...",
      "type": "registry:hook"
    }
  ]
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "use-debounce",
  "type": "registry:hook",
  "dependencies": ["react"],
  "files": [
    {
      "path": "hooks/use-debounce.ts",
      "content": "...",
      "type": "registry:hook"
    }
  ]
}```

Use `files[].target` placeholders when a registry item should install files
under the user's configured shadcn directories. The available placeholders are
`@components/`, `@ui/`, `@lib/` and `@hooks/`.

The placeholders are resolved from `components.json`, so the same registry item
works in projects using `@/`, custom TypeScript aliases, package imports or
workspace package exports.

Anything after the placeholder is preserved. For example,
`@ui/ai/prompt-input.tsx` installs under the user's configured `ui` directory
at `ai/prompt-input.tsx`.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "alias-child",
  "type": "registry:item",
  "files": [
    {
      "path": "registry/new-york/alias/target-alias-button.tsx",
      "type": "registry:ui",
      "target": "@ui/target-alias-button.tsx",
      "content": "..."
    },
    {
      "path": "registry/new-york/alias/target-alias-helper.ts",
      "type": "registry:lib",
      "target": "@lib/target-alias-helper.ts",
      "content": "..."
    },
    {
      "path": "registry/new-york/alias/prompt-input.tsx",
      "type": "registry:ui",
      "target": "@ui/ai/prompt-input.tsx",
      "content": "..."
    }
  ]
}```

Registry dependencies can use target placeholders too. In the following example,
the child item installs a UI component and a helper, while the parent item
installs an app component and a hook.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "alias-parent",
  "type": "registry:item",
  "registryDependencies": ["https://example.com/r/alias-child.json"],
  "files": [
    {
      "path": "registry/new-york/alias/target-alias-panel.tsx",
      "type": "registry:component",
      "target": "@components/target-alias-panel.tsx",
      "content": "..."
    },
    {
      "path": "registry/new-york/alias/use-target-alias.ts",
      "type": "registry:hook",
      "target": "@hooks/use-target-alias.ts",
      "content": "..."
    }
  ]
}```

The `target` controls where the file is written, even when it differs from the
file `type`.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "type-mismatch",
  "type": "registry:item",
  "files": [
    {
      "path": "registry/new-york/example/format-date.ts",
      "type": "registry:ui",
      "target": "@lib/format-date.ts",
      "content": "..."
    }
  ]
}```

A `registry:font` item installs a Google Font. The `font` field is required and configures the font family, provider, import name, and CSS variable.

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
    "subsets": ["latin"],
    "dependency": "@fontsource-variable/inter"
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "font-jetbrains-mono",
  "type": "registry:font",
  "font": {
    "family": "'JetBrains Mono Variable', monospace",
    "provider": "google",
    "import": "JetBrains_Mono",
    "variable": "--font-mono",
    "weight": ["400", "500", "600", "700"],
    "subsets": ["latin"],
    "dependency": "@fontsource-variable/jetbrains-mono"
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "font-lora",
  "type": "registry:font",
  "font": {
    "family": "'Lora Variable', serif",
    "provider": "google",
    "import": "Lora",
    "variable": "--font-serif",
    "subsets": ["latin"],
    "dependency": "@fontsource-variable/lora"
  }
}```

Use the `selector` field to apply a font to specific CSS selectors instead of globally on `html`. This is useful for heading fonts or other targeted font applications.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "font-playfair-display",
  "type": "registry:font",
  "font": {
    "family": "'Playfair Display Variable', serif",
    "provider": "google",
    "import": "Playfair_Display",
    "variable": "--font-heading",
    "subsets": ["latin"],
    "selector": "h1, h2, h3, h4, h5, h6",
    "dependency": "@fontsource-variable/playfair-display"
  }
}```

When `selector` is set, the font utility class (e.g. `font-heading`) is applied via CSS `@apply` on the specified selector within `@layer base`, instead of being added to the `<html>` element. The CSS variable is still injected on `<html>` so it's available globally.

A `registry:base` item is a complete design system base. It defines the full set of dependencies, CSS variables, and configuration for a project. The `config` field is unique to `registry:base` items.

The `config` field accepts the following properties (all optional):

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-base",
  "type": "registry:base",
  "config": {
    "style": "custom-base",
    "iconLibrary": "lucide",
    "tailwind": {
      "baseColor": "neutral"
    }
  },
  "dependencies": [
    "class-variance-authority",
    "tw-animate-css",
    "lucide-react"
  ],
  "registryDependencies": ["utils", "font-inter"],
  "cssVars": {
    "light": {
      "background": "oklch(1 0 0)",
      "foreground": "oklch(0.141 0.005 285.823)",
      "primary": "oklch(0.21 0.006 285.885)",
      "primary-foreground": "oklch(0.985 0 0)"
    },
    "dark": {
      "background": "oklch(0.141 0.005 285.823)",
      "foreground": "oklch(0.985 0 0)",
      "primary": "oklch(0.985 0 0)",
      "primary-foreground": "oklch(0.21 0.006 285.885)"
    }
  },
  "css": {
    "@import \"tw-animate-css\"": {},
    "@layer base": {
      "*": {
        "@apply border-border outline-ring/50": {}
      },
      "body": {
        "@apply bg-background text-foreground": {}
      }
    }
  }
}```

Use `extends: none` to create a base that doesn't extend shadcn/ui defaults.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "my-design-system",
  "extends": "none",
  "type": "registry:base",
  "config": {
    "style": "my-design-system",
    "iconLibrary": "lucide",
    "tailwind": {
      "baseColor": "slate"
    }
  },
  "dependencies": ["tailwind-merge", "clsx", "tw-animate-css", "lucide-react"],
  "registryDependencies": ["utils", "font-geist"],
  "cssVars": {
    "light": {
      "background": "oklch(1 0 0)",
      "foreground": "oklch(0.141 0.005 285.823)"
    },
    "dark": {
      "background": "oklch(0.141 0.005 285.823)",
      "foreground": "oklch(0.985 0 0)"
    }
  }
}```

Use the `author` field to add attribution to your registry items.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-component",
  "type": "registry:ui",
  "author": "shadcn",
  "files": [
    {
      "path": "ui/custom-component.tsx",
      "content": "...",
      "type": "registry:ui"
    }
  ]
}```

Use the `devDependencies` field to install packages as dev dependencies.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-item",
  "type": "registry:item",
  "devDependencies": ["@types/mdx"],
  "files": [
    {
      "path": "lib/mdx.ts",
      "content": "...",
      "type": "registry:lib"
    }
  ]
}```

Use the `meta` field to attach arbitrary metadata to your registry items. This can be used to store custom data that your tools or scripts can use.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-component",
  "type": "registry:ui",
  "meta": {
    "category": "forms",
    "version": "2.0.0"
  },
  "files": [
    {
      "path": "ui/custom-component.tsx",
      "content": "...",
      "type": "registry:ui"
    }
  ]
}```

Add custom theme variables to the `theme` object.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-theme",
  "type": "registry:theme",
  "cssVars": {
    "theme": {
      "font-heading": "Inter, sans-serif",
      "shadow-card": "0 0 0 1px rgba(0, 0, 0, 0.1)"
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-theme",
  "type": "registry:theme",
  "cssVars": {
    "theme": {
      "spacing": "0.2rem",
      "breakpoint-sm": "640px",
      "breakpoint-md": "768px",
      "breakpoint-lg": "1024px",
      "breakpoint-xl": "1280px",
      "breakpoint-2xl": "1536px"
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-style",
  "type": "registry:style",
  "css": {
    "@layer base": {
      "h1": {
        "font-size": "var(--text-2xl)"
      },
      "h2": {
        "font-size": "var(--text-xl)"
      }
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-card",
  "type": "registry:component",
  "css": {
    "@layer components": {
      "card": {
        "background-color": "var(--color-white)",
        "border-radius": "var(--rounded-lg)",
        "padding": "var(--spacing-6)",
        "box-shadow": "var(--shadow-xl)"
      }
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-component",
  "type": "registry:component",
  "css": {
    "@utility content-auto": {
      "content-visibility": "auto"
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-component",
  "type": "registry:component",
  "css": {
    "@utility scrollbar-hidden": {
      "scrollbar-hidden": {
        "&::-webkit-scrollbar": {
          "display": "none"
        }
      }
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-component",
  "type": "registry:component",
  "css": {
    "@utility tab-*": {
      "tab-size": "var(--tab-size-*)"
    }
  }
}```

Use `@import` to add CSS imports to your registry item. The imports will be placed at the top of the CSS file.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-import",
  "type": "registry:component",
  "css": {
    "@import \"tailwindcss\"": {},
    "@import \"./styles/base.css\"": {}
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "font-import",
  "type": "registry:item",
  "css": {
    "@import url(\"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap\")": {},
    "@import url('./local-styles.css')": {}
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "responsive-import",
  "type": "registry:item",
  "css": {
    "@import \"print-styles.css\" print": {},
    "@import url(\"mobile.css\") screen and (max-width: 768px)": {}
  }
}```

Use `@plugin` to add Tailwind plugins to your registry item. Plugins will be automatically placed after imports and before other content.

**Important:** When using plugins from npm packages, you must also add them to the `dependencies` array.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-plugin",
  "type": "registry:item",
  "css": {
    "@plugin \"@tailwindcss/typography\"": {},
    "@plugin \"foo\"": {}
  }
}```

When using plugins from npm packages like `@tailwindcss/typography`, include them in the dependencies.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "typography-component",
  "type": "registry:item",
  "dependencies": ["@tailwindcss/typography"],
  "css": {
    "@plugin \"@tailwindcss/typography\"": {},
    "@layer components": {
      ".prose": {
        "max-width": "65ch"
      }
    }
  }
}```

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "scoped-plugins",
  "type": "registry:component",
  "css": {
    "@plugin \"@headlessui/tailwindcss\"": {},
    "@plugin \"tailwindcss/plugin\"": {},
    "@plugin \"./custom-plugin.js\"": {}
  }
}```

When you add multiple plugins, they are automatically grouped together and deduplicated.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "multiple-plugins",
  "type": "registry:item",
  "dependencies": [
    "@tailwindcss/typography",
    "@tailwindcss/forms",
    "tw-animate-css"
  ],
  "css": {
    "@plugin \"@tailwindcss/typography\"": {},
    "@plugin \"@tailwindcss/forms\"": {},
    "@plugin \"tw-animate-css\"": {}
  }
}```

When using both `@import` and `@plugin` directives, imports are placed first, followed by plugins, then other CSS content.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "combined-example",
  "type": "registry:item",
  "dependencies": ["@tailwindcss/typography", "tw-animate-css"],
  "css": {
    "@import \"tailwindcss\"": {},
    "@import url(\"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap\")": {},
    "@plugin \"@tailwindcss/typography\"": {},
    "@plugin \"tw-animate-css\"": {},
    "@layer base": {
      "body": {
        "font-family": "Inter, sans-serif"
      }
    },
    "@utility content-auto": {
      "content-visibility": "auto"
    }
  }
}```

Note: you need to define both `@keyframes` in css and `theme` in cssVars to use animations.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-component",
  "type": "registry:component",
  "cssVars": {
    "theme": {
      "--animate-wiggle": "wiggle 1s ease-in-out infinite"
    }
  },
  "css": {
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

You can add environment variables using the `envVars` field.

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "custom-item",
  "type": "registry:item",
  "envVars": {
    "NEXT_PUBLIC_APP_URL": "http://localhost:4000",
    "DATABASE_URL": "postgresql://postgres:postgres@localhost:5432/postgres",
    "OPENAI_API_KEY": ""
  }
}```

Environment variables are added to the `.env.local` or `.env` file. Existing variables are not overwritten.

**IMPORTANT:** Use `envVars` to add development or example variables. Do NOT use it to add production variables.

As of `2.9.0`, you can create universal items that can be installed without framework detection or components.json.

To make an item universal i.e framework agnostic, all the files in the item must have an explicit target.

Here's an example of a registry item that installs custom Cursor rules for *python*:

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "python-rules",
  "type": "registry:item",
  "files": [
    {
      "path": "/path/to/your/registry/default/custom-python.mdc",
      "type": "registry:file",
      "target": "~/.cursor/rules/custom-python.mdc",
      "content": "..."
    }
  ]
}```

Here's another example for installing a custom ESLint config:

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "my-eslint-config",
  "type": "registry:item",
  "files": [
    {
      "path": "/path/to/your/registry/default/custom-eslint.json",
      "type": "registry:file",
      "target": "~/.eslintrc.json",
      "content": "..."
    }
  ]
}```

You can also have a universal item that installs multiple files:

```
Copy{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "my-custom-starter-template",
  "type": "registry:item",
  "dependencies": ["better-auth"],
  "files": [
    {
      "path": "/path/to/file-01.json",
      "type": "registry:file",
      "target": "~/file-01.json",
      "content": "..."
    },
    {
      "path": "/path/to/file-02.vue",
      "type": "registry:file",
      "target": "~/pages/file-02.vue",
      "content": "..."
    }
  ]
}```

On This Page

