# DESIGN SPEC — Bloom Cloud Backend

**The unbreakable guide for building the Bloom Cloud control plane.**

Last updated: 2026-08-14 · Status: source of truth for Phases 0 → 6.

Rules that govern every phase: backend is Djangors `=0.7.0`; no internal `i64` key crosses the API boundary; every write path emits an event; every organization-scoped model is `Scoped`; money (billing) is integer cents; every module ships tests and passes `cargo fmt --check`, `cargo check`, `cargo clippy --all-targets -- -D warnings`, and `cargo test`.

---

## 0. Where the system stands and where it is going

Bloom is split into three products:

```text
                    BLOOM
                      │
       ┌──────────────┼──────────────┐
       │              │              │
   Bloom Framework  Bloom Cloud    Bloom UI
       │              │              │
    Build Apps      Ship Apps      Design Apps
       │              │              │
       └──────────────┼──────────────┘
                      │
                 Bloom Ecosystem
```

Bloom Cloud (`bloomcloud.dev`) is the **deployment, release, and operational control plane** for Bloom applications. It is not a generic hosting provider, not a replacement for TestFlight, and not a competing OTA engine. It is the orchestration layer that connects `bloom deploy` to the actual distribution surfaces: Apple TestFlight/App Store, Google Play testing tracks/production, Shorebird patches, and Bloom-owned Flutter Web hosting.

### 0.1 Important distinction: Bloom Cloud is not TestFlight

Bloom Cloud **integrates** TestFlight, Google Play, and Shorebird rather than replacing them.

For iOS:

```text
Bloom CLI / Dashboard
        ↓
Bloom Cloud
        ↓
Build IPA
        ↓
Upload via Transporter / App Store Connect API
        ↓
App Store Connect processing
        ↓
TestFlight
        ↓
Developer's testers
```

For Android:

```text
Bloom CLI / Dashboard
        ↓
Bloom Cloud
        ↓
Build AAB/APK
        ↓
Google Play Developer API
        ↓
Internal / Closed / Open / Production testing
        ↓
Developer's testers
```

For Web, Bloom Cloud actually owns the infrastructure:

```text
Bloom CLI / Dashboard
        ↓
Bloom Cloud
        ↓
Build Flutter Web bundle
        ↓
CDN / Edge
        ↓
Custom domain
```

### 0.2 Developer experience target

```bash
# Local development
bloom create my_app
bloom dev
bloom build ios
bloom build android
bloom build web

# Connect to Cloud
bloom login
bloom cloud project link
bloom cloud deploy --platform ios --target testflight
bloom cloud deploy --platform android --target closed
bloom cloud deploy --platform web --target production

# Release operations
bloom release
bloom patch
bloom cloud releases
bloom cloud logs
bloom cloud status
```

The Bloom Cloud backend is the API and orchestration that makes every command above work.

---

## 1. Architecture overview

```text
                   bloomcloud.dev
                         │
                 ┌───────▼────────┐
                 │   Djangors API │
                 │   Rust Backend │
                 │   (control plane) │
                 └───────┬────────┘
                         │
              ┌──────────┼───────────┐
              │          │           │
           Postgres     Redis      Object Storage
              │          │           │
              └──────────┼───────────┘
                         │
                  Job / Event Queue
                         │
             ┌───────────┼───────────┐
             │           │           │
        Build Worker   Deploy Worker  Web Worker
             │           │           │
        Flutter SDK     Apple         CDN
        Dart SDK        Google Play   Edge
        Bloom CLI       Shorebird
```

The **Djangors API** is the control plane. It does **not** run arbitrary Flutter builds. It creates job records, stores metadata, talks to platform APIs, and pushes events.

**Build workers** are disposable containers that check out source, provision the toolchain, run `bloom build`, and upload artifacts.

**Deploy workers** are disposable containers that take an artifact and a target configuration and push to the appropriate platform (App Store Connect, Google Play, Shorebird, CDN).

**Web workers** serve the dashboard, static marketing pages, and API documentation.

### 1.1 Core constraints

- The API never stores platform credentials in plain text. They are encrypted at rest (AES-256-GCM) and only workers decrypt them at runtime via a short-lived token.
- Build workers are isolated per job. No shared state between builds.
- Every mutation is auditable: `AuditLog` records who, what, when, and the before/after snapshot for sensitive fields.
- Every state change emits an event to Redis streams; dashboard and workers consume the same stream.
- The API is the single source of truth for release metadata. TestFlight, Google Play, and Shorebird are authoritative only for their own platform state.

