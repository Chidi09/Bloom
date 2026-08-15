-- up
CREATE TABLE environments_environment (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    api_config TEXT NOT NULL DEFAULT '{}',
    build_profile VARCHAR(32) NOT NULL DEFAULT 'release',
    flutter_version VARCHAR(64),
    dart_version VARCHAR(64),
    bloom_version VARCHAR(64),
    flavor VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(app_id, slug)
);

CREATE INDEX environments_environment_app_id_idx ON environments_environment(app_id);
CREATE INDEX environments_environment_organization_id_idx ON environments_environment(organization_id);

-- down
DROP TABLE environments_environment;
