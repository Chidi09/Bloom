# Bloom Cloud Dashboard — Frontend Scope

This document is the source-of-truth specification for the Bloom Cloud web dashboard. It is a large, single-page-application-style dashboard built on **Next.js (App Router)**, **Bun**, **TypeScript**, **Tailwind CSS**, **shadcn/ui primitives**, **Zod**, **Zustand**, and **TanStack** (Query, Table, Form, Router).

The visual design reuses the Bloom marketing landing system documented in `bloom-website/bloom-design-plan.md`: glass panels, mesh gradients, petal motif, Plus Jakarta Sans / JetBrains Mono typography, Lucide icons, and the same token/motion system. The dashboard is not a separate brand; it is the **operational continuation** of the marketing story.

---

## 1. Executive principles

1. **One design system.** Every dashboard primitive comes from the same token/motion/component spine as the marketing site. The only difference is semantic density: dashboards need tables, forms, and status surfaces, not hero sections.
2. **Bun-first.** Use `bun install`, `bun run dev`, `bun test`, `bun build`. Bun auto-loads `.env`.
3. **Type safety everywhere.** All API contracts, forms, query keys, and state slices are typed via Zod and TypeScript.
4. **Server state is the source of truth.** Use TanStack Query for all API data. Zustand for UI/client state only.
5. **Progressive disclosure.** A dashboard this large must hide complexity until needed. Navigation, command palette, and contextual side panels are the primary organization tools.
6. **Performance budget.** First meaningful paint under 2s on mid-tier mobile. Islands of interactivity load on demand. No below-the-fold JS blocks first paint.
7. **Accessibility is non-negotiable.** Focus management, ARIA, keyboard shortcuts, reduced-motion support, and color contrast from day one.

---

## 2. Technology stack

| Layer | Choice | Reason |
|-------|--------|--------|
| Framework | Next.js 14+ App Router | RSC, server actions, nested layouts, parallel routes, intercepting routes |
| Runtime/Package | Bun | Speed, built-in TS, `.env` auto-load, native test runner |
| Language | TypeScript 5.5+ | Strict mode, path aliases, branded types |
| Styling | Tailwind CSS 3.4+ | Utility-first, JIT, dark mode via `class` |
| Components | shadcn/ui primitives | Headless accessibility baseline, easy to theme |
| Design tokens | CSS custom properties + Tailwind theme extend | Shared with marketing site |
| State — server | TanStack Query v5 | Caching, background refetch, optimistic updates, infinite scroll |
| State — client | Zustand v4 | Small, TypeScript-friendly, slices |
| Forms | TanStack Form + Zod | Type-safe, validation, async validation, field arrays |
| Tables | TanStack Table v8 | Sorting, filtering, pagination, row selection, expansion |
| Routing (client) | Next.js App Router + `nuqs` for query params | Type-safe search params via `nuqs` |
| Validation | Zod v3 | API contracts, form schemas, env schemas |
| Icons | Lucide React | Consistent 2px stroke grid |
| Animations | Framer Motion + CSS transitions | Scroll reveals, layout transitions, micro-interactions |
| Charts | Tremor / Recharts / Visx | For analytics/observability dashboards |
| Testing | `bun test` + React Testing Library + Playwright | Unit, integration, E2E |
| Real-time | Server-Sent Events + TanStack Query subscription | Events stream for builds/deployments |
| API proxy | Next.js Route Handler BFF (`/api/bff/*`, §6.6) | Same-origin cookie handling across the dashboard/API subdomain split, simpler CORS |
| Mocking | MSW (`msw/browser` + `msw/node`, §6.5) | Build/demo screens before live backend creds exist; same handlers back integration tests |

Icons, charts, and animation choices in this table are superseded by §22 (Phosphor Icons, shadcn `chart.tsx`, 150–200ms CSS transitions) — this table is the Phase-0 baseline, §22 is current.

---

## 3. Design system (reuse marketing spine)

### 3.1 Tokens

Use the exact tokens from `bloom-website/bloom-design-plan.md`. They are duplicated here with dashboard-specific additions.

```css
:root {
  /* Petals */
  --petal-pink: #FF4B8B;
  --petal-orange: #FF884D;
  --petal-cyan: #20C9B0;
  --petal-blue: #3B82F6;
  --petal-purple: #8B5CF6;

  /* Surfaces */
  --surface-0: #FAFAFA;
  --surface-1: #FFFFFF;
  --surface-2: rgba(255, 255, 255, 0.6);
  --border-subtle: rgba(226, 232, 240, 0.5);
  --text-primary: #0F172A;
  --text-secondary: #475569;
  --text-tertiary: #94A3B8;

  /* Status semantics (dashboard-specific) */
  --status-success: #059669;
  --status-warning: #D97706;
  --status-error: #DC2626;
  --status-info: #3B82F6;
  --status-neutral: #64748B;
  --status-running: #8B5CF6;
  --status-pending: #94A3B8;

  /* Elevation */
  --shadow-1: 0 1px 2px rgba(0, 0, 0, 0.04);
  --shadow-2: 0 8px 32px rgba(31, 38, 135, 0.07);
  --shadow-3: 0 12px 40px -10px rgba(139, 92, 246, 0.15);
  --shadow-4: 0 20px 60px -15px rgba(0, 0, 0, 0.25);

  /* Motion */
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-spring: cubic-bezier(0.175, 0.885, 0.32, 1.275);
  --dur-instant: 120ms;
  --dur-fast: 200ms;
  --dur-base: 400ms;
  --dur-slow: 800ms;

  /* Radius */
  --r-sm: 8px;
  --r-md: 12px;
  --r-lg: 16px;
  --r-xl: 24px;
}

.dark {
  --surface-0: #030509;
  --surface-1: #0D1117;
  --surface-2: rgba(13, 17, 23, 0.6);
  --border-subtle: rgba(51, 65, 85, 0.5);
  --text-primary: #F8FAFC;
  --text-secondary: #94A3B8;
  --text-tertiary: #64748B;
}
```

Semantic mapping:

- **Purple** → primary action / framework identity
- **Blue** → cloud / infra / deployments
- **Cyan** → active / running / live
- **Pink/Orange** → accents / warnings / notifications
- **Green** → success / healthy
- **Red** → failure / error

### 3.2 Typography

Same as marketing: Plus Jakarta Sans for UI, JetBrains Mono for code/numbers/status badges.

### 3.3 Icon rules

- Lucide only.
- Sizes: 16px for inline/badges, 20px for buttons/nav.
- Stroke width: 1.75.
- Never icon-only without `aria-label`.
- Status icons are color-coded and paired with text for accessibility.

### 3.4 Animation tiers

- **Tier 1 micro-interactions** — buttons, cards, toggles: `translateY(-2px)` + shadow-3, `--dur-fast`.
- **Tier 2 scroll reveals** — page sections, empty states: opacity + 12px slide, `--dur-slow`.
- **Tier 3 ambient** — mesh background, status pulses. Respect `prefers-reduced-motion`.
- **Tier 4 narrative** — terminal deploy animation, build progress, pipeline visualizer. Use sparingly.

### 3.5 Shared shell components

These are the same components used across the marketing site, adapted for dashboard density:

- `<AmbientMesh />` — background with color anchors.
- `<GlassPanel variant="static|interactive">` — cards, panels, modals.
- `<Navbar />` — global top nav with org switcher, search, notifications, user menu.
- `<Footer />` — minimal dashboard footer (help, docs, status).
- `<CommandPalette />` — `cmd+k` global command surface.
- `<ToastSystem />` — notifications, action confirmations.
- `<ThemeToggle />` — light/dark/system.
- `<PetalLogo />` — brand mark with highlight segment.
- `<ScrollProgressRail />` — optional in wizard flows.

---

## 4. Application architecture

### 4.1 Next.js App Router structure

```text
dashboard/
├── app/
│   ├── layout.tsx                 # root layout: providers, theme, shell
│   ├── page.tsx                   # redirect to /overview or /onboarding
│   ├── (dashboard)/                # authenticated dashboard routes
│   │   ├── layout.tsx             # sidebar + topbar shell
│   │   ├── overview/page.tsx
│   │   ├── organizations/
│   │   │   ├── page.tsx
│   │   │   ├── [id]/
│   │   │   │   ├── page.tsx
│   │   │   │   ├── members/page.tsx
│   │   │   │   └── billing/page.tsx
│   │   ├── projects/
│   │   │   ├── page.tsx
│   │   │   └── [id]/
│   │   │       ├── page.tsx
│   │   │       └── apps/
│   │   │           └── page.tsx
│   │   ├── apps/
│   │   │   ├── page.tsx
│   │   │   └── [id]/
│   │   │       ├── page.tsx
│   │   │       ├── builds/page.tsx
│   │   │       ├── releases/page.tsx
│   │   │       ├── deployments/page.tsx
│   │   │       ├── environments/page.tsx
│   │   │       ├── secrets/page.tsx
│   │   │       ├── signing/page.tsx
│   │   │       ├── webhosting/page.tsx
│   │   │       ├── observability/page.tsx
│   │   │       └── settings/page.tsx
│   │   ├── builds/[id]/page.tsx
│   │   ├── releases/[id]/page.tsx
│   │   ├── deployments/[id]/page.tsx
│   │   ├── credentials/page.tsx
│   │   ├── git-connections/page.tsx
│   │   ├── workflows/page.tsx
│   │   ├── audit-log/page.tsx
│   │   ├── account/page.tsx
│   │   └── @modal/                 # parallel routes for modals
│   │       ├── (.)apps/[id]/deploy/page.tsx
│   │       └── ...
│   ├── auth/
│   │   ├── login/page.tsx
│   │   ├── register/page.tsx
│   │   └── device/page.tsx
│   ├── api/                        # Next.js API routes for proxy/edge if needed
│   └── error.tsx
├── components/
│   ├── ui/                         # shadcn primitives (Button, Dialog, etc.)
│   ├── shared/                     # shell components (Navbar, Sidebar, CommandPalette)
│   ├── data/                       # TanStack Table wrappers, filters, pagination
│   ├── forms/                      # reusable form fields (SecretInput, EnvVarBuilder)
│   ├── status/                     # status badges, timeline, pipeline visualizer
│   ├── charts/                     # Tremor/Recharts wrappers
│   └── marketing/                  # reused marketing components (AmbientMesh, GlassPanel)
├── lib/
│   ├── api/                        # API client + query hooks
│   ├── hooks/                      # custom React hooks
│   ├── stores/                     # Zustand slices
│   ├── schemas/                    # Zod schemas (forms + API)
│   ├── utils/                      # formatting, dates, slugs, etc.
│   └── auth/                       # auth helpers, token refresh
├── providers/
│   ├── query-provider.tsx
│   ├── theme-provider.tsx
│   └── auth-provider.tsx
├── server/                         # server actions and server-only helpers
├── styles/
│   └── globals.css
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── types/
    └── api.ts
```

