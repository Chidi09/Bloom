//! Business logic, state transitions, and workflows for `marketplace`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{
    CreateSellerOnboardingLinkRequest, FeatureTemplateRequest, PurchaseTemplateRequest,
    RecordInstallRequest, RefundPurchaseRequest, ReviewAuthorReplyRequest, ReviewCreateRequest,
    ReviewModerateRequest, ReviewReportRequest, ReviewUpdateRequest, SellerOnboardingLinkResponse,
    TemplateCreateRequest, TemplatePublishRequest, TemplateUpdateRequest,
    TemplateVersionCreateRequest,
};
use super::errors::MarketplaceError;
use super::models::{
    ReviewReport, SellerAccount, Template, TemplateInstallDedup, TemplatePurchase, TemplateReview,
    TemplateVersion,
};
use super::repositories;
use crate::infra::stripe::{
    CreateAccountLinkParams, CreateAccountParams, CreatePaymentIntentParams, CreateRefundParams,
    StripeClient,
};

/// Default platform commission rate in basis points (2000 bps = 20.00%).
pub const DEFAULT_COMMISSION_BPS: i64 = 2000;

/// Valid purchase lifecycle status identifiers.
pub const VALID_PURCHASE_STATUSES: &[&str] = &["pending", "succeeded", "refunded", "failed"];

/// Valid visibility scopes for templates.
pub const VALID_VISIBILITIES: &[&str] = &["private", "public"];

/// All valid template lifecycle statuses.
pub const VALID_STATUSES: &[&str] = &["draft", "published", "archived"];

/// Prior weight constant for Bayesian rating average calculation (JetBrains Marketplace uses m = 2).
pub const BAYESIAN_PRIOR_WEIGHT_M: i64 = 2;

/// Default global mean rating in milli-stars (3.5 stars = 3500 milli-stars) when no ratings exist.
pub const DEFAULT_GLOBAL_MEAN_MILLI: i64 = 3500;

/// Valid review moderation status identifiers.
pub const VALID_REVIEW_STATUSES: &[&str] = &["published", "hidden", "archived"];

/// Valid template featured placement types (distinguishing editorial curation from paid placement).
pub const VALID_FEATURED_TYPES: &[&str] = &["none", "editorial", "paid"];

/// Valid review abuse report status identifiers.
pub const VALID_REPORT_STATUSES: &[&str] = &["pending", "reviewed", "dismissed", "actioned"];

/// Emits an event to the system events log.
pub async fn emit_event(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) {
    crate::apps::events::emit(
        db,
        event_type,
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload,
    )
    .await;
}

/// Calculated platform fee and seller payout breakdown.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SplitAmounts {
    /// Total charged amount in integer minor units.
    pub amount: i64,

    /// Platform application fee cut in integer minor units.
    pub platform_fee: i64,

    /// Seller payout cut in integer minor units.
    pub seller_amount: i64,
}

/// Calculates the platform fee and seller payout for a given transaction amount.
///
/// # Rounding Rule (ADDENDUM D.8):
/// Platform commission is computed using integer minor units:
/// `platform_fee = (amount * commission_bps) / 10_000` (integer truncation towards zero).
/// The seller payout is strictly defined as `seller_amount = amount - platform_fee`.
///
/// This guarantees that `platform_fee + seller_amount == amount` exactly in every code path,
/// eliminating rounding discrepancies and preventing bias towards either party.
pub fn calculate_split(amount: i64, commission_bps: i64) -> Result<SplitAmounts, MarketplaceError> {
    if amount < 0 {
        return Err(MarketplaceError::ValidationError(
            "Amount cannot be negative.".to_string(),
        ));
    }
    if !(0..=10_000).contains(&commission_bps) {
        return Err(MarketplaceError::ValidationError(
            "Commission BPS must be between 0 and 10000.".to_string(),
        ));
    }

    let platform_fee = ((amount as i128 * commission_bps as i128) / 10_000) as i64;
    let seller_amount = amount - platform_fee;

    // Enforce documented Stripe constraint: Application fee cannot exceed payment amount
    if platform_fee > amount {
        return Err(MarketplaceError::ValidationError(
            "Application fee amount cannot exceed total payment amount.".to_string(),
        ));
    }

    Ok(SplitAmounts {
        amount,
        platform_fee,
        seller_amount,
    })
}

/// Validate pricing configuration for a template.
pub fn validate_pricing(
    is_free: bool,
    price_amount: i64,
    price_currency: &str,
) -> Result<(), MarketplaceError> {
    if is_free {
        if price_amount != 0 {
            return Err(MarketplaceError::ValidationError(
                "Free templates must have a price amount of 0.".to_string(),
            ));
        }
    } else {
        if price_amount <= 0 {
            return Err(MarketplaceError::ValidationError(
                "Paid templates must have a price amount greater than 0.".to_string(),
            ));
        }
        let cur = price_currency.trim();
        if cur.len() != 3 || !cur.chars().all(|c| c.is_ascii_alphabetic()) {
            return Err(MarketplaceError::ValidationError(
                "Price currency must be a valid 3-letter ISO code.".to_string(),
            ));
        }
    }
    Ok(())
}

/// Returns `true` when `from -> to` is a legal template status transition.
pub fn can_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("draft", "published")
            | ("draft", "archived")
            | ("published", "draft")
            | ("published", "archived")
    )
}

/// Convert a template name into a clean, URL-safe slug.
pub fn slugify(name: &str) -> String {
    crate::apps::common::slug::slugify(name, "template")
}

/// Validate that a version string is a valid semver format (e.g. `1.0.0`, `v2.1.0-beta`).
pub fn validate_version(version: &str) -> Result<(), MarketplaceError> {
    let trimmed = version.trim();
    if trimmed.is_empty() {
        return Err(MarketplaceError::ValidationError(
            "Version cannot be empty.".to_string(),
        ));
    }
    if trimmed.len() > 64 {
        return Err(MarketplaceError::ValidationError(
            "Version string exceeds 64 characters.".to_string(),
        ));
    }
    let v_stripped = trimmed.strip_prefix('v').unwrap_or(trimmed);
    let parts: Vec<&str> = v_stripped.split('.').collect();
    if parts.is_empty() || !parts[0].chars().any(|c| c.is_ascii_digit()) {
        return Err(MarketplaceError::ValidationError(format!(
            "Invalid version format: '{version}'. Must follow semantic versioning (e.g. 1.0.0)."
        )));
    }
    Ok(())
}

/// Validate visibility against [`VALID_VISIBILITIES`].
pub fn validate_visibility(visibility: &str) -> Result<(), MarketplaceError> {
    if VALID_VISIBILITIES.contains(&visibility) {
        Ok(())
    } else {
        Err(MarketplaceError::ValidationError(format!(
            "Invalid visibility '{visibility}'. Allowed values: {}.",
            VALID_VISIBILITIES.join(", ")
        )))
    }
}

/// Validate status against [`VALID_STATUSES`].
pub fn validate_status(status: &str) -> Result<(), MarketplaceError> {
    if VALID_STATUSES.contains(&status) {
        Ok(())
    } else {
        Err(MarketplaceError::ValidationError(format!(
            "Invalid status '{status}'. Allowed values: {}.",
            VALID_STATUSES.join(", ")
        )))
    }
}

/// Validate that a rating integer is strictly within 1..=5 stars.
pub fn validate_rating(rating: i64) -> Result<(), MarketplaceError> {
    if (1..=5).contains(&rating) {
        Ok(())
    } else {
        Err(MarketplaceError::InvalidRating(rating))
    }
}

/// Validate review moderation status against [`VALID_REVIEW_STATUSES`].
pub fn validate_review_status(status: &str) -> Result<(), MarketplaceError> {
    if VALID_REVIEW_STATUSES.contains(&status) {
        Ok(())
    } else {
        Err(MarketplaceError::InvalidReviewStatus(format!(
            "Invalid review status '{status}'. Allowed values: {}.",
            VALID_REVIEW_STATUSES.join(", ")
        )))
    }
}

