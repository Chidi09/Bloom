-- up
CREATE TABLE accounts_userprofile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    display_name VARCHAR(255),
    avatar_url VARCHAR(500),
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE accounts_apitoken (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX accounts_apitoken_user_id_idx ON accounts_apitoken(user_id);

CREATE TABLE accounts_deviceflowrequest (
    id BIGSERIAL PRIMARY KEY,
    device_code VARCHAR(80) NOT NULL UNIQUE,
    user_code VARCHAR(16) NOT NULL,
    status VARCHAR(32) NOT NULL,
    user_id BIGINT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX accounts_deviceflowrequest_user_code_idx ON accounts_deviceflowrequest(user_code);
CREATE INDEX accounts_deviceflowrequest_expires_at_idx ON accounts_deviceflowrequest(expires_at);

-- down
DROP TABLE accounts_deviceflowrequest;
DROP TABLE accounts_apitoken;
DROP TABLE accounts_userprofile;