### 1.2 Technology stack

| Layer | Technology |
|-------|--------------|
| API framework | Djangors `=0.7.0` |
| Database | PostgreSQL 16 (production), SQLite supported for local dev/tests via dual-backend |
| Cache / events / queue | Redis 7 (streams + pub/sub) |
| Background side effects | `djangors-tasks` (`#[task]`, `enqueue`, `Worker`, recurring cron) |
| Object storage | Cloudflare R2 / S3-compatible |
| Container runtime | Docker + Docker Compose (local) / Kubernetes (production) |
| Build worker | Disposable Ubuntu container with Flutter, Dart, Bloom CLI, Shorebird CLI, Transporter, fastlane (optional) |
| Deploy worker | Disposable container with platform-specific tools |
| Web dashboard | Bloom website (Next.js) calling the API |
| CLI authentication | JWT + API tokens |
| Typed config | `#[derive(Settings)]` from `djangors-macros` |

### 1.3 Repository layout

```text
bloom-cloud-backend/
├── Cargo.toml
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── djangors.toml
├── src/
│   ├── main.rs
│   ├── settings.rs
│   ├── urls.rs
│   ├── migrations.rs
│   ├── apps/
│   │   ├── mod.rs
│   │   ├── accounts/
│   │   ├── organizations/
│   │   ├── projects/
│   │   ├── apps/
│   │   ├── environments/
│   │   ├── builds/
│   │   ├── artifacts/
│   │   ├── releases/
│   │   ├── deployments/
│   │   ├── secrets/
│   │   ├── signing/
│   │   ├── credentials/
│   │   ├── git_connections/
│   │   ├── workflows/
│   │   ├── webhosting/
│   │   ├── observability/
│   │   ├── billing/
│   │   └── common/
│   ├── workers/
│   │   ├── build.rs
│   │   ├── deploy.rs
│   │   └── webhook.rs
│   └── infra/
│       ├── storage.rs
│       ├── queue.rs
│       ├── events.rs
│       └── crypto.rs
├── migrations/
│   └── <app>/NNNN_<app>.sql
└── tests/
    └── apps/
        └── <app>/
```

---

## 2. Domain model

### 2.1 Entity hierarchy

```text
Organization
├── Members (UserOrganizationMembership)
├── Projects
│   └── Apps
│       ├── Environments
│       ├── Builds
│       ├── Artifacts
│       ├── Releases
│       └── Deployments
├── Credentials (Apple, Google Play, Shorebird, GitHub, etc.)
├── Secrets (per-environment)
├── Signing identities
├── Git connections
├── Workflows
└── AuditLog
```

### 2.2 Core entities

#### Organization

Represents a billing and membership boundary. A user can belong to multiple organizations.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID, exposed as `"id"` |
| name | String | max 255 |
| slug | String | unique, URL-safe |
| plan | String | `free` / `pro` / `enterprise` (billing) |
| created_at | DateTime<Utc> | auto_now_add |
| updated_at | DateTime<Utc> | auto_now |

#### UserOrganizationMembership

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| user_id | ForeignKey<User> | internal Djangors auth user |
| organization_id | ForeignKey<Organization> | |
| role | String | `owner` / `admin` / `developer` / `release_manager` / `viewer` |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

Unique together: `(user_id, organization_id)`.

#### Project

A project groups applications. Usually one project per product (e.g., "My SaaS").

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| name | String | |
| slug | String | unique per organization |
| description | String | optional |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

Unique together: `(organization_id, slug)`.

#### App

Represents a Bloom application within a project. One app has multiple platforms and environments.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| project_id | ForeignKey<Project> | |
| name | String | |
| slug | String | unique per project |
| repository_url | String | optional Git URL |
| default_branch | String | default `main` |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

Unique together: `(project_id, slug)`.

#### Environment

An environment holds configuration, secrets, and deployment targets. Common: `development`, `staging`, `production`.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| name | String | e.g. `production` |
| slug | String | unique per app |
| api_config | Json | typed environment variables and feature flags |
| build_profile | String | `debug` / `profile` / `release` |
| flutter_version | String | optional pinned Flutter version |
| dart_version | String | optional pinned Dart version |
| bloom_version | String | optional pinned Bloom CLI version |
| flavor | String | optional |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

