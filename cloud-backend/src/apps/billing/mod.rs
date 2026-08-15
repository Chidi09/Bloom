//! Bloom billing and usage metering domain app (Phase 7).
//!
//! Provides plans, subscriptions, metered usage records, invoice management,
//! pure entitlement decision enforcement, and native payment gateway integrations
//! (Bachs and Paystack).

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

pub use contracts::{
    EnforcementDecision, Entitlements, FeatureEntitlements, InvoiceResponse, PlanResponse,
    SubscriptionResponse, UsageSummaryResponse,
};
pub use services::{
    apply_charge_initiation, apply_free_downgrade, apply_payment_success, calculate_build_minutes,
    calculate_prorated_amount, can_transition_subscription, check_bandwidth_entitlement,
    check_build_minutes_entitlement, check_storage_entitlement, check_web_hosting_entitlement,
    evaluate_feature_enforcement, evaluate_numeric_enforcement, validate_subscription_upgrade,
    EnforcementContext,
};

/// Build the billing app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
