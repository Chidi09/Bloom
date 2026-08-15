# PHASES — Bloom Cloud Backend Implementation

This document is the ordered execution plan. Each phase has a clear scope, deliverables, and exit gates. Do not start Phase N+1 until Phase N passes its exit gates.

---

## Phase 0 — Foundation & Scaffolding

**Goal**: A running Djangors backend with health endpoints, auth, organizations, and the golden `accounts` app established.

### Deliverables

1. Cargo workspace `bloom-cloud-backend/` with pinned Djangors `=0.7.0` dependencies.
2. `src/main.rs` bootstrapping dev/prod logging, settings, database, Redis, middleware pipeline.
3. `src/settings.rs` typed settings via `#[derive(Settings)]`.
4. `src/urls.rs` root router mounting `/api/v1`.
5. `src/migrations.rs` ordered migration registry.
6. `apps/accounts/` golden app:
   - `User` wrapper / profile model
   - Device-code login flow for CLI
   - JWT issuance/refresh
   - API token model and endpoints
   - `/me`, `/logout`
7. `apps/organizations/`:
   - Organization CRUD
   - UserOrganizationMembership with roles
   - Organization resolution middleware
   - `CurrentOrganizationId` extension
8. Health endpoints: `/healthz`, `/readyz`.
9. `docker-compose.yml` with PostgreSQL 16 and Redis 7.
10. `.env.example`, `Dockerfile`, `djangors.toml`.

### API endpoints

- `POST /api/v1/auth/device/` — start device flow
- `GET /api/v1/auth/device/token/` — poll token
- `POST /api/v1/auth/token/` — create API token
- `DELETE /api/v1/auth/token/{id}/` — revoke API token
- `POST /api/v1/auth/refresh/` — refresh JWT
- `GET /api/v1/auth/me/` — current user
- `POST /api/v1/auth/logout/`
- `GET/POST /api/v1/organizations/`
- `GET/PATCH/DELETE /api/v1/organizations/{id}/`
- `GET/POST /api/v1/organizations/{id}/members/`
- `PATCH/DELETE /api/v1/organizations/{id}/members/{id}/`

### Models

- `accounts::UserProfile`
- `accounts::DeviceFlowRequest`
- `accounts::ApiToken`
- `organizations::Organization`
- `organizations::UserOrganizationMembership`

### Exit gates

- [ ] `cargo fmt --check`, `cargo check --all-targets`, `cargo clippy --all-targets -- -D warnings`, `cargo test` all clean.
- [ ] `/healthz` and `/readyz` return 200 when services are healthy.
- [ ] A user can complete device-code login and receive a JWT.
- [ ] A user can create an organization and invite a member.
- [ ] Organization middleware rejects requests without a valid membership.
- [ ] Golden app pattern documented and followed by all subsequent apps.

---

## Phase 1 — Projects, Apps, Environments

**Goal**: The project hierarchy exists. Users can create projects, apps, and environments.

### Deliverables

1. `apps/projects/`:
   - Project CRUD, scoped to organization
   - Slug uniqueness per organization
2. `apps/apps/` (the application entity):
   - App CRUD, scoped to project
   - Link local directory to app (`bloom cloud project link`)
3. `apps/environments/`:
   - Environment CRUD, scoped to app
   - Config JSON with typed environment variables and feature flags
   - Flutter/Dart/Bloom version pinning
   - Build profile and flavor defaults
4. Organization scoping helper finalized and reused.
5. Public API supports listing projects for CLI link flow.

### API endpoints

- `GET/POST /api/v1/projects/`
- `GET/PATCH/DELETE /api/v1/projects/{id}/`
- `GET/POST /api/v1/apps/`
- `GET/PATCH/DELETE /api/v1/apps/{id}/`
- `POST /api/v1/apps/link/` — link by local `bloom.yaml` project slug
- `GET/POST /api/v1/environments/`
- `GET/PATCH/DELETE /api/v1/environments/{id}/`

### Models

- `projects::Project`
- `apps::App`
- `environments::Environment`

### Exit gates

- [ ] All CRUD endpoints scoped to organization/project/app correctly.
- [ ] Role-based permissions enforced (Developer can create apps, Viewer cannot).
- [ ] Cross-organization access returns 403 or 404.
- [ ] `bloom cloud project link` CLI flow works end-to-end.

---

## Phase 2 — Credentials, Secrets, Signing

**Goal**: Secure management of platform credentials, per-environment secrets, and signing materials.

### Deliverables

1. `apps/credentials/`:
   - Encrypted storage for Apple, Google Play, Shorebird, GitHub credentials
   - Metadata-only responses
   - Credential validation endpoints (test connection without exposing secret)
2. `apps/secrets/`:
   - Per-environment key/value secrets
   - Version history
   - Rollback to previous version
3. `apps/signing/`:
   - Android keystore upload
   - iOS certificate / provisioning profile / API key upload
   - Expiry warnings
4. Encryption utility in `src/infra/crypto.rs`:
   - AES-256-GCM with a master key from environment
   - Key rotation support via versioned ciphertext prefix
