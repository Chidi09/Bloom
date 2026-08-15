-- up
CREATE TABLE organizations_organization (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL UNIQUE,
    plan VARCHAR(32) NOT NULL DEFAULT 'free',
    billing_email VARCHAR(254),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE organizations_userorganizationmembership (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, organization_id)
);

CREATE INDEX organizations_membership_org_id_idx ON organizations_userorganizationmembership(organization_id);
CREATE INDEX organizations_membership_user_id_idx ON organizations_userorganizationmembership(user_id);

CREATE TABLE organizations_organizationinvite (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    email VARCHAR(254) NOT NULL,
    role VARCHAR(32) NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX organizations_invite_token_idx ON organizations_organizationinvite(token);
CREATE INDEX organizations_invite_org_id_idx ON organizations_organizationinvite(organization_id);

-- down
DROP TABLE organizations_organizationinvite;
DROP TABLE organizations_userorganizationmembership;
DROP TABLE organizations_organization;