Unique together: `(app_id, slug)`.

#### Build

A single execution of the build pipeline.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| environment_id | ForeignKey<Environment> | |
| git_commit | String | SHA |
| git_branch | String | |
| git_ref | String | tag or ref |
| status | String | `pending` / `queued` / `running` / `success` / `failed` / `cancelled` |
| platform | String | `android` / `ios` / `web` / `all` |
| build_profile | String | |
| flutter_version | String | |
| dart_version | String | |
| bloom_version | String | |
| flavor | String | optional |
| started_at | Option<DateTime<Utc>> | |
| finished_at | Option<DateTime<Utc>> | |
| logs_url | String | optional object-storage URL |
| metadata | Json | worker reports, durations, warnings |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

#### Artifact

An output of a build: IPA, AAB, APK, web bundle, source maps, dSYM, mapping.txt, etc.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| build_id | ForeignKey<Build> | |
| platform | String | `android` / `ios` / `web` |
| kind | String | `ipa` / `aab` / `apk` / `web_bundle` / `dsym` / `source_map` / `mapping` / `log` |
| storage_key | String | object-storage key |
| storage_bucket | String | |
| file_name | String | |
| file_size | i64 | bytes |
| checksum | String | sha256 |
| version | String | app version, e.g. `1.4.0` |
| build_number | i64 | integer build number |
| metadata | Json | extra platform metadata |
| created_at | DateTime<Utc> | |

Unique together is not required on `storage_key` because storage namespaces differ per environment, but we enforce it in repository code.

#### Release

A first-class release object: the thing that answers "what exactly is running in production?"

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| app_id | ForeignKey<App> | |
| version | String | semver, e.g. `1.4.0` |
| build_number | i64 | |
| commit | String | Git SHA |
| changelog | String | markdown |
| environment_id | ForeignKey<Environment> | optional, can be cross-environment later |
| status | String | `draft` / `pending_approval` / `approved` / `rolling_out` / `released` / `rolled_back` / `expired` |
| platforms | Json | `["ios", "android", "web"]` |
| artifacts | Json | list of artifact public_ids |
| rollout_status | Json | per-platform rollout state |
| created_by_id | ForeignKey<User> | |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

#### Deployment

A single push of an artifact/release to a platform target.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| release_id | ForeignKey<Release> | optional (build-only deployments possible) |
| artifact_id | ForeignKey<Artifact> | optional (when deploying a full release) |
| environment_id | ForeignKey<Environment> | |
| platform | String | `ios` / `android` / `web` |
| target | String | `testflight` / `app_store` / `internal` / `closed` / `open` / `production` / `preview` |
| status | String | `pending` / `queued` / `running` / `processing` / `ready` / `live` / `failed` / `rolled_back` |
| external_id | String | platform-specific ID, e.g. App Store Connect build ID |
| external_url | String | link to platform console |
| error_message | String | worker failure reason |
| started_at | Option<DateTime<Utc>> | |
| finished_at | Option<DateTime<Utc>> | |
| created_by_id | ForeignKey<User> | |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

### 2.3 Cross-cutting tables

#### Secret

Per-environment encrypted secrets.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| environment_id | ForeignKey<Environment> | |
| key | String | max 255 |
| encrypted_value | String | ciphertext |
| version | i64 | monotonic, for rollback |
| created_by_id | ForeignKey<User> | |
| created_at | DateTime<Utc> | |

Unique together: `(environment_id, key, version)` — or latest-version lookup by `(environment_id, key)` with a separate `is_latest` boolean. The spec uses the boolean approach for simplicity: unique `(environment_id, key)` plus `version` history in `SecretVersion`.

#### SecretVersion

History of secret changes.

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| secret_id | ForeignKey<Secret> | |
| encrypted_value | String | |
| version | i64 | |
| created_by_id | ForeignKey<User> | |
| created_at | DateTime<Utc> | |

#### SigningIdentity

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| platform | String | `android` / `ios` |
| name | String | |
| kind | String | `keystore` / `certificate` / `provisioning_profile` / `api_key` |
| encrypted_material | String | ciphertext |
| metadata | Json | fingerprints, bundle IDs, expiry, etc. |
| expires_at | Option<DateTime<Utc>> | |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