5. Audit logging for every secret/signing/credential change.

### API endpoints

- `GET/POST /api/v1/credentials/`
- `GET/DELETE /api/v1/credentials/{id}/`
- `POST /api/v1/credentials/{id}/test/`
- `GET/POST /api/v1/secrets/`
- `GET/PATCH/DELETE /api/v1/secrets/{id}/`
- `POST /api/v1/secrets/{id}/rollback/`
- `GET/POST /api/v1/signing/`
- `GET/DELETE /api/v1/signing/{id}/`

### Models

- `credentials::Credential`
- `secrets::Secret`
- `secrets::SecretVersion`
- `signing::SigningIdentity`
- `audit::AuditLog`

### Exit gates

- [ ] Secrets/credentials are encrypted at rest; raw values never appear in API responses.
- [ ] Workers can fetch decrypted secrets with a valid job token.
- [ ] Credential test endpoints return useful validation errors without leaking secrets.
- [ ] Audit log records every create/update/delete with before/after snapshots.
- [ ] Expiring signing materials trigger a dashboard warning.

---

## Phase 3 — Builds & Artifacts

**Goal**: Builds can be queued, executed by workers, and produce artifacts.

### Deliverables

1. `apps/builds/`:
   - Build record CRUD
   - Queue build job
   - Build status transitions and logs
   - Cancel build
2. `apps/artifacts/`:
   - Artifact metadata
   - Presigned download URLs
   - Artifact listing per build/app
3. `src/infra/storage.rs`:
   - S3/R2 upload/download/presign abstraction
4. `src/infra/queue.rs`:
   - Redis-based job queue with `SELECT ... FOR UPDATE SKIP LOCKED`-style claiming
5. `src/workers/build.rs` (worker skeleton):
   - Poll for pending build jobs
   - Claim job
   - Report stage events
   - Upload artifact metadata
6. Build matrix support: one platform per build; multi-platform queued as child jobs.
7. Events: `build.started`, `build.completed`, `build.failed`, `build.cancelled`.

### API endpoints

- `GET/POST /api/v1/builds/`
- `GET /api/v1/builds/{id}/`
- `POST /api/v1/builds/{id}/cancel/`
- `GET /api/v1/builds/{id}/logs/`
- `GET/POST /api/v1/artifacts/`
- `GET /api/v1/artifacts/{id}/`
- `GET /api/v1/artifacts/{id}/download/`

### Models

- `builds::Build`
- `builds::BuildStage`
- `artifacts::Artifact`

### Exit gates

- [ ] A user can queue a build via `bloom cloud build`.
- [ ] A worker can claim, execute, and complete a build job.
- [ ] Build logs are uploaded to object storage and served via presigned URL.
- [ ] Artifacts are stored privately and downloadable via short-lived presigned URLs.
- [ ] Build events are emitted and stored in `EventLog`.

---

## Phase 4 — Releases & Web Deployments

**Goal**: Releases are first-class objects. Flutter Web can be deployed to preview and production URLs.

### Deliverables

1. `apps/releases/`:
   - Release CRUD
   - Release approval flow
   - Rollback
   - Link artifacts to release
2. `apps/webhosting/`:
   - Web deployment records
   - Preview URL generation
   - Production deployment
   - Rollback
   - Custom domain records (schema only; DNS config deferred to Phase 5)
3. `src/workers/deploy.rs`:
   - Web deploy worker uploads bundle to object storage + invalidates CDN
4. Events: `release.created`, `release.approved`, `release.deployed`, `release.rolled_back`, `webhosting.deployed`.
5. CLI endpoint: `bloom cloud deploy --platform web --target production/preview`.

### API endpoints

- `GET/POST /api/v1/releases/`
- `GET/PATCH/DELETE /api/v1/releases/{id}/`
- `POST /api/v1/releases/{id}/approve/`
- `POST /api/v1/releases/{id}/rollback/`
- `GET/POST /api/v1/webhosting/deployments/`
- `GET/POST /api/v1/webhosting/domains/`
- `POST /api/v1/webhosting/deployments/{id}/rollback/`

### Models

- `releases::Release`
- `webhosting::WebDeployment`
- `webhosting::CustomDomain`

### Exit gates

- [ ] A user can create a release from a successful build.
- [ ] Production web deployments require Release Manager or above.
- [ ] A Flutter Web bundle deploys to a `*.bloomcloud.dev` preview URL.
- [ ] Rollback restores the previous web deployment.
- [ ] Release status transitions are enforced and auditable.

---

## Phase 5 — Mobile Deployments (TestFlight & Google Play)

**Goal**: iOS and Android builds deploy to TestFlight and Google Play testing tracks.

### Deliverables

1. `apps/deployments/`:
   - Deployment record CRUD
   - Platform-specific target configuration
   - Status transitions: pending → running → processing → ready/live/failed
2. `integrations/testflight.md` implemented in worker code:
   - Transporter upload
   - App Store Connect API polling
   - Internal/external tester group assignment
