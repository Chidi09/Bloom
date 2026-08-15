//! Business logic, state transitions, and workflows for `marketplace`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{
    CreateSellerOnboardingLinkRequest, PurchaseTemplateRequest, RefundPurchaseRequest,
    SellerOnboardingLinkResponse, TemplateCreateRequest, TemplatePublishRequest,
    TemplateUpdateRequest, TemplateVersionCreateRequest,
};
use super::errors::MarketplaceError;
use super::models::{SellerAccount, Template, TemplatePurchase, TemplateVersion};
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
    let mut slug = String::new();
    let mut prev_dash = false;

    for c in name.chars() {
        if c.is_alphanumeric() {
            slug.push(c.to_ascii_lowercase());
            prev_dash = false;
        } else if !prev_dash {
            slug.push('-');
            prev_dash = true;
        }
    }

    let trimmed = slug.trim_matches('-');
    if trimmed.is_empty() {
        "template".to_string()
    } else if trimmed.len() > 60 {
        trimmed[..60].trim_matches('-').to_string()
    } else {
        trimmed.to_string()
    }
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
    /// Purchased version public UUID if specified.
    pub version_public_id: Option<String>,
    /// Seller organization public UUID.
    pub seller_org_public_id: String,
    /// Stripe client secret for frontend confirmation if applicable.
    pub client_secret: Option<String>,
}

/// Outcome of a refund operation.
#[derive(Debug, Clone)]
pub struct RefundOutcome {
    /// Purchase public UUID.
    pub purchase_public_id: String,
    /// Stripe refund ID (`re_...`).
    pub stripe_refund_id: String,
    /// Refunded amount in minor units.
    pub amount: i64,
    /// Currency code.
    pub currency: String,
    /// Status of the refund.
    pub status: String,
}

/// Result of an access / entitlement check.
#[derive(Debug, Clone)]
pub struct TemplateAccessDecision {
    /// Whether access is granted.
    pub has_access: bool,
    /// Reason string (`owner`, `free_template`, `purchased`, `no_entitlement`).
    pub reason: String,
    /// Template public UUID.
    pub template_public_id: String,
    /// Version public UUID if applicable.
    pub version_public_id: Option<String>,
}

// ---------------------------------------------------------------------------
// Seller Onboarding & Account Management
// ---------------------------------------------------------------------------

/// Retrieve or create a seller payout account with Stripe Connect Express.
pub async fn get_or_create_seller_account(
    db: &Database,
    stripe: &dyn StripeClient,
    organization_id: i64,
    actor_id: i64,
    email: Option<String>,
    country: Option<String>,
) -> Result<SellerAccount, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    if let Some(account) = repositories::seller_account_by_org_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        return Ok(account);
    }

    let mut metadata = std::collections::HashMap::new();
    metadata.insert("organization_id".to_string(), org_summary.public_id.clone());

    let params = CreateAccountParams {
        email,
        country,
        business_type: Some("company".to_string()),
        metadata,
    };

    let stripe_acct = stripe.create_express_account(&params).await?;

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

/// Generate a hosted Stripe AccountLink onboarding URL for a seller organization.
pub async fn create_seller_onboarding_link(
    db: &Database,
    stripe: &dyn StripeClient,
    organization_id: i64,
    actor_id: i64,
    req: CreateSellerOnboardingLinkRequest,
) -> Result<SellerOnboardingLinkResponse, MarketplaceError> {
    let account =
        get_or_create_seller_account(db, stripe, organization_id, actor_id, None, None).await?;

    let link_params = CreateAccountLinkParams {
        account_id: account.stripe_account_id.clone(),
        refresh_url: req.refresh_url,
        return_url: req.return_url,
        link_type: Some("account_onboarding".to_string()),
    };

    let link = stripe.create_account_link(&link_params).await?;

    Ok(SellerOnboardingLinkResponse {
        url: link.url,
        expires_at: link.expires_at,
    })
}

