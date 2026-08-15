-- up
ALTER TABLE marketplace_template ADD COLUMN is_free BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE marketplace_template ADD COLUMN price_amount BIGINT NOT NULL DEFAULT 0;
ALTER TABLE marketplace_template ADD COLUMN price_currency VARCHAR(3) NOT NULL DEFAULT 'usd';

CREATE TABLE marketplace_selleraccount (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    stripe_account_id VARCHAR(255) NOT NULL,
    payouts_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    charges_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    details_submitted BOOLEAN NOT NULL DEFAULT FALSE,
    default_currency VARCHAR(3),
    last_payouts_checked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id)
);

CREATE INDEX marketplace_selleraccount_org_id_idx ON marketplace_selleraccount(organization_id);
CREATE INDEX marketplace_selleraccount_stripe_id_idx ON marketplace_selleraccount(stripe_account_id);

CREATE TABLE marketplace_templatepurchase (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    buyer_organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    template_id BIGINT NOT NULL REFERENCES marketplace_template(id) ON DELETE CASCADE,
    template_version_id BIGINT REFERENCES marketplace_templateversion(id) ON DELETE SET NULL,
    seller_organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    amount BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'usd',
    platform_fee BIGINT NOT NULL,
    seller_amount BIGINT NOT NULL,
    stripe_payment_intent_id VARCHAR(255) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    idempotency_key VARCHAR(128) NOT NULL,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX marketplace_templatepurchase_buyer_org_idx ON marketplace_templatepurchase(buyer_organization_id);
CREATE INDEX marketplace_templatepurchase_template_id_idx ON marketplace_templatepurchase(template_id);
CREATE INDEX marketplace_templatepurchase_seller_org_idx ON marketplace_templatepurchase(seller_organization_id);
CREATE INDEX marketplace_templatepurchase_status_idx ON marketplace_templatepurchase(status);
CREATE INDEX marketplace_templatepurchase_idempotency_idx ON marketplace_templatepurchase(idempotency_key);
CREATE INDEX marketplace_templatepurchase_payment_intent_idx ON marketplace_templatepurchase(stripe_payment_intent_id);

-- down
DROP TABLE marketplace_templatepurchase;
DROP TABLE marketplace_selleraccount;
ALTER TABLE marketplace_template DROP COLUMN price_currency;
ALTER TABLE marketplace_template DROP COLUMN price_amount;
ALTER TABLE marketplace_template DROP COLUMN is_free;
