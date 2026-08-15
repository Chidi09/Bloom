# PHASES-FINAL — Bloom Cloud Backend, Phases 9–15

`PHASES.md` covers Phases 0–8, all of which are implemented and committed. This document is its continuation: every remaining feature needed for Bloom Cloud to be a complete "Vercel for Flutter" backend, in execution order.

The same cross-phase rules apply — every phase adds migrations under `migrations/<app>/` registered in `src/migrations.rs`, adds tests under `tests/apps/<app>/`, emits events, updates this document with actual decisions, and ships with zero failing tests and zero clippy warnings.

**Scope note.** Phases 0–8 built a complete *control plane*: schema, API surface, auth, scoping, billing, and vendor clients. What is missing is almost entirely the *execution layer* — the code that actually runs a build, talks to a store, advances a workflow, and sends mail. Phases 9–12 close that gap. Phases 13–14 add the customer-facing communication layer (receipts, transactional email, lifecycle/promotional email). Phase 15 is hardening.

---

## Framework facilities to use (verified against the vendored 0.7.0 sources)

Do not hand-roll any of these. Each was read from the crate source, not assumed:

| Need | Crate | API |
| --- | --- | --- |
| Email delivery | `djangors-mail =0.7.0` | `Message { to: Vec<String>, from, subject, body, html_body: Option<String> }`, `trait MailBackend { async fn send(&self, &Message) -> Result<(), MailError> }`, impls `SmtpBackend` (lettre, `SmtpConfig::new(host).port(p).credentials(u, p).use_tls(bool)`), `ConsoleBackend`, `FileBackend`, `InMemoryBackend` |
| HTML/text templating | `djangors-template =0.7.0` | `TemplateEngine::from_embedded(..)` / `TemplateEngine::new(Vec<PathBuf>)`, `.render(name, ctx: impl Serialize) -> Result<String, TemplateError>`. minijinja under the hood; filters include `date`, `intcomma`, `filesizeformat`, `naturaltime`, `pluralize` |
| Scheduled + recurring jobs | `djangors-tasks =0.7.0` | `enqueue(db, task_name, &payload)`, `enqueue_scheduled(db, task_name, &payload, at)`, `register_recurring(db, task_name, &payload, cron_expr)` (five-field cron), `tick_recurring_tasks(db)`, `Worker::new(db).with_poll_interval(..).run()`, handlers registered via `inventory` + `TaskRegistration { name, handler }` |
| Build/deploy job claiming | `crate::infra::queue` | Redis Streams consumer groups. Already built. Tasks are for side effects; the queue is for build/deploy jobs. This split is mandated by `AI-AGENT-PRINCIPLES.md` and does not change. |

`djangors-mail` has **no** template integration of its own — `body` and `html_body` are plain `String`. Rendering is our job, via `djangors-template`, and the two are wired together in Phase 13.

---

## Phase 9 — Build Execution Engine

**Goal**: A queued build actually compiles Flutter code and produces real artifacts.

This is the single highest-value phase in the document. `src/workers/build.rs` today is an explicitly-labelled skeleton: the claim/heartbeat/report/upload/ack protocol is complete and correct, but lines 113–114 generate a *simulated* log and *simulated* artifacts. Nothing in the repo has ever invoked the Flutter toolchain.

### Deliverables

1. **`src/infra/executor.rs`** — a sandboxed command executor behind a trait, so tests never shell out:
   ```rust
   #[async_trait]
   pub trait CommandExecutor: Send + Sync {
       async fn run(&self, spec: &CommandSpec) -> Result<CommandOutput, ExecutorError>;
   }
   ```
   `CommandSpec` carries program, args, working directory, environment overlay, and a per-command timeout. `CommandOutput` carries exit status, captured stdout/stderr, and duration. Implementations: `LocalExecutor` (direct `tokio::process::Command`, for self-hosted runners) and `ContainerExecutor` (runs inside a per-build OCI container). A `RecordingExecutor` in `tests/` returns scripted outputs.