/// Refresh and synchronize the `payouts_enabled` state directly from Stripe.
pub async fn refresh_seller_payout_status(
    db: &Database,
    stripe: &dyn StripeClient,
    organization_id: i64,
    actor_id: i64,
) -> Result<SellerAccount, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let mut account = repositories::seller_account_by_org_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::SellerAccountNotFound)?;

    let stripe_acct = stripe.retrieve_account(&account.stripe_account_id).await?;

    account.payouts_enabled = stripe_acct.payouts_enabled;
    account.charges_enabled = stripe_acct.charges_enabled;
    account.details_submitted = stripe_acct.details_submitted;
    if let Some(cur) = stripe_acct.default_currency {
        account.default_currency = Some(cur);
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
            "organization_id": org_summary.public_id,
            "payouts_enabled": account.payouts_enabled,
            "charges_enabled": account.charges_enabled,
        }),
    )
    .await;

    Ok(account)
}

// ---------------------------------------------------------------------------
// Template Creation & Publishing
// ---------------------------------------------------------------------------

/// Create a new template in `draft` status within an organization.
pub async fn create_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    req: TemplateCreateRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let name_trimmed = req.name.trim();
    if name_trimmed.is_empty() {
        return Err(MarketplaceError::ValidationError(
            "Template name cannot be empty.".to_string(),
        ));
    }
    if name_trimmed.len() > 255 {
        return Err(MarketplaceError::ValidationError(
            "Template name exceeds 255 characters.".to_string(),
        ));
    }

    let visibility = req
        .visibility
        .as_deref()
        .map(|v| v.trim().to_lowercase())
        .unwrap_or_else(|| "private".to_string());
    validate_visibility(&visibility)?;

    let is_free = req.is_free.unwrap_or(true);
    let price_amount = req.price_amount.unwrap_or(0);
    let price_currency = req
        .price_currency
        .as_deref()
        .map(|c| c.trim().to_lowercase())
        .unwrap_or_else(|| "usd".to_string());

    validate_pricing(is_free, price_amount, &price_currency)?;

    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let base_slug = slugify(name_trimmed);
    let mut candidate_slug = base_slug.clone();
    let mut counter = 1;

    while repositories::template_slug_exists_in_org(db, organization_id, &candidate_slug)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        candidate_slug = format!("{base_slug}-{counter}");
        counter += 1;
    }

    let metadata_str = match req.metadata {
        Some(ref val) => serde_json::to_string(val).unwrap_or_else(|_| "{}".to_string()),
        None => "{}".to_string(),
    };

    let template = Template {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        name: name_trimmed.to_string(),
        slug: candidate_slug,
        description: req.description.map(|d| d.trim().to_string()),
        visibility,
        status: "draft".to_string(),
        is_free,
        price_amount,
        price_currency,
        metadata: metadata_str,
        created_by_id: actor_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_template(db, template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.created",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": saved.public_id,
            "organization_id": org_summary.public_id,
            "name": saved.name,
            "slug": saved.slug,
            "visibility": saved.visibility,
            "status": saved.status,
            "is_free": saved.is_free,
            "price_amount": saved.price_amount,
            "price_currency": saved.price_currency,
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

/// List all templates belonging to an organization.
pub async fn list_org_templates(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<TemplateDetail>, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let templates = repositories::templates_for_organization(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut details = Vec::with_capacity(templates.len());
    for t in templates {
        let latest = repositories::latest_version_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
        let count = repositories::count_versions_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        details.push(TemplateDetail {
            template: t,
            organization_public_id: org_summary.public_id.clone(),
            versions: Vec::new(),
            latest_version: latest.map(|v| v.version),
            versions_count: count,
        });
    }

    Ok(details)
}

/// Retrieve a template by public UUID within an organization.
pub async fn get_org_template(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

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

/// Partially update an organization template.
pub async fn update_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: TemplateUpdateRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let mut template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
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
        if trimmed.len() > 255 {
            return Err(MarketplaceError::ValidationError(
                "Template name exceeds 255 characters.".to_string(),
            ));
        }
        template.name = trimmed.to_string();
    }

    if let Some(ref desc) = req.description {
        template.description = Some(desc.trim().to_string());
    }

    if let Some(ref vis) = req.visibility {
        let vis_lower = vis.trim().to_lowercase();
        validate_visibility(&vis_lower)?;
        template.visibility = vis_lower;
    }

    if let Some(is_free) = req.is_free {
        template.is_free = is_free;
    }

    if let Some(amount) = req.price_amount {
        template.price_amount = amount;
    }

    if let Some(ref cur) = req.price_currency {
        template.price_currency = cur.trim().to_lowercase();
    }

    validate_pricing(
        template.is_free,
        template.price_amount,
        &template.price_currency,
    )?;

    let mut status_changed = false;
    if let Some(ref target_status) = req.status {
        let target_lower = target_status.trim().to_lowercase();
        validate_status(&target_lower)?;
        if target_lower != template.status {
            if !can_transition(&template.status, &target_lower) {
                return Err(MarketplaceError::InvalidStateTransition {
                    from: template.status.clone(),
                    to: target_lower,
                });
            }

            // Enforce payouts_enabled requirement for listing paid templates
            if target_lower == "published" && !template.is_free {
                let seller_account = repositories::seller_account_by_org_id(db, organization_id)
                    .await
                    .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

                match seller_account {
                    Some(ref sa) if sa.payouts_enabled => {}
                    _ => return Err(MarketplaceError::SellerPayoutsNotEnabled),
                }
            }

            template.status = target_lower;
            status_changed = true;
        }
    }

    if let Some(ref meta) = req.metadata {
        template.metadata = serde_json::to_string(meta).unwrap_or_else(|_| "{}".to_string());
    }

    template.updated_at = Utc::now();
    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let event_type = if status_changed && template.status == "published" {
        "template.published"
    } else if status_changed && template.status == "archived" {
        "template.archived"
    } else {
        "template.updated"
    };

    emit_event(
        db,
        event_type,
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "name": template.name,
            "visibility": template.visibility,
            "status": template.status,
            "is_free": template.is_free,
            "price_amount": template.price_amount,
            "price_currency": template.price_currency,
        }),
    )
    .await;

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

/// Explicitly publish a template.
///
/// If the template is paid (`is_free == false`), publishing REQUIRES that the seller's
/// payout account exists and has `payouts_enabled == true`.
pub async fn publish_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: TemplatePublishRequest,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let mut template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    // Enforce payouts_enabled requirement before publishing a paid template
    if !template.is_free {
        let seller_account = repositories::seller_account_by_org_id(db, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        match seller_account {
            Some(ref sa) if sa.payouts_enabled => {}
            _ => return Err(MarketplaceError::SellerPayoutsNotEnabled),
        }
    }

    if template.status != "published" {
        if !can_transition(&template.status, "published") {
            return Err(MarketplaceError::InvalidStateTransition {
                from: template.status.clone(),
                to: "published".to_string(),
            });
        }
        template.status = "published".to_string();
    }

    if let Some(ref vis) = req.visibility {
        let vis_lower = vis.trim().to_lowercase();
        validate_visibility(&vis_lower)?;
        template.visibility = vis_lower;
    }

    template.updated_at = Utc::now();
    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.published",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "visibility": template.visibility,
            "status": template.status,
            "is_free": template.is_free,
            "price_amount": template.price_amount,
            "price_currency": template.price_currency,
        }),
    )
    .await;

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

