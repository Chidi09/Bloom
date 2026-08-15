//! Route definitions and endpoint registration for the `apps` app.

use djangors_core::Router;
use hyper::Method;

use super::views;

/// Build the apps app router.
pub fn urls() -> Router {
    Router::new()
        .get("/apps", views::list_apps)
        .post("/apps", views::create_app)
        .post("/apps/link", views::link_app)
        .get("/apps/{id}", views::retrieve_app)
        .route("/apps/{id}", Method::PATCH, views::update_app)
        .delete("/apps/{id}", views::delete_app)
}
