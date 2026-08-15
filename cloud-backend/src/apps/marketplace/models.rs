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

    /// Total count of published user reviews.
    #[djangors(default = 0)]
    pub rating_count: i64,

    /// Sum of all star ratings from published reviews (1..=5 stars each).
    #[djangors(default = 0)]
    pub rating_sum: i64,

    /// Bayesian average rating in milli-stars (scale 1000..5000).
    #[djangors(default = 0, db_index)]
    pub rating_bayesian_milli: i64,

    /// Durable total install/download count across all versions.
    #[djangors(default = 0, db_index)]
    pub install_count: i64,

    /// Featured placement type: `none`, `editorial` (staff curated), or `paid` (sponsored placement).
    #[djangors(max_length = 32, default = "none", db_index)]
    pub featured_type: String,

    /// Optional timestamp until which the featured placement remains active.
    #[djangors(nullable)]
    pub featured_until: Option<DateTime<Utc>>,

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

    /// Durable total install/download count for this specific version.
    #[djangors(default = 0)]
    pub install_count: i64,

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

/// A buyer review and star rating for a template.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_templatereview")]
pub struct TemplateReview {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the rated template.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub template_id: ForeignKey<Template>,

    /// Foreign key referencing the reviewing buyer organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub buyer_organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Internal primary key of the user who authored the review.
    pub reviewer_user_id: i64,

    /// Rating score on a strict 1..=5 integer scale.
    pub rating: i64,

    /// Review title or headline.
    #[djangors(max_length = 255, default = "")]
    pub title: String,

    /// Detailed markdown or text review comments.
    #[djangors(default = "")]
    pub comment: String,

    /// Moderation status: `published`, `hidden`, or `archived`.
    #[djangors(max_length = 32, default = "published", db_index)]
    pub status: String,

    /// Optional author reply text (right of reply for template creators).
    #[djangors(nullable)]
    pub author_response: Option<String>,

    /// Timestamp when the template author replied.
    #[djangors(nullable)]
    pub author_responded_at: Option<DateTime<Utc>>,

    /// Internal user ID of the template author who replied.
    #[djangors(nullable)]
    pub author_responded_by_id: Option<i64>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for TemplateReview {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "buyer_organization_id")
    }
}

/// An abuse or violation report filed against a review.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_reviewreport")]
pub struct ReviewReport {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the reported review.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub review_id: ForeignKey<TemplateReview>,

    /// Foreign key referencing the reporting organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub reporter_organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Internal user ID of the reporting actor.
    pub reporter_user_id: i64,

    /// Report reason category (e.g. `spam`, `harassment`, `misleading`, `inappropriate`).
    #[djangors(max_length = 64)]
    pub reason: String,

    /// Additional context or details provided by the reporter.
    #[djangors(default = "")]
    pub details: String,

    /// Report review status: `pending`, `reviewed`, `dismissed`, or `actioned`.
    #[djangors(max_length = 32, default = "pending", db_index)]
    pub status: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for ReviewReport {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "reporter_organization_id")
    }
}

/// Short-lived deduplication record for install analytics.
///
/// # Privacy & Retention:
/// `actor_hash` stores a SHA-256 HMAC digest of (daily rotating salt + client identifier/IP).
/// No raw IP addresses or persistent user identifiers are ever stored in this table.
/// Records older than 48 hours can be safely purged without affecting aggregate counts.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_templateinstalldedup")]
pub struct TemplateInstallDedup {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the downloaded/installed template.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub template_id: ForeignKey<Template>,

    /// Optional nullable foreign key referencing the installed version.
    #[djangors(nullable)]
    pub template_version_id: Option<i64>,

    /// Daily salted SHA-256 hash of the installer actor for deduplication.
    #[djangors(max_length = 64)]
    pub actor_hash: String,

    /// Date bucket string (`YYYY-MM-DD`) partitioning deduplication windows.
    #[djangors(max_length = 10)]
    pub date_bucket: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

/// Durable verified install record gating reviews for free templates.
#[derive(Model, Debug, Clone)]
#[djangors(app = "marketplace", table_name = "marketplace_templateinstall")]
pub struct TemplateInstall {
    /// Internal auto-increment primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the installed template.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub template_id: ForeignKey<Template>,

    /// Optional nullable foreign key referencing the installed version.
    #[djangors(nullable)]
    pub template_version_id: Option<i64>,

    /// Foreign key referencing the installing buyer organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub buyer_organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Internal user ID who executed the installation.
    pub installed_by_user_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

impl Scoped for TemplateInstall {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "buyer_organization_id")
    }
}