#### Credential

Platform API credentials (Apple App Store Connect, Google Play, Shorebird, GitHub).

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| provider | String | `apple` / `google_play` / `shorebird` / `github` / `gitlab` / `bitbucket` |
| name | String | human-readable label |
| encrypted_token | String | ciphertext |
| metadata | Json | non-secret metadata (key ID, team ID, issuer ID, etc.) |
| expires_at | Option<DateTime<Utc>> | |
| last_used_at | Option<DateTime<Utc>> | |
| created_by_id | ForeignKey<User> | |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

#### GitConnection

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| provider | String | `github` / `gitlab` / `bitbucket` |
| installation_id | String | external installation/app ID |
| encrypted_access_token | String | ciphertext |
| metadata | Json | org/repo permissions, account info |
| created_at | DateTime<Utc> | |
| updated_at | DateTime<Utc> | |

#### AuditLog

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | |
| user_id | Option<ForeignKey<User>> | system actions can be null |
| action | String | e.g. `deployment.created`, `secret.updated`, `member.invited` |
| target_type | String | model name |
| target_id | i64 | internal target id |
| target_public_id | String | UUID |
| before | Json | snapshot before |
| after | Json | snapshot after |
| ip_address | String | optional |
| user_agent | String | optional |
| created_at | DateTime<Utc> | |

---

## 3. Authentication & authorization

### 3.1 Authentication mechanisms

Bloom Cloud supports three authentication mechanisms in priority order (mirroring `djangors_rest::current_user`):

1. **Session cookie** — dashboard sessions.
2. **API token** — long-lived machine tokens for CI and integrations. `Authorization: Token <64-hex-key>`.
3. **JWT** — short-lived tokens for the Bloom CLI. `Authorization: Bearer <jwt>`.

CLI authentication flow:

```bash
bloom login
# Browser opens bloomcloud.dev/login/device or terminal prompts
# CLI polls /auth/device/token
# Receives JWT + refresh token
# Stores in ~/.bloom/credentials.json
```

### 3.2 Authorization model

Authorization is role-based at the organization level, with project-level overrides.

| Capability | Owner | Admin | Developer | Release Manager | Viewer |
|------------|-------|-------|-----------|-----------------|--------|
| View org/projects/apps | yes | yes | yes | yes | yes |
| Create/edit projects | yes | yes | no | no | no |
| Create/edit apps | yes | yes | yes | no | no |
| Create builds | yes | yes | yes | yes | no |
| Create non-prod deployments | yes | yes | yes | yes | no |
| Approve production deployments | yes | yes | no | yes | no |
| Manage secrets/signing | yes | yes | no | yes | no |
| Manage credentials | yes | yes | no | no | no |
| Manage members/billing | yes | no | no | no | no |
| Delete org | yes | no | no | no | no |

Permissions are implemented as Djangors `Permission` classes. Organization-level checks are in `permissions.rs`; project-level checks consult `UserProjectRole` when overrides are enabled (Phase 5).

### 3.3 Organization resolution

Every authenticated request must resolve an active organization. The middleware reads the header `X-Bloom-Organization-Id` (public UUID), validates membership, and stores `CurrentOrganizationId(i64)` in request extensions. All scoped endpoints filter by this id.

The dashboard stores the selected organization in local state and sends it on every request.

The CLI sends the organization id from the linked project context (`bloom cloud project link` writes `bloomcloud.organization_id` to the local `bloom.yaml`).

---

## 4. Build pipeline

### 4.1 Trigger sources

A build can be triggered by:

1. `bloom cloud build` from the CLI (manual).
2. Git push to a connected repository (via webhook).
3. Pull request open/update (for preview builds, web only initially).
4. Scheduled nightly build.
5. Workflow step (Phase 6).

### 4.2 Build pipeline stages

```text
Git repository
      ↓
Checkout
      ↓
Install Dart/Flutter/Bloom
      ↓
Resolve dependencies
      ↓
Bloom generation
      ↓
Bloom prebuild
      ↓
Tests
      ↓
Analyze
      ↓
Flutter build
      ↓
Artifact upload
      ↓
Build record → success / failed
```

### 4.3 Build matrix

