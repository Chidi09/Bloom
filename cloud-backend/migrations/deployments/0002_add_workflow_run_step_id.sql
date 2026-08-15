-- Migration: 0002_add_workflow_run_step_id.sql
-- Domain: deployments
-- Purpose: Link a deployment back to the workflow run step waiting on it (Phase 11 resumption).
--
-- The mirror of migrations/builds/0002: a parked workflow run is woken by its child reaching a
-- terminal state, and this is the edge it is woken through. Nullable because most deployments
-- are started directly; ON DELETE SET NULL so run history can be discarded independently.

-- up
ALTER TABLE deployments_deployment ADD COLUMN workflow_run_step_id BIGINT REFERENCES workflows_workflowrunstep(id) ON DELETE SET NULL;
CREATE INDEX deployments_deployment_workflow_run_step_id_idx ON deployments_deployment(workflow_run_step_id);

-- down
DROP INDEX IF EXISTS deployments_deployment_workflow_run_step_id_idx;
ALTER TABLE deployments_deployment DROP COLUMN IF EXISTS workflow_run_step_id;
