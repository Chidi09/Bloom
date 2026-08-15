# Bloom Cloud Backend — Documentation Index

This directory contains the complete specification for the Bloom Cloud control-plane backend and its supporting plans.

## Start here

1. [`README.md`](../README.md) — what this is, stack, verification commands.
2. [`AI-AGENT-PRINCIPLES.md`](AI-AGENT-PRINCIPLES.md) — rules every agent must follow before writing code.
3. [`APP_PATTERN.md`](APP_PATTERN.md) — required file layout and dependency flow for every domain app.
4. [`DESIGN-SPEC.md`](DESIGN-SPEC.md) — master architecture, data model, and product scope.
5. [`PHASES.md`](PHASES.md) — ordered phase-by-phase implementation and exit gates.

## Cross-cutting docs

- [`infrastructure.md`](infrastructure.md) — storage, queue, events, crypto, worker auth, typed settings, dual backend.
- [`events.md`](events.md) — canonical event catalog.

## Domain apps

| App | Spec | Purpose |
|-----|------|---------|
| accounts | [`apps/accounts.md`](apps/accounts.md) | Golden app: auth, device flow, API tokens, me |
| organizations | [`apps/organizations.md`](apps/organizations.md) | Orgs, memberships, invites, org scoping |
| projects | [`apps/projects.md`](apps/projects.md) | Projects within org |
| apps | [`apps/apps.md`](apps/apps.md) | Applications within project |
| environments | [`apps/environments.md`](apps/environments.md) | Environments, API config, build defaults |
| builds | [`apps/builds.md`](apps/builds.md) | Build records, stages, logs |
| artifacts | [`apps/artifacts.md`](apps/artifacts.md) | Artifact metadata and download URLs |
| releases | [`apps/releases.md`](apps/releases.md) | Release lifecycle, approval, rollback |
| deployments | [`apps/deployments.md`](apps/deployments.md) | Deploy records and status |
| secrets | [`apps/secrets.md`](apps/secrets.md) | Encrypted per-environment secrets |
| signing | [`apps/signing.md`](apps/signing.md) | Signing identity vault |
| credentials | [`apps/credentials.md`](apps/credentials.md) | Platform API credentials |
| git_connections | [`apps/git_connections.md`](apps/git_connections.md) | Git provider connections and webhooks |
| webhosting | [`apps/webhosting.md`](apps/webhosting.md) | Flutter Web hosting deployments |
| observability | [`apps/observability.md`](apps/observability.md) | Release health and metrics |
| workers | [`apps/workers.md`](apps/workers.md) | Internal worker API surface |
| billing | [`apps/billing.md`](apps/billing.md) | Plans, subscriptions, usage, invoices (Phase 7) |

## Platform integrations

- [`integrations/testflight.md`](integrations/testflight.md) — Apple TestFlight / App Store Connect.
- [`integrations/google-play.md`](integrations/google-play.md) — Google Play Developer API.
- [`integrations/shorebird.md`](integrations/shorebird.md) — Shorebird OTA releases and patches.
- [`integrations/github.md`](integrations/github.md) — GitHub / GitLab / Bitbucket webhooks.

## Frontend

The dashboard frontend specification is at [`cloud-dashboard-frontend.md`](../../cloud-dashboard-frontend.md), at the repository root.

## Implementation order

Follow [`PHASES.md`](PHASES.md). Do not skip phases. Every phase has exit gates that must pass before starting the next.
