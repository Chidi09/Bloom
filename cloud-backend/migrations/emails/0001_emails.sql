-- up
CREATE TABLE emails_emaillog (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    template_key VARCHAR(128) NOT NULL,
    recipient VARCHAR(254) NOT NULL,
    organization_id BIGINT REFERENCES organizations_organization(id) ON DELETE SET NULL,
    subject VARCHAR(255) NOT NULL,
    status VARCHAR(32) NOT NULL,
    provider_message_id VARCHAR(255),
    error TEXT,
    campaign_key VARCHAR(128),
    is_promotional BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX emails_emaillog_recipient_created_at_idx ON emails_emaillog(recipient, created_at);
CREATE INDEX emails_emaillog_recipient_promo_idx ON emails_emaillog(recipient, is_promotional, created_at);
CREATE INDEX emails_emaillog_organization_id_idx ON emails_emaillog(organization_id);
CREATE INDEX emails_emaillog_template_key_idx ON emails_emaillog(template_key);
CREATE INDEX emails_emaillog_status_idx ON emails_emaillog(status);
CREATE INDEX emails_emaillog_campaign_key_idx ON emails_emaillog(campaign_key);

CREATE TABLE emails_notificationpreference (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    category VARCHAR(32) NOT NULL,
    value VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT emails_notificationpreference_user_org_cat_uniq UNIQUE (user_id, organization_id, category)
);

CREATE INDEX emails_notificationpreference_user_id_idx ON emails_notificationpreference(user_id);
CREATE INDEX emails_notificationpreference_organization_id_idx ON emails_notificationpreference(organization_id);

CREATE TABLE emails_emailsuppression (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    address VARCHAR(254) NOT NULL UNIQUE,
    reason VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX emails_emailsuppression_address_idx ON emails_emailsuppression(address);

CREATE TABLE emails_emailtemplateversion (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    template_key VARCHAR(128) NOT NULL,
    version VARCHAR(64) NOT NULL,
    checksum VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX emails_emailtemplateversion_key_idx ON emails_emailtemplateversion(template_key);

CREATE TABLE emails_campaign (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    key VARCHAR(128) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    subject_template VARCHAR(255) NOT NULL,
    body_template TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    trigger_rule TEXT NOT NULL DEFAULT '{}',
    score_floor_override BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX emails_campaign_key_idx ON emails_campaign(key);
CREATE INDEX emails_campaign_active_idx ON emails_campaign(active);

CREATE TABLE emails_campaignsend (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    campaign_id BIGINT NOT NULL REFERENCES emails_campaign(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    score_at_send BIGINT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    converted_at TIMESTAMPTZ,
    conversion_event VARCHAR(128)
);

CREATE INDEX emails_campaignsend_campaign_id_idx ON emails_campaignsend(campaign_id);
CREATE INDEX emails_campaignsend_user_id_idx ON emails_campaignsend(user_id);
CREATE INDEX emails_campaignsend_organization_id_idx ON emails_campaignsend(organization_id);
CREATE INDEX emails_campaignsend_user_campaign_idx ON emails_campaignsend(user_id, campaign_id, sent_at);

-- down
DROP TABLE emails_campaignsend;
DROP TABLE emails_campaign;
DROP TABLE emails_emailtemplateversion;
DROP TABLE emails_emailsuppression;
DROP TABLE emails_notificationpreference;
DROP TABLE emails_emaillog;
