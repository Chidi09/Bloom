-- up
CREATE TABLE webhosting_webdeployment (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    artifact_id BIGINT NOT NULL REFERENCES artifacts_artifact(id) ON DELETE CASCADE,
    release_id BIGINT REFERENCES releases_release(id) ON DELETE SET NULL,
    target VARCHAR(32) NOT NULL,
    url VARCHAR(500) NOT NULL,
    storage_prefix VARCHAR(500) NOT NULL,
    status VARCHAR(32) NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    deployed_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX webhosting_webdeployment_app_id_idx ON webhosting_webdeployment(app_id);
CREATE INDEX webhosting_webdeployment_organization_id_idx ON webhosting_webdeployment(organization_id);

CREATE TABLE webhosting_customdomain (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    domain VARCHAR(255) NOT NULL,
    certificate_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    certificate_expires_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(app_id, domain)
);

CREATE INDEX webhosting_customdomain_app_id_idx ON webhosting_customdomain(app_id);
CREATE INDEX webhosting_customdomain_organization_id_idx ON webhosting_customdomain(organization_id);

-- down
DROP TABLE webhosting_customdomain;
DROP TABLE webhosting_webdeployment;
