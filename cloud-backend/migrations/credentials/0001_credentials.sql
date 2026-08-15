-- up
CREATE TABLE credentials_credential (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    encrypted_token TEXT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX credentials_credential_organization_id_idx ON credentials_credential(organization_id);

-- down
DROP TABLE credentials_credential;
