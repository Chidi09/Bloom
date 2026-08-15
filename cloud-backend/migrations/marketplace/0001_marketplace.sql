-- up
CREATE TABLE marketplace_template (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    description TEXT,
    visibility VARCHAR(32) NOT NULL DEFAULT 'private',
    status VARCHAR(32) NOT NULL DEFAULT 'draft',
    metadata TEXT NOT NULL DEFAULT '{}',
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id, slug)
);

CREATE INDEX marketplace_template_org_id_idx ON marketplace_template(organization_id);
CREATE INDEX marketplace_template_status_idx ON marketplace_template(status);
CREATE INDEX marketplace_template_visibility_idx ON marketplace_template(visibility);

CREATE TABLE marketplace_templateversion (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    template_id BIGINT NOT NULL REFERENCES marketplace_template(id) ON DELETE CASCADE,
    version VARCHAR(64) NOT NULL,
    changelog TEXT NOT NULL DEFAULT '',
    manifest TEXT NOT NULL DEFAULT '{}',
    readme TEXT NOT NULL DEFAULT '',
    created_by_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(template_id, version)
);

CREATE INDEX marketplace_templateversion_template_id_idx ON marketplace_templateversion(template_id);
CREATE INDEX marketplace_templateversion_version_idx ON marketplace_templateversion(version);

-- down
DROP TABLE marketplace_templateversion;
DROP TABLE marketplace_template;
