# App spec — `billing`

Billing is Phase 7. This document defines the schema and scope so earlier phases do not paint themselves into a corner.

---

## 1. Models

### `Plan`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| name | String | `free` / `pro` / `enterprise` |
| description | String | |
| entitlements | String | JSON module/feature flags |
| active | bool | |
| created_at | DateTime<Utc> | |

### `Subscription`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| organization_id | ForeignKey<Organization> | 1:1 |
| plan_id | ForeignKey<Plan> | |
| status | String | `trialing` / `active` / `past_due` / `locked` / `cancelled` |
| trial_ends_at | Option<DateTime<Utc>> | |
| activated_at | Option<DateTime<Utc>> | |
| current_period_start | DateTime<Utc> | |
| current_period_end | DateTime<Utc> | |
| stripe_customer_id | String | optional |
| stripe_subscription_id | String | optional |

### `UsageRecord`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| organization_id | ForeignKey<Organization> | |
| metric | String | `build_minutes`, `artifact_storage_gb`, `web_bandwidth_gb`, `deploy_count` |
| value | i64 | integer minor units where applicable |
| recorded_at | DateTime<Utc> | |
| metadata | String | JSON |

### `Invoice`

| Field | Type | Notes |
|-------|------|-------|
| id | i64 | internal |
| public_id | String | UUID |
| subscription_id | ForeignKey<Subscription> | |
| organization_id | ForeignKey<Organization> | |
| amount_cents | i64 | integer cents |
| status | String | `draft` / `sent` / `paid` / `overdue` / `void` |
| due_date | NaiveDate | |
| paid_at | Option<DateTime<Utc>> | |
| stripe_invoice_id | String | optional |
| created_at | DateTime<Utc> | |

---

## 2. Entitlements

Entitlements are stored as JSON on `Plan.entitlements` and denormalized to a cache per organization.

Example:

```json
{
  "max_projects": 3,
  "max_apps": 5,
  "max_seats": 10,
  "build_minutes_monthly": 500,
  "artifact_storage_gb": 50,
  "web_bandwidth_gb": 100,
  "features": {
    "testflight_deployments": true,
    "google_play_deployments": true,
    "web_hosting": true,
    "shorebird": false,
    "workflows": false,
    "priority_support": false
  }
}
```

---

## 3. Usage metering

Record usage events:

- Build minutes: `build.finished_at - build.started_at`.
- Artifact storage: daily snapshot of total artifact bytes per org.
- Web bandwidth: CDN logs (Phase 5).
- Deploy count: each deployment creation.

Use `djangors_tasks` to aggregate usage into `UsageRecord` hourly/daily.

---

## 4. Enforcement

- Gate build creation on remaining build minutes.
- Gate web hosting on plan entitlement.
- Show upgrade prompt when limits approach.
- Soft enforcement for free tier; hard lock after grace period.

---

## 5. Stripe integration

- Stripe Customer per organization.
- Stripe Subscription linked to `Subscription`.
- Webhook `/webhooks/stripe` handles:
  - `invoice.paid`
  - `invoice.payment_failed`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`

---

## 6. API endpoints

```rust
Router::new()
    .get("/billing/plans", views::list_plans)
    .get("/billing/subscription", views::current_subscription)
    .post("/billing/subscribe", views::create_subscription)
    .post("/billing/cancel", views::cancel_subscription)
    .get("/billing/invoices", views::list_invoices)
    .get("/billing/usage", views::usage_summary)
```

---

## 7. Migration

```sql
-- up
CREATE TABLE billing_plan (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    name VARCHAR(32) NOT NULL,
    description TEXT,
    entitlements TEXT NOT NULL DEFAULT '{}',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE billing_subscription (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL UNIQUE REFERENCES organizations_organization(id) ON DELETE CASCADE,
    plan_id BIGINT NOT NULL REFERENCES billing_plan(id),
    status VARCHAR(32) NOT NULL,
    trial_ends_at TIMESTAMPTZ,
    activated_at TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end TIMESTAMPTZ NOT NULL,
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE billing_usagerecord (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    metric VARCHAR(32) NOT NULL,
    value BIGINT NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX billing_usagerecord_org_metric_recorded_idx ON billing_usagerecord(organization_id, metric, recorded_at);

CREATE TABLE billing_invoice (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    subscription_id BIGINT NOT NULL REFERENCES billing_subscription(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    amount_cents BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL,
    due_date DATE NOT NULL,
    paid_at TIMESTAMPTZ,
    stripe_invoice_id VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX billing_invoice_organization_id_idx ON billing_invoice(organization_id);

-- down
DROP TABLE billing_invoice;
DROP TABLE billing_usagerecord;
DROP TABLE billing_subscription;
DROP TABLE billing_plan;
```

---

## 8. Notes

- Money is always integer cents.
- Usage enforcement is checked at creation time, not retroactively.
- Keep billing data isolated per organization.
- Webhook handlers must be idempotent by Stripe event ID.