3. `integrations/google-play.md` implemented in worker code:
   - Google Play Developer API upload
   - Track assignment
   - Release commit
4. `apps/observability/` (basic):
   - Store platform-reported metrics (crashes, sessions) when available
   - Release health dashboard data endpoints
5. Events: `deployment.started`, `deployment.processing`, `deployment.completed`, `deployment.failed`, `testflight.ready`, `google_play.live`.
6. CLI endpoints: `bloom cloud deploy --platform ios --target testflight`, `bloom cloud deploy --platform android --target internal`.

### API endpoints

- `GET/POST /api/v1/deployments/`
- `GET /api/v1/deployments/{id}/`
- `POST /api/v1/deployments/{id}/rollback/`
- `GET /api/v1/observability/apps/{id}/health/`
- `GET /api/v1/observability/releases/{id}/health/`

### Models

- `deployments::Deployment`
- `observability::ReleaseHealthSnapshot`
- `observability::PlatformMetric`

### Exit gates

- [ ] iOS IPA uploads to TestFlight via Transporter and reaches `ready` state.
- [ ] Android AAB uploads to Google Play internal testing track and reaches `live` state.
- [ ] Deployment status is polled and updated automatically.
- [ ] Failed deployments show platform-provided error messages.
- [ ] Production deployments require approval.

---

## Phase 6 — Shorebird, Git Integration, Workflows

**Goal**: Shorebird patches, Git provider webhooks, and visual CI/CD workflows.

### Deliverables

1. `integrations/shorebird.md` implemented:
   - Shorebird release creation
   - Shorebird patch creation
   - Link Shorebird release/patch IDs to Bloom Release
2. `apps/git_connections/`:
   - GitHub/GitLab/Bitbucket OAuth/app connections
   - Repository listing
   - Webhook handlers (`/webhooks/github/`, etc.)
3. `apps/workflows/`:
   - Workflow definition storage
   - Workflow run execution engine
   - Approval gates
4. `src/workers/webhook.rs`:
   - Validate signatures
   - Deduplicate deliveries
   - Trigger builds/workflows
5. CLI commands: `bloom release`, `bloom patch`, `bloom cloud deploy` with Shorebird detection.
6. Events: `shorebird.release.created`, `shorebird.patch.created`, plus git/webhook events.

### API endpoints

- `GET/POST /api/v1/git-connections/`
- `GET /api/v1/git-connections/repositories/`
- `POST /webhooks/github/`
- `POST /webhooks/gitlab/`
- `POST /webhooks/bitbucket/`
- `GET/POST /api/v1/workflows/`
- `GET/POST /api/v1/workflows/{id}/runs/`
- `POST /api/v1/workflows/runs/{id}/approve/`
- `POST /api/v1/releases/{id}/patch/`

### Models

- `git_connections::GitConnection`
- `workflows::Workflow`
- `workflows::WorkflowRun`
- `workflows::WorkflowRunStep`

### Exit gates

- [ ] A Git push triggers a build and web preview deployment.
- [ ] `bloom patch` creates a Shorebird patch linked to a Bloom Release.
- [ ] Workflows can be defined in YAML and executed with approval gates.
- [ ] Webhook handlers verify signatures and are idempotent.

---

## Phase 7 — Billing & Usage

**Goal**: Metered billing, invoices, and plan management.

### Deliverables

1. `apps/billing/`:
   - Plan and subscription models
   - Usage recording (build minutes, storage, bandwidth)
   - Invoice generation
   - Stripe integration (webhooks)
2. Usage enforcement: block builds/deployments when limits exceeded (graceful for free tier).
3. Dashboard endpoints for current usage and invoices.

### Exit gates

- [ ] Usage is recorded for every build, artifact storage, and web deployment.
- [ ] Invoices are generated monthly.
- [ ] Stripe webhooks update subscription status.

---

## Phase 8 — Marketplace & Templates Backend (future)

**Goal**: Backend support for Bloom Templates and Marketplace.

This phase is intentionally light in planning; it depends on Bloom UI and Bloom Framework maturity. The schema should be extensible from Phase 1.

---

## Cross-phase rules

1. **Every phase adds migrations** under `migrations/<app>/` and registers them in `src/migrations.rs`.
2. **Every phase adds tests** under `tests/apps/<app>/`.
3. **Every phase emits events** for state changes.
4. **Every phase updates this document** with the actual implementation decisions and deviations.
5. **No phase ships with known failing tests or clippy warnings.**

---

## Definition of done for the entire backend

Bloom Cloud backend is complete through Phase 6 when:

1. A developer can run `bloom login`, `bloom cloud project link`, `bloom cloud build`, and `bloom cloud deploy` end-to-end for iOS TestFlight, Android internal testing, and Flutter Web.
2. Releases are first-class objects with approval and rollback.
3. Secrets, signing, and credentials are managed securely.
4. Git push triggers builds and preview deployments.
5. Shorebird patches are linked to Bloom releases.
6. All events are auditable.
7. The verification commands pass clean.
8. The documentation in this directory accurately reflects the code.
