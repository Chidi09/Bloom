# July 2026 - Base UI as the Default - shadcn/ui

> Source: https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default

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
# July 2026 - Base UI as the Default
New projects now use Base UI by default. Radix is still fully supported.

Starting today, **Base UI is the default component library in shadcn/ui**.

First, a bit of history. When shadcn/ui launched in January 2023, it was built on Radix. At the time, nothing else came close. Unstyled headless components, great APIs, great accessibility, battle-tested in millions of apps.

Fast forward a few years and the same folks who built Radix are building something new: [Base UI](https://www.base-ui.com). They've done it once. Now they get to do it again, with everything they learned the first time.

Last year, Base UI tagged a beta and a lot of you asked if we are going to replace Radix with it. I said "the worst thing you can do for your production app is switch component libraries". I meant it, and it still holds. So instead of switching, we did the shadcn thing: we rebuilt every component for Base UI, kept the same abstraction, and let you choose. December brought `npx shadcn create` with both libraries. January brought full Base UI docs.

Then we watched what you did with it.

---
- **Base UI is stable.** It's at 1.6.0 with 6M+ weekly downloads.
- **It keeps getting better.** The team ships new and useful components regularly.
- **We use it.** Every new project we've started runs on Base UI.
- **You use it.** Projects created on shadcn/create now pick Base UI over Radix 2 to 1.
The community already made the call. We're making it official.

---
- **New projects default to Base UI.** Run `npx shadcn init` and Base UI is the default pick.
- **shadcn/create shows Base UI first.**
- **The docs default to Base UI.** Component pages open on the Base UI tab. Radix docs are one click away.
**Radix is not being deprecated.** We still support it, and every update and new component will ship for both libraries (unless a component only exists in Base UI).

**You do not need to migrate.** Radix is a mature, tested library. We still run it in production today and we're not migrating. If your app works, keep shipping.

**Prefer Radix for new projects?** It's one flag away:

```
pnpm dlx shadcn init -b radix```

```
```

If you have scripts or CI running `shadcn init` non-interactively and expecting Radix, add `-b radix` to keep them on the same path.

**Building a registry?** Ship a `registry:base` config if you want to pin a specific library. Items without one now init as Base UI.

**Starting something new?** We recommend Base UI.

You don't need to migrate. But if you want to, we built a skill for it:

```
pnpm dlx skills add shadcn/ui```

```
```

Then ask your coding agent:

```
Copymigrate accordion to base-ui```

It's progressive by default: migrate one component and its usage at a time while your project stays green and shippable. Both libraries coexist while you work. Stop halfway, ship, come back next week and it picks up where you left off. Or ask for the whole project in one go.

Because you own the code. You've added variants, changed classes, threaded new props. A codemod handles the components you never touched and breaks on the ones you did.

So we shipped knowledge instead: every rename, every prop change, every behavior difference, hand-checked against both libraries. Your agent reads it, figures out what *you* changed, and carries those changes over.

Mechanical things get fixed everywhere (`asChild` is now `render`). Behavior changes get flagged, never silently patched. You decide.

Every run leaves three things:

- **Working code.** Typechecked and built before it reports success.
- **A report per component** in `.migration/` at your project root: what changed, what was left alone, and a short checklist of things to verify by hand.
- **Clean git history.** One commit per component, on a branch. Rollback is deleting the branch.
Here's what a report looks like:

```
Copy# accordion
 
<!-- date, strategy used, and the one-line verdict -->
 
## Changed
 
<!-- every file touched, with what changed and why -->
 
## Left alone
 
<!-- files that look related but were intentionally not touched -->
 
## Behavior changes
 
<!-- differences that compile fine but act differently. flagged, not patched -->
 
## Verify by hand
 
<!-- a short checklist: open, click, tab through. takes a minute -->```

No hidden state. Progress lives in your files and git history, so any agent, any session, any day picks up where the last one stopped.

It works with Claude Code, Cursor, or any agent that supports skills. We tested it on real projects: 60+ components, 36 of them on Radix. A full migration ran in about 25 minutes at roughly 10k tokens per component. Clean builds, customizations intact.

On This Page