2. **Real stage implementations** replacing the simulation in `execute_build_pipeline`, one per existing `BUILD_STAGES` entry (`checkout`, `install`, `resolve`, `generate`, `prebuild`, `test`, `analyze`, `build`, `upload`) — the stage list does not change, only its bodies:
   - `checkout` — shallow clone at the build's `commit`, using the decrypted `git_connections` token. Never log the token.
   - `install` — provision the Flutter SDK version pinned by the environment (see deliverable 3).
   - `resolve` — `flutter pub get` with a warm `PUB_CACHE`.
   - `generate` — `dart run build_runner build --delete-conflicting-outputs`, skipped when the project declares no builders.
   - `prebuild` — platform setup: CocoaPods for iOS, Gradle sync for Android.
   - `test` / `analyze` — `flutter test --machine` and `dart analyze --format=json`, both parsed into structured stage results rather than raw text. Failures here fail the build unless the environment marks them advisory.
   - `build` — the platform command matrix (deliverable 4).
   - `upload` — already implemented; keep it.
3. **`src/infra/toolchain.rs`** — Flutter SDK version resolution and caching. Resolves an environment's declared channel/version to a concrete SDK, caches it per-runner keyed by version, and records the exact resolved version on the `Build` row so a build is reproducible. An unpinned environment resolves to the current stable and **writes the resolved version back**, so the second build of the same environment is deterministic.
4. **Platform build matrix**, driven by the existing `Build.platform`:
   - `android` → `flutter build apk --release` and/or `flutter build appbundle --release`
   - `ios` → `flutter build ipa --release --export-options-plist=<generated>`, using the Phase 2 signing assets
   - `web` → `flutter build web --release`
   - `macos` / `windows` / `linux` → the corresponding `flutter build` desktop targets
5. **Dependency caching** — `~/.pub-cache`, Gradle caches, and CocoaPods caches persisted across builds keyed by a hash of the lockfiles. Cache hit/miss is recorded per build and surfaced in the build detail response; a cold cache must never be a correctness difference, only a speed one.
6. **Build cancellation, for real.** `src/apps/builds/services.rs:527` documents the gap: cancel currently updates the database while the worker keeps running. Implement the Redis cancel key the TODO describes — the worker checks it at every stage boundary and between long command polls, then terminates the process group and fails the job cleanly.
7. **Live log streaming.** `build_logs` (`services.rs:771`) serves a finished log from object storage. Add incremental append to Redis during execution and an SSE endpoint that tails it, falling back to the stored object once the build is terminal.
8. **Runner registration**: a `runners` concept (self-hosted or Bloom-managed) with platform capabilities, so iOS builds are only dispatched to macOS runners. Without this, an iOS build silently lands on a Linux runner and fails at `prebuild` with a confusing error.

### API endpoints

- `GET /api/v1/builds/{id}/logs/stream/` — SSE live log tail
- `POST /api/v1/builds/{id}/cancel/` — already exists; becomes effective
- `GET/POST /api/v1/runners/`, `DELETE /api/v1/runners/{id}/`

### Models

- `builds::Runner` — `public_id`, `name`, `platforms` (JSON array), `status`, `last_heartbeat_at`, `organization_id` (nullable for shared Bloom-managed runners)
- `Build` gains `resolved_flutter_version`, `runner_id` (nullable), `cache_hit` (bool)

### Exit gates

- [ ] Four gates clean.
- [ ] A real Flutter counter app builds end-to-end for web and Android, producing artifacts that download and run.
- [ ] A failing `flutter test` fails the build at the `test` stage with the parsed failure surfaced, not a generic message.
- [ ] Cancelling a running build terminates the process within 10 seconds.
- [ ] Two consecutive builds of an unchanged commit report a cache hit and the second is measurably faster.
- [ ] No secret, token, or signing password appears in any stored log. This is an explicit review item, not an assumption.

---

## Phase 10 — Mobile Store Delivery Wiring

**Goal**: A deployment targeting TestFlight, Google Play, or Shorebird actually reaches the vendor.

`src/infra/testflight.rs` (644 lines), `src/infra/googleplay.rs` (874 lines), and `src/infra/shorebird.rs` (498 lines) are real, documentation-verified vendor clients — and **nothing calls them**. `grep -rn "infra::testflight|infra::googleplay|infra::shorebird" src/` outside `src/infra/` returns zero results. `src/workers/deploy.rs` imports only `caddy`, `cdn`, `storage`, and `queue`, so a deployment to `app_store` or `play_store` today records status transitions against a vendor it never contacts.

This is the highest value-per-hour phase in the document: the hard, documentation-bound work is already written and reviewed. It needs to be called.

### Deliverables

