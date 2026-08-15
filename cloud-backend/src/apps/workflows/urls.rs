//! Route definitions and endpoint registration for the `workflows` app.

use djangors_core::Router;

use super::views;

/// Build the workflows app router.
///
/// Mounted under `/api/v1` (with prefix `/workflows`).
pub fn urls() -> Router {
    Router::new()
        .get("/workflows", views::list_workflows)
        .post("/workflows", views::create_workflow)
        .get("/workflows/{id}", views::retrieve_workflow)
        .get("/workflows/{id}/runs", views::list_workflow_runs)
        .post("/workflows/{id}/runs", views::create_workflow_run)
        .get("/workflows/runs/{id}", views::retrieve_workflow_run)
        .post("/workflows/runs/{id}/approve", views::approve_workflow_run)
}
