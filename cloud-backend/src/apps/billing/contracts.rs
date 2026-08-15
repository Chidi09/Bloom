//! Data transfer objects (request/response shapes) for the `billing` app.

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

/// Granular boolean feature entitlement flags defined in a plan's entitlements JSON.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeatureEntitlements {
    /// Whether iOS TestFlight deployments are permitted.
    #[serde(default)]
    pub testflight_deployments: bool,

    /// Whether Android Google Play track deployments are permitted.
    #[serde(default)]
    pub google_play_deployments: bool,

    /// Whether custom Flutter Web hosting and custom domains are permitted.
    #[serde(default)]
    pub web_hosting: bool,

    /// Whether Shorebird code push / patch creation is permitted.
    #[serde(default)]
    pub shorebird: bool,

    /// Whether visual CI/CD workflows and automated pipelines are permitted.
    #[serde(default)]
    pub workflows: bool,

    /// Whether SLA-backed priority customer support is enabled.
    #[serde(default)]
    pub priority_support: bool,
}

/// Typed structure parsed from `Plan.entitlements` JSON blob.
///
/// If unparseable or missing, defaults to zero quotas and disabled features
/// (most restrictive sensible defaults, never panics and never defaults to unlimited).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Entitlements {
    /// Maximum number of projects allowed in the organization.
    #[serde(default)]
    pub max_projects: i64,

    /// Maximum number of applications allowed across projects.
    #[serde(default)]
    pub max_apps: i64,

    /// Maximum number of member seats allowed in the organization.
    #[serde(default)]
    pub max_seats: i64,

    /// Monthly included build minutes.
    #[serde(default)]
    pub build_minutes_monthly: i64,

    /// Included build artifact storage in gigabytes.
    #[serde(default)]
    pub artifact_storage_gb: i64,

    /// Included web bandwidth in gigabytes per month.
    #[serde(default)]
    pub web_bandwidth_gb: i64,

    /// Granular boolean feature flags.
    #[serde(default)]
    pub features: FeatureEntitlements,
}

/// Explicit decision enum returned by entitlement and quota checks.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EnforcementDecision {
    /// Action is completely permitted under current quotas and plan entitlements.
    Allow,

    /// Action is permitted, but usage is approaching the limit (e.g. >= 80% quota consumed).
    Warn,

    /// Action is soft-blocked: warning prompted, but grace period / soft enforcement allows progress.
    SoftBlock,

    /// Action is strictly rejected: limit exceeded and grace period elapsed, or hard quota enforced.
    HardLock,
}

/// Response shape for a billing plan.
#[derive(Debug, Clone, Serialize)]
pub struct PlanResponse {
    /// External public UUID of the plan.
    pub id: String,

    /// Plan tier name (`free`, `pro`, `enterprise`).
    pub name: String,

    /// Optional plan description.
    pub description: Option<String>,

    /// Plan price in integer minor currency units (e.g. 0 for free, 2900 for $29.00).
    pub price_minor: i64,

    /// Three-letter ISO 4217 currency code (e.g. "USD").
    pub currency: String,

    /// Typed entitlements structure parsed from JSON.
    pub entitlements: Entitlements,

    /// Whether this plan is actively open for new subscriptions.
    pub active: bool,

    /// Plan creation timestamp.
    pub created_at: DateTime<Utc>,
}

/// Response shape for an organization's subscription.
#[derive(Debug, Clone, Serialize)]
pub struct SubscriptionResponse {
    /// External public UUID of the subscription.
    pub id: String,

    /// External public UUID of the tenant organization.
    pub organization_id: String,

    /// External public UUID of the linked plan.
    pub plan_id: String,

    /// Name of the linked plan (`free`, `pro`, `enterprise`).
    pub plan_name: String,

    /// Subscription status (`trialing`, `active`, `past_due`, `locked`, `cancelled`).
    pub status: String,

    /// Optional timestamp when free trial concludes.
    pub trial_ends_at: Option<DateTime<Utc>>,

    /// Optional timestamp when subscription was activated.
    pub activated_at: Option<DateTime<Utc>>,

    /// Start of current billing cycle.
    pub current_period_start: DateTime<Utc>,

    /// End of current billing cycle.
    pub current_period_end: DateTime<Utc>,

    /// Generic provider customer reference.
    pub provider_customer_id: Option<String>,

    /// Generic provider subscription reference.
    pub provider_subscription_id: Option<String>,

    /// Subscription creation timestamp.
    pub created_at: DateTime<Utc>,

    /// Subscription last updated timestamp.
    pub updated_at: DateTime<Utc>,
}