Each build specifies a platform matrix. Initially we support one platform per build for simplicity; multi-platform builds are queued as separate jobs sharing the same `Build` parent.

Build matrix dimensions:

| Dimension | Values |
|-------------|--------|
| Platform | `android`, `ios`, `web` |
| Build profile | `debug`, `profile`, `release` |
| Flutter version | pinned or `latest` |
| Dart version | pinned or `latest` |
| Bloom version | pinned or `latest` |
| Environment | `development`, `staging`, `production` |
| Flavor | user-defined |

### 4.4 Worker job structure

The API creates a `BuildJob` and pushes it to Redis. A worker polls, claims the job with `SELECT ... FOR UPDATE SKIP LOCKED`, and runs the build. Stages are reported as events with `build.stage.{started,completed,failed}`.

---

## 5. Artifact storage

### 5.1 Stored objects

| Kind | Extension | Platform | Notes |
|------|-----------|----------|-------|
| IPA | `.ipa` | iOS | App Store / TestFlight |
| AAB | `.aab` | Android | Play Store |
| APK | `.apk` | Android | Sideload / internal dev |
| Web bundle | `.tar.gz` | Web | Static files |
| dSYM | `.dSYM.zip` | iOS | Crash symbolication |
| Android mapping | `mapping.txt` | Android | ProGuard/R8 |
| Source map | `.map` | Web | |
| Build log | `.log` | all | Worker stdout/stderr |

### 5.2 Storage keys

```text
orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/builds/{build_public_id}/artifacts/{artifact_public_id}/{filename}
```

All artifacts are private. Presigned URLs are generated on demand with a short expiry (15 minutes default). API responses never expose the raw storage URL.

---

## 6. Release model

A Release is a first-class object that groups artifacts and deployment state across platforms.

```text
Release
├── version
├── build_number
├── commit
├── environment
├── platforms
├── changelog
├── deployment status
├── artifacts
└── rollout status
```

Release lifecycle:

1. `draft` — created manually or from a successful build.
2. `pending_approval` — waiting for release manager approval (production).
3. `approved` — approved, ready for deployment.
4. `rolling_out` — one or more deployments in progress.
5. `released` — all requested deployments live.
6. `rolled_back` — previous release restored.
7. `expired` — build/artifacts expired.

Release approval is required for production deployments to App Store, Google Play Production, and Shorebird production patches. TestFlight and internal/closed testing can be auto-deployed by Developers and Release Managers depending on policy.

---

## 7. Deployment targets

### 7.1 iOS

| Target | Platform API | Notes |
|--------|--------------|-------|
| TestFlight | App Store Connect API + Transporter | Build uploaded, processed, then assigned to internal/external groups |
| App Store | App Store Connect API | Submitted for review or released directly after review |

Deployment flow for TestFlight:

```text
build IPA
   ↓
upload via Transporter (JWT auth)
   ↓
poll App Store Connect until processing complete
   ↓
assign internal testers group
   ↓
optionally assign external testers group
   ↓
notify team
```

### 7.2 Android

| Target | Platform API | Notes |
|--------|--------------|-------|
| Internal testing | Google Play Developer API | Fastest, no review |
| Closed testing | Google Play Developer API | Review may be required |
| Open testing | Google Play Developer API | Public testing track |
| Production | Google Play Developer API | Full release |

Deployment flow:

```text
build AAB/APK
   ↓
upload to Google Play (service-account auth)
   ↓
assign to track
   ↓
configure release (country rollout, staged rollout %)
   ↓
commit release
```

### 7.3 Web

Bloom Cloud owns web hosting:

```text
Build Flutter Web bundle
   ↓
Upload to object storage
   ↓
Deploy to CDN edge
   ↓
Assign preview URL or production custom domain
   ↓
Serve with HTTPS, redirects, headers, caching
```

Features:

- Preview URLs per branch/PR: `https://{branch}-{project}.bloomcloud.dev`
- Production custom domains with auto SSL
- Deployment history and rollback
- Immutable asset URLs with long cache headers
- Redirects and custom headers configured in `bloom.yaml`

### 7.4 Shorebird integration

Shorebird is a native integration, not a competing OTA system.

```text
Bloom Cloud
     ↓
Build
     ↓
Shorebird release
     ↓
Shorebird patch
     ↓
Bloom release record
```

Bloom CLI commands:

