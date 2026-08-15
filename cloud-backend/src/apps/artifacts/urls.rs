//! Route definitions and endpoint registration for the `artifacts` app.

use djangors_core::Router;

use super::views;

/// Build the artifacts app router.
///
/// The worker registration endpoint is mounted under `/workers/jobs/{id}/artifact` so
/// that, composed at `/api/v1`, it serves the internal worker path
/// `/api/v1/workers/jobs/{id}/artifact`. It is registered here because `artifacts.md`
/// lists it as part of this app's contract.
pub fn urls() -> Router {
    Router::new()
        .get("/artifacts", views::list_artifacts)
        .get("/artifacts/{id}", views::retrieve_artifact)
        .get("/artifacts/{id}/download", views::download_artifact)
        .post("/workers/jobs/{id}/artifact", views::register_artifact)
}
