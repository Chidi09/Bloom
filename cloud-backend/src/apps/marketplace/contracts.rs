//! Data Transfer Objects (DTOs) and wire contracts for the `marketplace` app.

use serde::{Deserialize, Serialize};

/// Inbound payload for creating a new project template.
#[derive(Debug, Clone, Deserialize)]
pub struct TemplateCreateRequest {
    /// Human-readable template display name.
    pub name: String,

    /// Optional markdown or text description.
    pub description: Option<String>,

    /// Visibility scope: `private` or `public` (defaults to `private`).
    pub visibility: Option<String>,

    /// Whether this template is free (`true`) or paid (`false`). Defaults to `true`.
    pub is_free: Option<bool>,

    /// Template price in integer minor units (e.g. 2900 for $29.00). Must be > 0 if `is_free` is false.
    pub price_amount: Option<i64>,

    /// Three-letter ISO currency code (e.g. `usd`).
    pub price_currency: Option<String>,

    /// Optional structured JSON metadata (framework version, tags, platforms).
    pub metadata: Option<serde_json::Value>,
}

/// Inbound partial payload for updating an existing project template.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct TemplateUpdateRequest {
    /// Optional updated display name.
    pub name: Option<String>,

    /// Optional updated description.
    pub description: Option<String>,

    /// Optional updated visibility (`private` or `public`).
    pub visibility: Option<String>,

    /// Optional updated lifecycle status (`draft`, `published`, `archived`).
    pub status: Option<String>,

    /// Optional updated free/paid flag.
    pub is_free: Option<bool>,

    /// Optional updated price amount in minor units.
    pub price_amount: Option<i64>,

    /// Optional updated price currency.
    pub price_currency: Option<String>,

    /// Optional updated structured JSON metadata.
    pub metadata: Option<serde_json::Value>,
}

/// Inbound payload for explicitly publishing a template.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct TemplatePublishRequest {
    /// Optional updated visibility on publish (e.g. promote to `public`).
    pub visibility: Option<String>,
}

/// Inbound payload for creating and publishing a new template version.
#[derive(Debug, Clone, Deserialize)]
pub struct TemplateVersionCreateRequest {
    /// Semantic version string (e.g. `1.0.0`).
    pub version: String,

    /// Optional markdown release notes / changelog for this version.
    pub changelog: Option<String>,

    /// Optional structured template manifest (scaffold structure, variables).
    pub manifest: Option<serde_json::Value>,

    /// Optional markdown documentation / README.
    pub readme: Option<String>,
}

/// Inbound payload for creating an onboarding or update link for a seller.
#[derive(Debug, Clone, Deserialize)]
pub struct CreateSellerOnboardingLinkRequest {
    /// Redirect URL if the onboarding session expires or needs refresh.
    pub refresh_url: String,

    /// Redirect URL once onboarding is completed.
    pub return_url: String,
}

/// Inbound payload for purchasing a paid template.
///
/// NOTE: Price, fees, and destination accounts are NEVER supplied by the buyer.
/// They are resolved strictly server-side from the template and seller models.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct PurchaseTemplateRequest {
    /// Optional specific template version public ID being purchased.
    pub template_version_id: Option<String>,

    /// Optional client-supplied idempotency key for preventing duplicate charges.
    pub idempotency_key: Option<String>,
}

/// Inbound payload for refunding a template purchase.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct RefundPurchaseRequest {
    /// Optional reason for the refund.
    pub reason: Option<String>,
}

/// Outbound wire representation of a project template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// External public UUID v4 of the owning organization.
    pub organization_id: String,

    /// Display name.
    pub name: String,

    /// URL-safe slug unique per organization.
    pub slug: String,

    /// Optional description.
    pub description: Option<String>,

    /// Visibility scope: `private` or `public`.
    pub visibility: String,

    /// Lifecycle status: `draft`, `published`, or `archived`.
    pub status: String,

    /// Whether the template is free.
    pub is_free: bool,

    /// Price amount in integer minor units (0 for free templates).
    pub price_amount: i64,

    /// Three-letter ISO currency code.
    pub price_currency: String,

    /// Parsed JSON metadata.
    pub metadata: serde_json::Value,

    /// Semver string of the latest available version, if any.
    pub latest_version: Option<String>,

    /// Total count of published versions for this template.
    pub versions_count: i64,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,

    /// Last update timestamp (ISO 8601).
    pub updated_at: String,
}

