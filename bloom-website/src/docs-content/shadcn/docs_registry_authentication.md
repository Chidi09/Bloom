# Authentication - shadcn/ui

> Source: https://ui.shadcn.com/docs/registry/authentication

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
# Authentication
Secure your registry with authentication for private and personalized components.

Authentication lets you run private registries, control who can access your components, and give different teams or users different content. This guide shows common authentication patterns and how to set them up.

Authentication enables these use cases:

- **Private Components**: Keep your business logic and internal components secure
- **Team-Specific Resources**: Give different teams different components
- **Access Control**: Limit who can see sensitive or experimental components
- **Usage Analytics**: See who's using which components in your organization
- **Licensing**: Control who gets premium or licensed components
The most common approach uses Bearer tokens or API keys:

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

Set your token in environment variables:

```
CopyREGISTRY_TOKEN=your_secret_token_here```

Some registries use API keys in headers:

```
Copy{
  "registries": {
    "@company": {
      "url": "https://api.company.com/registry/{name}.json",
      "headers": {
        "X-API-Key": "${API_KEY}",
        "X-Workspace-Id": "${WORKSPACE_ID}"
      }
    }
  }
}```

For simpler setups, use query parameters:

```
Copy{
  "registries": {
    "@internal": {
      "url": "https://registry.company.com/{name}.json",
      "params": {
        "token": "${ACCESS_TOKEN}"
      }
    }
  }
}```

This creates: `https://registry.company.com/button.json?token=your_token`

Here's how to add authentication to your registry server:

```
Copyimport { NextRequest, NextResponse } from "next/server"
 
export async function GET(
  request: NextRequest,
  { params }: { params: { name: string } }
) {
  // Get token from Authorization header.
  const authHeader = request.headers.get("authorization")
  const token = authHeader?.replace("Bearer ", "")
 
  // Or from query parameters.
  const queryToken = request.nextUrl.searchParams.get("token")
 
  // Check if token is valid.
  if (!isValidToken(token || queryToken)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }
 
  // Check if token can access this component.
  if (!hasAccessToComponent(token, params.name)) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 })
  }
 
  // Return the component.
  const component = await getComponent(params.name)
  return NextResponse.json(component)
}
 
function isValidToken(token: string | null) {
  // Add your token validation logic here.
  // Check against database, JWT validation, etc.
  return token === process.env.VALID_TOKEN
}
 
function hasAccessToComponent(token: string, componentName: string) {
  // Add role-based access control here.
  // Check if token can access specific component.
  return true // Your logic here.
}```

```
Copyapp.get("/registry/:name.json", (req, res) => {
  const token = req.headers.authorization?.replace("Bearer ", "")
 
  if (!isValidToken(token)) {
    return res.status(401).json({ error: "Unauthorized" })
  }
 
  const component = getComponent(req.params.name)
  if (!component) {
    return res.status(404).json({ error: "Component not found" })
  }
 
  res.json(component)
})```

Give different teams different components:

```
Copyasync function GET(request: NextRequest) {
  const token = extractToken(request)
  const team = await getTeamFromToken(token)
 
  // Get components for this team.
  const components = await getComponentsForTeam(team)
  return NextResponse.json(components)
}```

Give users components based on their preferences:

```
Copyasync function GET(request: NextRequest) {
  const user = await authenticateUser(request)
 
  // Get user's style and framework preferences.
  const preferences = await getUserPreferences(user.id)
 
  // Get personalized component version.
  const component = await getPersonalizedComponent(params.name, preferences)
 
  return NextResponse.json(component)
}```

Use expiring tokens for better security:

```
Copyinterface TemporaryToken {
  token: string
  expiresAt: Date
  scope: string[]
}
 
async function validateTemporaryToken(token: string) {
  const tokenData = await getTokenData(token)
 
  if (!tokenData) return false
  if (new Date() > tokenData.expiresAt) return false
 
  return true
}```

With [namespaced registries](/docs/registry/namespace), you can set up multiple registries with different authentication:

```
Copy{
  "registries": {
    "@public": "https://public.company.com/{name}.json",
    "@internal": {
      "url": "https://internal.company.com/{name}.json",
      "headers": {
        "Authorization": "Bearer ${INTERNAL_TOKEN}"
      }
    },
    "@premium": {
      "url": "https://premium.company.com/{name}.json",
      "headers": {
        "X-License-Key": "${LICENSE_KEY}"
      }
    }
  }
}```

This lets you:

- Mix public and private registries
- Use different authentication per registry
- Organize components by access level
Never commit tokens to version control. Always use environment variables:

```
CopyREGISTRY_TOKEN=your_secret_token_here
API_KEY=your_api_key_here```

Then reference them in `components.json`:

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

Always use HTTPS URLs for registries to protect your tokens in transit:

```
Copy{
  "@secure": "https://registry.company.com/{name}.json" // ✅
  "@insecure": "http://registry.company.com/{name}.json" // ❌
}```

Protect your registry from abuse:

```
Copyimport rateLimit from "express-rate-limit"
 
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
})
 
app.use("/registry", limiter)```

Change access tokens regularly:

```
Copy// Create new token with expiration.
function generateToken() {
  const token = crypto.randomBytes(32).toString("hex")
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days.
 
  return { token, expiresAt }
}```

Track registry access for security and analytics:

```
Copyasync function logAccess(request: Request, component: string, userId: string) {
  await db.accessLog.create({
    timestamp: new Date(),
    userId,
    component,
    ip: request.ip,
    userAgent: request.headers["user-agent"],
  })
}```

Test your authenticated registry locally:

```
Copy# Test with curl.
curl -H "Authorization: Bearer your_token" \
  https://registry.company.com/button.json
 
# Test with the CLI.
REGISTRY_TOKEN=your_token npx shadcn@latest add @private/button```

The shadcn CLI handles authentication errors gracefully:

- **401 Unauthorized**: Token is invalid or missing
- **403 Forbidden**: Token lacks permission for this resource
- **429 Too Many Requests**: Rate limit exceeded
Your registry server can return custom error messages in the response body, and the CLI will display them to users:

```
Copy// Registry server returns custom error
return NextResponse.json(
  {
    error: "Unauthorized",
    message:
      "Your subscription has expired. Please renew at company.com/billing",
  },
  { status: 403 }
)```

The user will see:

```
CopyYour subscription has expired. Please renew at company.com/billing```

This helps provide context-specific guidance:

```
Copy// Different error messages for different scenarios
if (!token) {
  return NextResponse.json(
    {
      error: "Unauthorized",
      message:
        "Authentication required. Set REGISTRY_TOKEN in your .env.local file",
    },
    { status: 401 }
  )
}
 
if (isExpiredToken(token)) {
  return NextResponse.json(
    {
      error: "Unauthorized",
      message: "Token expired. Request a new token at company.com/tokens",
    },
    { status: 401 }
  )
}
 
if (!hasTeamAccess(token, component)) {
  return NextResponse.json(
    {
      error: "Forbidden",
      message: `Component '${component}' is restricted to the Design team`,
    },
    { status: 403 }
  )
}```

To set up authentication with multiple registries and advanced patterns, see the [Namespaced Registries](/docs/registry/namespace) documentation. It covers:

- Setting up multiple authenticated registries
- Using different authentication per namespace
- Cross-registry dependency resolution
- Advanced authentication patterns
On This Page

