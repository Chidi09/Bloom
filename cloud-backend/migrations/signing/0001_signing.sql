-- up
CREATE TABLE signing_signingidentity (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    kind VARCHAR(32) NOT NULL,
    encrypted_material TEXT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX signing_signingidentity_organization_id_idx ON signing_signingidentity(organization_id);

-- down
DROP TABLE signing_signingidentity;
