//! The `marketplace` domain app: Bloom templates, versioning, marketplace public catalog, Stripe Connect Express monetization, purchases, and refunds.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

pub use services::{
    archive_template, calculate_split, check_template_access, create_seller_onboarding_link,
    create_template, create_template_version, delete_template, delete_template_version,
    get_or_create_seller_account, get_org_template, get_organization_purchase, get_public_template,
    get_public_template_version, get_template_version, list_org_templates,
    list_organization_purchases, list_public_templates, list_template_versions, publish_template,
    purchase_template, refresh_seller_payout_status, refund_purchase, update_template,
    SplitAmounts, DEFAULT_COMMISSION_BPS, VALID_PURCHASE_STATUSES, VALID_STATUSES,
    VALID_VISIBILITIES,
};

/// Build the marketplace app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