1. Branch `run_deploy_job` on `Deployment.target`, extending the existing `DeployRouting`/`DeployWorkerDeps` context structs rather than growing the argument list:
   - `web` / `preview` → existing Caddy + CDN path (unchanged)
   - `testflight` / `app_store` → `infra::testflight`
   - `internal_testing` / `play_store` → `infra::googleplay`
   - `shorebird` → `infra::shorebird`
2. **App Store Connect delivery**: resolve the Phase 2 credential, mint the ES256 JWT, upload the `.ipa`, poll build processing, and assign to the requested TestFlight group. **`processingState` values remain unverified** — this was flagged during Phase 5 review and is still open. Treat any unrecognised state as "still processing" and time out rather than branching on a guessed constant, and confirm the enum against Apple's documentation before this path is enabled in production.
3. **Google Play delivery**: RS256 service-account assertion → access token, then the edit transaction lifecycle (`edits.insert` → `edits.bundles.upload` → `edits.tracks.update` → `edits.commit`). An abandoned edit must be explicitly deleted on failure, or the next deploy inherits a stale edit.
4. **Shorebird patches**: CLI-driven (the module makes no HTTP calls by design), linking the created patch back to the Bloom release. **`shorebird login:ci` tokens expire in September 2026** — surface token expiry as a first-class credential-health warning rather than discovering it as a deploy failure.
5. **Vendor error mapping**: every vendor failure maps onto a `DeploymentError` with the vendor's own message preserved. A 401 from Apple must read as a credential problem, not a generic deploy failure.
6. Per `COMMON_RULES.txt` §9(y), all vendor calls stay in workers. No request handler blocks on a store API.

### Exit gates

- [ ] Four gates clean.
- [ ] A build artifact reaches TestFlight and is visible in App Store Connect.
- [ ] An AAB reaches a Google Play internal testing track.
- [ ] A Shorebird patch is created and linked to its Bloom release.
- [ ] An invalid credential produces a clear, actionable error naming the credential.
- [ ] Every vendor call is covered by a test using a recorded response, with zero live network access in the suite.

---

## Phase 11 — Workflow Execution Engine

**Goal**: Workflow runs advance on their own.

`workflows/services.rs` creates runs, validates step and run transitions, parses the YAML definition (`parse_workflow_definition`, real since Phase 6), and handles approvals. There is no runner: `src/workers/` contains only `build.rs`, `deploy.rs`, and `webhook.rs`. A created run sits at its initial status forever.

### Deliverables

1. **`src/workers/workflow.rs`** — claims workflow runs, walks steps in `order`, and drives each `VALID_STEP_KINDS` entry:
   - `test` / `build` → enqueue a build job, then wait on its terminal status
   - `deploy_preview` / `deploy_production` → enqueue a deploy job, then wait
   - `approval_gate` → park the run in `awaiting_approval` and stop consuming a worker slot
   - `custom` → a declared command via the Phase 9 `CommandExecutor`
2. **Resumption after approval**: `approve_workflow_run` re-enqueues the run at the next step. A rejected gate fails the run and emits `workflow.rejected`.
3. **Failure semantics**: a failed step fails the run by default; a step may declare `continue_on_error`. Downstream steps see prior step outputs through a run-scoped context.
4. **Timeouts and orphan recovery**: a run whose worker dies is reclaimed by heartbeat expiry, mirroring the build queue's existing claim/heartbeat design rather than inventing a second mechanism.
5. **Concurrency control**: at most one active run per workflow per environment by default, with newer runs queued rather than racing.

### Exit gates

- [ ] Four gates clean.
- [ ] A three-step workflow (test → build → deploy_preview) completes end-to-end.
- [ ] An `approval_gate` blocks until approved, then resumes at the correct step.
- [ ] Killing a workflow worker mid-run results in the run being reclaimed, not stranded.

---

## Phase 12 — Custom Domains, DNS Verification, and TLS

**Goal**: A customer's own domain actually serves their Flutter web app over HTTPS.

`webhosting/services.rs:591` hardcodes `verified_at: None` — nothing ever verifies domain ownership. `src/infra/caddy.rs` contains no TLS, ACME, or `automatic_https` configuration at all. So a domain can be registered but never serves.

### Deliverables

