//! Route definitions and endpoint registration for the `signing` app.

use djangors_core::Router;

use super::views;

/// Build the signing router.
pub fn urls() -> Router {
    Router::new()
        .get("/signing", views::list_signing_identities)
        .post("/signing", views::upload_signing_identity)
        .get("/signing/{id}", views::retrieve_signing_identity)
        .delete("/signing/{id}", views::delete_signing_identity)
        .get("/signing/:id", views::retrieve_signing_identity)
        .delete("/signing/:id", views::delete_signing_identity)
}
