-- up
CREATE TABLE releases_release (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    version VARCHAR(64) NOT NULL,
    build_number BIGINT NOT NULL,
    commit VARCHAR(40) NOT NULL,
    changelog TEXT NOT NULL DEFAULT '',
    environment_id BIGINT REFERENCES environments_environment(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL,
    platforms TEXT NOT NULL DEFAULT '[]',
    artifacts TEXT NOT NULL DEFAULT '[]',
    rollout_status TEXT NOT NULL DEFAULT '{}',
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX releases_release_app_id_idx ON releases_release(app_id);
CREATE INDEX releases_release_organization_id_idx ON releases_release(organization_id);
CREATE INDEX releases_release_status_idx ON releases_release(status);

-- down
DROP TABLE releases_release;
