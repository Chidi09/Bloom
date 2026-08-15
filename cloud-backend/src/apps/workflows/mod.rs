//! CI/CD workflows: workflow definitions, execution engine, and approval gates.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

pub use models::{Workflow, WorkflowRun, WorkflowRunStep};
pub use services::{
    approve_workflow_run, can_run_transition, can_step_transition, create_workflow,
    create_workflow_run, get_workflow, get_workflow_run, list_workflow_runs, list_workflows,
};

/// Build the workflows app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