### 4.2 Route conventions

- All dashboard routes are under `app/(dashboard)/`.
- Authenticated layout checks session/JWT and redirects to `/auth/login`.
- Organization context is set once at the dashboard root; child routes read it from Zustand or URL params.
- Parallel routes (`@modal`) are used for deploy/release creation modals so they can be linkable and dismissible.
- Intercepting routes (`(.)apps/[id]/deploy`) allow opening a deploy modal from a table while keeping the underlying page in history.

### 4.3 Server/Client split

| Concern | Server (RSC/Server Actions) | Client |
|---------|------------------------------|--------|
| Initial data fetch | `async` page components calling API | TanStack Query for subsequent/refetch |
| Mutations | Server Actions preferred for auth forms; API client for complex multi-step flows | Optimistic updates via TanStack Query |
| Real-time | Server-Sent Events setup | EventSource consumer hook |
| Theme | `cookies` or `Accept` header | `localStorage` + system preference |
| Auth tokens | httpOnly refresh cookie | access token in memory (Zustand) |

---

## 5. State management

### 5.1 Zustand slices

```text
stores/
├── auth-store.ts           # tokens, user, login state
├── organization-store.ts   # current org, role, org list
├── ui-store.ts             # sidebar collapsed, command palette open, modal stack
├── notifications-store.ts  # unread count, toast queue
├── preferences-store.ts    # theme, density (compact/comfortable), timezone
└── sse-store.ts            # live event stream state, build/deploy status updates
```

Each slice is in its own file. Persist `preferences-store` to `localStorage`. Never persist auth tokens.

### 5.2 TanStack Query patterns

- **Query keys are hierarchical and typed:**

```ts
export const queryKeys = {
  organizations: ['organizations'] as const,
  organization: (id: string) => ['organizations', id] as const,
  projects: (orgId: string) => ['organizations', orgId, 'projects'] as const,
  apps: (orgId: string) => ['organizations', orgId, 'apps'] as const,
  app: (id: string) => ['apps', id] as const,
  builds: (appId: string) => ['apps', appId, 'builds'] as const,
  build: (id: string) => ['builds', id] as const,
  releases: (appId: string) => ['apps', appId, 'releases'] as const,
  deployments: (appId: string) => ['apps', appId, 'deployments'] as const,
  secrets: (envId: string) => ['environments', envId, 'secrets'] as const,
  credentials: (orgId: string) => ['organizations', orgId, 'credentials'] as const,
};
```

- **API client:** typed fetch wrapper with automatic token refresh, org header injection, and error parsing.

```ts
export async function api<T>(
  path: string,
  options?: RequestInit & { params?: Record<string, string> }
): Promise<T>;
```

- **Optimistic updates:** for status toggles (cancel build, approve release), update cache immediately and rollback on error.
- **Infinite scroll:** for build logs, audit log, event streams.
- **Polling:** for build/deploy status pages, poll every 3s until terminal state, then back off.
- **Prefetching:** on hover of table rows, prefetch detail pages.

---

## 6. Data layer and API integration

### 6.1 API client

The browser never calls `NEXT_PUBLIC_API_URL` directly — it calls the same-origin BFF proxy at `/api/bff/*` (§6.6), which forwards to `{NEXT_PUBLIC_API_URL}/api/v1` server-side. `src/lib/api/client.ts` is the one place that knows this; every hook/component calls `api.get/post/patch/delete(path)` with bare paths (`/organizations`, not `/api/bff/organizations`).

Headers:

- `Authorization: Bearer {access_token}`
- `X-Bloom-Organization-Id: {current_org_public_id}`
- `Content-Type: application/json`

Error handling:

```ts
interface ApiError {
  error: {
    code: string;
    message: string;
    details?: Record<string, string[]>;
  };
  status: number;
}
```

Zod schema for all API responses. Parse and throw on unexpected shapes.

### 6.2 Authentication flow

1. **Login page** — username/password or device-code flow.
2. **Tokens** — `TokenResponse` (`access_token`, `refresh_token`, `token_type`, `expires_in`) returned as a plain JSON body on login/register/refresh — no `Set-Cookie` anywhere in the accounts views. Both tokens are held in memory only (Zustand `auth-store`), never persisted.
3. **Refresh** — on 401, call `/api/v1/auth/refresh` with `{ refresh_token }` in the request body (`RefreshRequest`). If refresh fails, clear tokens and redirect to login.
4. **CLI device flow** — `/auth/device` page shows `user_code`, polls backend, then sets tokens.

### 6.3 Organization context

- On dashboard mount, fetch `/api/v1/organizations` and select the most recently active org (persist last selection in `localStorage`).
- All subsequent requests include `X-Bloom-Organization-Id`.
- If user is removed from org mid-session, 403 redirects to org switcher.

### 6.4 Real-time events

Use Server-Sent Events endpoint `/api/v1/events/stream` filtered by current organization.

```ts
function useOrganizationEvents(orgId: string) {
  useEffect(() => {
    const es = new EventSource(`/api/v1/events/stream?organization_id=${orgId}`);
    es.onmessage = (event) => {
      const ev = EventSchema.parse(JSON.parse(event.data));
      queryClient.invalidateQueries({ queryKey: deriveQueryKeyFromEvent(ev) });
      notifyIfRelevant(ev);
    };
    return () => es.close();
  }, [orgId]);
}
```

Event-driven invalidation keeps build/deploy/release pages live without aggressive polling.

### 6.5 Mocking — MSW

**Mock Service Worker** (`msw`, `msw/browser` + `msw/node`) is the mocking layer for both browser dev/demo mode and integration tests — one set of handlers, two runtimes:

- **`src/mocks/handlers.ts`** — one `http.get/post/...` handler per endpoint, response shaped exactly per the route inventory (§21.1) and envelopes (§21.2). This is the contract source screens get built against before the backend is reachable (creds/env deferred per the standing S5 note) — a screen built against a correctly-shaped mock swaps to the real BFF response with zero code change.
- **`src/mocks/browser.ts`** (`setupWorker`) — used by `src/mocks/msw-provider.tsx`, a client component gated by `NEXT_PUBLIC_API_MOCKING=enabled` that dynamically `import()`s the worker so it never ships in a real build even if the provider is accidentally left mounted.
- **`src/mocks/server.ts`** (`setupServer`) — used by integration tests (§16.2) to intercept the same handlers under Node, no browser needed.
- **Handlers intercept the BFF path** (`/api/bff/...`), not the backend origin — since the client (§6.1) always calls through the BFF, MSW only ever needs to know the one URL shape the app actually requests.
- `public/mockServiceWorker.js` is generated by `bunx msw init public/ --save` — regenerate it if the `msw` package version changes (the worker script is version-pinned to the installed package).

### 6.6 BFF — same-origin proxy

`src/app/api/bff/[...path]/route.ts` is a Next.js Route Handler that proxies every method (`GET/POST/PATCH/PUT/DELETE`) to `{NEXT_PUBLIC_API_URL}/api/v1/{path}`, forwarding headers and body through unchanged.

**Why a BFF instead of calling the backend origin directly from the browser** (§21 topology has the dashboard and API on different subdomains, `console.bloom.dev` / `api.bloom.dev`):

- Auth is bearer-token-in-body, not cookie-based (§6.2), so the original cookie-avoidance rationale doesn't apply here. The BFF's remaining value is same-origin request routing: it keeps `api.bloom.dev` out of client-side network calls/CSP, sidesteps CORS configuration entirely, and gives the dashboard one place to add server-side concerns (request logging, header normalization) later without touching every call site.
- It also means CORS on the backend only ever needs to allow the **server-to-server** call from the Next.js runtime, not arbitrary browser origins — simpler backend CORS config, and the backend origin never appears in browser network calls or needs to be in the dashboard's CSP `connect-src`.
- The proxy is intentionally dumb — no auth logic, no token refresh, no retry — that all still lives in `src/lib/api/client.ts` (§6.1) on the browser side. The BFF's only job is "same origin, pass everything through untouched."
- SSE (`/events/stream`, §6.4) is **not** proxied through this route — `EventSource` doesn't support custom headers or streaming through a buffering proxy well; it connects to the backend origin directly (confirm CORS allows the dashboard origin for that one endpoint specifically, per §21 topology's CORS note).

---

## 7. Layout and shell

### 7.1 Global layout

```text
┌─────────────────────────────────────────┐
│  Navbar (logo, org switcher, search,    │
│  notifications, user menu, theme)       │
├──────────┬────────────────────────────┤
│ Sidebar  │  Main content area           │
│          │                              │
│  Build   │                              │
│  Ship    │                              │
│  Bloom   │                              │
│          │                              │
└──────────┴────────────────────────────┘
```

### 7.2 Sidebar navigation

Grouped by product narrative:

```text
BUILD
  Overview
  Projects
  Apps
  Build History
  Environments

SHIP
  Releases
  Deployments
  Web Hosting
  Pipelines
  Workflows
  Credentials
  Signing
  Secrets

BLOOM
  Observability
  Audit Log
  Team & Billing
  Settings
```

Sidebar is collapsible on desktop, hidden on mobile behind a hamburger drawer. Active state uses petal-purple accent.

### 7.3 Command palette (`cmd+k`)

