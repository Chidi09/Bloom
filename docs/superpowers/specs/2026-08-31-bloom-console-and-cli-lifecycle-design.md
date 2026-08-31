# Bloom Console And CLI Lifecycle Design

## Goal

Give Bloom a recognizable administrative identity and make project setup, local Docker development, and production deployment discoverable from one CLI workflow.

## Bloom Console

`bloom_admin` becomes Bloom Console by default while retaining server-rendered HTML and existing customization APIs. `BloomSiteBranding` supplies an inline Bloom SVG mark, `Bloom Console` naming, and seed-to-canopy color tokens unless applications override logo, title, or accent color.

The base layout uses CSS custom properties, responsive side navigation, card-backed data grids, status chips, and clear primary actions. It remains JavaScript-free and preserves the existing CRUD, CSRF, and form contracts.

## CLI Lifecycle

`bloom deploy` is the deployment entry point. `bloom deploy init` detects Flutter, JS Native, server, and hybrid applications; `bloom deploy docker` generates a reviewed bundle of a production multi-stage Dockerfile, `.dockerignore`, Compose configuration for local development, environment template, and health checks. `--production-only` omits Compose.

Flutter builds a web artifact served by a minimal runtime image. JS Native builds the web bundle with an optional SSR server profile. Bloom server builds and runs the Dart server with health checks. Hybrid applications produce separate Compose services sharing dependency profiles.

`bloom doctor` validates Docker, required environment values, ports, build dependencies, and target-specific deployment prerequisites. Commands consistently support non-interactive CI flags and actionable diagnostics.

## Constraints

- Preserve existing public admin APIs where possible.
- Generated deployment files must not embed secrets.
- Docker output must be target-specific and reproducible.
- Compose is the default local-development output; production-only is explicit.
- Generated artifacts must have regression tests for every target.
