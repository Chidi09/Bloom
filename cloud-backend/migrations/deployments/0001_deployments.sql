-- up
CREATE TABLE deployments_deployment (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    release_id BIGINT REFERENCES releases_release(id) ON DELETE SET NULL,
    artifact_id BIGINT REFERENCES artifacts_artifact(id) ON DELETE SET NULL,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    target VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    external_id VARCHAR(255),
    external_url VARCHAR(500),
    error_message TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX deployments_deployment_release_id_idx ON deployments_deployment(release_id);
CREATE INDEX deployments_deployment_organization_id_idx ON deployments_deployment(organization_id);
CREATE INDEX deployments_deployment_status_idx ON deployments_deployment(status);

-- down
DROP TABLE deployments_deployment;
