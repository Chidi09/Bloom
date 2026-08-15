//! Persistence models for the `workflows` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// A workflow definition scoped to an application and tenant organization.
///
/// Holds the YAML workflow definition as authored, with metadata and active status.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "workflows",
    table_name = "workflows_workflow",
    unique_together = [["app_id", "slug"]]
)]
pub struct Workflow {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent application.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub app_id: ForeignKey<crate::apps::apps::models::App>,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Human-readable workflow name.
    #[djangors(max_length = 255)]
    pub name: String,

    /// URL-safe slug unique per application.
    #[djangors(max_length = 64)]
    pub slug: String,

    /// Optional markdown description of the workflow.
    #[djangors(max_length = 1000, nullable)]
    pub description: Option<String>,

    /// Raw workflow definition (YAML stored as text).
    pub definition: String,

    /// Whether this workflow is enabled for automatic trigger executions.
    #[djangors(default = true)]
    pub is_active: bool,

    /// Internal primary key of the user who created this workflow.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Workflow {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// A workflow run execution record representing one execution instance of a workflow.
#[derive(Model, Debug, Clone)]
#[djangors(app = "workflows", table_name = "workflows_workflowrun")]
pub struct WorkflowRun {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent workflow.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub workflow_id: ForeignKey<Workflow>,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Git commit SHA being built/executed in this run.
    #[djangors(max_length = 40)]
    pub git_commit: String,

    /// Git branch for this run.
    #[djangors(max_length = 255)]
    pub git_branch: String,

    /// Git ref or tag for this run.
    #[djangors(max_length = 255)]
    pub git_ref: String,

    /// Execution status: `pending`, `running`, `blocked`, `success`, `failed`, or `cancelled`.
    #[djangors(max_length = 32, db_index)]
    pub status: String,

    /// Event or mechanism that triggered this run (e.g. `manual`, `push`, `pull_request`, `schedule`).
    #[djangors(max_length = 64)]
    pub trigger_event: String,

    /// Timestamp when execution began.
    #[djangors(nullable)]
    pub started_at: Option<DateTime<Utc>>,

    /// Timestamp when execution completed or reached a terminal status.
    #[djangors(nullable)]
    pub finished_at: Option<DateTime<Utc>>,

    /// Internal primary key of the user who approved the run gate (if approval gate required).
    #[djangors(nullable)]
    pub approved_by_id: Option<i64>,

    /// Timestamp when the run gate was approved.
    #[djangors(nullable)]
    pub approved_at: Option<DateTime<Utc>>,

    /// JSON text of worker/engine execution metadata.
    #[djangors(default = "{}")]
    pub metadata: String,

    /// Internal primary key of the user who initiated this run (or creator if manual).
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for WorkflowRun {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// An individual ordered step within a workflow run execution.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "workflows",
    table_name = "workflows_workflowrunstep",
    unique_together = [["run_id", "step_order"]]
)]
pub struct WorkflowRunStep {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent workflow run.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub run_id: ForeignKey<WorkflowRun>,

    /// Explicit execution order index (1-indexed).
    pub step_order: i64,

    /// Human-readable step name or job identifier.
    #[djangors(max_length = 128)]
    pub name: String,

    /// Step kind: `test`, `build`, `deploy_preview`, `approval_gate`, `deploy_production`, or `custom`.
    #[djangors(max_length = 64)]
    pub step_kind: String,

    /// Step execution status: `pending`, `running`, `blocked`, `completed`, `failed`, or `skipped`.
    #[djangors(max_length = 32)]
    pub status: String,

    /// Whether this step acts as an approval gate requiring manual decision before proceeding.
    #[djangors(default = false)]
    pub requires_approval: bool,

    /// Timestamp when this step began running.
    #[djangors(nullable)]
    pub started_at: Option<DateTime<Utc>>,

    /// Timestamp when this step reached a terminal status.
    #[djangors(nullable)]
    pub finished_at: Option<DateTime<Utc>>,

    /// Optional tail of the step execution log.
    #[djangors(nullable)]
    pub log_snippet: Option<String>,

    /// JSON text containing step-specific configuration and output metadata.
    #[djangors(default = "{}")]
    pub metadata: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}
