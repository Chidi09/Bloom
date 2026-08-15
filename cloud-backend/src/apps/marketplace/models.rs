//! Persistence models for the `marketplace` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// A publishable, versioned project template.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_template")]
pub struct Template {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the owning organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Human-readable template display name.
    #[djangors(max_length = 255)]
    pub name: String,

    /// URL-safe slug, unique per organization.
    #[djangors(max_length = 64)]
    pub slug: String,

    /// Optional markdown or text description.
    #[djangors(max_length = 2000, nullable)]
    pub description: Option<String>,

    /// Visibility scope: `private` (organization-only) or `public` (discoverable in marketplace).
    #[djangors(max_length = 32, default = "private", db_index)]
    pub visibility: String,

    /// Lifecycle status: `draft`, `published`, or `archived`.
    #[djangors(max_length = 32, default = "draft", db_index)]
    pub status: String,

    /// Whether this template is free (`true`) or requires paid purchase (`false`).
    #[djangors(default = true)]
    pub is_free: bool,

    /// Template price in integer minor units (e.g. 2900 for $29.00). 0 for free templates.
    #[djangors(default = 0)]
    pub price_amount: i64,

    /// Three-letter ISO currency code (e.g. `usd`).
    #[djangors(max_length = 3, default = "usd")]
    pub price_currency: String,

    /// JSON metadata (tags, categories, framework requirements, icon URLs). Stored as JSON text.
    #[djangors(default = "{}")]
    pub metadata: String,

    /// Internal primary key of the user who created this template.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Template {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// A specific version of a template, with manifest and file layout.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_templateversion")]
pub struct TemplateVersion {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent template.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub template_id: ForeignKey<Template>,

    /// Semantic version string (e.g. `1.0.0`).
    #[djangors(max_length = 64, db_index)]
    pub version: String,

    /// Markdown changelog for this release version.
    #[djangors(default = "")]
    pub changelog: String,

    /// Template manifest (variables, dependencies, scaffold file structure). Stored as JSON text.
    #[djangors(default = "{}")]
    pub manifest: String,

    /// Markdown documentation / README for this version.
    #[djangors(default = "")]
    pub readme: String,

    /// Internal primary key of the user who published this version.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

/// A seller payout account linking an organization to Stripe Connect Express.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_selleraccount")]
pub struct SellerAccount {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the tenant organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Stripe connected account identifier (`acct_...`).
    #[djangors(max_length = 255)]
    pub stripe_account_id: String,

    /// Whether payouts are enabled for this account.
    ///
    /// Must be `true` before the seller can publish or list paid templates.
    #[djangors(default = false)]
    pub payouts_enabled: bool,

    /// Whether charges are enabled on Stripe.
    #[djangors(default = false)]
    pub charges_enabled: bool,

    /// Whether onboarding KYC details have been submitted.
    #[djangors(default = false)]
    pub details_submitted: bool,

    /// Default 3-letter currency code (e.g. `usd`, `eur`).
    #[djangors(max_length = 3, nullable)]
    pub default_currency: Option<String>,

    /// Timestamp when payout status was last refreshed from Stripe.
    #[djangors(nullable)]
    pub last_payouts_checked_at: Option<DateTime<Utc>>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for SellerAccount {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// A purchase/entitlement record for a template.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_templatepurchase")]
pub struct TemplatePurchase {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the purchasing (buyer) organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub buyer_organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Foreign key referencing the purchased template.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub template_id: ForeignKey<Template>,

    /// Optional nullable foreign key referencing the specific version at purchase time.
    #[djangors(nullable)]
    pub template_version_id: Option<i64>,

    /// Foreign key referencing the seller organization receiving the payout.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub seller_organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Total purchase amount in integer minor units (e.g. cents). Never a float.
    pub amount: i64,

    /// Three-letter ISO currency code (e.g. `usd`).
    #[djangors(max_length = 3, default = "usd")]
    pub currency: String,

    /// Platform application fee cut in integer minor units.
    pub platform_fee: i64,

    /// Seller payout amount in integer minor units (`amount - platform_fee`).
    pub seller_amount: i64,

    /// Stripe PaymentIntent ID (`pi_...`).
    #[djangors(max_length = 255)]
    pub stripe_payment_intent_id: String,

    /// Lifecycle status: `pending`, `succeeded`, `refunded`, or `failed`.
    #[djangors(max_length = 32, default = "pending")]
    pub status: String,

    /// Unique idempotency key for preventing duplicate charges.
    #[djangors(max_length = 128)]
    pub idempotency_key: String,

    /// Internal primary key of the user who performed the purchase.
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for TemplatePurchase {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "buyer_organization_id")
    }
}
