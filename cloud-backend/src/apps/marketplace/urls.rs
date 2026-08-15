//! Route definitions and endpoint registration for the `marketplace` app.

use djangors_core::Router;
use hyper::Method;

use super::views;

/// Build the marketplace and templates router.
pub fn urls() -> Router {
    Router::new()
        // Public marketplace discovery routes (no organization required)
        .get("/marketplace/templates", views::list_marketplace_templates)
        .get(
            "/marketplace/templates/{id}",
            views::retrieve_marketplace_template,
        )
        .get(
            "/marketplace/templates/:id",
            views::retrieve_marketplace_template,
        )
        .get(
            "/marketplace/templates/{id}/versions/{version_id}",
            views::retrieve_marketplace_template_version,
        )
        .get(
            "/marketplace/templates/:id/versions/:version_id",
            views::retrieve_marketplace_template_version,
        )
        // Seller Onboarding & Payouts (Stripe Connect Express)
        .get(
            "/marketplace/seller/account",
            views::retrieve_seller_account,
        )
        .post(
            "/marketplace/seller/onboarding",
            views::create_seller_onboarding,
        )
        .post("/marketplace/seller/refresh", views::refresh_seller_status)
        // Purchases, Entitlements & Refunds
        .post(
            "/marketplace/templates/{id}/purchase",
            views::purchase_template,
        )
        .post(
            "/marketplace/templates/:id/purchase",
            views::purchase_template,
        )
        .post("/templates/{id}/purchase", views::purchase_template)
        .post("/templates/:id/purchase", views::purchase_template)
        .get("/marketplace/purchases", views::list_purchases)
        .get("/marketplace/purchases/{id}", views::retrieve_purchase)
        .get("/marketplace/purchases/:id", views::retrieve_purchase)
        .post("/marketplace/purchases/{id}/refund", views::refund_purchase)
        .post("/marketplace/purchases/:id/refund", views::refund_purchase)
        // Entitlement checks for downloads
        .get("/templates/{id}/download", views::download_template)
        .get("/templates/:id/download", views::download_template)
        .get(
            "/templates/{id}/versions/{version_id}/download",
            views::download_template_version,
        )
        .get(
            "/templates/:id/versions/:version_id/download",
            views::download_template_version,
        )
        // Organization-scoped template management routes
        .get("/templates", views::list_templates)
        .post("/templates", views::create_template)
        .get("/templates/{id}", views::retrieve_template)
        .get("/templates/:id", views::retrieve_template)
        .route("/templates/{id}", Method::PATCH, views::update_template)
        .route("/templates/:id", Method::PATCH, views::update_template)
        .delete("/templates/{id}", views::delete_template)
        .delete("/templates/:id", views::delete_template)
        .post("/templates/{id}/publish", views::publish_template)
        .post("/templates/:id/publish", views::publish_template)
        .post("/templates/{id}/archive", views::archive_template)
        .post("/templates/:id/archive", views::archive_template)
        // Organization-scoped template version management routes
        .get("/templates/{id}/versions", views::list_template_versions)
        .get("/templates/:id/versions", views::list_template_versions)
        .post("/templates/{id}/versions", views::create_template_version)
        .post("/templates/:id/versions", views::create_template_version)
        .get(
            "/templates/{id}/versions/{version_id}",
            views::retrieve_template_version,
        )
        .get(
            "/templates/:id/versions/:version_id",
            views::retrieve_template_version,
        )
        .delete(
            "/templates/{id}/versions/{version_id}",
            views::delete_template_version,
        )
        .delete(
            "/templates/:id/versions/:version_id",
            views::delete_template_version,
        )
}