```bash
bloom release   # create a native binary release
bloom patch     # create a Dart patch if the change qualifies
bloom deploy    # Bloom decides native binary vs Dart patch
```

The worker invokes Shorebird CLI with the organization's Shorebird credentials. Patch eligibility is determined by the CLI; the Cloud records the Shorebird release/patch IDs and links them to the Bloom Release.

---

## 8. Secrets and signing

### 8.1 Secrets manager

Per-environment secrets are stored encrypted. Supported at launch:

- String key/value pairs
- JSON values (stored as encrypted string)

Secrets are injected into build workers via environment variables at build time. They are never logged, never returned in API responses, and only decrypted by workers with a short-lived job token.

### 8.2 Signing

#### Android

- Keystore (JKS or PKCS12)
- Key alias
- Passwords
- Play app signing integration (upload key vs signing key)

#### iOS

- Distribution certificates (P12)
- Provisioning profiles
- App Store Connect API keys (P8)
- Signing identities
- Bundle IDs
- Capabilities mapping

Signing materials are stored encrypted in `SigningIdentity`. Workers download them at build time and use them to sign the artifact.

---

## 9. Credentials vault

The credentials dashboard shows connected providers without ever displaying the secret again after initial entry:

```text
Credentials
──────────────────────
Apple
✓ Connected

Google Play
✓ Connected

Shorebird
✓ Connected

GitHub
✓ Connected
```

Each credential is encrypted at rest. The API returns only metadata: provider, name, last used, expiry. The secret is sent only to workers via a short-lived job token.

---

## 10. Git integration

First-class providers: GitHub, GitLab, Bitbucket.

Connected via OAuth app / GitHub App / GitLab application. After connection:

```text
git push
   ↓
Webhook → Bloom Cloud
   ↓
Create Build
   ↓
Test / Analyze / Build
   ↓
Deploy Preview (web) or Queue Release
```

Supported triggers:

- Push to branch
- Pull request open/update/merge
- Tag push
- Manual build

Webhook handlers are idempotent: deduplicated by delivery ID and payload signature verification.

---

## 11. CI/CD workflows

Phase 6 adds visual workflows. Phase 0-5 deployments are simpler but use the same underlying primitives.

Workflow target:

```text
Trigger
  ↓
Test
  ↓
Build
  ↓
Deploy Preview
  ↓
Approval
  ↓
Production
```

Workflow YAML (Phase 6):

```yaml
workflow:
  on:
    push:
      branches: [main]

  jobs:
    test:
      - bloom test
      - bloom analyze

    build:
      needs: test
      - bloom build android
      - bloom build ios
      - bloom build web

    deploy_preview:
      needs: build
      environment: staging
      platform: web
      target: preview

    deploy_production:
      needs: deploy_preview
      environment: production
      requires_approval: true
      platform: android
      target: production
      platform: ios
      target: testflight
```

Workflows are stored as `Workflow` records with a `definition: Json` column. Execution creates `WorkflowRun` and `WorkflowRunStep` records.

---

## 12. Web hosting

Bloom Cloud owns Flutter Web hosting end-to-end.

### 12.1 Hosting features

- Preview URLs per branch/PR
- Production URL (`https://{slug}.bloomcloud.dev` or custom domain)
- Custom domains with auto SSL
- Deployment history and rollback
- Redirects
- Custom headers
- Caching rules
- Analytics (Phase 5)

### 12.2 Deployment shape

A Flutter Web build produces a `build/web` directory. The deploy worker uploads it to the configured CDN origin (R2/S3) and invalidates the CDN cache. Each deployment gets a unique URL prefix for rollback.

---

## 13. Observability and release health

### 13.1 Health model

Every deployment becomes:

```text
Release
   ↓
Deployment
   ↓
Health
```

Example dashboard:

```text
Production
────────────────
v2.8.1     99.84% crash-free
v2.8.0     99.72%
v2.8.0b2   99.91% (TestFlight)
```

### 13.2 Data sources

At launch, observability is primarily metadata and platform APIs:

- TestFlight crash/sessions metrics from App Store Connect API
- Google Play crash statistics from Play Developer API
- Shorebird patch metrics
- Web analytics (basic page views, errors)

Full crash/performance telemetry from the app itself is Phase 6 and requires a Bloom SDK integration in the framework.

---

