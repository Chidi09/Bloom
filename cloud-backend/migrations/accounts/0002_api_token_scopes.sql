-- up
ALTER TABLE accounts_apitoken ADD COLUMN scopes TEXT NOT NULL DEFAULT '["*"]';
ALTER TABLE accounts_apitoken ADD COLUMN expires_at TIMESTAMPTZ;
ALTER TABLE accounts_apitoken ADD COLUMN organization_id BIGINT REFERENCES organizations_organization(id) ON DELETE SET NULL;
CREATE INDEX accounts_apitoken_organization_id_idx ON accounts_apitoken(organization_id);

-- down
DROP INDEX IF EXISTS accounts_apitoken_organization_id_idx;
ALTER TABLE accounts_apitoken DROP COLUMN organization_id;
ALTER TABLE accounts_apitoken DROP COLUMN expires_at;
ALTER TABLE accounts_apitoken DROP COLUMN scopes;