/// Explicitly archive a template.
pub async fn archive_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let mut template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    if template.status != "archived" {
        if !can_transition(&template.status, "archived") {
            return Err(MarketplaceError::InvalidStateTransition {
                from: template.status.clone(),
                to: "archived".to_string(),
            });
        }
        template.status = "archived".to_string();
    }

    template.updated_at = Utc::now();
    repositories::update_template(db, &template)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.archived",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "status": template.status,
        }),
    )
    .await;

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

/// Delete a template and cascade delete its versions.
pub async fn delete_template(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
) -> Result<(), MarketplaceError> {
    let org_summary = repositories::organization_summary_by_id(db, organization_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    repositories::delete_template_by_id(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.deleted",
        Some(organization_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "template_id": template.public_id,
            "organization_id": org_summary.public_id,
            "name": template.name,
        }),
    )
    .await;

    Ok(())
}

/// List public published templates for the marketplace catalog.
pub async fn list_public_templates(
    db: &Database,
    search: Option<&str>,
) -> Result<Vec<TemplateDetail>, MarketplaceError> {
    let templates = repositories::public_published_templates(db, search)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut details = Vec::with_capacity(templates.len());
    for t in templates {
        let org_summary = repositories::organization_summary_by_id(db, t.organization_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
        let org_pub = org_summary
            .map(|o| o.public_id)
            .unwrap_or_else(|| "org".to_string());

        let latest = repositories::latest_version_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
        let count = repositories::count_versions_for_template(db, t.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        details.push(TemplateDetail {
            template: t,
            organization_public_id: org_pub,
            versions: Vec::new(),
            latest_version: latest.map(|v| v.version),
            versions_count: count,
        });
    }

    Ok(details)
}

/// Look up a public published template by UUID or slug.
pub async fn get_public_template(
    db: &Database,
    template_public_id_or_slug: &str,
) -> Result<TemplateDetail, MarketplaceError> {
    let template =
        repositories::public_published_template_by_public_id(db, template_public_id_or_slug)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let template = match template {
        Some(t) => t,
        None => {
            let maybe_t = repositories::template_by_public_id(db, template_public_id_or_slug)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

            match maybe_t {
                Some(t) => {
                    if t.visibility != "public" {
                        return Err(MarketplaceError::TemplatePrivate);
                    }
                    if t.status != "published" {
                        return Err(MarketplaceError::TemplateNotPublished);
                    }
                    t
                }
                None => return Err(MarketplaceError::TemplateNotFound),
            }
        }
    };

    let org_summary = repositories::organization_summary_by_id(db, template.organization_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    let org_pub = org_summary
        .map(|o| o.public_id)
        .unwrap_or_else(|| "org".to_string());

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
// Template Versions
// ---------------------------------------------------------------------------

/// Create a new version for an organization template.
pub async fn create_template_version(
    db: &Database,
    organization_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: TemplateVersionCreateRequest,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    validate_version(&req.version)?;

    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let existing = repositories::version_by_semver_and_template(db, &req.version, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
    if existing.is_some() {
        return Err(MarketplaceError::VersionAlreadyExists);
    }

    let manifest_str = match req.manifest {
        Some(ref val) => serde_json::to_string(val).unwrap_or_else(|_| "{}".to_string()),
        None => "{}".to_string(),
    };

    let version = TemplateVersion {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        template_id: ForeignKey::new(template.id),
        version: req.version.trim().to_string(),
        changelog: req.changelog.unwrap_or_default(),
        manifest: manifest_str,
        readme: req.readme.unwrap_or_default(),
        created_by_id: actor_id,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let saved = repositories::insert_version(db, version)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    emit_event(
        db,
        "template.version.created",
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

/// List all versions belonging to a template within an organization.
pub async fn list_template_versions(
    db: &Database,
    organization_id: i64,
    template_public_id: &str,
) -> Result<Vec<TemplateVersionDetail>, MarketplaceError> {
    let template =
        repositories::template_by_public_id_and_org(db, template_public_id, organization_id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::TemplateNotFound)?;

    let versions = repositories::versions_for_template(db, template.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    Ok(versions
        .into_iter()
        .map(|v| TemplateVersionDetail {
            version: v,
            template_public_id: template.public_id.clone(),
        })
        .collect())
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

/// Delete a template version by public UUID.
pub async fn delete_template_version(
    db: &Database,
    organization_id: i64,
    _actor_id: i64,
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

    Ok(())
}

/// Retrieve a specific version of a public published template.
pub async fn get_public_template_version(
    db: &Database,
    template_public_id: &str,
    version_public_id: &str,
) -> Result<TemplateVersionDetail, MarketplaceError> {
    let template = repositories::public_published_template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let template = match template {
        Some(t) => t,
        None => {
            let maybe_t = repositories::template_by_public_id(db, template_public_id)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
            match maybe_t {
                Some(t) => {
                    if t.visibility != "public" {
                        return Err(MarketplaceError::TemplatePrivate);
                    }
                    if t.status != "published" {
                        return Err(MarketplaceError::TemplateNotPublished);
                    }
                    t
                }
                None => return Err(MarketplaceError::TemplateNotFound),
            }
        }
    };

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

// ---------------------------------------------------------------------------
// Purchases & Entitlements
// ---------------------------------------------------------------------------

/// Purchase a template using a Stripe Connect destination charge.
///
/// # Idempotency and Double-Charge Prevention:
/// 1. Checks if an active succeeded entitlement already exists for `(buyer_organization_id, template_id)`.
///    If present, returns the existing record immediately without contacting Stripe.
/// 2. Uses Stripe's idempotency key mechanism (`Idempotency-Key` header) so repeated network requests
///    cannot create duplicate payment intents or charges on Stripe's side.
/// 3. Records the idempotency key in `marketplace_templatepurchase` and checks it locally before insert.
pub async fn purchase_template(
    db: &Database,
    stripe: &dyn StripeClient,
    buyer_org_id: i64,
    actor_id: i64,
    template_public_id: &str,
    req: PurchaseTemplateRequest,
) -> Result<PurchaseOutcome, MarketplaceError> {
    let buyer_summary = repositories::organization_summary_by_id(db, buyer_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let template = repositories::template_by_public_id(db, template_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::TemplateNotFound)?;

    if template.organization_id.id == buyer_org_id {
        return Err(MarketplaceError::CannotPurchaseOwnTemplate);
    }

    let seller_summary = repositories::organization_summary_by_id(db, template.organization_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    // Check if buyer already owns an active entitlement for this template
    if let Some(existing) =
        repositories::succeeded_purchase_for_buyer_and_template(db, buyer_org_id, template.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        return Ok(PurchaseOutcome {
            purchase: existing,
            buyer_org_public_id: buyer_summary.public_id,
            template_public_id: template.public_id,
            template_name: template.name,
            version_public_id: req.template_version_id,
            seller_org_public_id: seller_summary.public_id,
            client_secret: None,
        });
    }

    let idempotency_key = req.idempotency_key.unwrap_or_else(|| {
        format!(
            "mkt_buy_{}_{}_{}",
            buyer_org_id,
            template.id,
            Uuid::new_v4()
        )
    });

    // Check local idempotency key
    if let Some(existing) = repositories::purchase_by_idempotency_key(db, &idempotency_key)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
    {
        return Ok(PurchaseOutcome {
            purchase: existing,
            buyer_org_public_id: buyer_summary.public_id,
            template_public_id: template.public_id,
            template_name: template.name,
            version_public_id: req.template_version_id,
            seller_org_public_id: seller_summary.public_id,
            client_secret: None,
        });
    }

    // Free template handling: zero-price entitlement granted directly without Stripe charge
    if template.is_free {
        let purchase = TemplatePurchase {
            id: 0,
            public_id: Uuid::new_v4().to_string(),
            buyer_organization_id: ForeignKey::new(buyer_org_id),
            template_id: ForeignKey::new(template.id),
            template_version_id: None,
            seller_organization_id: ForeignKey::new(template.organization_id.id),
            amount: 0,
            currency: template.price_currency.clone(),
            platform_fee: 0,
            seller_amount: 0,
            stripe_payment_intent_id: "free_grant".to_string(),
            status: "succeeded".to_string(),
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
            "marketplace.purchase.completed",
            Some(buyer_org_id),
            None,
            None,
            Some(actor_id),
            serde_json::json!({
                "purchase_id": saved.public_id,
                "buyer_organization_id": buyer_summary.public_id,
                "template_id": template.public_id,
                "amount": 0,
                "is_free": true,
            }),
        )
        .await;

        return Ok(PurchaseOutcome {
            purchase: saved,
            buyer_org_public_id: buyer_summary.public_id,
            template_public_id: template.public_id,
            template_name: template.name,
            version_public_id: req.template_version_id,
            seller_org_public_id: seller_summary.public_id,
            client_secret: None,
        });
    }

    // Paid template handling: verify seller Stripe account
    let seller_account = repositories::seller_account_by_org_id(db, template.organization_id.id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::SellerNotConfigured)?;

    if !seller_account.payouts_enabled {
        return Err(MarketplaceError::SellerPayoutsNotEnabled);
    }

    let split = calculate_split(template.price_amount, DEFAULT_COMMISSION_BPS)?;

    let mut metadata = std::collections::HashMap::new();
    metadata.insert("template_id".to_string(), template.public_id.clone());
    metadata.insert(
        "buyer_organization_id".to_string(),
        buyer_summary.public_id.clone(),
    );
    metadata.insert(
        "seller_organization_id".to_string(),
        seller_summary.public_id.clone(),
    );

    let pi_params = CreatePaymentIntentParams {
        amount: split.amount,
        currency: template.price_currency.clone(),
        application_fee_amount: split.platform_fee,
        destination_account_id: seller_account.stripe_account_id.clone(),
        description: Some(format!("Bloom Marketplace Template: {}", template.name)),
        metadata,
    };

    let payment_intent = stripe
        .create_payment_intent(&pi_params, Some(&idempotency_key))
        .await?;

    let version_fk = if let Some(ref ver_pub) = req.template_version_id {
        repositories::version_by_public_id(db, ver_pub)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .map(|v| v.id)
    } else {
        None
    };

    let purchase = TemplatePurchase {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        buyer_organization_id: ForeignKey::new(buyer_org_id),
        template_id: ForeignKey::new(template.id),
        template_version_id: version_fk,
        seller_organization_id: ForeignKey::new(template.organization_id.id),
        amount: split.amount,
        currency: template.price_currency.clone(),
        platform_fee: split.platform_fee,
        seller_amount: split.seller_amount,
        stripe_payment_intent_id: payment_intent.id.clone(),
        status: payment_intent.status.clone(),
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
        Some(buyer_org_id),
        None,
        None,
        Some(actor_id),
        serde_json::json!({
            "purchase_id": saved.public_id,
            "buyer_organization_id": buyer_summary.public_id,
            "template_id": template.public_id,
            "amount": saved.amount,
            "platform_fee": saved.platform_fee,
            "seller_amount": saved.seller_amount,
            "status": saved.status,
        }),
    )
    .await;

    Ok(PurchaseOutcome {
        purchase: saved,
        buyer_org_public_id: buyer_summary.public_id,
        template_public_id: template.public_id,
        template_name: template.name,
        version_public_id: req.template_version_id,
        seller_org_public_id: seller_summary.public_id,
        client_secret: payment_intent.client_secret,
    })
}

/// List all purchases for a buyer organization.
pub async fn list_organization_purchases(
    db: &Database,
    buyer_org_id: i64,
) -> Result<Vec<PurchaseOutcome>, MarketplaceError> {
    let buyer_summary = repositories::organization_summary_by_id(db, buyer_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let purchases = repositories::purchases_for_buyer_org(db, buyer_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

    let mut outcomes = Vec::with_capacity(purchases.len());
    for p in purchases {
        let template = repositories::template_by_id(db, p.template_id.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;

        let (tmpl_pub, tmpl_name) = match template {
            Some(t) => (t.public_id, t.name),
            None => ("deleted".to_string(), "Deleted Template".to_string()),
        };

        let seller_summary =
            repositories::organization_summary_by_id(db, p.seller_organization_id.id)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?;
        let seller_pub = seller_summary
            .map(|s| s.public_id)
            .unwrap_or_else(|| "unknown".to_string());

        let ver_pub = if let Some(vid) = p.template_version_id {
            repositories::version_by_id(db, vid)
                .await
                .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
                .map(|v| v.public_id)
        } else {
            None
        };

        outcomes.push(PurchaseOutcome {
            purchase: p,
            buyer_org_public_id: buyer_summary.public_id.clone(),
            template_public_id: tmpl_pub,
            template_name: tmpl_name,
            version_public_id: ver_pub,
            seller_org_public_id: seller_pub,
            client_secret: None,
        });
    }

    Ok(outcomes)
}

/// Retrieve a single purchase by public UUID for an organization.
pub async fn get_organization_purchase(
    db: &Database,
    buyer_org_id: i64,
    purchase_public_id: &str,
) -> Result<PurchaseOutcome, MarketplaceError> {
    let buyer_summary = repositories::organization_summary_by_id(db, buyer_org_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::OrganizationNotFound)?;

    let purchase = repositories::purchase_by_public_id(db, purchase_public_id)
        .await
        .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
        .ok_or(MarketplaceError::PurchaseNotFound)?;

    if purchase.buyer_organization_id.id != buyer_org_id
        && purchase.seller_organization_id.id != buyer_org_id
    {
        return Err(MarketplaceError::PurchaseNotFound);
    }

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
