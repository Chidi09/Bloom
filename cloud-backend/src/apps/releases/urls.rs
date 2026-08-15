//! Route definitions and endpoint registration for the `releases` app.

use djangors_core::Router;
use hyper::Method;

use super::views;

/// Build the releases app router.
pub fn urls() -> Router {
    Router::new()
        .get("/releases", views::list_releases)
        .post("/releases", views::create_release)
        .get("/releases/{id}", views::retrieve_release)
        .route("/releases/{id}", Method::PATCH, views::update_release)
        .post("/releases/{id}/approve", views::approve_release)
        .post("/releases/{id}/rollback", views::rollback_release)
        .get("/releases/:id", views::retrieve_release)
        .route("/releases/:id", Method::PATCH, views::update_release)
        .post("/releases/:id/approve", views::approve_release)
        .post("/releases/:id/rollback", views::rollback_release)
}