1. **Ownership verification**: on `create_custom_domain`, generate a verification token and return the required DNS record (`TXT _bloom-challenge.<domain>` = token, plus the `CNAME`/`A` target for the domain itself). A verification task resolves DNS and sets `verified_at` on success. Unverified domains are never added to the edge.
2. **Automatic TLS**: extend `CaddySiteBlock` with Caddy's automatic HTTPS/ACME configuration so certificates are issued on first request. Only verified domains are configured — an unverified domain in the Caddy config is an open redirect risk and a rate-limit hazard with the ACME provider.
3. **Certificate status** surfaced per domain (`pending`, `issuing`, `active`, `failed`) with the failure reason, so a customer with a misconfigured CNAME can self-diagnose.
4. **Apex and wildcard** handling, including the DNS-01 challenge path for wildcards.
5. **Domain removal** cleans up the Caddy site block and the certificate, and is idempotent.
6. **Re-verification**: a domain whose DNS stops resolving is flagged rather than silently 404-ing.

### Exit gates

- [ ] Four gates clean.
- [ ] A real domain, correctly pointed, verifies and serves over HTTPS with a valid certificate.
- [ ] A domain with wrong DNS reports precisely which record is wrong.
- [ ] An unverified domain is never present in the Caddy configuration.

---

## Phase 13 — Notifications, Receipts, and Transactional Email

**Goal**: Bloom talks to its customers. Every billable event produces a receipt; every important state change produces a notification the user actually chose to receive.

There is currently **no** email anywhere in the tree — `grep -rni "smtp|sendgrid|mailgun|resend|send_mail" src/` returns nothing — while `djangors-mail` sits unused in the dependency graph.

### 13.1 Deliverables — mail infrastructure

1. **`src/infra/mail.rs`** wrapping `djangors_mail::MailBackend`:
   - Backend selected from typed settings: `SmtpBackend` in production, `ConsoleBackend` in development, `InMemoryBackend` in tests. Never send real mail from a test run.
   - `BLOOM_MAIL_*` typed settings: `BACKEND`, `HOST`, `PORT`, `USERNAME`, `PASSWORD`, `FROM_ADDRESS`, `FROM_NAME`, `REPLY_TO`.
   - Per `COMMON_RULES.txt` §9(z), the settings struct redacts the password in its `Debug` impl.
2. **`src/infra/email_templates.rs`** wrapping `djangors_template::TemplateEngine::from_embedded` so templates compile into the binary — a container image with no template directory must still send mail. Every template renders **both** a text and an HTML body; `Message.body` is never empty, because a text-only client must still receive a readable email.
3. **All sending goes through `djangors-tasks`**, never inline in a request handler. A user's signup must not fail because an SMTP server is slow. Retries use the task queue's `max_attempts`.
4. **`emails` app** owning the record of what was sent.

### 13.2 Email format — the house standard

Every Bloom email, transactional or promotional, obeys this format. It is a contract, not a suggestion, and is enforced by a rendering test that asserts each rule against every registered template.

**Envelope**

| Field | Rule |
| --- | --- |
| `From` | `Bloom <notifications@bloom.dev>` for transactional; `Bloom <hello@bloom.dev>` for lifecycle/promotional. Separate addresses so a customer can filter one without losing the other. |
| `Reply-To` | `support@bloom.dev`. Never `no-reply` — a customer replying to a failed-build email should reach a human. |
| `Subject` | ≤ 60 characters, no emoji, no `RE:`/`FWD:`, front-loaded with the specific object: `Build #142 failed — acme-app (production)`, not `Your build has an update`. |
| Preheader | 40–90 characters, first element in the HTML body, visually hidden. Never leave it to fall back to the first visible text. |
| `List-Unsubscribe` | Required on **every** promotional email, with `List-Unsubscribe-Post: List-Unsubscribe=One-Click` (RFC 8058). Transactional receipts and security emails carry no unsubscribe, because they are not opt-out. |

**Body structure**, in order: preheader → wordmark → single `<h1>` restating the subject → one-sentence summary → the payload (a facts table or a receipt table) → exactly one primary call-to-action button → secondary context → footer (organization name, why this email was received, manage-preferences link, unsubscribe link for promotional only, postal address).

**Rendering constraints** — email clients are not browsers:

- Tables for layout. No flexbox, no grid, no CSS custom properties.
- All CSS inlined on the element. No `<style>` block relied upon; Gmail strips much of it.
- Max width 600px, single column.
- No web fonts. System font stack only.
- Every image has `alt` text and the email is fully comprehensible with images disabled — many clients block them by default.
- Dark-mode safe: never a transparent background, never dark text on an assumed-white ground. Set both `background-color` and `color` explicitly on every text-bearing element.
- Total HTML under 102 KB, or Gmail clips the message and hides the footer, including the unsubscribe link.

