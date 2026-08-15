-- up
CREATE TABLE git_connections_gitconnection (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL,
    installation_id VARCHAR(255) NOT NULL,
    encrypted_access_token TEXT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX git_connections_gitconnection_organization_id_idx ON git_connections_gitconnection(organization_id);

CREATE TABLE git_connections_webhookdelivery (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    provider VARCHAR(32) NOT NULL,
    delivery_id VARCHAR(255) NOT NULL UNIQUE,
    event_type VARCHAR(64) NOT NULL,
    payload TEXT NOT NULL DEFAULT '{}',
    status VARCHAR(32) NOT NULL DEFAULT 'received',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX git_connections_webhookdelivery_delivery_id_idx ON git_connections_webhookdelivery(delivery_id);
CREATE INDEX git_connections_webhookdelivery_provider_idx ON git_connections_webhookdelivery(provider);

-- down
DROP TABLE git_connections_webhookdelivery;
DROP TABLE git_connections_gitconnection;
