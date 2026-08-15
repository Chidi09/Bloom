-- up
CREATE TABLE builds_build (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    environment_id BIGINT NOT NULL REFERENCES environments_environment(id) ON DELETE CASCADE,
    git_commit VARCHAR(40),
    git_branch VARCHAR(255),
    git_ref VARCHAR(255),
    status VARCHAR(32) NOT NULL,
    platform VARCHAR(32) NOT NULL,
    build_profile VARCHAR(32) NOT NULL,
    flutter_version VARCHAR(64),
    dart_version VARCHAR(64),
    bloom_version VARCHAR(64),
    flavor VARCHAR(64),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    logs_url VARCHAR(500),
    worker_id VARCHAR(64),
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX builds_build_app_id_idx ON builds_build(app_id);
CREATE INDEX builds_build_organization_id_idx ON builds_build(organization_id);
CREATE INDEX builds_build_status_idx ON builds_build(status);

CREATE TABLE builds_buildstage (
    id BIGSERIAL PRIMARY KEY,
    build_id BIGINT NOT NULL REFERENCES builds_build(id) ON DELETE CASCADE,
    stage VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    log_snippet TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(build_id, stage)
);

CREATE INDEX builds_buildstage_build_id_idx ON builds_buildstage(build_id);

-- down
DROP TABLE builds_buildstage;
DROP TABLE builds_build;
