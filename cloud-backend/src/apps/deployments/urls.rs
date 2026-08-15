//! URL route definitions for the `deployments` app.

use djangors_core::Router;

use super::views;

/// Build and return the `deployments` app router.
pub fn urls() -> Router {
    Router::new()
        .get("/deployments", views::list_deployments)
        .post("/deployments", views::create_deployment)
        .get("/deployments/:id", views::retrieve_deployment)
        .post("/deployments/:id/rollback", views::rollback_deployment)
}
