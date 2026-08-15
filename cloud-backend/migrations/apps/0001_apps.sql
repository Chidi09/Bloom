-- up
CREATE TABLE apps_app (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    project_id BIGINT NOT NULL REFERENCES projects_project(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    repository_url VARCHAR(500),
    default_branch VARCHAR(255) NOT NULL DEFAULT 'main',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(project_id, slug)
);

CREATE INDEX apps_app_project_id_idx ON apps_app(project_id);
CREATE INDEX apps_app_organization_id_idx ON apps_app(organization_id);

-- down
DROP TABLE apps_app;