/// Validate featured placement type against [`VALID_FEATURED_TYPES`].
pub fn validate_featured_type(featured_type: &str) -> Result<(), MarketplaceError> {
    if VALID_FEATURED_TYPES.contains(&featured_type) {
        Ok(())
    } else {
        Err(MarketplaceError::InvalidFeaturedType(format!(
            "Invalid featured placement type '{featured_type}'. Allowed values: {}.",
            VALID_FEATURED_TYPES.join(", ")
        )))
    }
}

// ---------------------------------------------------------------------------
// Pure Mathematical and Ranking Decision Functions (No I/O)
// ---------------------------------------------------------------------------

/// Computes the Bayesian average rating in milli-stars (scale 1..5 stars -> 1000..5000 milli-stars).
///
/// # Formula (JetBrains Marketplace formulation):
/// `score_milli = (1000 * sum_of_ratings + m * global_mean_milli + (n + m) / 2) / (n + m)`
///
/// where `n` = number of ratings, `m` = prior weight (`BAYESIAN_PRIOR_WEIGHT_M = 2`),
/// and `global_mean_milli` = the marketplace-wide average in milli-stars.
/// The `+ (n + m) / 2` term provides exact round-half-up under integer division.
///
/// Integer-only arithmetic. No floats anywhere in the rating path.
pub fn calculate_bayesian_rating(
    rating_sum: i64,
    rating_count: i64,
    global_mean_milli: i64,
    prior_weight_m: i64,
) -> Result<i64, MarketplaceError> {
    if rating_count < 0 || rating_sum < 0 {
        return Err(MarketplaceError::ValidationError(
            "Rating count and sum must be non-negative.".to_string(),
        ));
    }
    if prior_weight_m <= 0 {
        return Err(MarketplaceError::ValidationError(
            "Prior weight m must be positive.".to_string(),
        ));
    }
    if !(1000..=5000).contains(&global_mean_milli) {
        return Err(MarketplaceError::ValidationError(
            "Global mean must be between 1000 and 5000 milli-stars.".to_string(),
        ));
    }
    if rating_count > 0 && (rating_sum < rating_count || rating_sum > rating_count * 5) {
        return Err(MarketplaceError::ValidationError(
            "Rating sum is out of bounds for given rating count.".to_string(),
        ));
    }

    let n = rating_count as i128;
    let m = prior_weight_m as i128;
    let sum = rating_sum as i128;
    let global_mean = global_mean_milli as i128;

    let numerator = 1000 * sum + m * global_mean + (n + m) / 2;
    let denominator = n + m;

    let score = numerator / denominator;
    Ok(score as i64)
}

/// Pure Hacker News popularity-vs-recency ranking score calculation.
///
/// # Formula:
/// `score = (P - 1) / (T + 2)^G` with `G = 1.8`
///
/// where `P` = total install/purchase count, `T` = elapsed hours since publication,
/// `+2` cushions the first hours and avoids division by zero, and `-1` removes the submitter's own baseline.
///
/// Floating-point operations are strictly confined to this pure ranking function due to the
/// fractional exponent `(T + 2)^1.8`. No float ever touches money or stored rating aggregates.
pub fn calculate_hn_ranking_score(installs_or_purchases: i64, hours_since_published: f64) -> f64 {
    if installs_or_purchases <= 1 || hours_since_published < 0.0 {
        return 0.0;
    }

    let p = installs_or_purchases as f64;
    let t = hours_since_published;
    let g = 1.8_f64;

    let numerator = p - 1.0;
    let denominator = (t + 2.0).powf(g);

    numerator / denominator
}

/// Computes the Wilson score confidence interval lower bound at 95% confidence (z = 1.96).
///
/// # Background:
/// The Wilson score lower bound encodes statistical uncertainty for rating quality ranking:
/// a 5.0 score from 2 ratings has high uncertainty and ranks below a 4.7 score from 400 ratings.
///
/// # Formula:
/// `W = (p + z^2 / (2n) - z * sqrt((p * (1 - p) + z^2 / (4n^2)) / n)) / (1 + z^2 / n)`
/// with `z = 1.96` (95% two-sided normal confidence bound).
///
/// Floating-point operations are strictly confined to this pure ranking function.
pub fn calculate_wilson_score_lower_bound(rating_sum: i64, rating_count: i64) -> f64 {
    if rating_count <= 0 || rating_sum <= 0 {
        return 0.0;
    }

    // z = 1.96 for 95% confidence level
    const Z: f64 = 1.96;
    const Z_SQUARED: f64 = Z * Z; // 3.8416

    let n = rating_count as f64;
    // Map 1..=5 star ratings onto normalized [0.0, 1.0] proportion
    let p = ((rating_sum - rating_count) as f64 / (4.0 * n)).clamp(0.0, 1.0);

    let denominator = 1.0 + Z_SQUARED / n;
    let center = p + Z_SQUARED / (2.0 * n);
    let variance_term = (p * (1.0 - p) + Z_SQUARED / (4.0 * n * n)) / n;
    let spread = Z * variance_term.max(0.0).sqrt();

    ((center - spread) / denominator).clamp(0.0, 1.0)
}

/// Computes a privacy-preserving SHA-256 hash for install deduplication.
///
/// # Privacy & Retention:
/// Combines a daily rotating salt with identifying client inputs (e.g. IP or fingerprint).
/// Because the salt rotates daily, the hash is unlinkable across days and cannot be reversed
/// to reveal raw IP addresses.
pub fn compute_install_actor_hash(salt: &str, identifier: &str) -> String {
    crate::infra::crypto::Crypto::hash_token(&format!("{salt}:{identifier}"))
}

// ---------------------------------------------------------------------------
// Composite Domain Detail & Outcome Types
// ---------------------------------------------------------------------------

/// Detailed composite representation of a template and its versions.
#[derive(Debug, Clone)]
pub struct TemplateDetail {
    /// The template database model.
    pub template: Template,
    /// Owning organization's public UUID v4.
    pub organization_public_id: String,
    /// Associated versions.
    pub versions: Vec<TemplateVersion>,
    /// Latest semver version string, if any.
    pub latest_version: Option<String>,
    /// Count of published versions.
    pub versions_count: i64,
}

/// Detailed representation of a template version and its parent.
#[derive(Debug, Clone)]
pub struct TemplateVersionDetail {
    /// The template version database model.
    pub version: TemplateVersion,
    /// Parent template's public UUID v4.
    pub template_public_id: String,
}

/// Outcome of a template purchase operation.
#[derive(Debug, Clone)]
pub struct PurchaseOutcome {
    /// The created or existing purchase record.
    pub purchase: TemplatePurchase,
    /// Buyer organization public UUID.
    pub buyer_org_public_id: String,
    /// Purchased template public UUID.
    pub template_public_id: String,
    /// Name of the purchased template.
    pub template_name: String,
    /// Purchased template version public UUID if version-specific.
    pub version_public_id: Option<String>,
    /// Seller organization public UUID.
    pub seller_org_public_id: String,
    /// Client secret for client-side Stripe confirmation if required.
    pub client_secret: Option<String>,
}

/// Outcome of a refund operation.
#[derive(Debug, Clone)]
pub struct RefundOutcome {
    /// Purchase public UUID v4.
    pub purchase_public_id: String,
    /// Stripe refund ID (`re_...`).
    pub stripe_refund_id: String,
    /// Refunded amount in integer minor units.
    pub amount: i64,
    /// Three-letter ISO currency code.
    pub currency: String,
    /// Refund status.
    pub status: String,
}

/// Decision result for a template entitlement check.
#[derive(Debug, Clone)]
pub struct TemplateAccessDecision {
    /// Whether access is granted.
    pub has_access: bool,
    /// Reason code (e.g. `owner`, `free_template`, `purchased`).
    pub reason: String,
    /// Template public UUID.
    pub template_public_id: String,
    /// Version public UUID if checked for a version.
    pub version_public_id: Option<String>,
}

