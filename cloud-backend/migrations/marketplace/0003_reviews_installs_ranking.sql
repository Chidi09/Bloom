-- up
ALTER TABLE marketplace_template ADD COLUMN rating_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE marketplace_template ADD COLUMN rating_sum BIGINT NOT NULL DEFAULT 0;
ALTER TABLE marketplace_template ADD COLUMN rating_bayesian_milli BIGINT NOT NULL DEFAULT 0;
ALTER TABLE marketplace_template ADD COLUMN install_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE marketplace_template ADD COLUMN featured_type VARCHAR(32) NOT NULL DEFAULT 'none';
ALTER TABLE marketplace_template ADD COLUMN featured_until TIMESTAMPTZ;

CREATE INDEX marketplace_template_featured_type_idx ON marketplace_template(featured_type);
CREATE INDEX marketplace_template_rating_bayesian_idx ON marketplace_template(rating_bayesian_milli);
CREATE INDEX marketplace_template_install_count_idx ON marketplace_template(install_count);

ALTER TABLE marketplace_templateversion ADD COLUMN install_count BIGINT NOT NULL DEFAULT 0;

CREATE TABLE marketplace_templatereview (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    template_id BIGINT NOT NULL REFERENCES marketplace_template(id) ON DELETE CASCADE,
    buyer_organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    reviewer_user_id BIGINT NOT NULL,
    rating BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL DEFAULT '',
    comment TEXT NOT NULL DEFAULT '',
    status VARCHAR(32) NOT NULL DEFAULT 'published',
    author_response TEXT,
    author_responded_at TIMESTAMPTZ,
    author_responded_by_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(template_id, buyer_organization_id)
);

CREATE INDEX marketplace_templatereview_template_id_idx ON marketplace_templatereview(template_id);
CREATE INDEX marketplace_templatereview_buyer_org_idx ON marketplace_templatereview(buyer_organization_id);
CREATE INDEX marketplace_templatereview_status_idx ON marketplace_templatereview(status);

CREATE TABLE marketplace_reviewreport (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    review_id BIGINT NOT NULL REFERENCES marketplace_templatereview(id) ON DELETE CASCADE,
    reporter_organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    reporter_user_id BIGINT NOT NULL,
    reason VARCHAR(64) NOT NULL,
    details TEXT NOT NULL DEFAULT '',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX marketplace_reviewreport_review_id_idx ON marketplace_reviewreport(review_id);
CREATE INDEX marketplace_reviewreport_reporter_org_idx ON marketplace_reviewreport(reporter_organization_id);
CREATE INDEX marketplace_reviewreport_status_idx ON marketplace_reviewreport(status);

CREATE TABLE marketplace_templateinstalldedup (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    template_id BIGINT NOT NULL REFERENCES marketplace_template(id) ON DELETE CASCADE,
    template_version_id BIGINT REFERENCES marketplace_templateversion(id) ON DELETE SET NULL,
    actor_hash VARCHAR(64) NOT NULL,
    date_bucket VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(template_id, actor_hash, date_bucket)
);

CREATE INDEX marketplace_templateinstalldedup_lookup_idx ON marketplace_templateinstalldedup(template_id, actor_hash, date_bucket);

CREATE TABLE marketplace_templateinstall (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    template_id BIGINT NOT NULL REFERENCES marketplace_template(id) ON DELETE CASCADE,
    template_version_id BIGINT REFERENCES marketplace_templateversion(id) ON DELETE SET NULL,
    buyer_organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    installed_by_user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(template_id, buyer_organization_id)
);

CREATE INDEX marketplace_templateinstall_lookup_idx ON marketplace_templateinstall(template_id, buyer_organization_id);

-- down
DROP TABLE marketplace_templateinstall;
DROP TABLE marketplace_templateinstalldedup;
DROP TABLE marketplace_reviewreport;
DROP TABLE marketplace_templatereview;
ALTER TABLE marketplace_templateversion DROP COLUMN install_count;
ALTER TABLE marketplace_template DROP COLUMN featured_until;
ALTER TABLE marketplace_template DROP COLUMN featured_type;
ALTER TABLE marketplace_template DROP COLUMN install_count;
ALTER TABLE marketplace_template DROP COLUMN rating_bayesian_milli;
ALTER TABLE marketplace_template DROP COLUMN rating_sum;
ALTER TABLE marketplace_template DROP COLUMN rating_count;