**Copy rules**, consistent with the product voice: active voice, second person, name things as the customer knows them ("your build", not "the job record"). An error email states what went wrong, what it means, and the single next action. No apology boilerplate, no exclamation marks.

**Money**, everywhere it appears: rendered from integer minor units, formatted at the edge only. No float ever touches a currency value — this rule already governs `src/apps/billing/` and extends unchanged into rendering.

### 13.3 Receipts

`billing::Invoice` exists with `amount_cents`, `status`, `due_date`, `paid_at`, and a provider reference — but there is no line-item breakdown, no currency field, and no rendered receipt. An invoice today cannot answer "what am I paying for?"

**Deliverables**

1. **`billing::InvoiceLineItem`** — `invoice_id` (FK), `description`, `quantity`, `unit_amount_cents`, `amount_cents`, `metric` (nullable, one of `VALID_METRICS`), `period_start`, `period_end`. The invoice total is the sum of its line items and is asserted equal to `Invoice.amount_cents` at generation time; a mismatch is a hard error, never a silent reconciliation.
2. **`currency` on `Plan` and `Invoice`** — an ISO 4217 code. This is a genuine gap: Paystack settles in NGN and the schema currently assumes a single implicit currency, so a multi-currency customer base would produce wrong receipts. Minor-unit exponent is resolved per currency; do not assume 2 (a receipt in a zero-decimal currency divided by 100 is off by two orders of magnitude).
3. **Receipt numbering** — `BLM-{YYYY}-{ORG_SEQ:06}`, sequential and gapless per organization per year, allocated inside the same transaction as the invoice. Gapless numbering is an accounting requirement in most jurisdictions; a `MAX()+1` outside a transaction will collide under concurrency.
4. **Receipt content**, mandatory fields: receipt number; issue date; Bloom's legal entity name, address, and tax identifier; the customer's organization name and billing address; the line items with per-item and total amounts; tax lines shown separately with rate and jurisdiction; the total; amount paid and payment method (brand and last four only — never a full instrument number); the billing period; and the provider reference for reconciliation.
5. **Immutability** — a receipt is generated once, at the moment payment is confirmed, and stored as a rendered artifact in object storage under a canonical key. Re-fetching returns the stored artifact. It is never re-rendered from live data, because a plan rename or price change must not retroactively alter a historical receipt. Corrections are issued as a separate credit note referencing the original.
6. **Delivery** — sent to `Organization.billing_email`, falling back to the owner's `djangors_auth::User.email`. Receipts are transactional: no unsubscribe, and they are sent regardless of every marketing preference.
7. **Retrieval** — `GET /api/v1/billing/invoices/{id}/receipt/` returns a presigned URL, organization-scoped like every other artifact download.

### 13.4 Transactional email catalogue

Each is a registered template with text and HTML bodies, keyed by a stable `template_key` recorded on every send.

| Key | Trigger | Recipients |
| --- | --- | --- |
| `auth.device_login` | Device-code login approved from a new device | The user |
| `auth.token_created` | New API token issued | The user |
| `org.invitation` | Member invited | The invitee |
| `org.member_joined` | Invitation accepted | Org admins |
| `build.failed` | Build enters `failed` | Build author, plus subscribed org members |
| `build.recovered` | Build succeeds after a previous failure on the same environment | Same as above |
| `deploy.succeeded` | Production deployment reaches `succeeded` | Subscribed org members |
| `deploy.failed` | Deployment enters `failed` | Deploy author + subscribed |
| `deploy.rolled_back` | Rollback executed | Org admins |
| `release.approval_requested` | Release awaits approval | Users holding the approver role |
| `workflow.approval_requested` | `approval_gate` reached | Approvers |
| `domain.verification_failed` | DNS verification fails after retries | Org admins |
| `domain.certificate_failed` | ACME issuance fails | Org admins |
| `credential.expiring` | Signing cert / Shorebird token / store key within 30 days of expiry | Org admins |
| `billing.receipt` | Payment confirmed | Billing email |
| `billing.payment_failed` | Provider reports failure | Billing email |
| `billing.quota_warning` | Usage crosses the existing `Warn` threshold (80%) | Billing email + admins |
| `billing.hard_lock` | `EnforcementDecision::HardLock` first blocks an action | Billing email + admins |
| `billing.trial_ending` | 3 days before trial end | Billing email |