/// Outcome of a review creation or update.
#[derive(Debug, Clone)]
pub struct ReviewOutcome {
    /// The review model instance.
    pub review: TemplateReview,
    /// Public UUID of the rated template.
    pub template_public_id: String,
    /// Public UUID of the reviewing buyer organization.
    pub buyer_org_public_id: String,
}

/// Outcome of filing a review abuse report.
#[derive(Debug, Clone)]
pub struct ReviewReportOutcome {
    /// The report model instance.
    pub report: ReviewReport,
    /// Public UUID of the reported review.
    pub review_public_id: String,
    /// Public UUID of the reporting organization.
    pub reporter_org_public_id: String,
}

/// Outcome of an install/download event recording.
#[derive(Debug, Clone)]
pub struct InstallOutcome {
    /// Public UUID of the installed template.
    pub template_public_id: String,
    /// Public UUID of the installed version if specified.
    pub version_public_id: Option<String>,
    /// Updated total install counter.
    pub install_count: i64,
    /// Whether this install was deduplicated within the window.
    pub deduplicated: bool,
}

// ---------------------------------------------------------------------------
// Stripe Connect Express Seller Account Services
// ---------------------------------------------------------------------------

/// Retrieve or create the [`SellerAccount`] for an organization.
pub async fn get_or_create_seller_account(
    db: &Database,
    stripe: &dyn StripeClient,
    organization_id: i64,
    actor_id: i64,
) -> Result<SellerAccount, MarketplaceError> {
    if let Some(existing) = repositories::seller_account_by_org_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        return Ok(existing);
    }

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    // Express is implied by `create_express_account`; there is no account_type field to set.
    // Metadata is flat string pairs, not JSON -- Stripe's API is form-encoded.
    let mut metadata = std::collections::HashMap::new();
    metadata.insert("organization_id".to_string(), org_summary.public_id.clone());
    metadata.insert(
        "platform".to_string(),
        "bloom_cloud_marketplace".to_string(),
    );

    let create_params = CreateAccountParams {
        country: None,
        email: None,
        business_type: Some("company".to_string()),
        metadata,
    };

    let stripe_acct = stripe.create_express_account(&create_params).await?;

    let new_account = SellerAccount {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        stripe_account_id: stripe_acct.id,
        payouts_enabled: stripe_acct.payouts_enabled,
        charges_enabled: stripe_acct.charges_enabled,
        details_submitted: stripe_acct.details_submitted,
        default_currency: stripe_acct.default_currency,
        last_payouts_checked_at: Some(Utc::now()),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_seller_account(db, new_account)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.seller.created",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "seller_account_id": saved.public_id,
            "organization_id": org_summary.public_id,
            "payouts_enabled": saved.payouts_enabled,
        }),
    )
    .await;

    Ok(saved)
}

/// Create a hosted Stripe AccountLink for seller onboarding or account updating.
pub async fn create_seller_onboarding_link(
    db: &Database,
    stripe: &dyn StripeClient,
    organization_id: i64,
    actor_id: i64,
    req: CreateSellerOnboardingLinkRequest,
) -> Result<SellerOnboardingLinkResponse, MarketplaceError> {
    let account = get_or_create_seller_account(db, stripe, organization_id, actor_id).await?;

    let link_type = if account.details_submitted {
        "account_update"
    } else {
        "account_onboarding"
    };

    let params = CreateAccountLinkParams {
        account_id: account.stripe_account_id.clone(),
        refresh_url: req.refresh_url,
        return_url: req.return_url,
        link_type: Some(link_type.to_string()),
    };

    let link = stripe.create_account_link(&params).await?;

    Ok(SellerOnboardingLinkResponse {
        url: link.url,
        expires_at: link.expires_at,
    })
}

/// Refresh seller account capabilities directly from Stripe and update database cache.
pub async fn refresh_seller_payout_status(
    db: &Database,
    stripe: &dyn StripeClient,
    organization_id: i64,
    actor_id: i64,
) -> Result<SellerAccount, MarketplaceError> {
    let mut account = repositories::seller_account_by_org_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::SellerAccountNotFound)?;

    let remote = stripe.retrieve_account(&account.stripe_account_id).await?;

    account.payouts_enabled = remote.payouts_enabled;
    account.charges_enabled = remote.charges_enabled;
    account.details_submitted = remote.details_submitted;
    if remote.default_currency.is_some() {
        account.default_currency = remote.default_currency;
    }
    account.last_payouts_checked_at = Some(Utc::now());
    account.updated_at = Utc::now();

    repositories::update_seller_account(db, &account)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.seller.refreshed",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "seller_account_id": account.public_id,
            "payouts_enabled": account.payouts_enabled,
            "charges_enabled": account.charges_enabled,
        }),
    )
    .await;

    Ok(account)
}

// ---------------------------------------------------------------------------
// Template Management Workflows
// ---------------------------------------------------------------------------

/// Create a new draft project template for an organization.
pub async fn create_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    req: TemplateCreateRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let name = req.name.trim();
    if name.is_empty() {
        return Err(MarketplaceError::ValidationError(
            "Template name cannot be empty.".to_string(),
        ));
    }

    let is_free = req.is_free.unwrap_or(true);
    let price_amount = req.price_amount.unwrap_or(0);
    let price_currency = req
        .price_currency
        .unwrap_or_else(|| "usd".to_string())
        .to_lowercase();

    validate_pricing(is_free, price_amount, &price_currency)?;

    let visibility = req
        .visibility
        .unwrap_or_else(|| "private".to_string())
        .to_lowercase();
    validate_visibility(&visibility)?;

    // If template is paid, verify seller payouts are enabled
    if !is_free {
        let seller = repositories::seller_account_by_org_id(db, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::SellerNotConfigured)?;

        if !seller.payouts_enabled {
            return Err(MarketplaceError::SellerPayoutsNotEnabled);
        }
    }

    let base_slug = slugify(name);
    let mut slug = base_slug.clone();
    let mut counter = 1;
    while repositories::template_slug_exists_in_org(db, organization_id, &slug)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        slug = format!("{base_slug}-{counter}");
        counter += 1;
    }

    let metadata_str = req
        .metadata
        .map(|v| v.to_string())
        .unwrap_or_else(|| "{}".to_string());

    let template = Template {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        name: name.to_string(),
        slug,
        description: req.description,
        visibility,
        status: "draft".to_string(),
        is_free,
        price_amount,
        price_currency,
        metadata: metadata_str,
        rating_count: 0,
        rating_sum: 0,
        rating_bayesian_milli: 0,
        install_count: 0,
        featured_type: "none".to_string(),
        featured_until: None,
        created_by_id: actor_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_template(db, template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    emit_event(
        db,
        "marketplace.template.created",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": saved.public_id,
            "name": saved.name,
            "slug": saved.slug,
            "visibility": saved.visibility,
            "is_free": saved.is_free,
            "price_amount": saved.price_amount,
        }),
    )
    .await;

    Ok(TemplateDetail {
        template: saved,
        organization_public_id: org_summary.public_id,
        versions: Vec::new(),
        latest_version: None,
        versions_count: 0,
    })
}

