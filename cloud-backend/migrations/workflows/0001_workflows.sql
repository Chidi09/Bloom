-- up
CREATE TABLE workflows_workflow (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    app_id BIGINT NOT NULL REFERENCES apps_app(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(64) NOT NULL,
    description VARCHAR(1000),
    definition TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(app_id, slug)
);

CREATE INDEX workflows_workflow_app_id_idx ON workflows_workflow(app_id);
CREATE INDEX workflows_workflow_organization_id_idx ON workflows_workflow(organization_id);

CREATE TABLE workflows_workflowrun (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    workflow_id BIGINT NOT NULL REFERENCES workflows_workflow(id) ON DELETE CASCADE,
    organization_id BIGINT NOT NULL REFERENCES organizations_organization(id) ON DELETE CASCADE,
    git_commit VARCHAR(40) NOT NULL,
    git_branch VARCHAR(255) NOT NULL,
    git_ref VARCHAR(255) NOT NULL,
    status VARCHAR(32) NOT NULL,
    trigger_event VARCHAR(64) NOT NULL,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    approved_by_id BIGINT REFERENCES auth_user(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_by_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX workflows_workflowrun_workflow_id_idx ON workflows_workflowrun(workflow_id);
CREATE INDEX workflows_workflowrun_organization_id_idx ON workflows_workflowrun(organization_id);
CREATE INDEX workflows_workflowrun_status_idx ON workflows_workflowrun(status);

CREATE TABLE workflows_workflowrunstep (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(36) NOT NULL UNIQUE,
    run_id BIGINT NOT NULL REFERENCES workflows_workflowrun(id) ON DELETE CASCADE,
    step_order BIGINT NOT NULL,
    name VARCHAR(128) NOT NULL,
    step_kind VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    log_snippet TEXT,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(run_id, step_order)
);

CREATE INDEX workflows_workflowrunstep_run_id_idx ON workflows_workflowrunstep(run_id);

-- down
DROP TABLE workflows_workflowrunstep;
DROP TABLE workflows_workflowrun;
DROP TABLE workflows_workflow;
