-- up
CREATE TABLE observability_releasehealthsnapshot (
    id BIGSERIAL PRIMARY KEY,
    release_id BIGINT NOT NULL REFERENCES releases_release(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    target VARCHAR(32) NOT NULL,
    crash_free_rate DOUBLE PRECISION,
    sessions BIGINT,
    crashes BIGINT,
    active_users BIGINT,
    metric_data TEXT NOT NULL DEFAULT '{}',
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX observability_releasehealthsnapshot_release_id_idx ON observability_releasehealthsnapshot(release_id);

CREATE TABLE observability_platformmetric (
    id BIGSERIAL PRIMARY KEY,
    deployment_id BIGINT NOT NULL REFERENCES deployments_deployment(id) ON DELETE CASCADE,
    metric_type VARCHAR(32) NOT NULL,
    value BIGINT NOT NULL,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX observability_platformmetric_deployment_id_idx ON observability_platformmetric(deployment_id);

-- down
DROP TABLE observability_platformmetric;
DROP TABLE observability_releasehealthsnapshot;