/// Update an existing template in an organization.
pub async fn update_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    public_id: &str,
    req: TemplateUpdateRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let mut template = repositories::template_by_public_id_and_org(db, public_id, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    if let Some(ref name) = req.name {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(MarketplaceError::ValidationError(
                "Template name cannot be empty.".to_string(),
            ));
        }
        template.name = trimmed.to_string();
    }

    if req.description.is_some() {
        template.description = req.description;
    }

    if let Some(ref vis) = req.visibility {
        validate_visibility(vis)?;
        template.visibility = vis.to_lowercase();
    }

    if let Some(ref target_status) = req.status {
        validate_status(target_status)?;
        if target_status != &template.status && !can_transition(&template.status, target_status) {
            return Err(MarketplaceError::InvalidStateTransition {
                from: template.status.clone(),
                to: target_status.clone(),
            });
        }
        template.status = target_status.clone();
    }

    let is_free = req.is_free.unwrap_or(template.is_free);
    let price_amount = req.price_amount.unwrap_or(template.price_amount);
    let price_currency = req
        .price_currency
        .as_deref()
        .unwrap_or(&template.price_currency)
        .to_lowercase();

    validate_pricing(is_free, price_amount, &price_currency)?;

    if !is_free {
        let seller = repositories::seller_account_by_org_id(db, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::SellerNotConfigured)?;

        if !seller.payouts_enabled {
            return Err(MarketplaceError::SellerPayoutsNotEnabled);
        }
    }

    template.is_free = is_free;
    template.price_amount = price_amount;
    template.price_currency = price_currency;

    if let Some(ref meta) = req.metadata {
        template.metadata = meta.to_string();
    }

    template.updated_at = Utc::now();
    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    emit_event(
        db,
        "marketplace.template.updated",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "status": template.status,
            "visibility": template.visibility,
            "is_free": template.is_free,
        }),
    )
    .await;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count,
    })
}

/// Publish a template, transitioning it to `published` and optionally setting visibility.
pub async fn publish_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    public_id: &str,
    req: TemplatePublishRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let mut template = repositories::template_by_public_id_and_org(db, public_id, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    if template.status == "archived" {
        return Err(MarketplaceError::InvalidStateTransition {
            from: "archived".to_string(),
            to: "published".to_string(),
        });
    }

    if !template.is_free {
        let seller = repositories::seller_account_by_org_id(db, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::SellerNotConfigured)?;

        if !seller.payouts_enabled {
            return Err(MarketplaceError::SellerPayoutsNotEnabled);
        }
    }

    let version_count = repositories::count_versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    if version_count == 0 {
        return Err(MarketplaceError::ValidationError(
            "Cannot publish a template without at least one version.".to_string(),
        ));
    }

    template.status = "published".to_string();
    if let Some(ref vis) = req.visibility {
        validate_visibility(vis)?;
        template.visibility = vis.to_lowercase();
    }
    template.updated_at = Utc::now();

    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());

    emit_event(
        db,
        "marketplace.template.published",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "visibility": template.visibility,
        }),
    )
    .await;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count: version_count,
    })
}

/// Archive a template.
pub async fn archive_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    public_id: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let mut template = repositories::template_by_public_id_and_org(db, public_id, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    template.status = "archived".to_string();
    template.updated_at = Utc::now();

    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    emit_event(
        db,
        "marketplace.template.archived",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
        }),
    )
    .await;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count,
    })
}

/// Delete a template and cascade-delete its versions.
pub async fn delete_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    public_id: &str,
) -> Result<(), MarketplaceError> {
    let template = repositories::template_by_public_id_and_org(db, public_id, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    repositories::delete_template_by_id(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.template.deleted",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
        }),
    )
    .await;

    Ok(())
}

/// List all templates in an organization with pagination.
pub async fn list_org_templates(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<TemplateDetail>, i64), MarketplaceError> {
    let (templates, total) =
        repositories::list_org_templates_query(db, organization_id, limit, offset)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    if templates.is_empty() {
        return Ok((Vec::new(), total));
    }

    // 1. Hoist loop-invariant organization lookup
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    // 2. Prefetch child template versions in ONE query via prefetch_related
    let mut versions_map = djangors_orm::prefetch_related::<Template, TemplateVersion, _>(
        db,
        &templates,
        "templateversion",
    )
    .await
    .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut details = Vec::with_capacity(templates.len());
    for t in templates {
        let mut versions = versions_map.remove(&t.id).unwrap_or_default();
        versions.sort_by_key(|v| std::cmp::Reverse(v.created_at));
        let latest_version = versions.first().map(|v| v.version.clone());
        let versions_count = versions.len() as i64;
        details.push(TemplateDetail {
            template: t,
            organization_public_id: org_summary.public_id.clone(),
            versions,
            latest_version,
            versions_count,
        });
    }

    Ok((details, total))
}

/// Retrieve a template by public UUID within an organization.
pub async fn get_org_template(
    db: &Database,
    organization_id: i64,
    public_id: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let template = repositories::template_by_public_id_and_org(db, public_id, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_summary.public_id,
        versions,
        latest_version,
        versions_count,
    })
}

// ---------------------------------------------------------------------------
// Public Marketplace Discovery Workflows
// ---------------------------------------------------------------------------

/// List all public and published templates in the marketplace catalog with pagination.
pub async fn list_public_templates(
    db: &Database,
    search: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<TemplateDetail>, i64), MarketplaceError> {
    let (templates, total) =
        repositories::list_public_published_templates_query(db, search, limit, offset)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    if templates.is_empty() {
        return Ok((Vec::new(), total));
    }

    // 1. Batch lookup owning organizations in ONE query via id__in
    let mut org_ids: Vec<i64> = templates.iter().map(|t| t.organization_id.id).collect();
    org_ids.sort_unstable();
    org_ids.dedup();
    let org_map = repositories::organizations_by_ids(db, &org_ids)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    // 2. Prefetch child template versions in ONE query via prefetch_related
    let mut versions_map = djangors_orm::prefetch_related::<Template, TemplateVersion, _>(
        db,
        &templates,
        "templateversion",
    )
    .await
    .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut details = Vec::with_capacity(templates.len());
    for t in templates {
        let org_pub = org_map
            .get(&t.organization_id.id)
            .map(|s| s.public_id.clone())
            .unwrap_or_else(|| "unknown".to_string());

        let mut versions = versions_map.remove(&t.id).unwrap_or_default();
        versions.sort_by_key(|v| std::cmp::Reverse(v.created_at));
        let latest_version = versions.first().map(|v| v.version.clone());
        let versions_count = versions.len() as i64;

        details.push(TemplateDetail {
            template: t,
            organization_public_id: org_pub,
            versions,
            latest_version,
            versions_count,
        });
    }

    Ok((details, total))
}

/// Retrieve a public template by its public UUID.
pub async fn get_public_template(
    db: &Database,
    public_id: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let template = repositories::public_published_template_by_public_id(db, public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    let org_summary = repositories::organization_summary_by_id(db, template.organization_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let org_pub = org_summary
        .map(|s| s.public_id)
        .unwrap_or_else(|| "unknown".to_string());

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_pub,
        versions,
        latest_version,
        versions_count,
    })
}

// ---------------------------------------------------------------------------
// Template Version Management Workflows
// ---------------------------------------------------------------------------

/// Create and publish a new version for a template.
pub async fn create_template_version(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: TemplateVersionCreateRequest,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    validate_version(&req.version)?;

    if let Some(_existing) =
        repositories::version_by_semver_and_template(db, &req.version, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        return Err(MarketplaceError::VersionAlreadyExists);
    }

    let manifest_str = req
        .manifest
        .map(|v| v.to_string())
        .unwrap_or_else(|| "{}".to_string());

    let version = TemplateVersion {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        template_id: ForeignKey::new(template.id),
        version: req.version.trim().to_string(),
        changelog: req.changelog.unwrap_or_default(),
        manifest: manifest_str,
        readme: req.readme.unwrap_or_default(),
        install_count: 0,
        created_by_id: actor_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_version(db, version)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.template.version_created",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "version_id": saved.public_id,
            "version": saved.version,
        }),
    )
    .await;

    Ok(TemplateVersionDetail {
        version: saved,
        template_public_id: template.public_id,
    })
}