## 14. Events system

Every state change emits an event. Events are written to Redis streams and also stored in `EventLog` for replay/debugging.

### 14.1 Event categories

```text
build.started
build.completed
build.failed
build.cancelled

release.created
release.approved
release.deployed
release.rolled_back

deployment.started
deployment.processing   # platform-specific intermediate state
deployment.completed
deployment.failed
deployment.rolled_back

shorebird.release.created
shorebird.patch.created

testflight.processing
testflight.ready

google_play.processing
google_play.live

webhosting.deployed
webhosting.rolled_back

secret.updated
secret.rolled_back

member.invited
member.joined
member.role_changed
member.removed
```

### 14.2 Event payload

```json
{
  "event_id": "uuid",
  "event_type": "build.completed",
  "organization_id": "uuid",
  "project_id": "uuid",
  "app_id": "uuid",
  "actor_id": "uuid",
  "payload": { "build_id": "uuid", "status": "success" },
  "created_at": "2026-08-14T12:00:00Z"
}
```

---

## 15. Billing (outline)

Billing is not implemented in Phases 0-4. The schema is designed to support it later.

- `Plan` — free, pro, enterprise
- `Subscription` — organization 1:1
- `Invoice` — monthly, usage-based on build minutes, storage, bandwidth
- `UsageRecord` — metered events (build minutes, artifact storage GB, web bandwidth, deploy count)

Money is stored as integer cents. Never float.

---

## 16. API surface

All API routes are under `/api/v1/` unless otherwise specified.

### 16.1 Route prefixes by app

| App | Prefix | Description |
|-----|--------|-------------|
| accounts | `/api/v1/auth/` | login, logout, tokens, me, device flow |
| organizations | `/api/v1/organizations/` | CRUD, members, invites |
| projects | `/api/v1/projects/` | projects within org |
| apps | `/api/v1/apps/` | apps within project |
| environments | `/api/v1/environments/` | environments within app |
| builds | `/api/v1/builds/` | build records and logs |
| artifacts | `/api/v1/artifacts/` | artifact metadata and URLs |
| releases | `/api/v1/releases/` | release lifecycle |
| deployments | `/api/v1/deployments/` | deployment records |
| secrets | `/api/v1/secrets/` | per-environment secrets |
| signing | `/api/v1/signing/` | signing identities |
| credentials | `/api/v1/credentials/` | platform credentials |
| git_connections | `/api/v1/git-connections/` | Git provider connections |
| webhosting | `/api/v1/webhosting/` | web deployments, domains, previews |
| observability | `/api/v1/observability/` | health metrics, events |
| workflows | `/api/v1/workflows/` | CI/CD workflows (Phase 6) |
| billing | `/api/v1/billing/` | billing (Phase 7) |

### 16.2 Webhooks

External webhooks from Git providers and payment systems are under `/webhooks/<provider>/`:

- `/webhooks/github/`
- `/webhooks/gitlab/`
- `/webhooks/bitbucket/`
- `/webhooks/stripe/` (billing Phase 7)

Webhook endpoints are unauthenticated by route but verify signatures.

---

## 17. CLI contract

The Bloom CLI talks to the Cloud API. These are the backend endpoints required for CLI commands.

| CLI command | Method | Endpoint | Notes |
|-------------|--------|----------|-------|
| `bloom login` | POST | `/api/v1/auth/device/` | start device flow |
| | GET | `/api/v1/auth/device/token/` | poll token |
| `bloom cloud project link` | GET | `/api/v1/projects/` | list projects |
| | POST | `/api/v1/apps/link/` | link current directory to app |
| `bloom cloud deploy` | POST | `/api/v1/deployments/` | create deployment |
| `bloom cloud build` | POST | `/api/v1/builds/` | create build |
| `bloom cloud releases` | GET | `/api/v1/releases/` | list releases |
| `bloom cloud status` | GET | `/api/v1/apps/{id}/status/` | current status |
| `bloom cloud logs` | GET | `/api/v1/builds/{id}/logs/` | stream build logs |
| `bloom release` | POST | `/api/v1/releases/` | create release |
| `bloom patch` | POST | `/api/v1/releases/{id}/patch/` | create Shorebird patch |

---

## 18. Worker model

### 18.1 Build worker lifecycle

