//! Route definitions and endpoint registration for the `git_connections` app.

use djangors_core::Router;

use super::views;

/// Build and return the `git_connections` app router matching the spec in `docs/apps/git_connections.md`.
pub fn urls() -> Router {
    Router::new()
        .get("/git-connections", views::list_connections)
        .post("/git-connections", views::create_connection)
        .get("/git-connections/{id}", views::retrieve_connection)
        .get(
            "/git-connections/{id}/repositories",
            views::list_repositories,
        )
        .delete("/git-connections/{id}", views::delete_connection)
        .post("/webhooks/github", views::github_webhook)
        .post("/webhooks/gitlab", views::gitlab_webhook)
        .post("/webhooks/bitbucket", views::bitbucket_webhook)
}
