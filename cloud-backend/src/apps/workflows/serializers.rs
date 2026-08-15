//! Serialization adapters and representation converters for `workflows`.

use serde_json::Value;

use super::contracts::{WorkflowResponse, WorkflowRunResponse, WorkflowRunStepResponse};
use super::models::{Workflow, WorkflowRun, WorkflowRunStep};

/// Serializes a [`WorkflowRunStep`] model instance into a [`WorkflowRunStepResponse`].
///
/// Ensures JSON text stored in `metadata` is parsed back to real JSON and never emitted as a raw string.
pub fn serialize_step(step: &WorkflowRunStep) -> WorkflowRunStepResponse {
    let metadata_value: Value =
        serde_json::from_str(&step.metadata).unwrap_or_else(|_| serde_json::json!({}));

    WorkflowRunStepResponse {
        id: step.public_id.clone(),
        step_order: step.step_order,
        name: step.name.clone(),
        step_kind: step.step_kind.clone(),
        status: step.status.clone(),
        requires_approval: step.requires_approval,
        started_at: step.started_at.map(|dt| dt.to_rfc3339()),
        finished_at: step.finished_at.map(|dt| dt.to_rfc3339()),
        log_snippet: step.log_snippet.clone(),
        metadata: metadata_value,
        created_at: step.created_at.to_rfc3339(),
    }
}

/// Serializes a [`Workflow`] model instance into a [`WorkflowResponse`].
pub fn serialize_workflow(
    workflow: &Workflow,
    app_public_id: &str,
    organization_public_id: &str,
    created_by_public_id: &str,
) -> WorkflowResponse {
    WorkflowResponse {
        id: workflow.public_id.clone(),
        app_id: app_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        name: workflow.name.clone(),
        slug: workflow.slug.clone(),
        description: workflow.description.clone(),
        definition: workflow.definition.clone(),
        is_active: workflow.is_active,
        created_by: created_by_public_id.to_string(),
        created_at: workflow.created_at.to_rfc3339(),
        updated_at: workflow.updated_at.to_rfc3339(),
    }
}

/// Serializes a [`WorkflowRun`] model instance with its steps into a [`WorkflowRunResponse`].
///
/// Ensures JSON text in `metadata` is parsed back to real JSON.
pub fn serialize_workflow_run(
    run: &WorkflowRun,
    steps: &[WorkflowRunStep],
    workflow_public_id: &str,
    organization_public_id: &str,
    created_by_public_id: &str,
    approved_by_public_id: Option<&str>,
) -> WorkflowRunResponse {
    let metadata_value: Value =
        serde_json::from_str(&run.metadata).unwrap_or_else(|_| serde_json::json!({}));

    WorkflowRunResponse {
        id: run.public_id.clone(),
        workflow_id: workflow_public_id.to_string(),
        organization_id: organization_public_id.to_string(),
        git_commit: run.git_commit.clone(),
        git_branch: run.git_branch.clone(),
        git_ref: run.git_ref.clone(),
        status: run.status.clone(),
        trigger_event: run.trigger_event.clone(),
        started_at: run.started_at.map(|dt| dt.to_rfc3339()),
        finished_at: run.finished_at.map(|dt| dt.to_rfc3339()),
        approved_by: approved_by_public_id.map(|s| s.to_string()),
        approved_at: run.approved_at.map(|dt| dt.to_rfc3339()),
        metadata: metadata_value,
        steps: steps.iter().map(serialize_step).collect(),
        created_by: created_by_public_id.to_string(),
        created_at: run.created_at.to_rfc3339(),
        updated_at: run.updated_at.to_rfc3339(),
    }
}
