-- up
CREATE TABLE artifacts_artifact (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    build_id BIGINT NOT NULL REFERENCES builds_build(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    kind VARCHAR(32) NOT NULL,
    storage_key VARCHAR(500) NOT NULL,
    storage_bucket VARCHAR(255) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    checksum VARCHAR(64) NOT NULL,
    version VARCHAR(64) NOT NULL,
    build_number BIGINT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX artifacts_artifact_build_id_idx ON artifacts_artifact(build_id);
CREATE INDEX artifacts_artifact_organization_id_idx ON artifacts_artifact(organization_id);

-- down
DROP TABLE artifacts_artifact;
