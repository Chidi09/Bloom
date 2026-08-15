//! Route definitions for the `secrets` domain app.

use djangors_core::Router;
use hyper::http::Method;

use super::views;

/// Returns the router containing all secrets endpoints.
pub fn urls() -> Router {
    Router::new()
        .get("/secrets", views::list_secrets)
        .post("/secrets", views::create_or_update_secret)
        .get("/secrets/:id", views::retrieve_secret)
        // Router exposes get/post/put/delete helpers only; PATCH goes through `route`.
        .route("/secrets/:id", Method::PATCH, views::update_secret)
        .post("/secrets/:id/rollback", views::rollback_secret)
        .delete("/secrets/:id", views::delete_secret)
}
