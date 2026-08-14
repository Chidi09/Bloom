# Button Group - shadcn/ui

> Source: https://ui.shadcn.com/docs/components/aria/button-group

- [Introduction](/docs)
- [Components](/docs/components)
- [Installation](/docs/installation)
- [Theming](/docs/theming)
- [CLI](/docs/cli)
- [Typeset](/docs/typeset)
- [Skills](/docs/skills)
- [Registry](/docs/registry)
- [Changelog](/docs/changelog)
- [Accordion](/docs/components/aria/accordion)
- [Alert](/docs/components/aria/alert)
- [Alert Dialog](/docs/components/aria/alert-dialog)
- [Aspect Ratio](/docs/components/aria/aspect-ratio)
- [Attachment](/docs/components/aria/attachment)
- [Avatar](/docs/components/aria/avatar)
- [Badge](/docs/components/aria/badge)
- [Breadcrumb](/docs/components/aria/breadcrumb)
- [Bubble](/docs/components/aria/bubble)
- [Button](/docs/components/aria/button)
- [Button Group](/docs/components/aria/button-group)
- [Calendar](/docs/components/aria/calendar)
- [Card](/docs/components/aria/card)
- [Carousel](/docs/components/aria/carousel)
- [Chart](/docs/components/aria/chart)
- [Checkbox](/docs/components/aria/checkbox)
- [Collapsible](/docs/components/aria/collapsible)
- [Combobox](/docs/components/aria/combobox)
- [Command](/docs/components/aria/command)
- [Context Menu](/docs/components/aria/context-menu)
- [Data Table](/docs/components/aria/data-table)
- [Date Picker](/docs/components/aria/date-picker)
- [Dialog](/docs/components/aria/dialog)
- [Direction](/docs/components/aria/direction)
- [Drawer](/docs/components/aria/drawer)
- [Dropdown Menu](/docs/components/aria/dropdown-menu)
- [Empty](/docs/components/aria/empty)
- [Field](/docs/components/aria/field)
- [Hover Card](/docs/components/aria/hover-card)
- [Input](/docs/components/aria/input)
- [Input Group](/docs/components/aria/input-group)
- [Input OTP](/docs/components/aria/input-otp)
- [Item](/docs/components/aria/item)
- [Kbd](/docs/components/aria/kbd)
- [Label](/docs/components/aria/label)
- [Marker](/docs/components/aria/marker)
- [Message](/docs/components/aria/message)
- [Message Scroller](/docs/components/aria/message-scroller)
- [Native Select](/docs/components/aria/native-select)
- [Pagination](/docs/components/aria/pagination)
- [Popover](/docs/components/aria/popover)
- [Progress](/docs/components/aria/progress)
- [Questionnaire](/docs/components/aria/questionnaire)
- [Radio Group](/docs/components/aria/radio-group)
- [Resizable](/docs/components/aria/resizable)
- [Scroll Area](/docs/components/aria/scroll-area)
- [Select](/docs/components/aria/select)
- [Separator](/docs/components/aria/separator)
- [Sheet](/docs/components/aria/sheet)
- [Sidebar](/docs/components/aria/sidebar)
- [Skeleton](/docs/components/aria/skeleton)
- [Slider](/docs/components/aria/slider)
- [Sonner](/docs/components/aria/sonner)
- [Spinner](/docs/components/aria/spinner)
- [Switch](/docs/components/aria/switch)
- [Table](/docs/components/aria/table)
- [Tabs](/docs/components/aria/tabs)
- [Textarea](/docs/components/aria/textarea)
- [Toast](/docs/components/aria/toast)
- [Toggle](/docs/components/aria/toggle)
- [Toggle Group](/docs/components/aria/toggle-group)
- [Tooltip](/docs/components/aria/tooltip)
- [Typography](/docs/components/aria/typography)
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
# Button Group
A container that groups related buttons together with consistent styling.

```
"use client"

import * as React from "react"```

```
pnpm dlx shadcn@latest add button-group```

```
```

```
Copyimport {
  ButtonGroup,
  ButtonGroupSeparator,
  ButtonGroupText,
} from "@/components/ui/button-group"```

```
Copy<ButtonGroup>
  <Button>Button 1</Button>
  <Button>Button 2</Button>
</ButtonGroup>```

Use the following composition to build a `ButtonGroup`:

```
CopyButtonGroup
├── Button or Input
├── ButtonGroupSeparator
└── ButtonGroupText```

- The `ButtonGroup` component has the `role` attribute set to `group`.
- Use Tab to navigate between the buttons in the group.
- Use `aria-label` or `aria-labelledby` to label the button group.
```
Copy<ButtonGroup aria-label="Button group">
  <Button>Button 1</Button>
  <Button>Button 2</Button>
</ButtonGroup>```

- Use the `ButtonGroup` component when you want to group buttons that perform an action.
- Use the `ToggleGroup` component when you want to group buttons that toggle a state.
Set the `orientation` prop to change the button group layout.

```
import { MinusIcon, PlusIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

Control the size of buttons using the `size` prop on individual buttons.

```
import { PlusIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

Nest `<ButtonGroup>` components to create button groups with spacing.

```
import { AudioLinesIcon, PlusIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

The `ButtonGroupSeparator` component visually divides buttons within a group.

Buttons with variant `outline` do not need a separator since they have a border. For other variants, a separator is recommended to improve the visual hierarchy.

```
import { Button } from "@/components/ui/button"
import {
  ButtonGroup,```

Create a split button group by adding two buttons separated by a `ButtonGroupSeparator`.

```
import { IconPlus } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"```

Wrap an `Input` component with buttons.

```
import { SearchIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

Wrap an `InputGroup` component to create complex input layouts.

```
"use client"

import * as React from "react"```

Create a split button group with a `DropdownMenu` component.

```
"use client"

import {```

Pair with a `Select` component.

```
"use client"

import * as React from "react"```

Use with a `Popover` component.

```
import { BotIcon, ChevronDownIcon } from "lucide-react"

import { Button } from "@/components/ui/button"```

To enable RTL support in shadcn/ui, see the [RTL configuration guide](/docs/rtl).

```
"use client"

import * as React from "react"```

The `ButtonGroup` component is a container that groups related buttons together with consistent styling.

```
Copy<ButtonGroup>
  <Button>Button 1</Button>
  <Button>Button 2</Button>
</ButtonGroup>```

Nest multiple button groups to create complex layouts with spacing. See the nested example for more details.

```
Copy<ButtonGroup>
  <ButtonGroup />
  <ButtonGroup />
</ButtonGroup>```

The `ButtonGroupSeparator` component visually divides buttons within a group.

```
Copy<ButtonGroup>
  <Button>Button 1</Button>
  <ButtonGroupSeparator />
  <Button>Button 2</Button>
</ButtonGroup>```

Use this component to display text within a button group.

```
Copy<ButtonGroup>
  <ButtonGroupText>Text</ButtonGroupText>
  <Button>Button</Button>
</ButtonGroup>```

Use the `render` prop to render a custom component as the text, for example a label.

```
Copyimport { ButtonGroupText } from "@/components/ui/button-group"
import { Label } from "@/components/ui/label"
 
export function ButtonGroupTextDemo() {
  return (
    <ButtonGroup>
      <ButtonGroupText
        render={(props) => (
          <Label {...props} htmlFor="name">
            Text
          </Label>
        )}
      />
      <Input placeholder="Type something here..." id="name" />
    </ButtonGroup>
  )
}```

On This Page

