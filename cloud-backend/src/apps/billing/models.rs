//! Persistence models for the `billing` domain app.

use chrono::{DateTime, NaiveDate, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// A billing plan defines pricing tiers, quotas, and feature flags.
///
/// Standard plan tiers include `free`, `pro`, and `enterprise`. Entitlements are stored
/// as JSON text in the `entitlements` column and parsed at runtime into typed structures.
#[derive(Model, Debug, Clone)]
#[djangors(app = "billing", table_name = "billing_plan")]
pub struct Plan {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Plan name tier: `free`, `pro`, or `enterprise`.
    #[djangors(max_length = 32)]
    pub name: String,

    /// Optional human-readable description of the plan tier.
    #[djangors(nullable)]
    pub description: Option<String>,

    /// Plan price in integer minor currency units (e.g. 0 for free, 2900 for $29.00 Pro).
    #[djangors(default = 0)]
    pub price_minor: i64,

    /// Three-letter ISO 4217 currency code (e.g. "USD").
    #[djangors(max_length = 3, default = "USD")]
    pub currency: String,

    /// JSON string containing feature flags and quota limits.
    #[djangors(default = "{}")]
    pub entitlements: String,

    /// Whether this plan is currently available for subscription.
    #[djangors(default = true)]
    pub active: bool,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

/// An active subscription linking a tenant organization to a billing plan.
///
/// Scoped to an organization via a 1:1 foreign key. Provider reference columns
/// (`stripe_customer_id` and `stripe_subscription_id`) retain their schema names
/// for compatibility with the spec, but function as generic provider identifiers
/// for Bachs (`checkout_id` / `customer_id`) or Paystack (`customer_code` / `subscription_code`).
#[derive(Model, Debug, Clone)]
#[djangors(app = "billing", table_name = "billing_subscription")]
pub struct Subscription {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// 1:1 foreign key referencing the tenant organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Foreign key referencing the active billing plan.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub plan_id: ForeignKey<Plan>,

    /// Optional foreign key ID of pending plan upgrade awaiting payment confirmation.
    #[djangors(nullable)]
    pub pending_plan_id: Option<i64>,

    /// Lifecycle status: `trialing`, `active`, `past_due`, `locked`, or `cancelled`.
    #[djangors(max_length = 32)]
    pub status: String,

    /// Optional timestamp when a free trial period concludes.
    #[djangors(nullable)]
    pub trial_ends_at: Option<DateTime<Utc>>,

    /// Optional timestamp when the subscription was activated/paid.
    #[djangors(nullable)]
    pub activated_at: Option<DateTime<Utc>>,

    /// Start timestamp of the current billing cycle.
    pub current_period_start: DateTime<Utc>,

    /// End timestamp of the current billing cycle.
    pub current_period_end: DateTime<Utc>,

    /// Generic provider customer reference (column named `stripe_customer_id` per spec schema).
    #[djangors(max_length = 255, nullable)]
    pub stripe_customer_id: Option<String>,

    /// Generic provider subscription reference (column named `stripe_subscription_id` per spec schema).
    #[djangors(max_length = 255, nullable)]
    pub stripe_subscription_id: Option<String>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Subscription {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// A discrete usage event recorded for metering and quota tracking.
///
/// Metrics include `build_minutes`, `artifact_storage_gb`, `web_bandwidth_gb`, and `deploy_count`.
/// Value represents integer units (e.g. whole minutes, whole gigabytes, integer counts).
#[derive(Model, Debug, Clone)]
#[djangors(app = "billing", table_name = "billing_usagerecord")]
pub struct UsageRecord {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// Foreign key referencing the tenant organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Usage metric name: `build_minutes`, `artifact_storage_gb`, `web_bandwidth_gb`, or `deploy_count`.
    #[djangors(max_length = 32)]
    pub metric: String,

    /// Numeric metric value in integer units (minutes, GB, or counts).
    pub value: i64,

    /// Timestamp when usage occurred or was aggregated.
    #[djangors(auto_now_add)]
    pub recorded_at: DateTime<Utc>,

    /// Arbitrary metadata JSON string associated with the usage event.
    #[djangors(default = "{}")]
    pub metadata: String,
}

impl Scoped for UsageRecord {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// An invoice record generated periodically for metered and subscription charges.
///
/// All monetary values are integer minor units (`amount_cents: i64`). Provider invoice reference
/// (`stripe_invoice_id`) retains its schema name for compatibility with the spec, but carries
/// generic provider invoice or transaction references from Bachs or Paystack.
#[derive(Model, Debug, Clone)]
#[djangors(app = "billing", table_name = "billing_invoice")]
pub struct Invoice {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the subscription this invoice belongs to.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub subscription_id: ForeignKey<Subscription>,

    /// Foreign key referencing the tenant organization.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Total invoice amount in integer cents (e.g. 2900 for $29.00). Never a float.
    pub amount_cents: i64,

    /// Invoice status: `draft`, `sent`, `paid`, `overdue`, or `void`.
    #[djangors(max_length = 32)]
    pub status: String,

    /// Due date for payment.
    pub due_date: NaiveDate,

    /// Optional timestamp when payment was confirmed.
    #[djangors(nullable)]
    pub paid_at: Option<DateTime<Utc>>,

    /// Generic provider invoice/charge reference (column named `stripe_invoice_id` per spec schema).
    #[djangors(max_length = 255, nullable)]
    pub stripe_invoice_id: Option<String>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

impl Scoped for Invoice {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
