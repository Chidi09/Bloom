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
