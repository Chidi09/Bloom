-- up
CREATE TABLE events_eventlog (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    event_id VARCHAR(36) NOT NULL UNIQUE,
    event_type VARCHAR(128) NOT NULL,
    organization_id BIGINT,
    project_id BIGINT,
    app_id BIGINT,
    actor_id BIGINT,
    payload TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX events_eventlog_event_type_idx ON events_eventlog(event_type);
CREATE INDEX events_eventlog_organization_id_idx ON events_eventlog(organization_id);
CREATE INDEX events_eventlog_app_id_idx ON events_eventlog(app_id);
CREATE INDEX events_eventlog_created_at_idx ON events_eventlog(created_at);

-- down
DROP TABLE events_eventlog;