```text
Create worker
   ↓
Checkout source
   ↓
Provision toolchain (Docker image pre-baked)
   ↓
Inject secrets and signing
   ↓
Run Bloom build
   ↓
Upload artifacts
   ↓
Upload logs
   ↓
Report result
   ↓
Destroy worker
```

Workers are isolated. Each build job gets a fresh container with no access to previous builds. They authenticate to the API with a short-lived job token (TTL 24 hours or build duration + 1 hour, whichever is shorter).

### 18.2 Deploy worker lifecycle

```text
Claim deployment job
   ↓
Download artifact
   ↓
Decrypt platform credentials
   ↓
Invoke platform API / CLI
   ↓
Poll platform state
   ↓
Report deployment status
   ↓
Destroy worker
```

### 18.3 Background task side effects

Use `djangors-tasks` for non-build-queue side effects:

- `send_email` — invite emails, notifications, alerts.
- `process_webhook_async` — heavy or retryable webhook handling.
- `poll_platform_status` — periodic polling of TestFlight/Play/Shorebird status.
- `cleanup_expired_builds` — purge old artifacts and logs.
- `audit_log_snapshot` — long-running audit snapshot writes.

Tasks are defined with `#[task]`, queued via `enqueue`, and executed by a worker pool running `dj runworker` or a custom runner. Recurring tasks (cron) are registered with `register_recurring` and ticked via `tick_recurring_tasks`.

The build/deploy worker queue itself remains a custom Redis-based system because it needs platform-specific containers, job-scoped tokens, and artifact lifecycle. Task machinery is the default for all other background work.

Workers authenticate with a job-scoped token. The token is a JWT signed by the API with claims:

```json
{
  "sub": "job:{job_public_id}",
  "job_id": "uuid",
  "job_type": "build|deploy",
  "organization_id": "uuid",
  "exp": 1723600000
}
```

The API endpoint `/api/v1/workers/jobs/{id}/claim` issues the token only when a worker successfully claims a pending job.

---

## 19. Infrastructure and runtime

### 19.1 Local development

```bash
cd cloud-backend
cp .env.example .env
# edit DATABASE_URL, REDIS_URL, SECRET_KEY, R2 credentials, etc.
docker compose up -d db redis
# migrations applied automatically or via `dj migrate`
cargo run
```

### 19.2 Production runtime

- Djangors API runs as a single binary container behind a reverse proxy (Caddy or nginx).
- PostgreSQL and Redis are managed services (or containerized in early production).
- Build/deploy workers run in an ephemeral container runtime (Docker-in-Docker or Kubernetes jobs).
- Object storage is R2/S3.
- Logs are shipped via the `tracing` JSON formatter to the log aggregator.

### 19.3 Health endpoints

- `GET /healthz` → `200 {"status":"ok"}`
- `GET /readyz` → `200 {"status":"ready","checks":{"database":"ok","cache":"ok","queue":"ok"}}` or `503` with failing checks

---

## 20. Migration from existing Bloom

Bloom already has a `docs/` directory and `bloom-website/`. The Cloud backend is a new Cargo workspace. No existing Flutter/Dart code is touched by the backend implementation. The website will eventually be pointed at the new API endpoints as they become available.

---

## 21. Non-goals (explicitly out of scope for Phases 0-6)

- Replacing TestFlight with a custom iOS beta-distribution platform.
- Replacing Shorebird with a custom OTA engine.
- Building a generic CI/CD system for non-Flutter projects.
- Supporting self-hosted workers in Phase 0 (Phase 5).
- Mobile crash telemetry SDK in Phase 0 (Phase 6).
- Real-time log streaming websockets in Phase 0 (Phase 4).
- Marketplace and templates backend in Phase 0 (Phase 8).

---

## 22. Success criteria

Bloom Cloud backend is successful when:

1. A user can `bloom login` and `bloom cloud project link`.
2. A user can run `bloom cloud build` and see build progress in the dashboard.
3. A user can deploy a Flutter Web app to a `*.bloomcloud.dev` preview URL.
4. A user can deploy an iOS build to TestFlight and a Google Play build to internal testing.
5. A user can create a Release, approve it, and roll it back.
6. A user can manage secrets, signing, and credentials from the dashboard.
7. All actions are auditable and emit events.
8. All endpoints pass the verification bar (compile, lint, tests, spec parity).