/// List all versions of a template within an organization with pagination.
pub async fn list_template_versions(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<TemplateVersionDetail>, i64), MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let (versions, total) =
        repositories::list_template_versions_query(db, template.id, limit, offset)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let details = versions
        .into_iter()
        .map(|v| TemplateVersionDetail {
            version: v,
            template_public_id: template.public_id.clone(),
        })
        .collect();

    Ok((details, total))
}

/// Retrieve a specific template version by public UUID within an organization.
pub async fn get_template_version(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
    version_public_id: &str,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let version =
        repositories::version_by_public_id_and_template(db, version_public_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateVersionNotFound)?;

    Ok(TemplateVersionDetail {
        version,
        template_public_id: template.public_id,
    })
}

/// Retrieve a public template version by public UUID.
pub async fn get_public_template_version(
    db: &Database,
    template_public_id: &str,
    version_public_id: &str,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    let template = repositories::public_published_template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    let version =
        repositories::version_by_public_id_and_template(db, version_public_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateVersionNotFound)?;

    Ok(TemplateVersionDetail {
        version,
        template_public_id: template.public_id,
    })
}

/// Delete a template version.
pub async fn delete_template_version(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    version_public_id: &str,
) -> Result<(), MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let version =
        repositories::version_by_public_id_and_template(db, version_public_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateVersionNotFound)?;

    repositories::delete_version_by_id(db, version.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.template.version_deleted",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "version_id": version.public_id,
            "version": version.version,
        }),
    )
    .await;

    Ok(())
}

// ---------------------------------------------------------------------------
// Monetization & Purchase Workflows
// ---------------------------------------------------------------------------

/// Purchase a template and establish an entitlement.
pub async fn purchase_template(
    db: &Database,
    stripe: &dyn StripeClient,
    buyer_organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: PurchaseTemplateRequest,
) -> Result<PurchaseOutcome, MarketplaceError> {
    let template = repositories::template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    if template.status != "published" {
        return Err(MarketplaceError::TemplateNotPublished);
    }
    if template.visibility != "public" {
        return Err(MarketplaceError::TemplatePrivate);
    }

    if template.organization_id.id == buyer_organization_id {
        return Err(MarketplaceError::CannotPurchaseOwnTemplate);
    }

    if template.is_free {
        return Err(MarketplaceError::ValidationError(
            "Free templates do not require purchase.".to_string(),
        ));
    }

    let seller_org_id = template.organization_id.id;
    let seller = repositories::seller_account_by_org_id(db, seller_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::SellerNotConfigured)?;

    if !seller.payouts_enabled {
        return Err(MarketplaceError::SellerPayoutsNotEnabled);
    }

    let idempotency_key = req.idempotency_key.unwrap_or_else(|| {
        format!(
            "pur_{}_{}_{}",
            buyer_organization_id,
            template.id,
            Uuid::new_v4()
        )
    });

    if let Some(existing) = repositories::purchase_by_idempotency_key(db, &idempotency_key)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        return get_purchase_outcome(db, existing).await;
    }

    if let Some(active) = repositories::succeeded_purchase_for_buyer_and_template(
        db,
        buyer_organization_id,
        template.id,
    )
    .await
    .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        return get_purchase_outcome(db, active).await;
    }

    let version = if let Some(ref ver_pub) = req.template_version_id {
        Some(
            repositories::version_by_public_id_and_template(db, ver_pub, template.id)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
                .ok_or(MarketplaceError::TemplateVersionNotFound)?,
        )
    } else {
        None
    };

    let split = calculate_split(template.price_amount, DEFAULT_COMMISSION_BPS)?;

    let buyer_summary = repositories::organization_summary_by_id(db, buyer_organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let seller_summary = repositories::organization_summary_by_id(db, seller_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    // Stripe metadata is flat string pairs over a form-encoded request, not nested JSON.
    let mut pi_metadata = std::collections::HashMap::new();
    pi_metadata.insert("template_id".to_string(), template.public_id.clone());
    pi_metadata.insert("template_name".to_string(), template.name.clone());
    pi_metadata.insert(
        "buyer_organization_id".to_string(),
        buyer_summary.public_id.clone(),
    );
    pi_metadata.insert(
        "seller_organization_id".to_string(),
        seller_summary.public_id.clone(),
    );
    pi_metadata.insert(
        "platform".to_string(),
        "bloom_cloud_marketplace".to_string(),
    );

    let pi_params = CreatePaymentIntentParams {
        amount: split.amount,
        currency: template.price_currency.clone(),
        application_fee_amount: split.platform_fee,
        destination_account_id: seller.stripe_account_id.clone(),
        description: Some(format!("Bloom template purchase: {}", template.name)),
        metadata: pi_metadata,
    };

    let pi = stripe
        .create_payment_intent(&pi_params, Some(&idempotency_key))
        .await?;

    let purchase = TemplatePurchase {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        buyer_organization_id: ForeignKey::new(buyer_organization_id),
        template_id: ForeignKey::new(template.id),
        template_version_id: version.as_ref().map(|v| v.id),
        seller_organization_id: ForeignKey::new(seller_org_id),
        amount: split.amount,
        currency: template.price_currency,
        platform_fee: split.platform_fee,
        seller_amount: split.seller_amount,
        stripe_payment_intent_id: pi.id.clone(),
        status: pi.status.clone(),
        idempotency_key,
        created_by_id: actor_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_purchase(db, purchase)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.purchase.created",
        Some(buyer_organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "purchase_id": saved.public_id,
            "template_id": template.public_id,
            "amount": saved.amount,
            "status": saved.status,
        }),
    )
    .await;

    Ok(PurchaseOutcome {
        purchase: saved,
        buyer_org_public_id: buyer_summary.public_id,
        template_public_id: template.public_id,
        template_name: template.name,
        version_public_id: version.map(|v| v.public_id),
        seller_org_public_id: seller_summary.public_id,
        client_secret: pi.client_secret,
    })
}

