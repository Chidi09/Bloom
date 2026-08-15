# Events — Bloom Cloud Backend

This document is the canonical list of events emitted by Bloom Cloud. Every service that mutates state must emit the events listed here. The event infrastructure is in [`infrastructure.md`](infrastructure.md).

---

## Event schema

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub event_id: String,        // UUID v4
    pub event_type: String,      // dot-separated
    pub organization_id: Option<String>, // public UUID
    pub project_id: Option<String>,
    pub app_id: Option<String>,
    pub actor_id: Option<String>, // user public_id or "system"
    pub payload: serde_json::Value,
    pub created_at: chrono::DateTime<chrono::Utc>,
}
```

Event IDs are UUID v4. Event types are lowercase `category.action`. Payloads are JSON objects with stable keys.

---

## Build events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `build.created` | `{ build_id, app_id, environment_id, platform }` | build record inserted |
| `build.queued` | `{ build_id }` | job pushed to queue |
| `build.started` | `{ build_id, worker_id }` | worker claims job |
| `build.stage.started` | `{ build_id, stage }` | build stage begins |
| `build.stage.completed` | `{ build_id, stage, duration_ms }` | build stage ends |
| `build.completed` | `{ build_id, status: "success" }` | all artifacts uploaded |
| `build.failed` | `{ build_id, reason }` | worker reports failure |
| `build.cancelled` | `{ build_id, cancelled_by }` | user cancels build |

Stage values: `checkout`, `install`, `resolve`, `generate`, `prebuild`, `test`, `analyze`, `build`, `upload`.

---

## Artifact events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `artifact.created` | `{ artifact_id, build_id, platform, kind }` | artifact metadata registered |
| `artifact.uploaded` | `{ artifact_id, size, checksum }` | artifact bytes confirmed in storage |

---

## Release events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `release.created` | `{ release_id, app_id, version, build_number }` | release inserted |
| `release.approved` | `{ release_id, approved_by }` | release manager approves |
| `release.rejected` | `{ release_id, rejected_by, reason }` | release rejected |
| `release.deployed` | `{ release_id, deployment_ids }` | all requested deployments live |
| `release.rolled_back` | `{ release_id, rolled_back_by }` | rollback executed |
| `release.expired` | `{ release_id }` | artifacts expired |

---

## Deployment events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `deployment.created` | `{ deployment_id, release_id, platform, target }` | deployment record inserted |
| `deployment.started` | `{ deployment_id, worker_id }` | deploy worker claims job |
| `deployment.processing` | `{ deployment_id, external_id, external_url }` | platform acknowledges upload |
| `deployment.completed` | `{ deployment_id, status: "live" }` | platform reports live/ready |
| `deployment.failed` | `{ deployment_id, reason }` | platform or worker error |
| `deployment.rolled_back` | `{ deployment_id }` | rollback executed |

Platform-specific intermediate events:

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `testflight.processing` | `{ deployment_id, build_id }` | App Store Connect reports processing |
| `testflight.ready` | `{ deployment_id, build_id }` | build ready for testers |
| `google_play.processing` | `{ deployment_id, version_code }` | Play processing upload |
| `google_play.live` | `{ deployment_id, version_code, track }` | track release live |
| `webhosting.deployed` | `{ deployment_id, url }` | CDN edge updated |
| `webhosting.rolled_back` | `{ deployment_id, previous_deployment_id }` | rollback completed |

---

## Shorebird events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `shorebird.release.created` | `{ release_id, shorebird_release_id }` | Shorebird release linked |
| `shorebird.patch.created` | `{ release_id, shorebird_patch_id, platform }` | Shorebird patch linked |

---

## Secret events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `secret.created` | `{ secret_id, environment_id, key }` | new secret inserted |
| `secret.updated` | `{ secret_id, environment_id, key, version }` | new version created |
| `secret.rolled_back` | `{ secret_id, environment_id, key, to_version }` | rollback to previous version |
| `secret.deleted` | `{ secret_id, environment_id, key }` | secret deleted |

Secret payloads must **never** include the value or ciphertext.

---

## Signing events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `signing.created` | `{ signing_id, platform, name }` | signing identity uploaded |
| `signing.deleted` | `{ signing_id, platform, name }` | signing identity deleted |
| `signing.expiring` | `{ signing_id, platform, expires_at }` | expiry warning emitted |

---

## Credential events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `credential.created` | `{ credential_id, provider }` | credential added |
| `credential.updated` | `{ credential_id, provider }` | credential updated |
| `credential.deleted` | `{ credential_id, provider }` | credential deleted |
| `credential.tested` | `{ credential_id, provider, success }` | test connection run |

---

## Organization & membership events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `organization.created` | `{ organization_id, created_by }` | org created |
| `organization.updated` | `{ organization_id }` | org updated |
| `organization.deleted` | `{ organization_id }` | org deleted |
| `member.invited` | `{ organization_id, invite_id, email, role }` | invite sent |
| `member.joined` | `{ organization_id, user_id, membership_id }` | invite accepted |
| `member.role_changed` | `{ organization_id, membership_id, old_role, new_role }` | role changed |
| `member.removed` | `{ organization_id, membership_id }` | member removed |

---

## Project & app events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `project.created` | `{ project_id, organization_id }` | project created |
| `project.updated` | `{ project_id }` | project updated |
| `project.deleted` | `{ project_id }` | project deleted |
| `app.created` | `{ app_id, project_id }` | app created |
| `app.updated` | `{ app_id }` | app updated |
| `app.deleted` | `{ app_id }` | app deleted |

---

## Environment events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `environment.created` | `{ environment_id, app_id }` | environment created |
| `environment.updated` | `{ environment_id, app_id }` | environment updated |
| `environment.deleted` | `{ environment_id, app_id }` | environment deleted |

---

## Git & workflow events

| Event type | Payload | Emitted when |
|------------|---------|--------------|
| `git.connected` | `{ connection_id, provider }` | provider connected |
| `git.disconnected` | `{ connection_id, provider }` | provider disconnected |
| `git.push` | `{ connection_id, repository, ref, commit }` | push webhook received |
| `git.pull_request` | `{ connection_id, repository, pr_number, action }` | PR webhook received |
| `workflow.created` | `{ workflow_id, app_id }` | workflow created |
| `workflowrun.started` | `{ run_id, workflow_id }` | run started |
| `workflowrun.step.started` | `{ run_id, step_id, step_name }` | step started |
| `workflowrun.step.completed` | `{ run_id, step_id, status }` | step completed |
| `workflowrun.completed` | `{ run_id, status }` | run completed |

---

## Audit events

Every event in this document is also mirrored in `AuditLog` for sensitive operations. The `AuditLog` table stores before/after snapshots in addition to the event payload.

---

## EventLog model

```rust
#[derive(Model, Debug, Clone)]
#[djangors(app = "events", table_name = "events_eventlog")]
pub struct EventLog {
    #[djangors(primary_key, auto)]
    pub id: i64,
    #[djangors(max_length = 36)]
    pub event_id: String,
    #[djangors(max_length = 128)]
    pub event_type: String,
    pub organization_id: Option<i64>,
    pub project_id: Option<i64>,
    pub app_id: Option<i64>,
    pub actor_id: Option<i64>,
    pub payload: String, // JSON text
    #[djangors(auto_now_add)]
    pub created_at: chrono::DateTime<chrono::Utc>,
}
```

Indexes:

- `event_type`
- `organization_id`
- `app_id`
- `created_at` (for retention queries)

---

## Implementation checklist

Every service that mutates state must:

- [ ] Emit the exact event type listed here.
- [ ] Include all payload keys listed here.
- [ ] Use the public UUID for all id references in payloads.
- [ ] Use `"system"` as `actor_id` for automated/platform actions.
- [ ] Not include secrets, ciphertext, or raw tokens in payloads.
- [ ] Persist to `EventLog` via `events::publish`.