Global command surface with sections:

- Navigate to any page
- Switch organization
- Create new project/app/release
- Deploy latest release
- Search builds/releases/members
- Open documentation
- Toggle theme

Use `cmdk` or shadcn Command component. Register commands in a flat registry with keywords and `action()` callbacks.

### 7.4 Notifications

Toast system for:

- Build started/completed/failed
- Deployment status changes
- Member invitations
- Errors

Each toast has a primary action ("View build", "Retry deployment") and a dismiss. Persistent notifications are stored in a panel accessible from the navbar.

### 7.5 Organization switcher

Dropdown in navbar showing:

- Org avatar/initials
- Org name and role badge
- Current plan indicator
- "Switch organization" list
- "Create organization" action

---

## 8. Page-by-page feature scope

### 8.1 Overview (`/overview`)

- Welcome card with setup checklist for new organizations.
- Recent activity feed (builds, deployments, releases).
- Quick actions: "Create app", "New release", "Deploy".
- Health summary per app: latest release, platform status, crash-free rate.
- Usage summary (build minutes, storage) for billing.

### 8.2 Organizations (`/organizations`)

- List organizations with role and plan.
- Create organization modal.
- Org detail page:
  - General settings (name, slug, billing email).
  - Members table with invite, role change, remove.
  - Plan and billing (Phase 7).
  - Danger zone: delete org.

### 8.3 Projects (`/projects`)

- Project grid with status cards.
- Create project modal.
- Project detail page with app list and recent activity.

### 8.4 Apps (`/apps`)

- App list with platform icons, latest release, health sparkline.
- App detail page:
  - Header: app name, repository link, branch, quick actions.
  - Tabs: Builds, Releases, Deployments, Environments, Secrets, Signing, Web Hosting, Observability, Settings.
  - Build → Release → Deploy pipeline visualizer.

### 8.5 Builds (`/apps/[id]/builds`)

- Table with filters: platform, status, branch, date range.
- Columns: status icon, build #, platform, branch/commit, duration, environment, created by, actions.
- Expandable rows show build stages and log tail.
- "New build" button with platform matrix selection.
- Build detail page: full stage timeline, live logs, artifacts, rebuild action.

### 8.6 Releases (`/apps/[id]/releases`)

- Table of releases: version, build number, commit, platforms, status, rollout.
- Create release from build.
- Approval workflow: pending/approved/rejected states.
- Rollback action.
- Changelog editor (markdown).
- Compare releases (diff commits, platforms, health).

### 8.7 Deployments (`/apps/[id]/deployments`)

- Table of deployments: platform, target, release/artifact, status, external link, duration.
- "Deploy" button with wizard:
  1. Select platform
  2. Select target (TestFlight, App Store, internal, closed, open, production, preview)
  3. Select release/artifact
  4. Environment
  5. Confirm
- Deployment detail page: status timeline, platform-specific processing info, logs, rollback.

### 8.8 Environments (`/apps/[id]/environments`)

- List of environments with cards.
- Environment editor:
  - Name, slug, build profile defaults.
  - Pinned Flutter/Dart/Bloom versions.
  - Flavor.
  - API config (env vars + feature flags) builder.
- Delete environment (if no builds).

### 8.9 Secrets (`/apps/[id]/secrets`)

- Per-environment secret list.
- Secret editor: key, value, JSON toggle, version history.
- Rollback to previous version.
- Never display value after save; only show placeholders.
- Bulk import from `.env` file.

### 8.10 Signing (`/apps/[id]/signing`)

- Upload Android keystore, iOS certificate, provisioning profile, App Store Connect API key.
- List with metadata, expiry warnings.
- Download (for backup) only for release managers.
- Expiry alerts in notifications.

### 8.11 Credentials (`/credentials`)

- Platform credential cards: Apple, Google Play, Shorebird, GitHub, GitLab, Bitbucket.
- Add credential wizard per provider.
- Test connection button.
- Show only metadata, never the secret.
- Last used timestamp.

### 8.12 Git Connections (`/git-connections`)

- Connect/disconnect providers.
- List repositories.
- Branch deploy policies editor.
- Webhook delivery log (delivery ID, event, status, replay).

### 8.13 Web Hosting (`/apps/[id]/webhosting`)

- Deployments table with preview URLs.
- Deploy now button.
- Custom domains list with certificate status.
- Domain verification instructions.
- Rollback to previous deployment.
- Redirects/headers editor (from `bloom.yaml`).

### 8.14 Observability (`/apps/[id]/observability`)

- Release health dashboard: crash-free rates, sessions, crashes per platform.
- Charts: crash-free rate over time, deployment markers, active users.
- Per-release breakdown.
- Web analytics: page views, top routes, referrers.

### 8.15 Workflows (`/workflows`)

- Visual pipeline builder (Phase 6).
- YAML editor for advanced users.
- Workflow runs list with status, trigger, duration.
- Run detail: step-by-step log, approvals.

### 8.16 Audit Log (`/audit-log`)

- Filterable table of all actions in organization.
- Columns: timestamp, actor, action, target, IP, before/after snapshots.
- Export to CSV.

### 8.17 Account Settings (`/account`)

- Profile, avatar, timezone.
- API tokens: create, revoke, last used.
- Security: sessions, password change, 2FA (Phase 7).

---

## 9. Component inventory

### 9.1 shadcn/ui primitives to install

Use these as the baseline. Theme them with the Bloom token system.

```text
Accordion, Alert, AlertDialog, Avatar, Badge, Breadcrumb, Button, Calendar,
Card, Checkbox, Collapsible, Command, ContextMenu, Dialog, Drawer, DropdownMenu,
Form, HoverCard, Input, InputOTP, Label, Menubar, NavigationMenu, Pagination,
Popover, Progress, RadioGroup, Resizable, ScrollArea, Select, Separator, Sheet,
Skeleton, Slider, Sonner, Switch, Table, Tabs, Textarea, Toast, Toggle, ToggleGroup,
Tooltip
```

### 9.2 Dashboard-specific custom components

| Component | Purpose |
|-----------|---------|
| `<StatusBadge />` | status with icon + color (build, deployment, release, domain) |
| `<PlatformIcon />` | iOS/Android/Web/All with platform colors |
| `<PipelineVisualizer />` | build → release → deploy flow diagram |
| `<BuildTimeline />` | stage-by-stage timeline with logs |
| `<DeploymentTargetSelector />` | platform/target wizard step |
| `<EnvironmentConfigBuilder />` | env vars + feature flags drag-and-drop builder |
| `<SecretInput />` | masked input with reveal toggle, copy, generate |
| `<CredentialCard />` | provider card with status and last used |
| `<OrganizationSwitcher />` | org dropdown with role + plan |
| `<CommandPalette />` | global cmd+k surface |
| `<NotificationPanel />` | persistent notifications with actions |
| `<UsageChart />` | build minutes, storage, bandwidth |
| `<ReleaseHealthChart />` | crash-free rate with deployment markers |
| `<AuditLogTable />` | TanStack Table with filters |
| `<AppShell />` | main layout wrapper |
| `<PageHeader />` | title, breadcrumbs, actions |
| `<EmptyState />` | consistent empty state with illustration and CTA |
| `<LoadingSkeleton />` | page-level and card-level skeletons |

---

## 10. Forms and validation

### 10.1 Form patterns

- Use TanStack Form + Zod for all client forms.
- Server-side validation is the source of truth; client validation mirrors it for fast feedback.
- Async validation for unique slugs, available names, credential tests.
- Field arrays for: env vars, feature flags, build matrix platforms, domain redirects.
- Auto-save drafts for long forms (release changelog, workflow YAML).

### 10.2 Example Zod schema

```ts
export const createEnvironmentSchema = z.object({
  name: z.string().min(1).max(255),
  slug: z.string().min(1).max(64).regex(/^[a-z0-9-]+$/),
  buildProfile: z.enum(['debug', 'profile', 'release']).default('release'),
  flutterVersion: z.string().optional(),
  dartVersion: z.string().optional(),
  bloomVersion: z.string().optional(),
  flavor: z.string().optional(),
  envVars: z.array(z.object({
    key: z.string().regex(/^[A-Z_][A-Z0-9_]*$/),
    value: z.string(),
  })),
  featureFlags: z.array(z.object({
    key: z.string().regex(/^[a-z0-9_-]+$/),
    enabled: z.boolean(),
  })),
});
```

### 10.3 Error display

- Inline field errors under inputs.
- Non-field errors in a callout at the top of the form.
- API error `details` map to field errors automatically.

---

## 11. Tables and data grids

### 11.1 TanStack Table requirements

Every table supports:

- Column sorting (single/multi)
- Column visibility toggle
- Global search
- Per-column filters (text, select, date range, status)
- Pagination (cursor or page number)
- Row selection (bulk actions)
- Row expansion (details/logs)
- Density switch (compact/comfortable)
- CSV export (where applicable)
- Empty state and loading skeleton

### 11.2 Table toolbar

```text
[Search] [Filter] [Columns ▼] [Density ▼] [Export] [+ New]
```

### 11.3 Row actions

Overflow menu with context-aware actions: view, edit, duplicate, delete, rerun, rollback, approve.

---

## 12. Real-time features

### 12.1 Live build/deploy pages

- SSE event stream invalidates TanStack Query keys.
- Build logs use a virtualized list that appends new lines.
- Terminal-like log viewer with syntax highlighting for Flutter build output.
- Status pulses with heartbeat animation.

### 12.2 Live activity feed

- Global activity feed on overview and per-app pages.
- Event types rendered as rich cards with icons and deep links.
- Group consecutive events by release/build.

### 12.3 Presence (optional Phase 6)

- Show other users viewing the same deployment/release.
- Prevent concurrent edits on release approval/secrets.

---

## 13. CLI-like dashboard features

Bloom CLI users should feel at home in the dashboard.

### 13.1 Terminal blocks

- Display build logs and deploy commands in a terminal-styled panel with JetBrains Mono.
- Copy command to clipboard.
- Show the exact `bloom` command that produced the action.

