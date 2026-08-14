# Typeset - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/aria/typography

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
# Typeset
A styling system for HTML and rendered markdown, from blog posts to streaming chat. One CSS file you own.

You render markdown and get back plain unstyled HTML: headings, paragraphs, lists, and tables. So you style the elements one by one: font sizes, line heights, spacing.

You do it for your blog. Then you do it again for the docs. Then again for the chat app. Every time you're fighting the same thing: sizing and spacing.

To fix this, we created **shadcn/typeset**. It's one CSS file that styles everything inside a `typeset` container. The file lives in your project, so you can change it directly when you need to.

A typeset is just a small preset class. You can have multiple typesets in your app, for different contexts.

```
Copy.typeset-docs {
  --typeset-font-body: var(--font-geist);
  --typeset-font-heading: var(--font-geist);
  --typeset-font-mono: var(--font-geist-mono);
  --typeset-size: 15px;
  --typeset-leading: 1.75;
  --typeset-flow: 1.25em;
}```

---
We read a lot about type: scale ratios, tracking, kerning, optical sizing, measure, leading, the space above and below every element. We tried exposing all of it, and it was too much. Nobody wants to set a dozen variables to make markdown look right.

So we sat down and condensed everything into three controls: size, leading, and flow. Everything else, heading sizes, list indents, the gap under a heading, the space around a rule, derives from them. Three controls. We called it rhythm.

---
- **It fits its container.** Put it in a chat bubble and it follows the smaller type around it. Put it in an article and it scales up with the page. On smaller screens, it gets a small bump for readability.
- **It uses your theme.** Colors, fonts, and radius come from your app. Dark mode follows the same tokens.
- **It's easy to tune.** Three values control the base size, line height, and space between blocks. Change them in a preset and the whole document follows.
- **It works well with streaming.** When a new block arrives, Typeset doesn't make earlier blocks switch margins, borders, or styles.
---
Create your typeset in the [typeset builder](/typeset). Pick your fonts and rhythm, then preview them on docs, chat, articles, and other real content.

The panel gives you the `typeset.css` file, the font setup for your framework, a preset class with your choices, and the wrapper to add around your content.

Copy `typeset.css` next to your main CSS file and import it after Tailwind:

```
Copy@import "tailwindcss";
@import "./typeset.css";```

Then wrap your rendered markdown with `typeset` and your preset class:

```
Copy<div className="typeset typeset-docs">
  <YourMarkdownRenderer>{content}</YourMarkdownRenderer>
</div>```

`typeset` turns the styles on. `typeset-docs` is the preset you created in the builder.

---
The file includes defaults, so you can use `typeset` by itself. Most of the reading rhythm comes from three values:

```
Copy.typeset {
  --typeset-font-body: inherit;
  --typeset-font-heading: var(--font-heading);
  --typeset-font-mono: var(--font-mono);
 
  --typeset-size: 1em; /* body font-size */
  --typeset-leading: 1.75; /* line-height */
  --typeset-flow: 1.25em; /* space between blocks */
}```

- **`--typeset-size`** sets the base text size. `1em` follows the surrounding layout. On smaller screens, Typeset bumps it up a little.
- **`--typeset-leading`** sets the space between lines.
- **`--typeset-flow`** sets the space between blocks. Headings and other elements derive their spacing from it.
The font variables tell Typeset which families to use. Leave them alone and it follows your app. Colors and radius come from your theme too.

Typeset doesn't set a maximum width. Your layout owns that. The Measure control in the builder adds a `max-width` to the wrapper instead of hiding it in the stylesheet.

You can keep more than one preset in the same app. Here is a tighter one for chat and a roomier one for docs:

```
Copy.typeset-chat {
  --typeset-flow: 1em;
  --typeset-leading: 1.6;
}
 
.typeset-docs {
  --typeset-size: 15px;
  --typeset-flow: 1.5em;
}```

```
Copy<div className="typeset typeset-chat">{message}</div>
<article className="typeset typeset-docs">{page}</article>```

For a one-off change, skip the preset and set a value on the container:

```
Copy<article className="typeset [--typeset-flow:1.75em]">...</article>```

---
A preset can change the whole feel of the content, not just the spacing. You can give readers a serif reading mode, a compact UI mode, or any other style that fits your product.

```
Copy/* Reading: serif, larger type, roomy rhythm. */
.typeset-reading {
  --typeset-font-body: var(--font-lora);
  --typeset-font-heading: var(--font-lora);
  --typeset-size: 18px;
  --typeset-leading: 1.9;
  --typeset-flow: 2em;
}
 
/* Compact: sans, smaller type, tighter rhythm. */
.typeset-compact {
  --typeset-font-body: var(--font-geist);
  --typeset-font-heading: var(--font-geist);
  --typeset-size: 14px;
  --typeset-leading: 1.6;
  --typeset-flow: 1em;
}```

---
For readers who prefer larger type and more space, create a roomier typeset and expose it as a setting:

```
Copy.typeset-large {
  --typeset-size: 16px;
  --typeset-leading: 2;
  --typeset-flow: 2em;
}```

Dark mode already follows your theme colors. If the text feels a little tight on a dark surface, you can loosen the leading there:

```
Copy.dark .typeset {
  --typeset-leading: 1.9;
}```

---
Tables stay real tables and wrap to fit. To scroll a wide one horizontally instead, wrap it in `typeset-scroll`:

```
Copy<div className="typeset-scroll">
  <table>...</table>
</div>```

Do this in your renderer's table component or a small rehype plugin. It works for any wide block, not just tables.

---
Typeset lives in the `components` layer and uses `:where()` for its element selectors. Tailwind utilities on an element win without `!important`:

```
Copy<div className="typeset typeset-docs">
  <p className="text-lg">...</p>
</div>```

Plain CSS can override Typeset with a normal selector too.

---
To keep a component out of Typeset, add `not-typeset` or `data-not-typeset`:

```
Copy<div className="typeset">
  <p>Styled prose.</p>
  <Card className="not-typeset">Untouched component.</Card>
</div>```

Both options cover the component and everything inside it. Another `typeset` container inside that subtree stays opted out too.

---
Typeset is written so that adding a new block does not change the styles of the blocks already on screen.

- No forward-looking selectors. `:last-child`, `:has()`, and `:empty` are left out of layout rules because their matches can change as content is added.
- Spacing flows in one direction, using `margin-block-start` only. A new block adds its own space.
- Table separators live on the cells being added, so a new row does not restyle the row above it.
Text that is still streaming can grow and wrap normally. Typeset just avoids restyling the blocks that came before it.

---
The `prose` class from `@tailwindcss/typography` is excellent at what it was built for: adding beautiful typographic defaults to plain HTML, including content rendered from Markdown or a CMS.

Typeset takes a different approach with container-aware sizing, app theme tokens, presets for different contexts, and streaming stability. Here's where they differ:

Typeset borrows the two best ideas from the plugin: the zero-specificity `:where()` guard pattern, and the escape-hatch class (`not-typeset`, in the spirit of `not-prose`).

On This Page

