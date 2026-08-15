//! Route definitions and endpoint registration for the `projects` app.

use djangors_core::Router;
use hyper::Method;

use super::views;

/// Build the projects router.
pub fn urls() -> Router {
    Router::new()
        .get("/projects", views::list_projects)
        .post("/projects", views::create_project)
        .get("/projects/{id}", views::retrieve_project)
        .route("/projects/{id}", Method::PATCH, views::update_project)
        .delete("/projects/{id}", views::delete_project)
}
