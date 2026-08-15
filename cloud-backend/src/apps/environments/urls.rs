//! Route definitions and endpoint registration for the `environments` app.

use djangors_core::Router;
use hyper::Method;

use super::views;

/// Build the environments app router.
pub fn urls() -> Router {
    Router::new()
        .get("/environments", views::list_environments)
        .post("/environments", views::create_environment)
        .get("/environments/{id}", views::retrieve_environment)
        .route(
            "/environments/{id}",
            Method::PATCH,
            views::update_environment,
        )
        .delete("/environments/{id}", views::delete_environment)
}