/// Outbound detailed representation of a template including all version summaries.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateDetailResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// External public UUID v4 of the owning organization.
    pub organization_id: String,

    /// Display name.
    pub name: String,

    /// URL-safe slug unique per organization.
    pub slug: String,

    /// Optional description.
    pub description: Option<String>,

    /// Visibility scope: `private` or `public`.
    pub visibility: String,

    /// Lifecycle status: `draft`, `published`, or `archived`.
    pub status: String,

    /// Whether the template is free.
    pub is_free: bool,

    /// Price amount in integer minor units.
    pub price_amount: i64,

    /// Three-letter ISO currency code.
    pub price_currency: String,

    /// Parsed JSON metadata.
    pub metadata: serde_json::Value,

    /// Summary list of all available versions.
    pub versions: Vec<TemplateVersionSummaryResponse>,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,

    /// Last update timestamp (ISO 8601).
    pub updated_at: String,
}

/// Outbound wire representation of a full template version.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateVersionResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// External public UUID v4 of the parent template.
    pub template_id: String,

    /// Semantic version string.
    pub version: String,

    /// Markdown changelog.
    pub changelog: String,

    /// Parsed JSON manifest (variables, file structures).
    pub manifest: serde_json::Value,

    /// Markdown documentation / README.
    pub readme: String,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,

    /// Last update timestamp (ISO 8601).
    pub updated_at: String,
}

/// Lightweight summary of a template version in listing contexts.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateVersionSummaryResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// Semantic version string.
    pub version: String,

    /// Markdown changelog.
    pub changelog: String,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,
}

/// Outbound representation of an organization's seller payout account.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SellerAccountResponse {
    /// External public UUID v4 identifier.
    pub id: String,

    /// External public UUID v4 of the organization.
    pub organization_id: String,

    /// Stripe connected account ID (`acct_...`).
    pub stripe_account_id: String,

    /// Whether payouts are enabled. Must be true to list paid templates.
    pub payouts_enabled: bool,

    /// Whether charges are enabled.
    pub charges_enabled: bool,

    /// Whether KYC details have been submitted.
    pub details_submitted: bool,

    /// Default payout currency code.
    pub default_currency: Option<String>,

    /// Timestamp when status was last verified against Stripe (ISO 8601).
    pub last_payouts_checked_at: Option<String>,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,

    /// Last update timestamp (ISO 8601).
    pub updated_at: String,
}

/// Outbound representation of a Stripe AccountLink for seller onboarding.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SellerOnboardingLinkResponse {
    /// Hosted Stripe Connect URL.
    pub url: String,

    /// Expiration unix timestamp.
    pub expires_at: i64,
}

/// Outbound representation of a template purchase / entitlement.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PurchaseResponse {
    /// External public UUID v4 of the purchase.
    pub id: String,

    /// Buyer organization public UUID v4.
    pub buyer_organization_id: String,

    /// Purchased template public UUID v4.
    pub template_id: String,

    /// Name of the purchased template.
    pub template_name: String,

    /// Purchased version public UUID v4 if version-specific.
    pub template_version_id: Option<String>,

    /// Seller organization public UUID v4.
    pub seller_organization_id: String,

    /// Total purchase price in integer minor units.
    pub amount: i64,

    /// Three-letter ISO currency code.
    pub currency: String,

    /// Platform commission cut in minor units.
    pub platform_fee: i64,

    /// Seller payout amount in minor units.
    pub seller_amount: i64,

    /// Lifecycle status (`pending`, `succeeded`, `refunded`, `failed`).
    pub status: String,

    /// Stripe client secret if client-side payment confirmation is required.
    pub client_secret: Option<String>,

    /// Creation timestamp (ISO 8601).
    pub created_at: String,
}

/// Outbound representation of a refund outcome.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefundResponse {
    /// Purchase public UUID v4.
    pub purchase_id: String,

    /// Stripe refund identifier (`re_...`).
    pub stripe_refund_id: String,

    /// Refunded amount in integer minor units.
    pub amount: i64,

    /// Three-letter ISO currency code.
    pub currency: String,

    /// Refund status (`succeeded`, `pending`, `failed`).
    pub status: String,
}

/// Outbound response for template entitlement / access check.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateAccessResponse {
    /// Whether the organization is entitled to download/use this template.
    pub has_access: bool,

    /// Reason or entitlement tier (e.g. `owner`, `free_template`, `purchased`, `no_entitlement`).
    pub access_reason: String,

    /// Template public UUID.
    pub template_id: String,

    /// Version public UUID if checked for a version.
    pub version_id: Option<String>,
}