**Noise control.** `build.failed` on a busy repository is the fastest way to get every Bloom email filtered to spam. Consecutive failures on the same environment collapse into one email plus a digest; the second through Nth failures do not each send. A recovery always sends, because "it's fixed" is the message people actually want.

### 13.5 Preferences and suppression

1. **`emails::NotificationPreference`** — per user, per organization, per category (`builds`, `deployments`, `releases`, `security`, `billing`, `product`), with values `all`, `mine_only`, `digest`, `none`. `security` and `billing` cannot be set to `none`.
2. **`emails::EmailSuppression`** — address, reason (`hard_bounce`, `spam_complaint`, `manual`, `unsubscribed`), timestamp. Checked before **every** send, transactional included. Sending to a hard-bounced address damages domain reputation for every other customer.
3. **`emails::EmailLog`** — `template_key`, recipient, organization, subject, status (`queued`, `sent`, `failed`, `bounced`, `complained`), provider message id, error, timestamps. This is the audit trail for "did we email them?" and the input to the Phase 14 algorithm.
4. **Unsubscribe tokens** — HMAC-signed via the existing `Crypto::hmac_sha256_hex`, containing user, category, and issue time. One-click unsubscribe must work without a login session, and must be constant-time compared.

### API endpoints

- `GET/PATCH /api/v1/notifications/preferences/`
- `POST /api/v1/notifications/unsubscribe/` — token-authenticated, no session, RFC 8058 one-click
- `GET /api/v1/billing/invoices/{id}/receipt/`
- `GET /api/v1/organizations/{id}/email-log/` — admin only

### Models

- `emails::EmailLog`, `emails::NotificationPreference`, `emails::EmailSuppression`, `emails::EmailTemplateVersion`
- `billing::InvoiceLineItem`; `currency` added to `billing::Plan` and `billing::Invoice`

### Exit gates

- [ ] Four gates clean.
- [ ] Every registered template renders with both a text and an HTML body, under 102 KB, passing the format assertions in 13.2.
- [ ] A receipt totals exactly the sum of its line items, in integer minor units, with zero float arithmetic anywhere in the path.
- [ ] Receipt numbers are gapless and unique under a concurrent-generation test.
- [ ] A suppressed address receives nothing, including transactional mail.
- [ ] One-click unsubscribe works without a session and rejects a tampered token.
- [ ] The test suite sends zero real emails — `InMemoryBackend` only, asserted.

---

## Phase 14 — Lifecycle and Promotional Email

**Goal**: Bloom sends promotional and lifecycle email that is targeted, rate-limited, consent-based, and measurable — not a blast.

This phase depends entirely on Phase 13's infrastructure, preferences, suppression list, and `EmailLog`. It must not begin before those exist.

### 14.1 Principles

Three rules govern everything below, and each exists because violating it is how a sending domain gets blocked:

1. **Consent is explicit.** The `product` category defaults to *off* for new users. A user who never opted in receives no promotional email regardless of how well they match a segment.
2. **Frequency is capped globally.** At most **one** promotional email per user per **7 days**, and at most **four** per 30 days, across all campaigns. The cap is enforced at send time against `EmailLog`, not at campaign-planning time, because two campaigns planned independently will otherwise both fire on the same Tuesday.
3. **Transactional always wins.** A promotional send is suppressed if the user received any transactional email within the last 24 hours, and is never sent while an organization is in `HardLock` — an upsell arriving the same hour a customer's builds stopped working is the worst possible timing.

### 14.2 The selection algorithm

Runs daily via `djangors_tasks::register_recurring` with cron `0 9 * * *`, evaluated per-user in the user's local timezone.

**Stage 1 — Build the eligible pool.** Start from all active users; remove, in order:
- users whose `product` preference is not `all` or `digest`
- addresses present in `EmailSuppression`
- users created less than 3 days ago (they are still in onboarding, which is a separate transactional sequence)
- users who received any promotional email within 7 days, or 4 within 30 days
- users who received transactional email within 24 hours
- users in an organization currently in `HardLock` or `past_due`

**Stage 2 — Score each remaining user against each campaign.** Every campaign declares a `TriggerRule` evaluated against a `UserActivitySnapshot` computed from existing tables — `builds`, `deployments`, `releases`, `billing::UsageRecord`, `EmailLog` — with no new tracking infrastructure. Scoring is integer-only, mirroring the billing enforcement functions, and lives in a pure function that is unit-testable with zero I/O:

```rust
pub fn score_campaign(
    snapshot: &UserActivitySnapshot,
    campaign: &CampaignRule,
) -> Option<CampaignScore>
```

Returning `None` means "not eligible", which is distinct from "eligible with score 0" — the distinction matters, because a zero-scored eligible user still counts toward suppression bookkeeping.

Score components, summed:

| Signal | Weight | Rationale |
| --- | --- | --- |
| Trigger condition matched exactly | +50 | The campaign's core reason to exist |
| Recency of the triggering event (≤ 3 days) | +20 | A stale trigger is a wrong trigger |
| Feature gap is real (entitlement present but feature never used) | +15 | We are recommending something they can actually do |
| Engagement history (opened a Bloom email in the last 90 days) | +10 | Reward attention rather than assuming it |
| Never received this campaign before | +10 | Repetition without new information is spam |
| Organization is on a paid plan | +5 | Slight bias toward customers with a live relationship |
| Same campaign sent in the last 90 days | −40 | Strong penalty, not a hard exclusion — a genuine re-trigger may justify it |
| No login in 60 days | −25 | Dormant users bounce and complain more |
| Any campaign email unopened in the last 3 sends | −20 | Disengagement is a signal to back off, not push harder |

**Stage 3 — Pick at most one campaign per user**: the highest score above a floor of **60**. The floor is deliberate — a user matching nothing well receives nothing at all. Ties break toward the campaign never sent to that user, then toward the lower total send volume, so a small campaign is not permanently starved by a large one.

**Stage 4 — Send window.** Enqueue via `enqueue_scheduled` for 10:00 local time on a weekday. Never send on Saturday or Sunday, and never between 20:00 and 08:00 local. A user with no timezone recorded is treated as UTC.

**Stage 5 — Record.** Write to `EmailLog` with the campaign key before dispatch, so a crash mid-run cannot double-send on retry. The pre-write is what makes the whole algorithm idempotent, and it is the single most important implementation detail in this phase.

### 14.3 Campaign catalogue

Every campaign is triggered by observed product behaviour. None is calendar-driven, because a calendar blast is exactly what the frequency cap exists to prevent.

| Campaign key | Trigger | Message |
| --- | --- | --- |
| `promo.first_build_success` | First successful build ever, within 3 days | What to do next: connect Git for automatic builds |
| `promo.git_not_connected` | ≥ 3 manual builds, no `git_connection` | Push-to-build, with the two-step setup |
| `promo.web_hosting_unused` | `web_hosting` entitled, zero web deployments in 30 days | Deploy a Flutter web build to a real URL |
| `promo.custom_domain_unused` | ≥ 5 web deployments, zero custom domains | Point your own domain, with TLS handled |
| `promo.workflows_unused` | `workflows` entitled, zero workflows, ≥ 10 builds | Automate the sequence you are running by hand |
| `promo.shorebird_unused` | `shorebird` entitled, mobile releases exist, zero patches | Ship a fix without a store review |
| `promo.approaching_limit` | Usage at `Warn` for 2 consecutive weeks | Upgrade before it blocks you — **sent only while `Allow`/`Warn`, never during a lock** |
| `promo.team_of_one` | Org active 30 days, exactly one member, ≥ 20 builds | Invite your team |
| `promo.marketplace_publish` | ≥ 3 projects with a shared structure | Publish a template |
| `promo.reactivation` | No build in 45 days, previously active | One email, then the user is excluded from all campaigns for 180 days |

`promo.approaching_limit` is the only campaign touching billing, and it carries the strictest guard: it is suppressed the moment enforcement moves to `SoftBlock` or `HardLock`, at which point the *transactional* `billing.quota_warning` and `billing.hard_lock` emails take over. A promotional upsell must never be the vehicle for telling someone their account is restricted.

### 14.4 Measurement

1. **`emails::Campaign`** — key, name, subject template, body template, active flag, trigger rule (JSON), score floor override (nullable), created/updated.
2. **`emails::CampaignSend`** — campaign, user, organization, score at send time, sent_at, opened_at, clicked_at, converted_at, conversion_event. Storing the score enables retrospective analysis of whether the weights above are right; without it, tuning is guesswork.
3. **Conversion** is the campaign's *specific* action taken within 14 days — connecting Git for `promo.git_not_connected`, not merely opening the email. A campaign converting below 2% over 500 sends is automatically disabled and flagged for review, because a persistently ignored campaign is pure reputation cost.
4. **Open tracking** via a pixel, honoured as best-effort only: Apple Mail Privacy Protection pre-fetches images and inflates opens substantially. Click and conversion are the metrics that decide anything; opens inform the engagement penalty and nothing else.
5. **Holdout**: 5% of the eligible pool receives nothing, permanently assigned by hashing the user id, so campaign effect is measurable against a real baseline rather than against a pre/post comparison that confounds with seasonality.

