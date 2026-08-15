//! URL route definitions for the `emails` app.

use djangors_core::Router;
use hyper::http::Method;

use super::views;

/// Build and return the `emails` app router.
pub fn urls() -> Router {
    Router::new()
        .get("/notifications/preferences", views::list_preferences)
        .get("/notifications/preferences/", views::list_preferences)
        .route(
            "/notifications/preferences",
            Method::PATCH,
            views::update_preferences,
        )
        .route(
            "/notifications/preferences/",
            Method::PATCH,
            views::update_preferences,
        )
        .post("/notifications/unsubscribe", views::unsubscribe)
        .post("/notifications/unsubscribe/", views::unsubscribe)
        .get("/organizations/{id}/email-log", views::list_email_logs)
        .get("/organizations/{id}/email-log/", views::list_email_logs)
        .get("/admin/campaigns", views::list_campaigns)
        .get("/admin/campaigns/", views::list_campaigns)
        .post("/admin/campaigns", views::create_campaign)
        .post("/admin/campaigns/", views::create_campaign)
        .route(
            "/admin/campaigns/{id}",
            Method::PATCH,
            views::update_campaign,
        )
        .route(
            "/admin/campaigns/{id}/",
            Method::PATCH,
            views::update_campaign,
        )
        .get("/admin/campaigns/{id}/stats", views::campaign_stats)
        .get("/admin/campaigns/{id}/stats/", views::campaign_stats)
        .post("/admin/campaigns/{id}/preview", views::preview_campaign)
        .post("/admin/campaigns/{id}/preview/", views::preview_campaign)
}