### 13.2 Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `cmd+k` | Command palette |
| `cmd+/` | Keyboard shortcuts help |
| `cmd+b` | Toggle sidebar |
| `cmd+1..9` | Navigate primary sidebar items |
| `g o` | Go to overview |
| `g p` | Go to projects |
| `g a` | Go to apps |
| `g r` | Go to releases |
| `g d` | Go to deployments |
| `n b` | New build |
| `n r` | New release |
| `n d` | New deployment |
| `?` | Help |

Use a `<KeyboardShortcutsProvider />` with `useHotkeys` hook.

### 13.3 Breadcrumbs and deep links

Every page has breadcrumbs that mirror the hierarchy:

```text
Organizations / Acme / Projects / Mobile App / Apps / iOS Client / Releases / v1.4.0
```

Breadcrumbs are clickable except the current page.

---

## 14. Accessibility

- **Focus management**: restore focus after modal close, trap focus in modals/drawers.
- **ARIA**: landmark regions, `aria-current` for navigation, `aria-live` for status updates.
- **Keyboard**: all interactive elements reachable via Tab; shortcuts do not conflict with screen readers.
- **Color**: do not rely on color alone for status; always pair with icon + text.
- **Motion**: respect `prefers-reduced-motion`.
- **Contrast**: all text meets WCAG AA (4.5:1), large text 3:1.
- **Screen reader testing**: every table, form, and status page must be navigable with NVDA/VoiceOver.

---

## 15. Performance

### 15.1 Loading strategy

- Use `next/dynamic` for heavy components (charts, terminal, code editor).
- Use `Suspense` boundaries around data-fetching sections.
- Prefetch detail pages on row hover.
- Use `unstable_noStore` or `dynamic = 'force-dynamic'` only where truly dynamic.

### 15.2 Bundle optimization

- Tree-shake Lucide icons with named imports.
- Lazy load charting libraries.
- Split routes by feature.
- Monitor bundle size with `@next/bundle-analyzer` in CI.

### 15.3 Caching

- TanStack Query stale time: 30s for lists, 10s for live status, 5m for static metadata.
- Next.js `fetch` cache for server-rendered metadata where appropriate.
- CDN cache for static assets and marketing-reused components.

---

## 16. Testing strategy

### 16.1 Unit tests (`bun test`)

- Zod schema validation.
- Utility functions (date formatting, slug generation, status mapping).
- Zustand store actions.
- API client error handling.

### 16.2 Integration tests (React Testing Library)

- Form submission flows with mocked API.
- Table sorting/filtering.
- Command palette navigation.
- Modal/drawer lifecycle.

### 16.3 E2E tests (Playwright)

- Login flow.
- Create organization → project → app → environment.
- Trigger build and watch live status update.
- Create release and approve.
- Deploy to web preview and verify URL.
- Secrets create/rollback.

### 16.4 Visual regression (optional)

- Chromatic or Playwright screenshots for critical pages.
- Test both light and dark themes.

### 16.5 CI checks

```bash
bun run lint
bun run typecheck
bun run format:check
bun test
bun run build
```

---

## 17. Environment configuration

Bun auto-loads `.env` files.

```text
NEXT_PUBLIC_API_URL=https://api.bloomcloud.dev
NEXT_PUBLIC_APP_URL=https://dashboard.bloomcloud.dev
NEXT_PUBLIC_WS_URL=https://api.bloomcloud.dev
```

No secrets in `NEXT_PUBLIC_`. Server-only secrets use unprefixed vars:

```text
# None needed for pure client dashboard; if server actions call internal APIs, use server-only env validation.
```

Validate env with Zod at build time:

```ts
const envSchema = z.object({
  NEXT_PUBLIC_API_URL: z.string().url(),
  NEXT_PUBLIC_APP_URL: z.string().url(),
});
```

---

## 18. Phase implementation (frontend)

### Phase 0 — Foundation

- Scaffold Next.js + Bun + Tailwind + shadcn.
- Set up tokens, theme toggle, fonts.
- Build shared shell: Navbar, Sidebar, CommandPalette, Toast, GlassPanel, AmbientMesh.
- Set up TanStack Query, Zustand, auth provider.
- Login/register pages.
- Organization list and switcher.

### Phase 1 — Organization, Projects, Apps

- Organization CRUD pages.
- Project list/detail.
- App list/detail with tabs.
- Overview page.

### Phase 2 — Secrets, Signing, Credentials

- Credentials vault page.
- Secrets manager per environment.
- Signing identity upload/list.
- Form builders.

### Phase 3 — Builds, Artifacts, Logs

- Builds table and detail page.
- Live log viewer.
- Artifacts list with download.
- Build timeline component.

### Phase 4 — Releases and Web Deployments

- Releases table, approval, rollback.
- Web hosting deployments and preview URLs.
- Deployment wizard (web only first).

### Phase 5 — Mobile Deployments and Observability

- TestFlight and Google Play deployment wizard steps.
- Deployment detail platform-specific views.
- Observability charts and health dashboard.

### Phase 6 — Workflows, Git, Audit Log

- Git connections and webhook logs.
- Workflows visual builder and YAML editor.
- Workflow runs and approvals.
- Audit log table.

### Phase 7 — Billing, Marketplace, Polish

- Billing pages.
- Templates marketplace (Phase 8).
- Performance polish, keyboard shortcuts, accessibility audit.

---

## 19. Cross-cutting concerns

### 19.1 Error boundaries

- Global error boundary shows friendly error with reload and report.
- Route-level error boundaries for dashboard sections.
- API errors show toast or inline error depending on context.

### 19.2 Logging and analytics

- Track page views, feature usage (optional, privacy-respecting).
- Log errors to Sentry (via `next.config` or error boundary).
- No sensitive data in analytics.

### 19.3 Feature flags

- Use environment flags for early features.
- Per-user/org feature gates driven by backend plan/entitlements (Phase 7).

### 19.4 Internationalization (future)

- Use `next-intl` or similar from day one with English base.
- All user-facing strings in translation files, no hardcoded strings in components.

---

## 20. Definition of done

A dashboard page is complete when:

1. It matches the design token and motion system.
2. It is type-safe end-to-end (API → hook → component).
3. It handles loading, empty, error, and success states.
4. It is accessible via keyboard and screen reader.
5. It has unit/integration tests for core logic.
6. It passes lint, typecheck, format check, and build.
7. It works in both light and dark themes.
8. It respects `prefers-reduced-motion`.

---

## 22. Visual direction supersedes §3/§7/§9 — Vercel-style, shadcn-only, AMOLED

This section is the current source of truth for look, feel, and screen inventory. §3 (glass/petal marketing spine), the Lucide icon rule in §3.3, and the informal page list in §8 are superseded where they conflict with this section. §1–§2, §4–§6, §10–§21 (architecture, state, data layer, forms, tables, real-time, a11y, perf, routes/contracts) still stand unchanged.

**What changed and why:**
- **Aesthetic**: not a "continuation of the marketing story" anymore. This is an operational tool — Vercel/Linear-grade: dense, quiet, fast, monochrome-first with color reserved for status. Drop `<AmbientMesh>`, mesh gradients, and glass panels as the *default* surface — flat solid surfaces with 1px borders are the norm; motion is minimal (150–200ms fades/slides, no springy tier-2/3/4 marketing motion).
- **Icons**: **Phosphor Icons** (`@phosphor-icons/react`), not Lucide. `regular` weight for all tables, nav links, and inline telemetry; `fill` weight reserved strictly for active/selected/pinned states (active sidebar route, pinned environment, starred template). Optical sizing is fixed, not ad hoc: **14–16px** for inline status indicators, table cells, dropdown options, micro-badges; **18–20px** for main nav, tab headers, primary button triggers. Vendor/platform logos (Apple, Android, GitHub, GitLab, Web, Bitbucket) are the one allowed non-Phosphor SVG set — keep them at a uniform 16×16 box and 1.75px stroke so they don't optically clash with Phosphor glyphs sitting next to them. Never mix icon sets otherwise.
- **Typography split**: sans-serif (Geist Sans or Inter — pick one, do not use Plus Jakarta Sans from the marketing site, that's the marketing brand voice not this tool's) for nav labels and prose UI; **tabular monospace** (Geist Mono or JetBrains Mono, `font-variant-numeric: tabular-nums`) for anything that is a metric, ID, hash, duration, IP, or timestamp — build numbers, commit SHAs, durations, log lines, audit-log IPs. This is a hard rule, not a stylistic default: a build number or commit hash rendered in the sans font is a bug.
- **Theme**: AMOLED-first dark mode — true `#000000` base surface, not `#0D1117`. Every component must be theme-aware (CSS variables, not hardcoded hex in components) so light mode and a future "dim" mode are cheap additions, but dark/AMOLED is the primary design target and what gets designed first.
- **Primitives discipline**: pages are composed **only** from installed shadcn/ui primitives (§9.1 list, extended below). No bespoke divs styled to look like a card/button/badge. If a screen needs something shadcn doesn't ship (e.g. a pipeline graph, a log viewer), that's a named exception — get explicit approval before building it, and build it as a wrapper *around* primitives (e.g. a log viewer is a `ScrollArea` + `Skeleton` + monospace `<pre>`, not a from-scratch scrolling engine).
- **Density**: compact by default. Table row height 36–40px, page padding 16–24px (not 32–48px), no oversized hero sections inside the dashboard shell. A "comfortable" density toggle (§11.1) is the escape hatch for users who want more air — compact is the default, not comfortable.

### 22.1 Updated tokens (replaces §3.1 surface/status block)

