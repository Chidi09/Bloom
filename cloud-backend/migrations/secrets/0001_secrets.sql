-- up
CREATE TABLE secrets_secret (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    encrypted_value TEXT NOT NULL,
    is_json BOOLEAN NOT NULL DEFAULT FALSE,
    version BIGINT NOT NULL DEFAULT 1,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(environment_id, key)
);

CREATE INDEX secrets_secret_environment_id_idx ON secrets_secret(environment_id);
CREATE INDEX secrets_secret_organization_id_idx ON secrets_secret(organization_id);

CREATE TABLE secrets_secretversion (
    id BIGSERIAL PRIMARY KEY,
    secret_id BIGINT NOT NULL REFERENCES secrets_secret(id) ON DELETE CASCADE,
    encrypted_value TEXT NOT NULL,
    version BIGINT NOT NULL,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX secrets_secretversion_secret_id_idx ON secrets_secretversion(secret_id);

-- down
DROP TABLE secrets_secretversion;
DROP TABLE secrets_secret;
