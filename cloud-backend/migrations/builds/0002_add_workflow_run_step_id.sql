-- Migration: 0002_add_workflow_run_step_id.sql
-- Domain: builds
-- Purpose: Link a build back to the workflow run step waiting on it (Phase 11 resumption).
--
-- A workflow step that starts a build parks its run and releases the worker slot. When the
-- build reaches a terminal state it re-enqueues the parent run through this link. Nullable
-- because most builds are started directly and belong to no workflow; ON DELETE SET NULL so
-- discarding a run's history never cascades into deleting build records.

-- up
ALTER TABLE builds_build ADD COLUMN workflow_run_step_id BIGINT REFERENCES workflows_workflowrunstep(id) ON DELETE SET NULL;
CREATE INDEX builds_build_workflow_run_step_id_idx ON builds_build(workflow_run_step_id);

-- down
DROP INDEX IF EXISTS builds_build_workflow_run_step_id_idx;
ALTER TABLE builds_build DROP COLUMN IF EXISTS workflow_run_step_id;
