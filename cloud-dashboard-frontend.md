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

Base URL from `process.env.NEXT_PUBLIC_API_URL`.

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
2. **Tokens** — access token JWT (short, in-memory), refresh token httpOnly cookie.
3. **Refresh** — on 401, call `/api/v1/auth/refresh`. If refresh fails, redirect to login.
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
