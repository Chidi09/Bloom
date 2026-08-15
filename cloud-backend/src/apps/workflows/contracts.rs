//! HTTP contracts (request and response DTOs) for the `workflows` app.

use serde::{Deserialize, Serialize};

/// Request payload to create a new workflow definition.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct WorkflowCreateRequest {
    /// Public UUID of the parent application.
    pub app_id: String,
    /// Human-readable workflow name.
    pub name: String,
    /// URL-safe slug unique per application.
    pub slug: String,
    /// Optional workflow description.
    #[serde(default)]
    pub description: Option<String>,
    /// Workflow definition as YAML text.
    pub definition: String,
    /// Whether this workflow is enabled for automatic executions.
    #[serde(default = "default_true")]
    pub is_active: bool,
}

fn default_true() -> bool {
    true
}

/// Request payload to trigger a new execution run of a workflow.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct WorkflowRunCreateRequest {
    /// Optional Git commit SHA to execute (defaults to latest branch head if empty).
    #[serde(default)]
    pub git_commit: Option<String>,
    /// Optional Git branch (defaults to app's default branch if not provided).
    #[serde(default)]
    pub git_branch: Option<String>,
    /// Optional Git ref or tag.
    #[serde(default)]
    pub git_ref: Option<String>,
    /// Trigger event identifier, defaults to "manual".
    #[serde(default = "default_trigger_manual")]
    pub trigger_event: String,
}

fn default_trigger_manual() -> String {
    "manual".to_string()
}

/// Request payload to approve or reject a blocked workflow run at an approval gate.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct WorkflowApproveRequest {
    /// True to approve and resume execution; false to reject and terminate the run.
    pub approved: bool,
    /// Optional reason or comment for the decision.
    #[serde(default)]
    pub reason: Option<String>,
}

/// Wire representation of an individual workflow run step.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WorkflowRunStepResponse {
    /// Public UUID identifier of the step.
    pub id: String,
    /// Ordered execution sequence index (1-indexed).
    pub step_order: i64,
    /// Step or job name.
    pub name: String,
    /// Step kind (`test`, `build`, `deploy_preview`, `approval_gate`, `deploy_production`, `custom`).
    pub step_kind: String,
    /// Step status (`pending`, `running`, `blocked`, `completed`, `failed`, `skipped`).
    pub status: String,
    /// Whether this step requires manual approval.
    pub requires_approval: bool,
    /// ISO 8601 timestamp when step execution began.
    pub started_at: Option<String>,
    /// ISO 8601 timestamp when step execution completed.
    pub finished_at: Option<String>,
    /// Optional tail log snippet.
    pub log_snippet: Option<String>,
    /// Step metadata as parsed JSON.
    pub metadata: serde_json::Value,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
}

/// Wire representation of a `Workflow`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WorkflowResponse {
    /// Public UUID identifier of the workflow.
    pub id: String,
    /// Public UUID identifier of the parent application.
    pub app_id: String,
    /// Public UUID identifier of the owning organization.
    pub organization_id: String,
    /// Human-readable workflow name.
    pub name: String,
    /// URL-safe slug unique per application.
    pub slug: String,
    /// Optional workflow description.
    pub description: Option<String>,
    /// Workflow definition as YAML text.
    pub definition: String,
    /// Whether this workflow is enabled.
    pub is_active: bool,
    /// Public identifier of the creator user.
    pub created_by: String,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
    /// ISO 8601 last update timestamp.
    pub updated_at: String,
}

/// Wire representation of a `WorkflowRun`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WorkflowRunResponse {
    /// Public UUID identifier of the workflow run.
    pub id: String,
    /// Public UUID identifier of the parent workflow.
    pub workflow_id: String,
    /// Public UUID identifier of the owning organization.
    pub organization_id: String,
    /// Git commit SHA executed in this run.
    pub git_commit: String,
    /// Git branch executed in this run.
    pub git_branch: String,
    /// Git ref executed in this run.
    pub git_ref: String,
    /// Execution status (`pending`, `running`, `blocked`, `success`, `failed`, `cancelled`).
    pub status: String,
    /// Trigger event identifier.
    pub trigger_event: String,
    /// ISO 8601 timestamp when execution began.
    pub started_at: Option<String>,
    /// ISO 8601 timestamp when execution completed.
    pub finished_at: Option<String>,
    /// Public identifier of the user who approved this run (if approved).
    pub approved_by: Option<String>,
    /// ISO 8601 timestamp when approval was granted.
    pub approved_at: Option<String>,
    /// Run execution metadata as parsed JSON.
    pub metadata: serde_json::Value,
    /// Ordered steps in this workflow run.
    pub steps: Vec<WorkflowRunStepResponse>,
    /// Public identifier of the user who initiated this run.
    pub created_by: String,
    /// ISO 8601 creation timestamp.
    pub created_at: String,
    /// ISO 8601 last update timestamp.
    pub updated_at: String,
}
