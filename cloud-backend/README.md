# Bloom Cloud Backend

Djangors-based control-plane backend for `bloomcloud.dev`.

This directory contains the source-of-truth plans and specifications for building the Bloom Cloud backend in Rust with the [Djangors](https://djangors.vercel.app/) framework. The implementation lives in a separate Cargo workspace (to be scaffolded at `cloud-backend/src`); these documents are the unbreakable guide for that work.

## What Bloom Cloud is

Bloom Cloud is the deployment, release, and operational control plane for Bloom applications. It is **not** a beta-distribution platform. It orchestrates builds, artifacts, releases, and deployments through Apple App Store Connect / TestFlight, Google Play, Shorebird, and Bloom-owned web hosting.

```text
                     Bloom Cloud
                          │
             ┌────────────┼────────────┐
             │            │            │
          Build         Release      Monitor
             │            │            │
             └────────────┼────────────┘
                          │
              ┌───────────┴───────────┐
              │                       │
        Apple App Store          Google Play
              │                       │
          TestFlight            Testing Tracks
```

## Documents

All specifications live in [`docs/`](docs/).

| Document | Purpose |
|----------|---------|
| [`AI-AGENT-PRINCIPLES.md`](docs/AI-AGENT-PRINCIPLES.md) | Rules every agent must follow before writing code |
| [`APP_PATTERN.md`](docs/APP_PATTERN.md) | Required file layout and dependency flow for every domain app |
| [`DESIGN-SPEC.md`](docs/DESIGN-SPEC.md) | Master architecture, data model, and product scope |
| [`PHASES.md`](docs/PHASES.md) | Phase-by-phase implementation order and exit gates (phases 0-8) |
| [`PHASES-FINAL.md`](docs/PHASES-FINAL.md) | Phases 9-15: execution layer, communication, hardening |
| [`infrastructure.md`](docs/infrastructure.md) | Runtime, workers, storage, queues, events, settings, dual backend |
| [`events.md`](docs/events.md) | Canonical event catalog |
| [`GOLDEN_APP.md`](docs/GOLDEN_APP.md) | Reference app walkthrough |
| [`SUMMARY.md`](docs/SUMMARY.md) | Index of every specification document |
| [`apps/*.md`](docs/apps/) | Per-domain app specifications |
| [`integrations/*.md`](docs/integrations/) | External-platform integration specifications |

## Frontend scope

The dashboard frontend specification is in [`cloud-dashboard-frontend.md`](../cloud-dashboard-frontend.md) at the repo root. It covers Next.js, Bun, Zod, Zustand, TanStack, shadcn/ui themed with the Bloom marketing design system, and the full page-by-page feature scope.

## Tech stack

- **Framework**: [Djangors](https://djangors.vercel.app/) `=0.7.0` (Rust)
- **Database**: PostgreSQL 16
- **Cache / queue broker**: Redis 7
- **Object storage**: Cloudflare R2 or S3-compatible
- **Build workers**: disposable Docker containers running Flutter/Dart/Bloom toolchains
- **Identity**: Djangors auth + JWT for CLI, session + JWT for dashboard

## Verification commands (run before every commit)

```bash
cargo fmt --check
cargo check --all-targets
cargo clippy --all-targets -- -D warnings
cargo test
```

## Status

Pre-implementation. These plans are the source of truth for Phase 0 scaffolding through Phase 6 full pipeline.
