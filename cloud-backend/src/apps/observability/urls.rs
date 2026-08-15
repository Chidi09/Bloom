//! Route definitions and endpoint registration for the `observability` app.

use djangors_core::Router;

use super::views;

/// Build the observability app router.
pub fn urls() -> Router {
    Router::new()
        .get("/observability/apps/:id/status", views::app_status)
        .get("/observability/apps/{id}/status", views::app_status)
        .get("/observability/apps/:id/health", views::app_health)
        .get("/observability/apps/{id}/health", views::app_health)
        .get("/observability/releases/:id/health", views::release_health)
        .get("/observability/releases/{id}/health", views::release_health)
}
