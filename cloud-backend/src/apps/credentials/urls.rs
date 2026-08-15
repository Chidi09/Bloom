//! Route definitions and endpoint registration for the `credentials` app.

use djangors_core::Router;

use super::views;

/// Build the credentials router matching the contract in `docs/apps/credentials.md`.
pub fn urls() -> Router {
    Router::new()
        .get("/credentials", views::list_credentials)
        .post("/credentials", views::create_credential)
        .get("/credentials/{id}", views::retrieve_credential)
        .post("/credentials/{id}/test", views::test_credential)
        .delete("/credentials/{id}", views::delete_credential)
}