### API endpoints

- `GET/POST /api/v1/admin/campaigns/` — staff only
- `PATCH /api/v1/admin/campaigns/{id}/`
- `GET /api/v1/admin/campaigns/{id}/stats/`
- `POST /api/v1/admin/campaigns/{id}/preview/` — render against a real user snapshot without sending

### Exit gates

- [ ] Four gates clean.
- [ ] `score_campaign` is covered by pure unit tests for every signal in the table, including both negatives, with no database access.
- [ ] The frequency cap holds under a test that runs the daily selection 30 consecutive simulated days: no user exceeds 1 per 7 days or 4 per 30.
- [ ] A user who never opted into `product` receives nothing across that entire 30-day simulation.
- [ ] An organization in `HardLock` receives zero promotional email while locked.
- [ ] Re-running the daily task twice on the same day sends nothing the second time (idempotence via the Stage 5 pre-write).
- [ ] Every promotional email carries `List-Unsubscribe` and `List-Unsubscribe-Post`; no transactional email does.
- [ ] The holdout group is stable across runs.

---

## Phase 15 — Completeness and Hardening

**Goal**: Close the audit, verification, and correctness gaps left behind by earlier phases. Each item below is a specific, located defect, not a general aspiration.

### Deliverables

1. **Finish event emission.** A dozen `TODO(spec)` sites never emit or audit-log, including `credentials/services.rs:152,153,185,186,274` (credential create, delete, test), `projects/services.rs:122`, and `environments/services.rs:91`. Credential mutation going unaudited directly contradicts the Phase 6 definition-of-done item "all events are auditable".
2. **GitLab and Bitbucket webhook signatures.** `workers/webhook.rs:254,261` record that both schemes are unverified. GitHub is correct and verified. Until the other two are confirmed against vendor documentation, those endpoints must **reject** rather than accept — an unverified signature check is worse than a missing one, because it looks like security.
3. **Resolve the remaining cross-app `TODO(spec)` stubs**: `observability/models.rs:67` and `observability/repositories.rs:67` (deployment linkage), `apps/repositories.rs:195` (extend to builds and releases), `artifacts/permissions.rs:14` (authoritative job-token issuance).
4. **PR preview comments**: post the preview URL back to the pull request on GitHub. This is the single most visible piece of the Vercel experience and is currently absent.
5. **Log drains**: forward build and deploy logs to a customer-configured sink.
6. **Deployment analytics**: per-deployment request and bandwidth reporting beyond the aggregate billing counters, so bandwidth charges are explainable line by line on the receipt.
7. **Rate limiting** on authentication, webhook, and unsubscribe endpoints.
8. **Confirm the Apple `processingState` enum** and remove the defensive fallback introduced in Phase 10 once verified.

### Exit gates

- [ ] Four gates clean.
- [ ] Zero `TODO(spec)` markers remain in `src/`.
- [ ] Every state-changing operation emits an event and, where it touches a secret, an audit log with the secret redacted.
- [ ] GitLab and Bitbucket webhooks either verify correctly against a documented scheme or are disabled.
- [ ] A pull request receives a preview URL comment within 60 seconds of a successful preview deployment.

---

## Definition of done for the whole backend

Bloom Cloud is feature-complete when, in addition to the Phase 0–8 gates:

1. A developer runs `bloom cloud build` and real Flutter code compiles on a real runner, producing a downloadable artifact.
2. `bloom cloud deploy` reaches TestFlight, Google Play, Shorebird, or the web edge — actually contacting the vendor.
3. A git push runs a workflow end-to-end, including approval gates, and comments the preview URL on the pull request.
4. A custom domain verifies, obtains a certificate, and serves over HTTPS.
5. Every payment produces an immutable, gapless, line-itemised receipt in the correct currency, delivered by email.
6. Users receive the notifications they chose, in the house format, and no others.
7. Promotional email is consent-based, frequency-capped, measurably converting, and never lands during an outage or a billing lock.
8. Zero `TODO(spec)` markers, and every state change is auditable.
9. The four verification commands pass clean, and this document reflects what the code actually does.