/// Request body to create or upgrade a subscription.
#[derive(Debug, Clone, Deserialize)]
pub struct SubscribeRequest {
    /// Target plan public UUID or tier name (`pro`, `enterprise`).
    pub plan_id: String,

    /// Optional payment provider preference (`bachs` or `paystack`).
    pub provider: Option<String>,

    /// Optional callback URL for payment completion redirect.
    pub callback_url: Option<String>,
}

/// Response body returned after initiating subscription change.
#[derive(Debug, Clone, Serialize)]
pub struct SubscribeResponse {
    /// Updated subscription record.
    pub subscription: SubscriptionResponse,

    /// Optional payment authorization checkout URL (if checkout initiation was required).
    pub authorization_url: Option<String>,

    /// Optional payment reference string.
    pub reference: Option<String>,
}

/// Request body to cancel an active subscription.
#[derive(Debug, Clone, Deserialize)]
pub struct CancelSubscriptionRequest {
    /// Optional cancellation reason feedback.
    pub reason: Option<String>,

    /// Whether to cancel immediately rather than at period end.
    pub immediately: Option<bool>,
}

/// Response shape for an invoice.
#[derive(Debug, Clone, Serialize)]
pub struct InvoiceResponse {
    /// External public UUID of the invoice.
    pub id: String,

    /// External public UUID of the subscription.
    pub subscription_id: String,

    /// External public UUID of the tenant organization.
    pub organization_id: String,

    /// Total amount in integer cents (e.g. 2900 for $29.00). Never a float.
    pub amount_cents: i64,

    /// Invoice status (`draft`, `sent`, `paid`, `overdue`, `void`).
    pub status: String,

    /// Due date for payment.
    pub due_date: NaiveDate,

    /// Optional payment completion timestamp.
    pub paid_at: Option<DateTime<Utc>>,

    /// Generic provider invoice/charge reference.
    pub provider_invoice_id: Option<String>,

    /// Invoice creation timestamp.
    pub created_at: DateTime<Utc>,
}

/// Summary of enforcement evaluation across key metric dimensions.
#[derive(Debug, Clone, Serialize)]
pub struct UsageEnforcementSummary {
    /// Overall composite enforcement decision.
    pub overall_decision: EnforcementDecision,

    /// Build minutes quota decision.
    pub build_minutes_decision: EnforcementDecision,

    /// Storage quota decision.
    pub storage_decision: EnforcementDecision,

    /// Bandwidth quota decision.
    pub bandwidth_decision: EnforcementDecision,
}

/// Aggregated usage and quota consumption summary for the dashboard.
#[derive(Debug, Clone, Serialize)]
pub struct UsageSummaryResponse {
    /// External public UUID of the organization.
    pub organization_id: String,

    /// Active plan tier name.
    pub plan_name: String,

    /// Start timestamp of current usage period.
    pub current_period_start: DateTime<Utc>,

    /// End timestamp of current usage period.
    pub current_period_end: DateTime<Utc>,

    /// Total build minutes consumed in current period.
    pub build_minutes_used: i64,

    /// Monthly build minutes limit from plan entitlements.
    pub build_minutes_limit: i64,

    /// Total artifact storage currently used in gigabytes.
    pub artifact_storage_gb_used: i64,

    /// Artifact storage limit from plan entitlements.
    pub artifact_storage_gb_limit: i64,

    /// Total web bandwidth consumed in current period in gigabytes.
    pub web_bandwidth_gb_used: i64,

    /// Web bandwidth limit from plan entitlements.
    pub web_bandwidth_gb_limit: i64,

    /// Total deployment count recorded in current period.
    pub deploy_count: i64,

    /// Active quota enforcement decisions.
    pub enforcement: UsageEnforcementSummary,
}

/// Inbound usage record creation request (e.g. from workers or internal aggregation tasks).
#[derive(Debug, Clone, Deserialize)]
pub struct RecordUsageRequest {
    /// Metric name (`build_minutes`, `artifact_storage_gb`, `web_bandwidth_gb`, `deploy_count`).
    pub metric: String,

    /// Integer numeric value to record.
    pub value: i64,

    /// Optional JSON metadata associated with the event.
    pub metadata: Option<serde_json::Value>,
}

/// Generic response returned by webhook endpoints.
#[derive(Debug, Clone, Serialize)]
pub struct WebhookResponse {
    /// Whether the webhook delivery was processed successfully.
    pub success: bool,

    /// Human-readable diagnostic or status message.
    pub message: String,

    /// Transaction reference or event identifier if available.
    pub reference: Option<String>,
}