/// Retrieve purchases made by an organization using cursor pagination and batch entity lookups.
pub async fn list_organization_purchases_cursor(
    db: &Database,
    buyer_org_id: i64,
    cursor: Option<&str>,
    limit: i64,
) -> Result<(Vec<PurchaseOutcome>, Option<String>), MarketplaceError> {
    let (purchases, next_cursor) =
        repositories::list_purchases_cursor(db, buyer_org_id, cursor, limit)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    if purchases.is_empty() {
        return Ok((Vec::new(), next_cursor));
    }

    // 1. Hoist loop-invariant buyer organization lookup
    let buyer_summary = repositories::organization_summary_by_id(db, buyer_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    // 2. Batch lookup seller organizations in ONE query
    let mut seller_org_ids: Vec<i64> = purchases
        .iter()
        .map(|p| p.seller_organization_id.id)
        .collect();
    seller_org_ids.sort_unstable();
    seller_org_ids.dedup();
    let seller_org_map = repositories::organizations_by_ids(db, &seller_org_ids)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    // 3. Batch lookup templates in ONE query
    let mut template_ids: Vec<i64> = purchases.iter().map(|p| p.template_id.id).collect();
    template_ids.sort_unstable();
    template_ids.dedup();
    let template_map = repositories::templates_by_ids(db, &template_ids)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    // 4. Batch lookup template versions in ONE query
    let mut version_ids: Vec<i64> = purchases
        .iter()
        .filter_map(|p| p.template_version_id)
        .collect();
    version_ids.sort_unstable();
    version_ids.dedup();
    let version_map = repositories::versions_by_ids(db, &version_ids)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut outcomes = Vec::with_capacity(purchases.len());
    for p in purchases {
        let seller_pub = seller_org_map
            .get(&p.seller_organization_id.id)
            .map(|s| s.public_id.clone())
            .unwrap_or_else(|| "unknown".to_string());

        let template_pub = template_map
            .get(&p.template_id.id)
            .map(|t| t.public_id.clone())
            .unwrap_or_else(|| "unknown".to_string());

        let template_name = template_map
            .get(&p.template_id.id)
            .map(|t| t.name.clone())
            .unwrap_or_else(|| "Template".to_string());

        let version_pub = p
            .template_version_id
            .and_then(|vid| version_map.get(&vid).map(|v| v.public_id.clone()));

        outcomes.push(PurchaseOutcome {
            purchase: p,
            buyer_org_public_id: buyer_summary.public_id.clone(),
            template_public_id: template_pub,
            template_name,
            version_public_id: version_pub,
            seller_org_public_id: seller_pub,
            client_secret: None,
        });
    }

    Ok((outcomes, next_cursor))
}

/// Retrieve a specific purchase by public ID for an organization.
pub async fn get_organization_purchase(
    db: &Database,
    buyer_org_id: i64,
    purchase_public_id: &str,
) -> Result<PurchaseOutcome, MarketplaceError> {
    let purchase = repositories::purchase_by_public_id(db, purchase_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::PurchaseNotFound)?;

    if purchase.buyer_organization_id.id != buyer_org_id {
        return Err(MarketplaceError::PurchaseNotFound);
    }

    get_purchase_outcome(db, purchase).await
}

/// Helper to build a complete [`PurchaseOutcome`] with cross-table projections.
async fn get_purchase_outcome(
    db: &Database,
    purchase: TemplatePurchase,
) -> Result<PurchaseOutcome, MarketplaceError> {
    let buyer_summary =
        repositories::organization_summary_by_id(db, purchase.buyer_organization_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::OrganizationNotFound)?;

    let template = repositories::template_by_id(db, purchase.template_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let (tmpl_pub, tmpl_name) = match template {
        Some(t) => (t.public_id, t.name),
        None => ("deleted".to_string(), "Deleted Template".to_string()),
    };

    let seller_summary =
        repositories::organization_summary_by_id(db, purchase.seller_organization_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let seller_pub = seller_summary
        .map(|s| s.public_id)
        .unwrap_or_else(|| "unknown".to_string());

    let ver_pub = if let Some(vid) = purchase.template_version_id {
        repositories::version_by_id(db, vid)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .map(|v| v.public_id)
    } else {
        None
    };

    Ok(PurchaseOutcome {
        purchase,
        buyer_org_public_id: buyer_summary.public_id,
        template_public_id: tmpl_pub,
        template_name: tmpl_name,
        version_public_id: ver_pub,
        seller_org_public_id: seller_pub,
        client_secret: None,
    })
}

// ---------------------------------------------------------------------------
// Entitlement Access Checks & Download Verification
// ---------------------------------------------------------------------------

/// Evaluate whether an organization is entitled to access and download a template.
///
/// Rules:
/// - The organization that OWNS the template always has access without purchase.
/// - Any organization has access to a free template (`is_free == true`).
/// - For paid templates, requires an active completed purchase record (`status == "succeeded"`).
pub async fn check_template_access(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
    version_public_id: Option<&str>,
) -> Result<TemplateAccessDecision, MarketplaceError> {
    let template = repositories::template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    // 1. Template owner always has full access
    if template.organization_id.id == organization_id {
        return Ok(TemplateAccessDecision {
            has_access: true,
            reason: "owner".to_string(),
            template_public_id: template.public_id,
            version_public_id: version_public_id.map(|s| s.to_string()),
        });
    }

    // 2. Free templates are available to all organizations
    if template.is_free {
        return Ok(TemplateAccessDecision {
            has_access: true,
            reason: "free_template".to_string(),
            template_public_id: template.public_id,
            version_public_id: version_public_id.map(|s| s.to_string()),
        });
    }

    // 3. Paid templates require confirmed purchase
    let active_purchase =
        repositories::succeeded_purchase_for_buyer_and_template(db, organization_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    if active_purchase.is_some() {
        Ok(TemplateAccessDecision {
            has_access: true,
            reason: "purchased".to_string(),
            template_public_id: template.public_id,
            version_public_id: version_public_id.map(|s| s.to_string()),
        })
    } else {
        Err(MarketplaceError::PaymentRequired)
    }
}

// ---------------------------------------------------------------------------
// Refunds & Entitlement Revocation
// ---------------------------------------------------------------------------

/// Issue a refund on a paid template purchase, reversing the transfer and revoking the entitlement.
pub async fn refund_purchase(
    db: &Database,
    stripe: &dyn StripeClient,
    actor_org_id: i64,
    actor_id: i64,
    purchase_public_id: &str,
    _req: RefundPurchaseRequest,
) -> Result<RefundOutcome, MarketplaceError> {
    let mut purchase = repositories::purchase_by_public_id(db, purchase_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::PurchaseNotFound)?;

    if purchase.buyer_organization_id.id != actor_org_id
        && purchase.seller_organization_id.id != actor_org_id
    {
        return Err(MarketplaceError::PurchaseNotFound);
    }

    if purchase.status == "refunded" {
        return Err(MarketplaceError::PurchaseAlreadyRefunded);
    }

    if purchase.status != "succeeded" {
        return Err(MarketplaceError::InvalidRefundState(format!(
            "Cannot refund purchase with status '{}'. Only succeeded purchases can be refunded.",
            purchase.status
        )));
    }

    let refund_idempotency = format!("ref_{}", purchase.public_id);
    let refund_params = CreateRefundParams {
        payment_intent_id: purchase.stripe_payment_intent_id.clone(),
        amount: Some(purchase.amount),
        reverse_transfer: true,
        refund_application_fee: Some(true),
    };

    let refund = stripe
        .create_refund(&refund_params, Some(&refund_idempotency))
        .await?;

    purchase.status = "refunded".to_string();
    purchase.updated_at = Utc::now();
    repositories::update_purchase(db, &purchase)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.purchase.refunded",
        Some(purchase.buyer_organization_id.id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "purchase_id": purchase.public_id,
            "refund_id": refund.id,
            "amount": refund.amount,
            "currency": refund.currency,
        }),
    )
    .await;

    Ok(RefundOutcome {
        purchase_public_id: purchase.public_id,
        stripe_refund_id: refund.id,
        amount: refund.amount,
        currency: refund.currency,
        status: refund.status,
    })
}

// ---------------------------------------------------------------------------
// Reviews, Ratings & Moderation Workflows
// ---------------------------------------------------------------------------

/// Helper to recalculate a template's Bayesian rating aggregate across published reviews.
async fn recalculate_template_rating_aggregate(
    db: &Database,
    template: &mut Template,
) -> Result<(), MarketplaceError> {
    let (count, sum) = repositories::published_reviews_aggregate_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let global_mean = repositories::marketplace_global_rating_mean_milli(db)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let bayesian_milli = if count == 0 {
        0
    } else {
        calculate_bayesian_rating(sum, count, global_mean, BAYESIAN_PRIOR_WEIGHT_M)?
    };

    template.rating_count = count;
    template.rating_sum = sum;
    template.rating_bayesian_milli = bayesian_milli;
    template.updated_at = Utc::now();

    repositories::update_template(db, template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// Create or update a review on a template.
///
/// # Anti-Spam / Gating Rules:
/// - Reviews MUST be gated on a verified purchase (paid templates) or verified install (free templates).
/// - Authors cannot review their own templates.
/// - One review per buyer organization per template: submitting again updates the previous review.
pub async fn create_or_update_review(
    db: &Database,
    buyer_org_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: ReviewCreateRequest,
) -> Result<ReviewOutcome, MarketplaceError> {
    validate_rating(req.rating)?;

    let mut template = repositories::template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    // 1. Authors cannot review their own template
    if template.organization_id.id == buyer_org_id {
        return Err(MarketplaceError::AuthorCannotReviewOwnTemplate);
    }

    // 2. Verified purchase or install entitlement gating
    if template.is_free {
        let has_install = repositories::verified_install_exists(db, template.id, buyer_org_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        if !has_install {
            return Err(MarketplaceError::ReviewNotAllowedNoPurchaseOrInstall);
        }
    } else {
        let active_purchase =
            repositories::succeeded_purchase_for_buyer_and_template(db, buyer_org_id, template.id)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        if active_purchase.is_none() {
            return Err(MarketplaceError::ReviewNotAllowedNoPurchaseOrInstall);
        }
    }

    let existing_review =
        repositories::review_by_template_and_buyer_org(db, template.id, buyer_org_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let review = if let Some(mut existing) = existing_review {
        existing.rating = req.rating;
        if let Some(t) = req.title {
            existing.title = t;
        }
        if let Some(c) = req.comment {
            existing.comment = c;
        }
        existing.reviewer_user_id = actor_id;
        existing.updated_at = Utc::now();

        repositories::update_review(db, &existing)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        emit_event(
            db,
            "marketplace.review.updated",
            Some(template.organization_id.id),
            None,
            None,
            Some(actor_id),
            serde_json::json!({
                "review_id": existing.public_id,
                "template_id": template.public_id,
                "rating": existing.rating,
            }),
        )
        .await;

        existing
    } else {
        let new_review = TemplateReview {
            id: 0,
            public_id: Uuid::new_v4().to_string(),
            template_id: ForeignKey::new(template.id),
            buyer_organization_id: ForeignKey::new(buyer_org_id),
            reviewer_user_id: actor_id,
            rating: req.rating,
            title: req.title.unwrap_or_default(),
            comment: req.comment.unwrap_or_default(),
            status: "published".to_string(),
            author_response: None,
            author_responded_at: None,
            author_responded_by_id: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        let saved = repositories::insert_review(db, new_review)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        emit_event(
            db,
            "marketplace.review.created",
            Some(template.organization_id.id),
            None,
            None,
            Some(actor_id),
            serde_json::json!({
                "review_id": saved.public_id,
                "template_id": template.public_id,
                "rating": saved.rating,
            }),
        )
        .await;

        saved
    };

    // Recalculate template Bayesian rating aggregate
    recalculate_template_rating_aggregate(db, &mut template).await?;

    let buyer_summary = repositories::organization_summary_by_id(db, buyer_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    Ok(ReviewOutcome {
        review,
        template_public_id: template.public_id,
        buyer_org_public_id: buyer_summary.public_id,
    })
}

/// Update an existing review by its authoring buyer organization.
pub async fn update_review(
    db: &Database,
    buyer_org_id: i64,
    actor_id: i64,
    review_public_id: &str,
    req: ReviewUpdateRequest,
) -> Result<ReviewOutcome, MarketplaceError> {
    let mut review = repositories::review_by_public_id(db, review_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::ReviewNotFound)?;

    let mut template = repositories::template_by_id(db, review.template_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    // Prohibition: Template author CANNOT edit reviews on their own template
    if template.organization_id.id == buyer_org_id
        && review.buyer_organization_id.id != buyer_org_id
    {
        return Err(MarketplaceError::AuthorCannotModerateReviews);
    }

    if review.buyer_organization_id.id != buyer_org_id {
        return Err(MarketplaceError::Forbidden);
    }

    if let Some(r) = req.rating {
        validate_rating(r)?;
        review.rating = r;
    }
    if let Some(t) = req.title {
        review.title = t;
    }
    if let Some(c) = req.comment {
        review.comment = c;
    }
    review.reviewer_user_id = actor_id;
    review.updated_at = Utc::now();

    repositories::update_review(db, &review)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    recalculate_template_rating_aggregate(db, &mut template).await?;

    let buyer_summary = repositories::organization_summary_by_id(db, buyer_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    Ok(ReviewOutcome {
        review,
        template_public_id: template.public_id,
        buyer_org_public_id: buyer_summary.public_id,
    })
}

/// Withdraw / delete a review by its authoring buyer organization.
pub async fn withdraw_review(
    db: &Database,
    buyer_org_id: i64,
    _actor_id: i64,
    review_public_id: &str,
) -> Result<(), MarketplaceError> {
    let review = repositories::review_by_public_id(db, review_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::ReviewNotFound)?;

    let mut template = repositories::template_by_id(db, review.template_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    // Prohibition: Template author CANNOT delete reviews on their own template
    if template.organization_id.id == buyer_org_id
        && review.buyer_organization_id.id != buyer_org_id
    {
        return Err(MarketplaceError::AuthorCannotModerateReviews);
    }

    if review.buyer_organization_id.id != buyer_org_id {
        return Err(MarketplaceError::Forbidden);
    }

    repositories::delete_review_by_id(db, review.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    recalculate_template_rating_aggregate(db, &mut template).await?;

    Ok(())
}

/// Reply to a review as the template author (Right of Reply: one response per review).
pub async fn author_reply_to_review(
    db: &Database,
    author_org_id: i64,
    actor_id: i64,
    review_public_id: &str,
    req: ReviewAuthorReplyRequest,
) -> Result<ReviewOutcome, MarketplaceError> {
    let mut review = repositories::review_by_public_id(db, review_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::ReviewNotFound)?;

    let template = repositories::template_by_id(db, review.template_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    if template.organization_id.id != author_org_id {
        return Err(MarketplaceError::Forbidden);
    }

    if review.author_response.is_some() {
        return Err(MarketplaceError::AuthorReplyAlreadyExists);
    }

    let trimmed = req.response.trim();
    if trimmed.is_empty() {
        return Err(MarketplaceError::ValidationError(
            "Author reply cannot be empty.".to_string(),
        ));
    }

    review.author_response = Some(trimmed.to_string());
    review.author_responded_at = Some(Utc::now());
    review.author_responded_by_id = Some(actor_id);
    review.updated_at = Utc::now();

    repositories::update_review(db, &review)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.review.author_replied",
        Some(author_org_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "review_id": review.public_id,
            "template_id": template.public_id,
        }),
    )
    .await;

    let buyer_summary =
        repositories::organization_summary_by_id(db, review.buyer_organization_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let buyer_pub = buyer_summary
        .map(|s| s.public_id)
        .unwrap_or_else(|| "unknown".to_string());

    Ok(ReviewOutcome {
        review,
        template_public_id: template.public_id,
        buyer_org_public_id: buyer_pub,
    })
}

/// File an abuse report on a review to staff.
pub async fn report_review_abuse(
    db: &Database,
    reporter_org_id: i64,
    actor_id: i64,
    review_public_id: &str,
    req: ReviewReportRequest,
) -> Result<ReviewReportOutcome, MarketplaceError> {
    let review = repositories::review_by_public_id(db, review_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::ReviewNotFound)?;

    let reason = req.reason.trim();
    if reason.is_empty() {
        return Err(MarketplaceError::ValidationError(
            "Report reason cannot be empty.".to_string(),
        ));
    }

    let report = ReviewReport {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        review_id: ForeignKey::new(review.id),
        reporter_organization_id: ForeignKey::new(reporter_org_id),
        reporter_user_id: actor_id,
        reason: reason.to_string(),
        details: req.details.unwrap_or_default(),
        status: "pending".to_string(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_review_report(db, report)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.review.reported",
        Some(reporter_org_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "report_id": saved.public_id,
            "review_id": review.public_id,
            "reason": saved.reason,
        }),
    )
    .await;

    let reporter_summary = repositories::organization_summary_by_id(db, reporter_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    Ok(ReviewReportOutcome {
        report: saved,
        review_public_id: review.public_id,
        reporter_org_public_id: reporter_summary.public_id,
    })
}

/// Moderate a review status (Staff / Platform Admin action).
///
/// If hidden or archived, the review is suppressed from public discovery AND excluded from rating aggregates.
pub async fn moderate_review(
    db: &Database,
    actor_id: i64,
    review_public_id: &str,
    req: ReviewModerateRequest,
) -> Result<ReviewOutcome, MarketplaceError> {
    validate_review_status(&req.status)?;

    let mut review = repositories::review_by_public_id(db, review_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::ReviewNotFound)?;

    let mut template = repositories::template_by_id(db, review.template_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    review.status = req.status.clone();
    review.updated_at = Utc::now();

    repositories::update_review(db, &review)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    recalculate_template_rating_aggregate(db, &mut template).await?;

    emit_event(
        db,
        "marketplace.review.moderated",
        Some(template.organization_id.id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "review_id": review.public_id,
            "template_id": template.public_id,
            "new_status": review.status,
        }),
    )
    .await;

    let buyer_summary =
        repositories::organization_summary_by_id(db, review.buyer_organization_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let buyer_pub = buyer_summary
        .map(|s| s.public_id)
        .unwrap_or_else(|| "unknown".to_string());

    Ok(ReviewOutcome {
        review,
        template_public_id: template.public_id,
        buyer_org_public_id: buyer_pub,
    })
}

/// List reviews for a template with pagination and batch buyer organization lookup.
pub async fn list_template_reviews(
    db: &Database,
    template_public_id: &str,
    include_unmoderated: bool,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<ReviewOutcome>, i64), MarketplaceError> {
    let template = repositories::template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    let (reviews, total) = repositories::list_template_reviews_query(
        db,
        template.id,
        include_unmoderated,
        limit,
        offset,
    )
    .await
    .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    if reviews.is_empty() {
        return Ok((Vec::new(), total));
    }

    // Batch lookup buyer organizations in ONE query via id__in
    let mut buyer_org_ids: Vec<i64> = reviews.iter().map(|r| r.buyer_organization_id.id).collect();
    buyer_org_ids.sort_unstable();
    buyer_org_ids.dedup();
    let buyer_org_map = repositories::organizations_by_ids(db, &buyer_org_ids)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut outcomes = Vec::with_capacity(reviews.len());
    for r in reviews {
        let buyer_pub = buyer_org_map
            .get(&r.buyer_organization_id.id)
            .map(|s| s.public_id.clone())
            .unwrap_or_else(|| "unknown".to_string());

        outcomes.push(ReviewOutcome {
            review: r,
            template_public_id: template.public_id.clone(),
            buyer_org_public_id: buyer_pub,
        });
    }

    Ok((outcomes, total))
}

/// Retrieve a single review by public UUID.
pub async fn get_template_review(
    db: &Database,
    review_public_id: &str,
) -> Result<ReviewOutcome, MarketplaceError> {
    let review = repositories::review_by_public_id(db, review_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::ReviewNotFound)?;

    let template = repositories::template_by_id(db, review.template_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    let buyer_summary =
        repositories::organization_summary_by_id(db, review.buyer_organization_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let buyer_pub = buyer_summary
        .map(|s| s.public_id)
        .unwrap_or_else(|| "unknown".to_string());

    Ok(ReviewOutcome {
        review,
        template_public_id: template.public_id,
        buyer_org_public_id: buyer_pub,
    })
}

// ---------------------------------------------------------------------------
// Install Analytics & Verification Workflows
// ---------------------------------------------------------------------------

/// Record a template install/download event with deduplication and privacy protections.
///
/// # Deduplication:
/// Repeated installs by the same actor within the daily rotating window count ONCE.
///
/// # Privacy:
/// Raw IP addresses and persistent user IDs are NEVER stored. Identifying inputs are combined
/// with a daily rotating salt and hashed with SHA-256 via [`compute_install_actor_hash`].
pub async fn record_template_install(
    db: &Database,
    actor_org_id: Option<i64>,
    actor_id: Option<i64>,
    template_public_id: &str,
    req: RecordInstallRequest,
    client_identifier: &str,
) -> Result<InstallOutcome, MarketplaceError> {
    let mut template = repositories::template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    let version = if let Some(ref ver_pub) = req.template_version_id {
        Some(
            repositories::version_by_public_id_and_template(db, ver_pub, template.id)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
                .ok_or(MarketplaceError::TemplateVersionNotFound)?,
        )
    } else {
        repositories::latest_version_for_template(db, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    };

    let date_bucket = Utc::now().format("%Y-%m-%d").to_string();
    let rotating_salt = format!("bloom_install_salt_{date_bucket}");
    let identifying_input = req
        .client_fingerprint
        .as_deref()
        .unwrap_or(client_identifier);
    let actor_hash = compute_install_actor_hash(&rotating_salt, identifying_input);

    let already_deduped =
        repositories::install_dedup_exists(db, template.id, &actor_hash, &date_bucket)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    if already_deduped {
        return Ok(InstallOutcome {
            template_public_id: template.public_id,
            version_public_id: version.map(|v| v.public_id),
            install_count: template.install_count,
            deduplicated: true,
        });
    }

    // Insert short-lived deduplication record
    let dedup_record = TemplateInstallDedup {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        template_id: ForeignKey::new(template.id),
        template_version_id: version.as_ref().map(|v| v.id),
        actor_hash,
        date_bucket,
        created_at: Utc::now(),
    };
    // Everything below is one transaction. The dedup row is what makes this install
    // un-repeatable, so if it commits while a counter update fails, the install is lost
    // permanently: the retry sees the dedup row and returns early, and the count never moves.
    //
    // Counters are incremented in the database (`install_count = install_count + 1`) rather
    // than read-modify-written from the row fetched earlier. Two installs racing on the same
    // template would otherwise both read the same starting value and one increment would be
    // silently dropped.
    let version_for_tx = version.as_ref().map(|v| (v.id, v.public_id.clone()));
    let template_id = template.id;
    let install_actor = actor_org_id.zip(actor_id);

    repositories::record_install_atomically(
        db,
        dedup_record,
        template_id,
        version_for_tx.as_ref().map(|(id, _)| *id),
        install_actor,
    )
    .await
    .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let version_pub = version_for_tx.map(|(_, public_id)| public_id);

    // Reflect the increment in the value returned to the caller. The authoritative count now
    // lives in the database; this is the local copy fetched before the transaction.
    template.install_count = template.install_count.saturating_add(1);

    emit_event(
        db,
        "marketplace.template.installed",
        Some(template.organization_id.id),
        None,
        None,
        actor_id,
        serde_json::json!({
            "template_id": template.public_id,
            "version_id": version_pub,
            "install_count": template.install_count,
        }),
    )
    .await;

    Ok(InstallOutcome {
        template_public_id: template.public_id,
        version_public_id: version_pub,
        install_count: template.install_count,
        deduplicated: false,
    })
}

// ---------------------------------------------------------------------------
// Staff Curation & Featured Placement Workflows
// ---------------------------------------------------------------------------

/// Configure staff curation or paid featuring on a template.
///
/// # Regulatory Compliance (EU Regulation 2019/1150 P2B & FTC):
/// Paid placement is explicitly distinguished from editorial curation via `featured_type`.
pub async fn curate_template_featuring(
    db: &Database,
    actor_id: i64,
    template_public_id: &str,
    req: FeatureTemplateRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    validate_featured_type(&req.featured_type)?;

    let mut template = repositories::template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    let featured_until = if req.featured_type == "none" {
        None
    } else {
        req.duration_days
            .map(|d| Utc::now() + chrono::Duration::days(d))
    };

    template.featured_type = req.featured_type.clone();
    template.featured_until = featured_until;
    template.updated_at = Utc::now();

    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "marketplace.template.featured",
        Some(template.organization_id.id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "featured_type": template.featured_type,
            "featured_until": template.featured_until.map(|t| t.to_rfc3339()),
        }),
    )
    .await;

    let org_summary = repositories::organization_summary_by_id(db, template.organization_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let org_pub = org_summary
        .map(|s| s.public_id)
        .unwrap_or_else(|| "unknown".to_string());

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let latest_version = versions.first().map(|v| v.version.clone());
    let versions_count = versions.len() as i64;

    Ok(TemplateDetail {
        template,
        organization_public_id: org_pub,
        versions,
        latest_version,
        versions_count,
    })
}
