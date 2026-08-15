//! Route definitions and endpoint registration for the `organizations` app.

use djangors_core::Router;
use hyper::Method;

use super::views;

/// Build the organizations router.
pub fn urls() -> Router {
    Router::new()
        .get("/organizations", views::list_organizations)
        .post("/organizations", views::create_organization)
        .get("/organizations/current", views::current_organization)
        .get("/organizations/{id}", views::retrieve_organization)
        .route(
            "/organizations/{id}",
            Method::PATCH,
            views::update_organization,
        )
        .delete("/organizations/{id}", views::delete_organization)
        .get("/organizations/{id}/members", views::list_members)
        .post("/organizations/{id}/members", views::invite_member)
        .route(
            "/organizations/{id}/members/{member_id}",
            Method::PATCH,
            views::change_role,
        )
        .delete(
            "/organizations/{id}/members/{member_id}",
            views::remove_member,
        )
        .post("/organizations/invites/accept", views::accept_invite)
}
