//! URL route definitions for the `webhosting` app.

use djangors_core::Router;

use super::views;

/// Build and return the `webhosting` app router.
pub fn urls() -> Router {
    Router::new()
        .get("/webhosting/deployments", views::list_web_deployments)
        .post("/webhosting/deployments", views::deploy_web)
        .get(
            "/webhosting/deployments/:id",
            views::retrieve_web_deployment,
        )
        .post(
            "/webhosting/deployments/:id/rollback",
            views::rollback_web_deployment,
        )
        .get("/webhosting/domains", views::list_custom_domains)
        .post("/webhosting/domains", views::create_custom_domain)
        .get("/webhosting/domains/:id", views::retrieve_custom_domain)
        .post(
            "/webhosting/domains/:id/verify",
            views::verify_custom_domain,
        )
        .delete("/webhosting/domains/:id", views::delete_custom_domain)
}
