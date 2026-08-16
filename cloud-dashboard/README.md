# Bloom Cloud Dashboard

Next.js console for Bloom Cloud. Read `/root/dev/Bloom/cloud-dashboard-frontend.md` before
writing any screen — it is the single source of truth for stack, routes, data shapes, visual
direction (§22), and the screen-by-screen spec (§22.4). Do not invent API shapes; every
endpoint, envelope, and field is documented there against the real backend
(`/root/dev/Bloom/cloud-backend`).

## Stack

Next.js (App Router) + Bun + TypeScript + Tailwind v4 + shadcn/ui (`base-mira` preset,
base-ui primitives — not Radix, see `components.json`) + Phosphor icons + TanStack
(Query/Table/Form) + Zustand + Zod + `nuqs`.

## Commands

```bash
bun install
bun run dev
bun run build
bun run lint
bun run typecheck
bun run format        # bun run format:check in CI
bun test               # unit + integration (tests/unit, tests/integration)
bun run test:e2e        # Playwright (tests/e2e)
```

`bun run build`'s underlying `next build` succeeds even though the Bun 1.3.14 process itself
segfaults on exit afterward (a Bun bug, not ours) — check `.next/BUILD_ID` exists rather than
trusting the exit code alone if this trips a CI check.

## Environment

Copy `.env.example` to `.env.local`. `NEXT_PUBLIC_API_URL` is the backend **origin only**
(e.g. `http://localhost:8000`) — the BFF proxy route appends `/api/v1` itself, not the client.

Set `NEXT_PUBLIC_API_MOCKING=enabled` to build/demo screens against MSW instead of a live
backend (`src/mocks/`) — useful right now since backend creds/env for live testing are
deferred (S5). Add a handler per endpoint in `src/mocks/handlers.ts` as you build each screen.

## BFF

The browser never calls the backend origin directly — `src/lib/api/client.ts` calls
`/api/bff/*` (this app's own origin), which `src/app/api/bff/[...path]/route.ts` proxies to
the real backend server-side. This keeps refresh-token cookies first-party across the
`console.*` / `api.*` subdomain split. See spec §6.6 for the full rationale. SSE
(`/events/stream`) is the one exception — it connects to the backend origin directly, not
through this proxy (`EventSource` can't stream through a buffering Route Handler well).

## Structure

```text
src/
├── app/                # routes — (dashboard) group for authenticated screens, auth/ for login
├── components/
│   ├── ui/              # shadcn primitives only — do not hand-edit without reason
│   ├── shared/           # shell: navbar, sidebar, command palette
│   ├── data/              # table wrappers, filters
│   ├── forms/              # reusable form fields
│   ├── status/              # StatusBadge, PlatformIcon, timelines
│   └── charts/               # shadcn chart.tsx wrappers
├── lib/
│   ├── api/               # client.ts, query-keys.ts, envelopes.ts, errors.ts
│   ├── auth/                # roles.ts — OrganizationRole ordinals, hasRole()
│   ├── hooks/                 # use-organization-events.ts (SSE), etc.
│   └── schemas/                # Zod schemas per resource
├── stores/                      # Zustand — auth (in-memory only), organization, ui
├── providers/                    # theme, query, and combined AppProviders
├── mocks/                         # MSW handlers + browser/node setup, msw-provider.tsx
└── app/api/bff/[...path]/          # same-origin proxy Route Handler to the backend
```

## Ground rules for dispatched work

- Screens are composed **only** from installed shadcn primitives (`src/components/ui`). A
  screen needing something not in that list is a named exception — get it approved first,
  see spec §22 for the standing exceptions already agreed (log viewer, pipeline visualizer).
- Every list/detail screen implements all 5 states from spec §22.2: loading (skeleton),
  empty (actionable), error (scoped, retryable), success (toast), pending/warning (badge).
- Role-gated actions are hard-hidden, never disabled — `hasRole()` from `lib/auth/roles.ts`.
- AMOLED dark is the primary design target (`.dark` in `src/app/globals.css`), light mode
  must still work via the same tokens — never hardcode a color in a component.
- IDs on the wire are UUID strings, money is integer minor units, timestamps are ISO 8601 —
  spec §21.3. Don't guess a field name; check the route inventory (§21.1) first.
