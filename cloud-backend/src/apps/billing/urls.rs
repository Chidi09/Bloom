//! URL route definitions for the `billing` app.

use djangors_core::Router;

use super::views;

/// Build and return the `billing` app router.
pub fn urls() -> Router {
    Router::new()
        .get("/billing/plans", views::list_plans)
        .get("/billing/subscription", views::current_subscription)
        .post("/billing/subscribe", views::create_subscription)
        .post("/billing/cancel", views::cancel_subscription)
        .get("/billing/invoices", views::list_invoices)
        .get("/billing/usage", views::usage_summary)
        .post("/webhooks/bachs", views::handle_bachs_webhook)
        .post("/webhooks/paystack", views::handle_paystack_webhook)
}