```css
:root {
  /* Light mode */
  --background: #FFFFFF;
  --surface-1: #FAFAFA;      /* cards, panels */
  --surface-2: #F4F4F5;      /* nested surfaces, table header */
  --border: #E4E4E7;
  --border-strong: #D4D4D8;
  --text-primary: #09090B;
  --text-secondary: #52525B;
  --text-tertiary: #A1A1AA;
  --accent: #FFFFFF;          /* primary button bg in dark, inverted in light */
  --accent-foreground: #000000;

  --status-success: #16A34A;
  --status-success-bg: #F0FDF4;
  --status-warning: #D97706;
  --status-warning-bg: #FFFBEB;
  --status-error: #DC2626;
  --status-error-bg: #FEF2F2;
  --status-info: #2563EB;
  --status-info-bg: #EFF6FF;
  --status-pending: #71717A;
  --status-pending-bg: #FAFAFA;
  --status-running: #7C3AED;
  --status-running-bg: #F5F3FF;

  --radius: 8px;             /* shadcn default radius, not the marketing 12-24px scale */
}

.dark {
  /* AMOLED */
  --background: #000000;
  --surface-1: #0A0A0A;
  --surface-2: #131313;
  --border: #1F1F1F;
  --border-strong: #2E2E2E;
  --text-primary: #FAFAFA;
  --text-secondary: #A1A1AA;
  --text-tertiary: #6B6B70;
  --accent: #FFFFFF;
  --accent-foreground: #000000;

  --status-success: #22C55E;
  --status-success-bg: rgba(34, 197, 94, 0.1);
  --status-warning: #F59E0B;
  --status-warning-bg: rgba(245, 158, 11, 0.1);
  --status-error: #EF4444;
  --status-error-bg: rgba(239, 68, 68, 0.1);
  --status-info: #3B82F6;
  --status-info-bg: rgba(59, 130, 246, 0.1);
  --status-pending: #71717A;
  --status-pending-bg: rgba(113, 113, 122, 0.08);
  --status-running: #A78BFA;
  --status-running-bg: rgba(167, 139, 250, 0.1);
}
```

Wire these through shadcn's standard `--background`/`--foreground`/`--card`/`--border`/`--ring` token names (`components.json` `cssVariables: true`) so every installed primitive theme-switches for free — do not fork shadcn component source to hardcode colors.

### 22.2 Global states every screen must implement

Five states, every list/detail screen, no exceptions:

| State | Primitive(s) | Rule |
|---|---|---|
| **Loading** | `<Skeleton>` shaped like the real content (row skeletons for tables, card skeletons for grids) | Never a full-page spinner for a screen that has a known layout; spinner only for actions inside a `<Button>` (`disabled` + inline spinner icon) |
| **Empty** | `<EmptyState>` (icon + heading + one-line description + primary `<Button>` action) | Always actionable — "No builds yet" pairs with "Trigger your first build", never a dead end |
| **Error** | `<Alert variant="destructive">` inline for section-level failures; full-page error boundary only for unrecoverable route failures | Always includes a retry action; never swallow the error message silently |
| **Success** (transient) | `<Sonner>` toast, `--status-success` | Mutations confirm via toast, not a full reload; toast has a deep-link action where relevant ("View release") |
| **Pending/Warning** (persistent, in-content) | `<Badge>` using `--status-pending`/`--status-warning` tokens, paired with icon + text (never color alone, per §14) | Used for domain-verification-pending, release-awaiting-approval, credential-expiring, subscription-past-due, etc. |

### 22.3 Extended shadcn primitive set (adds to §9.1)

No new primitives beyond shadcn's own catalog — the addition is just naming the ones §9.1 omitted that this screen inventory needs: `AspectRatio`, `Combobox` (Command + Popover composition, not a separate package), `DataTable` (TanStack Table wrapped in Table primitives — this is a composition, not a new primitive), `Chart` (shadcn's `chart.tsx` wrapper over Recharts — replaces the bare "Tremor/Recharts/Visx" line in §2, use shadcn's own chart primitives so theming stays token-driven).

### 22.4 Full screen inventory

Each entry: **route** · **shadcn primitives used** · **what the user sees** · **states**. Sidebar grouping (BUILD/SHIP/BLOOM) from §7.2 stays as the nav taxonomy.

#### Auth
- **`/auth/login`** — `Card`, `Input`, `Label`, `Button`, `Alert`. Email + password, "forgot password" link (backend has no reset endpoint yet per route inventory — this link goes to a support mailto until that route exists, do not build a dead form). Rate-limit errors (10/min) render as `Alert variant="destructive"` with a countdown, not a generic "try again."
- **`/auth/register`** — same primitives + password strength hint text. Throttled 5/min, same treatment.
- No device-flow screen (§21.5 — CLI-only, not built here).

#### Overview — `/overview`
- `Card` (setup checklist, uses `Checkbox` rows, only shown until all steps done — then the card disappears, not just greys out), `Card` grid for per-app health (each card: `PlatformIcon` (Phosphor `AppleLogo`/`AndroidLogo`/`Globe`), app name, `Badge` for latest release status, `Progress` or sparkline via `Chart` for crash-free rate), activity feed (`ScrollArea` of compact rows: icon + text + relative time via `Tooltip` showing absolute time), `DropdownMenu` "Quick actions" button.
- Empty state (brand-new org): checklist only, no health cards, no activity feed section rendered at all (not an empty table — omit the section header too).

#### Organizations — `/organizations`
- List: `Table` (name, role `Badge`, plan `Badge`, member count, created date), row click → detail. `Dialog` for create.
- Detail `/organizations/[id]`: `Tabs` (General / Members / Billing / Danger Zone).
  - General: `Form` (name, slug, billing email) using `Input` + shadcn `Form` (react-hook-form or TanStack Form binding per §10.1).
  - Members: `Table` with `Avatar`, name, email, role `Select` (inline edit, disabled if current user's role ≤ target — hide the control entirely per §21.5, don't grey it out), `DropdownMenu` row actions (change role / remove), `Dialog` invite flow with `Combobox` for role select and `Input` for email, pending-invite rows get `Badge` "Pending" in `--status-pending`.
  - Billing: see Billing screens below, embedded via the same components, org-scoped.
  - Danger Zone: `Card` with `AlertDialog` confirming delete (type-to-confirm `Input` matching org slug).

#### Projects — `/projects`
- Grid of `Card`s (name, app count `Badge`, last activity). `Dialog` create. Detail page: `Card` header + `Table` of apps in project + recent activity `ScrollArea`, same pattern as Overview's feed component reused.

#### Apps — `/apps` and `/apps/[id]`
- List: `Table` toolbar per §11.2 (`Input` search, `Select`/`Combobox` filters for platform/status, `DropdownMenu` columns, density `ToggleGroup`, `Button` "New app"). Columns: `PlatformIcon`, name, project, latest release `Badge`, health sparkline (`Chart`), updated.
- Create: `Dialog` with `Tabs` for "Link existing repo" vs "Blank app" (mirrors `POST /apps` vs `POST /apps/link`).
- Detail: `PageHeader` (breadcrumb §13.3, app name, repo link `Button variant="link"` with `GithubLogo`/`GitlabLogo`/`BitbucketLogo`, branch `Badge`), then `Tabs`: Builds / Releases / Deployments / Environments / Secrets / Signing / Web Hosting / Observability / Settings — each tab is its own route (`/apps/[id]/builds` etc., not client-only tab state) so they're deep-linkable, `Tabs` component just reflects the active route.
  - Settings sub-tab: `Form` (name, default branch, repo), `AlertDialog` delete-app.

