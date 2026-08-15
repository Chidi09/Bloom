//! The `marketplace` domain app: Bloom templates, versioning, marketplace public catalog, Stripe Connect Express monetization, purchases, reviews, ratings, moderation, install analytics, and ranking.

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
    archive_template, author_reply_to_review, calculate_bayesian_rating,
    calculate_hn_ranking_score, calculate_split, calculate_wilson_score_lower_bound,
    check_template_access, compute_install_actor_hash, create_or_update_review,
    create_seller_onboarding_link, create_template, create_template_version,
    curate_template_featuring, delete_template, delete_template_version,
    get_or_create_seller_account, get_org_template, get_organization_purchase, get_public_template,
    get_public_template_version, get_template_review, get_template_version, list_org_templates,
    list_organization_purchases, list_public_templates, list_template_reviews,
    list_template_versions, moderate_review, publish_template, purchase_template,
    record_template_install, refresh_seller_payout_status, refund_purchase, report_review_abuse,
    update_review, update_template, validate_featured_type, validate_rating,
    validate_review_status, withdraw_review, InstallOutcome, ReviewOutcome, ReviewReportOutcome,
    SplitAmounts, BAYESIAN_PRIOR_WEIGHT_M, DEFAULT_COMMISSION_BPS, DEFAULT_GLOBAL_MEAN_MILLI,
    VALID_FEATURED_TYPES, VALID_PURCHASE_STATUSES, VALID_REPORT_STATUSES, VALID_REVIEW_STATUSES,
    VALID_STATUSES, VALID_VISIBILITIES,
};

/// Build the marketplace app router.
pub fn urls() -> djangors_core::Router {
    urls::urls()
}
