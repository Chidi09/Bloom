//! Route definitions and endpoint registration for the `builds` app.

use djangors_core::Router;

use super::views;

/// Build the builds app router.
///
/// Tenant-facing routes live under `/api/v1` (the reviewer mounts this router at `""`).
/// The worker-facing routes (`/workers/jobs/{id}/...`) are the same shape the `artifacts`
/// app uses so a worker shares one job-token flow across both.
pub fn urls() -> Router {
    Router::new()
        .get("/builds", views::list_builds)
        .post("/builds", views::create_build)
        .get("/builds/{id}", views::retrieve_build)
        .post("/builds/{id}/cancel", views::cancel_build)
        .get("/builds/{id}/logs", views::build_logs)
        .post("/workers/jobs/{id}/stage", views::update_build_stage)
        .post("/workers/jobs/{id}/complete", views::complete_build)
}