#### Builds — `/apps/[id]/builds` and `/apps/[id]/builds/[buildId]`
- List: `DataTable` (status icon+`Badge`, build #, platform, branch/commit `Tooltip` showing full SHA, duration, environment, created-by `Avatar`+name, `DropdownMenu` row actions: view/cancel — cancel hidden unless role permits and status is running/pending). Row expansion (`Collapsible` inside the row) shows stage list + last 10 log lines in monospace.
- "New build" — `Dialog`/`Sheet` wizard: environment `Select`, platform matrix `Checkbox` group.
- Detail: `PageHeader`, stage `Timeline` (composed from `Separator` + status `Badge` per stage — no bespoke timeline primitive), live log viewer (`ScrollArea` + monospace `<pre>`, virtualized for length, auto-scroll toggle `Switch`), artifacts list (`Table`, `Button` download), `Button` "Rebuild".
- Running state: stage `Badge`s pulse (`--status-running`, CSS opacity animation respecting `prefers-reduced-motion`), log viewer live-appends via SSE (§21.4, `build.stage_updated`/`build.completed` events).

#### Releases — `/apps/[id]/releases` and `.../releases/[releaseId]`
- List: `DataTable` (version, build #, commit, platform icons, status `Badge` [draft/pending/approved/rejected/rolled_back], rollout %). `Button` "Create release" (`Dialog`, select source build).
- Detail: `PageHeader`, changelog `Textarea` (markdown, autosave draft per §10.1) with a `Tabs` write/preview split, approval panel (`Card` with `Button` approve/reject — hidden for roles below ReleaseManager per §21.5), `Button` rollback (`AlertDialog` confirm), "Compare releases" `Dialog` with two `Combobox` pickers producing a diff `Table`.
- Pending-approval state: `Alert` banner at top of detail page (`--status-warning`) visible to everyone, actionable only for ReleaseManager+.

#### Deployments — `/apps/[id]/deployments` and `.../deployments/[id]`
- List: `DataTable` (platform icon, target `Badge` [TestFlight/App Store/internal/production/preview], release version, status, external link `Button variant="ghost"` with `ArrowSquareOut`, duration).
- "Deploy" — multi-step `Dialog` (or `Sheet` if the step content gets tall): platform → target → release/artifact `Combobox` → environment `Select` → confirm `Card` summary. Step indicator via `Tabs` styled as a stepper (no bespoke stepper primitive) or simple numbered `Badge` row.
- Detail: status `Timeline` (same composition as Builds), platform-specific info `Card` (e.g. TestFlight processing state, App Store review status), `Button` rollback.

#### Environments — `/apps/[id]/environments`
- `Card` grid, one per environment (name, slug `Badge`, build profile). Click → `Sheet` editor (not a full page — this is a config surface, not a browsable record): `Form` fields, pinned versions `Input`s, flavor `Input`, env-vars `Table` field-array (add/remove rows), feature-flags `Table` field-array with `Switch` per row.
- Delete: `AlertDialog`, disabled (button hidden with `Tooltip` explaining why, not just disabled-looking) if the environment has builds.

#### Secrets — `/apps/[id]/secrets`
- Per-environment `Select` at top, then `Table` (key, masked value `••••••` with `Button` reveal-toggle that calls a fresh fetch rather than ever caching plaintext client-side, version `Badge`, updated). `Sheet` editor: key `Input`, value `Textarea`/`Input` with a JSON `Switch`, `Button` save creates a new version (never mutates in place per backend's version history model).
- History: `DropdownMenu` row action "View history" → `Dialog` with version `Table`, `Button` rollback per version (`AlertDialog` confirm — rollback is itself a new version write, not a destructive delete).
- Bulk import: `Dialog` with file `Input` (`.env`) → preview `Table` of parsed pairs before commit.
- **Never render a previously-saved value** — only ever show the placeholder + reveal-on-demand, and reveal never persists across a page reload (state, not cache).

#### Signing — `/apps/[id]/signing`
- `Card` grid or `Table` (type icon, metadata fields per §21.3's `SigningIdentityMetadata` tagged union — render the right fields per `kind`), expiry `Badge` (`--status-warning` inside 30 days, `--status-error` if expired). `Dialog` upload with `Tabs` per kind (keystore/certificate/provisioning_profile/api_key), file `Input` + kind-specific fields.
- Download: `Button` visible only to ReleaseManager+ (§21.5).

#### Credentials — `/credentials`
- `Card` grid keyed by provider (Apple/Google Play/Shorebird/GitHub/GitLab/Bitbucket), each showing `PlatformIcon`, masked metadata field per §21.3's `CredentialMetadata` union, last-used relative time, `Badge` connected/not-connected.
- `Dialog` add-credential wizard, `Tabs` or `Select` for provider first (form fields change per variant), `Button` "Test connection" inline in the card (`Sonner` toast for pass/fail, spinner in-button while pending).

#### Git Connections — `/git-connections`
- `Table` of connections (provider icon, account name, status). `Button` connect (OAuth redirect — plain link/button, not a form). Repository list `Sheet` per connection (`GET .../repositories`, used for app-linking, per §21.1's note). Branch deploy policy `Table` field-array (branch pattern → environment mapping). Webhook delivery log: `DataTable` (delivery ID, event type `Badge`, status, `Button` "Replay").

#### Web Hosting — `/apps/[id]/webhosting`
- Two `Tabs`: Deployments / Domains.
  - Deployments: `DataTable` (preview URL `Button variant="link"`, status, created), `Button` "Deploy now", `Button` rollback per row.
  - Domains: `Table` (domain, cert status `Badge` [pending/issued/failed] in `--status-*`), `Dialog` add domain showing `required_records` (§21.1) in a copyable `Card` (monospace, `Button` copy-to-clipboard per record), `Button` "Verify" polls/re-checks.
  - Redirects/headers editor: `Table` field-array from `bloom.yaml`, read-mostly with an "edit in repo" hint if the backend doesn't accept writes here (confirm against contracts before building a write path — if there's no PATCH for this, render read-only with a `Tooltip` explaining it's config-as-code).

#### Observability — `/apps/[id]/observability`
- `Chart` (crash-free rate over time, line chart, deployment markers as vertical reference lines), `Card` KPI row (sessions, crashes, active users — big number + delta `Badge`), per-release `Table` breakdown, web analytics sub-section (`Chart` page views, `Table` top routes/referrers) only rendered if the app has web-hosting deployments.

#### Workflows — `/workflows` and `/workflows/[id]`
- List: `DataTable` (name, trigger, last run status, duration). YAML editor: `Textarea` (monospace) inside a `Card`, no visual pipeline builder in v1 — §18 Phase 6 visual builder is deferred; ship the YAML editor first since it maps directly to the one real backend surface (`workflows`/`workflows/runs`).
- Runs: `DataTable` nested under workflow detail (`Tabs`: Definition / Runs), run detail `Sheet` with step `Timeline` + `Button` approve (`AlertDialog`) for gated steps.

#### Audit Log — `/audit-log`
- `DataTable`, full §11.1 feature set (this is the canonical "needs everything" table): filters (`Combobox` actor, `Select` action type, `Calendar`+`Popover` date range), columns (timestamp, actor `Avatar`+name, action `Badge`, target link, IP monospace), row click → `Sheet` with before/after JSON diff (two-column monospace `<pre>`), `Button` export CSV.

#### Team & Billing — `/organizations/[id]/billing` (embedded tab, not top-level nav per §7.2's grouping — correct the sidebar: "Team & Billing" under BLOOM routes here, not a separate top-level page)
- `Card` current plan + `Button` upgrade/downgrade, usage `Progress` bars (build minutes, storage vs plan limits), `Table` invoices (`Button` download PDF link), payment method section reflects §21.6's webhook-only reality: after `POST /billing/subscribe`, show a `Card` "Redirecting to complete payment…" state, then rely on SSE `billing.subscription.activated` to flip the plan `Badge` live — **do not build a "confirm payment" button, the backend has no such action.**

#### Account Settings — `/account`
- `Tabs`: Profile / API Tokens / Security.
  - Profile: `Form` (name, avatar `Avatar`+`Input[type=file]`, timezone `Combobox`).
  - API Tokens: `Table` (name, created, last used, `Button` revoke `AlertDialog`), `Dialog` create shows the raw token **once** in a copyable monospace `Card` with an explicit "you won't see this again" `Alert`.
  - Security: sessions `Table` (device/IP/last active, `Button` revoke), password change `Form`. No 2FA UI — backend doesn't have it yet (§18 Phase 7), don't build a dead toggle.

#### Marketplace (Phase 7, backend already routes it — spec it now since the routes exist)
- **`/marketplace`** (public templates browse, can reuse for both public discovery and org's install flow): `Card` grid, `Input` search, `Select` category filter, template `Card` (name, seller, price via the integer-minor-units rule §21.3, rating).
- **`/marketplace/[id]`**: detail `Card`, version `Select`, `Button` purchase/install, reviews `Tabs` (list `Card` per review with `Button` reply for the template's own author, `Button` report for others — report opens `Dialog` with reason `Textarea`).
- **`/templates`** (org's own — create/manage): `DataTable` (name, status `Badge` [draft/published/archived], installs count), `Button` create → editor with version `Table` field-array, `Button` publish/archive.
- **`/marketplace/purchases`**: `DataTable` cursor-paginated (§21.2 — this list has no `count`, so the `DataTable` pagination footer must render "Load more" not page numbers), `Button` refund (`AlertDialog`, staff/admin only).
- **Seller onboarding**: `Card` with `Button` "Connect payout account" (Stripe Connect redirect), status `Badge` reflecting onboarding state, `Button` refresh status.

### 22.5 Sidebar correction (supersedes §7.2's grouping for the two items that moved)

```text
BUILD
  Overview
  Projects
  Apps
  Build History
  Environments

SHIP
  Releases
  Deployments
  Web Hosting
  Workflows
  Credentials
  Signing
  Secrets
  Git Connections
  Marketplace

BLOOM
  Observability
  Audit Log
  Settings
```

"Team & Billing" is not a top-level sidebar item — it lives under the current organization's detail page (`/organizations/[id]` → Billing tab, §22.4), reached via the org switcher, not the primary nav. "Account" is reached from the navbar user menu, not the sidebar, consistent with the Vercel pattern of separating personal settings from workspace nav.

### 22.6 Progressive disclosure — three layers, plus modal as the fourth (destructive/wizard only)

Every list screen (Builds, Releases, Deployments, Audit Log, Workflows runs, etc.) is built from the same three layers so triage never requires a navigation. Pick the right layer per interaction — don't default to a full page nav for something that's really an inline expand:

1. **Surface layer — the scannable grid.** `DataTable`/`Table` row shows only what's needed to triage at a glance: status `Badge`, ID/name, target/branch, duration, relative timestamp (`Tooltip` on hover for the absolute one). This is the 36–40px row height layer from §22.2's density rule — nothing here should force a taller row.
2. **Inline accordion — instant triage.** Clicking a row (not navigating) expands a `Collapsible` directly beneath it in the list: stage progress, last N log lines, metadata diff. The filter bar, scroll position, and sibling rows stay exactly where they were — this is the layer that answers "why did this fail" without a route change. Builds' stage/log preview (§22.4) and Audit Log's before/after diff both use this, not a separate page, for the common case; a full detail *route* still exists for deep-linking/sharing a specific build or run, but the accordion is the fast path.
3. **Slide-over sheet — deep configuration.** Multi-field editors that need real estate but shouldn't lose the underlying page context: `Sheet` from the right edge. Environment config, secret editor + version history, git-connection repository picker, workflow run detail. The list/filters stay visible and interactive-looking (dimmed) behind the sheet so the user's place in the list is never lost.
4. **Modal (`Dialog`/`AlertDialog`) — destructive confirmations and short wizards only.** Delete org, rollback production, revoke a token, the multi-step Deploy wizard (§22.4 Deployments). If a "wizard" needs more than ~3 steps or scrolls past one screen, it should be a `Sheet`, not a `Dialog` — dialogs stay compact and modal-appropriate.

Layer selection is not a style choice per screen — it is fixed by what the interaction *is*: triage → accordion, configure → sheet, destroy/confirm or short multi-step → modal. Don't let a screen invent a fifth pattern.

### 22.7 Operational polish (ties together §22.2 states, §21.5 roles, §21.4 SSE)

- **Role-based pruning is hard-hidden, not disabled.** Reaffirming §21.5/§22.2: an action the current role can't reach (cancel a running build, revoke a credential, approve a release) does not render at all — no greyed-out button, no tooltip explaining why, because the row/menu item simply isn't there. This applies uniformly across every `DropdownMenu` row-action and every primary `Button` on every screen in §22.4.
- **Hollow containers never render.** An empty section is omitted — no header, no zero-state table, nothing — rather than showing a container with nothing useful in it (§22.2's empty-state rule already covers the *primary* content area; this extends it to secondary/optional sections like Overview's activity feed when an org has no events yet).
- **`Cmd+K` is the cross-resource search surface**, not just page navigation (§13.3 already scopes it to navigate/switch-org/create/deploy/search/docs/theme — no change needed, just reaffirming it's the primary way experienced users move around, not a nice-to-have).
- **Running/pending states pulse via SSE-driven state, not polling** — §21.4's event stream flips a `Badge`/row from pending → running → terminal live; a screen should never need a manual refresh to see a build or deployment finish.

---

## 21. Deployment topology — connecting to the marketing site

The marketing site (`bloom-website`) is a **separate Vercel project** (`bloom-platform`, currently on `bloom-platform-ten.vercel.app`, no custom domain wired yet) built with Astro + Preact + Bun. It stays exactly as-is; this dashboard does not live inside it.

- **Split by subdomain, not path.** `bloom.dev` → marketing (existing Astro project). `console.bloom.dev` (or `app.bloom.dev`) → this dashboard, as a second Vercel project pointed at this repo. Each project has its own build, own env vars, own deploy cadence, and neither needs to know the other exists.
- **Why not a path-based split** (`bloom.dev/console` via Vercel rewrites): it adds a proxy hop and couples two independently-deployed apps' routing config together for no benefit here.
- **CORS.** The browser only ever calls the dashboard's own origin (`/api/bff/*`, §6.6); the BFF's server-side fetch to `api.bloom.dev` is not subject to CORS. `cloud-backend` only needs to allow cross-origin calls from non-BFF clients (the CLI, marketing site widgets, etc.), not the dashboard itself.
- **Shared nothing except the design tokens**, which are already duplicated into this document (§3.1) rather than imported, since there is no shared package between the two repos today. If token drift becomes a real problem, extracting `@bloom/tokens` as a published or workspace package is the fix — not sharing the Astro repo.

### 21.1 Full backend route inventory

Every route registered in `cloud-backend`, grouped by app, as of this session (`088d253`, `263738b`, `3855813`). Routes appear twice in the router source for legacy `:id`/`{id}` path-param compatibility — collapsed here to one row each. **Every path below is mounted under `/api/v1`** (`src/urls.rs:13`, `.mount("/api/v1", apps::urls())`) — e.g. `GET /releases` in the table is actually `GET /api/v1/releases`. Set the API client's base URL to `{API_ORIGIN}/api/v1` once and use the bare paths below everywhere else.

**accounts** (auth — no organization scoping, no bearer token required except where noted)
| Method | Path | Handler | Auth |
|---|---|---|---|
| POST | `/auth/register` | `register` | none — throttled 5/min |
| POST | `/auth/login` | `login` | none — throttled 10/min |
| POST | `/auth/refresh` | `refresh_token` | refresh token — throttled 20/min |
| POST | `/auth/logout` | `logout` | bearer |
| GET | `/auth/me` | `me` | bearer |
| POST | `/auth/device` | `device_flow_init` | none |
| POST | `/auth/device/authorize` | `device_flow_authorize` | bearer (user approving a CLI device) |
| GET | `/auth/device/token` | `device_flow_poll` | none — throttled 60/min |
| POST | `/auth/token` | `create_api_token` | bearer |
| DELETE | `/auth/token/{id}` | `revoke_api_token` | bearer |

**organizations**
| Method | Path | Handler |
|---|---|---|
| GET | `/organizations` | `list_organizations` |
| POST | `/organizations` | `create_organization` |
| GET | `/organizations/current` | `current_organization` |
| GET | `/organizations/{id}` | `retrieve_organization` |
| PATCH | `/organizations/{id}` | `update_organization` |
| DELETE | `/organizations/{id}` | `delete_organization` |
| GET | `/organizations/{id}/members` | `list_members` |
| POST | `/organizations/{id}/members` | `invite_member` |
| PATCH | `/organizations/{id}/members/{member_id}` | `change_role` |
| DELETE | `/organizations/{id}/members/{member_id}` | `remove_member` |
| POST | `/organizations/invites/accept` | `accept_invite` |

**projects**
| Method | Path | Handler |
|---|---|---|
| GET | `/projects` | `list_projects` |
| POST | `/projects` | `create_project` |
| GET | `/projects/{id}` | `retrieve_project` |
| PATCH | `/projects/{id}` | `update_project` |
| DELETE | `/projects/{id}` | `delete_project` |

**apps**
| Method | Path | Handler |
|---|---|---|
| GET | `/apps` | `list_apps` |
| POST | `/apps` | `create_app` |
| POST | `/apps/link` | `link_app` |
| GET | `/apps/{id}` | `retrieve_app` |
| PATCH | `/apps/{id}` | `update_app` |
| DELETE | `/apps/{id}` | `delete_app` |

**environments**
| Method | Path | Handler |
|---|---|---|
| GET | `/environments` | `list_environments` |
| POST | `/environments` | `create_environment` |
| GET | `/environments/{id}` | `retrieve_environment` |
| PATCH | `/environments/{id}` | `update_environment` |
| DELETE | `/environments/{id}` | `delete_environment` |

**secrets**
| Method | Path | Handler |
|---|---|---|
| GET | `/secrets` | `list_secrets` |
| POST | `/secrets` | `create_or_update_secret` |
| GET | `/secrets/{id}` | `retrieve_secret` |
| PATCH | `/secrets/{id}` | `update_secret` |
| DELETE | `/secrets/{id}` | `delete_secret` |
| POST | `/secrets/{id}/rollback` | `rollback_secret` |

**credentials**
| Method | Path | Handler |
|---|---|---|
| GET | `/credentials` | `list_credentials` |
| POST | `/credentials` | `create_credential` |
| GET | `/credentials/{id}` | `retrieve_credential` |
| DELETE | `/credentials/{id}` | `delete_credential` |
| POST | `/credentials/{id}/test` | `test_credential` |

**signing**
| Method | Path | Handler |
|---|---|---|
| GET | `/signing` | `list_signing_identities` |
| POST | `/signing` | `upload_signing_identity` |
| GET | `/signing/{id}` | `retrieve_signing_identity` |
| DELETE | `/signing/{id}` | `delete_signing_identity` |

**git_connections**
| Method | Path | Handler |
|---|---|---|
| GET | `/git-connections` | `list_connections` |
| POST | `/git-connections` | `create_connection` |
| GET | `/git-connections/{id}` | `retrieve_connection` |
| GET | `/git-connections/{id}/repositories` | `list_repositories` — returns `RepositoryResponse[]` (§21.1 contracts) to power the app-linking picker |
| DELETE | `/git-connections/{id}` | `delete_connection` |
| POST | `/webhooks/github` | `github_webhook` (inbound, not client-called) |
| POST | `/webhooks/gitlab` | `gitlab_webhook` (inbound) |
| POST | `/webhooks/bitbucket` | `bitbucket_webhook` (inbound) |

**builds**
| Method | Path | Handler |
|---|---|---|
| GET | `/builds` | `list_builds` |
| POST | `/builds` | `create_build` |
| GET | `/builds/{id}` | `retrieve_build` |
| POST | `/builds/{id}/cancel` | `cancel_build` |
| GET | `/builds/{id}/logs` | `build_logs` |
| POST | `/workers/jobs/{id}/stage` | `update_build_stage` (worker-token, not client-called) |
| POST | `/workers/jobs/{id}/complete` | `complete_build` (worker-token) |

**artifacts**
| Method | Path | Handler |
|---|---|---|
| GET | `/artifacts` | `list_artifacts` |
| GET | `/artifacts/{id}` | `retrieve_artifact` |
| GET | `/artifacts/{id}/download` | `download_artifact` |
| POST | `/workers/jobs/{id}/artifact` | `register_artifact` (worker-token) |

**releases**
| Method | Path | Handler |
|---|---|---|
| GET | `/releases` | `list_releases` |
| POST | `/releases` | `create_release` |
| GET | `/releases/{id}` | `retrieve_release` |
| PATCH | `/releases/{id}` | `update_release` |
| POST | `/releases/{id}/approve` | `approve_release` |
| POST | `/releases/{id}/rollback` | `rollback_release` |

**deployments** (mobile / Shorebird OTA)
| Method | Path | Handler |
|---|---|---|
| GET | `/deployments` | `list_deployments` |
| POST | `/deployments` | `create_deployment` |
| GET | `/deployments/{id}` | `retrieve_deployment` |
| POST | `/deployments/{id}/rollback` | `rollback_deployment` |

**webhosting** (Flutter Web)
| Method | Path | Handler |
|---|---|---|
| GET | `/webhosting/deployments` | `list_web_deployments` |
| POST | `/webhosting/deployments` | `deploy_web` |
| GET | `/webhosting/deployments/{id}` | `retrieve_web_deployment` |
| POST | `/webhosting/deployments/{id}/rollback` | `rollback_web_deployment` |
| GET | `/webhosting/domains` | `list_custom_domains` |
| POST | `/webhosting/domains` | `create_custom_domain` |
| GET | `/webhosting/domains/{id}` | `retrieve_custom_domain` |
| POST | `/webhosting/domains/{id}/verify` | `verify_custom_domain` — checks DNS records against `required_records` (§21 contracts) and advances `certificate_status` |
| DELETE | `/webhosting/domains/{id}` | `delete_custom_domain` |

**workflows**
| Method | Path | Handler |
|---|---|---|
| GET | `/workflows` | `list_workflows` |
| POST | `/workflows` | `create_workflow` |
| GET | `/workflows/{id}` | `retrieve_workflow` |
| GET | `/workflows/{id}/runs` | `list_workflow_runs` |
| POST | `/workflows/{id}/runs` | `create_workflow_run` |
| GET | `/workflows/runs/{id}` | `retrieve_workflow_run` |
| POST | `/workflows/runs/{id}/approve` | `approve_workflow_run` |

**observability**
| Method | Path | Handler |
|---|---|---|
| GET | `/observability/apps/{id}/status` | `app_status` |
| GET | `/observability/apps/{id}/health` | `app_health` |
| GET | `/observability/releases/{id}/health` | `release_health` |

**events**
| Method | Path | Handler |
|---|---|---|
| GET | `/events` | `list_events` (cursor-paginated) |
| GET | `/events/{id}` | `retrieve_event` |
| GET | `/events/stream` | `stream_events` — Server-Sent Events, see §21.4 |

**billing**
| Method | Path | Handler |
|---|---|---|
| GET | `/billing/plans` | `list_plans` |
| GET | `/billing/subscription` | `current_subscription` |
| POST | `/billing/subscribe` | `create_subscription` |
| POST | `/billing/cancel` | `cancel_subscription` |
| GET | `/billing/invoices` | `list_invoices` |
| GET | `/billing/usage` | `usage_summary` |
| POST | `/webhooks/bachs` | `handle_bachs_webhook` (inbound) |
| POST | `/webhooks/paystack` | `handle_paystack_webhook` (inbound) |

**marketplace** (templates, purchases, reviews, seller payouts)
| Method | Path | Handler |
|---|---|---|
| GET | `/marketplace/templates` | `list_marketplace_templates` — public, no auth |
| GET | `/marketplace/templates/{id}` | `retrieve_marketplace_template` — public |
| GET | `/marketplace/templates/{id}/versions/{version_id}` | `retrieve_marketplace_template_version` — public |
| GET | `/templates` | `list_templates` — organization's own templates |
| POST | `/templates` | `create_template` |
| GET | `/templates/{id}` | `retrieve_template` |
| PATCH | `/templates/{id}` | `update_template` |
| DELETE | `/templates/{id}` | `delete_template` |
| POST | `/templates/{id}/publish` | `publish_template` |
| POST | `/templates/{id}/archive` | `archive_template` |
| POST | `/templates/{id}/feature` | `feature_template` |
| GET | `/templates/{id}/versions` | `list_template_versions` |
| POST | `/templates/{id}/versions` | `create_template_version` |
| GET | `/templates/{id}/download` | `download_template` — latest version |
| GET | `/templates/{id}/versions/{version_id}/download` | `download_template_version` — a specific version |
| POST | `/templates/{id}/purchase` | `purchase_template` |
| POST | `/templates/{id}/install` | `record_template_install` |
| GET | `/templates/{id}/reviews` | `list_template_reviews` |
| POST | `/templates/{id}/reviews` | `create_or_update_template_review` — same handler creates or updates the caller's own review |
| GET | `/marketplace/reviews/{id}` | `retrieve_template_review` |
| PATCH | `/marketplace/reviews/{id}` | `update_template_review` |
| DELETE | `/marketplace/reviews/{id}` | `delete_template_review` |
| POST | `/marketplace/reviews/{id}/reply` | `author_reply_template_review` — template author replies to a review |
| POST | `/marketplace/reviews/{id}/report` | `report_template_review` — flag a review for moderation |
| POST | `/marketplace/reviews/{id}/moderate` | `moderate_template_review` — staff-only, resolves a report |
| GET | `/marketplace/purchases` | `list_purchases` — cursor-paginated |
| GET | `/marketplace/purchases/{id}` | `retrieve_purchase` |
| POST | `/marketplace/purchases/{id}/refund` | `refund_purchase` |
| GET | `/marketplace/seller/account` | `retrieve_seller_account` |
| POST | `/marketplace/seller/onboarding` | `create_seller_onboarding` |
| POST | `/marketplace/seller/refresh` | `refresh_seller_status` |

**emails** (notification preferences + admin campaigns — staff-only for admin routes)
| Method | Path | Handler |
|---|---|---|
| GET | `/notifications/preferences` | `list_preferences` |
| PATCH | `/notifications/preferences` | `update_preferences` |
| POST | `/notifications/unsubscribe` | `unsubscribe` — token-authenticated, no session |
| GET | `/organizations/{id}/email-log` | `list_email_logs` — admin role |
| GET | `/admin/campaigns` | `list_campaigns` — staff only |
| POST | `/admin/campaigns` | `create_campaign` — staff only |
| PATCH | `/admin/campaigns/{id}` | `update_campaign` — staff only |
| GET | `/admin/campaigns/{id}/stats` | `campaign_stats` — staff only |
| POST | `/admin/campaigns/{id}/preview` | `preview_campaign` — staff only |

The `emails` admin routes are an internal ops surface, not customer-facing — do not build them into the org-scoped console; if they need a UI at all, it's a separate staff-only tool.

### 21.2 Envelopes every response follows

Three shapes, framework-level, identical across every app — write one Zod schema for each and reuse:

**Page-number list envelope** (`PageNumberPagination`, the default):
```json
{ "count": 142, "page": 1, "total_pages": 8, "results": [ /* T[] */ ] }
```

**Cursor list envelope** (`events`, `marketplace/purchases`, and any endpoint documented as cursor-paginated — no `count`, deliberately, since a cursor query never issues a COUNT):
```json
{ "count": null, "results": [ /* T[] */ ], "next_cursor": "opaque-string-or-null", "previous_cursor": null }
```

**Error envelope** (every non-2xx response, framework-wide):
```json
{ "error": { "status": 403, "code": "insufficient_role", "message": "...", "details": { "field": ["reason"] } } }
```
`details` is omitted entirely (not `null`) when absent — the Zod schema for it must be `.optional()`, not `.nullable()`.

Every detail/create/update response is the bare resource object (`ReleaseResponse`, `AppResponse`, etc.) — never wrapped.

### 21.3 Cross-cutting conventions (apply to every schema you write)

- **Every ID on the wire is a UUID string**, never the internal integer primary key. `AppResponse.id`, `AppResponse.project_id`, `AppResponse.organization_id` — all UUID strings. There is no numeric ID anywhere in a response body.
- **Money is always an integer in minor units** (`price_minor`, `amount_cents`, `amount`, `platform_fee`, `seller_amount`). Never render or submit a float for money. Divide by 100 (or the currency's minor-unit factor) only at the last formatting step, and do it with integer-safe arithmetic, not `parseFloat`.
- **Timestamps are RFC3339 strings** in most apps (`created_at: String`) but **typed `DateTime<Utc>`/`NaiveDate` in billing, emails, and the newer apps** — both serialize to the same ISO 8601 wire format, so one `z.string().datetime()` (or a shared `z.coerce.date()`) schema covers both; the Rust-side type difference is invisible on the wire.
- **`Option<T>` fields are `null`, not absent**, when empty — schemas should be `.nullable()` for these, not `.optional()`, unless the field is genuinely request-only-and-omittable (check the request contracts above for which apply).
- **Tagged unions on the wire**: `CredentialMetadata` and `SigningIdentityMetadata` are Rust enums serialized with an internal tag field (`"provider"` and `"kind"` respectively — see the field tables below). Model these as Zod discriminated unions keyed on that tag, not as a loose `Record<string, unknown>`.

**`CredentialMetadata`** (tag field: `provider`)
| Variant | Fields |
|---|---|
| `apple` | `key_id`, `issuer_id`, `team_id` |
| `google_play` | `client_email` |
| `shorebird` | `app_id` |
| `github` | `installation_id` |
| `gitlab` | `application_id` |
| `bitbucket` | `workspace` |

**`SigningIdentityMetadata`** (tag field: `kind`)
| Variant | Fields |
|---|---|
| `keystore` | `alias` |
| `certificate` | `fingerprint` |
| `provisioning_profile` | `bundle_id`, `uuid` |
| `api_key` | `key_id`, `issuer_id`, `team_id` |

These two tagged unions should drive the `<CredentialCard>` and signing-identity upload form directly — the variant list above is exhaustive; there is no "other" case.

### 21.4 Real-time: the actual SSE contract

`GET /events/stream` requires a valid bearer token and an active organization *before* the connection opens — auth happens before the Redis subscription, not after, so a 401 here means the token expired mid-session and the client must re-auth, not retry the stream. The backend sends a heartbeat frame on an interval (see `HEARTBEAT_INTERVAL_SECS` in `src/apps/events/views.rs`) in addition to real event frames, so a client that only listens for named events and treats any message as "connection alive" will work without extra plumbing. Each event frame's `data` is one `EventResponse` JSON object (§21.1's `events` app shape): `{ event_type, organization_id, project_id, app_id, actor_id, payload, created_at }`. Drive TanStack Query cache invalidation off `event_type` (e.g. `build.completed` invalidates the build-detail and build-list query keys for that `app_id`).

### 21.5 Auth and role model (ground truth for §6.2 and the sidebar/permission gating in §7)

- Roles, in ascending order, as an actual Rust enum with explicit ordinal values (so role comparisons in the UI should mirror this ordering, not alphabetize it): `Viewer` (1) → `Developer` (2) → `ReleaseManager` (3) → `Admin` (4) → `Owner` (5).
- Every mutating route is gated to a *minimum* role; the dashboard should hide (not just disable) actions the current user's role can't reach — e.g. hide "Cancel build" entirely for a Viewer, since the API will 403 regardless, and there's no reason to show an action that only produces an error.
- Auth throttle rates, worth surfacing in the login/register UI as real constraints (e.g. "too many attempts, try again in a minute") rather than a generic error: register 5/min, login 10/min, refresh 20/min, device-flow poll 60/min.
- The device-code flow (`POST /auth/device` → poll `GET /auth/device/token`) exists for the CLI, not the web dashboard — the dashboard's own login is the plain `POST /auth/login` username/password flow from §6.2. Don't build device-flow UI into the dashboard; it belongs to `bloom` CLI docs, not this app.

### 21.6 Gaps this backend has today — build the UI to degrade gracefully around them, not to hide them

- **Billing webhooks are the only path that advances a subscription.** There is no "confirm payment" client action — after `POST /billing/subscribe` returns an `authorization_url`, the dashboard's job is to redirect the user there and then poll or wait on the SSE stream for a `billing.subscription.activated` event; it cannot mark the subscription active itself.
- **`emails` admin campaigns are staff-only** and out of scope for the customer-facing console (§21.1).
- **Worker-token routes** (`/workers/jobs/{id}/*`) are never called by this dashboard — they're the build/deploy workers reporting status back to the API. Do not build a UI affordance that calls them.
