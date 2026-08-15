-- up
CREATE TABLE projects_project (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id, slug)
);

CREATE INDEX projects_project_org_id_idx ON projects_project(organization_id);

-- down
DROP TABLE projects_project;
