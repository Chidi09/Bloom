//! Business logic, pure entitlement enforcement, usage metering, and payment processing.

use chrono::{DateTime, Duration, Utc};
// The `bachs` and `paystack` modules are private; the crate re-exports these types at its root.
use djangors_contrib_payments::{
    BachsProvider, InitiateChargeRequest, PaymentProvider, PaystackProvider,
};
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{
    CancelSubscriptionRequest, EnforcementDecision, Entitlements, FeatureEntitlements,
    SubscribeRequest,
};
use super::errors::BillingError;
use super::models::{Invoice, Plan, Subscription, UsageRecord};
use super::repositories;
use super::serializers::parse_entitlements_json;
use crate::settings::{BachsSettings, PaystackSettings};

/// Valid usage metric identifiers.
pub const VALID_METRICS: &[&str] = &[
    "build_minutes",
    "artifact_storage_gb",
    "web_bandwidth_gb",
    "deploy_count",
];

/// Valid subscription status identifiers.
pub const VALID_SUBSCRIPTION_STATUSES: &[&str] =
    &["trialing", "active", "past_due", "locked", "cancelled"];

/// Valid invoice status identifiers.
pub const VALID_INVOICE_STATUSES: &[&str] = &["draft", "sent", "paid", "overdue", "void"];

/// Default free-tier grace period in days before soft enforcement becomes hard lock.
pub const DEFAULT_FREE_TIER_GRACE_DAYS: i64 = 14;

// ---------------------------------------------------------------------------
// Pure entitlement evaluation functions (Unit-testable, no I/O)
// ---------------------------------------------------------------------------

/// Context for evaluating entitlement decisions.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnforcementContext {
    /// Plan tier name (e.g. `free`, `pro`, `enterprise`).
    pub plan_name: String,

    /// Current subscription lifecycle status.
    pub subscription_status: String,

    /// Number of days elapsed past due or over quota (0 if within normal cycle).
    pub grace_days_elapsed: i64,

    /// Maximum grace days allowed before soft enforcement transitions to hard lock.
    pub max_grace_days: i64,
}

impl Default for EnforcementContext {
    fn default() -> Self {
        Self {
            plan_name: "free".to_string(),
            subscription_status: "active".to_string(),
            grace_days_elapsed: 0,
            max_grace_days: DEFAULT_FREE_TIER_GRACE_DAYS,
        }
    }
}

/// Pure decision function evaluating numeric quota limits against current and requested usage.
///
/// # Rules (billing.md §4):
/// - If subscription is `locked` or `cancelled`: returns `HardLock`.
/// - If projected usage <= limit: returns `Warn` if usage >= 80% of limit, else `Allow`.
/// - If projected usage > limit:
///   - For `free` tier or `past_due` status: returns `SoftBlock` during the grace period
///     (`grace_days_elapsed < max_grace_days`), and `HardLock` once the grace period expires.
///   - For paid active plans with hard limits: returns `HardLock`.
/// - Integer arithmetic only throughout.
pub fn evaluate_numeric_enforcement(
    current_value: i64,
    requested_additional: i64,
    limit: i64,
    context: &EnforcementContext,
) -> EnforcementDecision {
    if context.subscription_status == "locked" || context.subscription_status == "cancelled" {
        return EnforcementDecision::HardLock;
    }

    let projected_value = current_value.saturating_add(requested_additional.max(0));

    // If quota limit is 0 or unconfigured:
    if limit <= 0 {
        if context.plan_name == "free" && context.grace_days_elapsed < context.max_grace_days {
            return EnforcementDecision::SoftBlock;
        }
        return EnforcementDecision::HardLock;
    }

    if projected_value <= limit {
        // Warning threshold: integer 80% usage check without float division
        let warning_threshold = limit.saturating_mul(80) / 100;
        if projected_value >= warning_threshold {
            EnforcementDecision::Warn
        } else {
            EnforcementDecision::Allow
        }
    } else {
        // Limit exceeded
        if context.plan_name == "free" || context.subscription_status == "past_due" {
            if context.grace_days_elapsed >= context.max_grace_days {
                EnforcementDecision::HardLock
            } else {
                EnforcementDecision::SoftBlock
            }
        } else {
            EnforcementDecision::HardLock
        }
    }
}

/// Pure decision function evaluating boolean feature flag entitlements.
pub fn evaluate_feature_enforcement(
    feature_enabled: bool,
    context: &EnforcementContext,
) -> EnforcementDecision {
    if context.subscription_status == "locked" || context.subscription_status == "cancelled" {
        return EnforcementDecision::HardLock;
    }

    if feature_enabled {
        EnforcementDecision::Allow
    } else if context.plan_name == "free" && context.grace_days_elapsed < context.max_grace_days {
        EnforcementDecision::SoftBlock
    } else {
        EnforcementDecision::HardLock
    }
}

/// Evaluate build minutes entitlement for a new build.
pub fn check_build_minutes_entitlement(
    entitlements: &Entitlements,
    current_minutes: i64,
    estimated_build_minutes: i64,
    context: &EnforcementContext,
) -> EnforcementDecision {
    evaluate_numeric_enforcement(
        current_minutes,
        estimated_build_minutes,
        entitlements.build_minutes_monthly,
        context,
    )
}

/// Evaluate web hosting entitlement.
pub fn check_web_hosting_entitlement(
    entitlements: &Entitlements,
    context: &EnforcementContext,
) -> EnforcementDecision {
    evaluate_feature_enforcement(entitlements.features.web_hosting, context)
}

/// Evaluate artifact storage quota entitlement.
pub fn check_storage_entitlement(
    entitlements: &Entitlements,
    current_storage_gb: i64,
    additional_gb: i64,
    context: &EnforcementContext,
) -> EnforcementDecision {
    evaluate_numeric_enforcement(
        current_storage_gb,
        additional_gb,
        entitlements.artifact_storage_gb,
        context,
    )
}

/// Evaluate bandwidth quota entitlement.
pub fn check_bandwidth_entitlement(
    entitlements: &Entitlements,
    current_bandwidth_gb: i64,
    additional_gb: i64,
    context: &EnforcementContext,
) -> EnforcementDecision {
    evaluate_numeric_enforcement(
        current_bandwidth_gb,
        additional_gb,
        entitlements.web_bandwidth_gb,
        context,
    )
}

// ---------------------------------------------------------------------------
// Pure money and usage arithmetic (Strict integer minor units, no floats)
// ---------------------------------------------------------------------------

/// Compute billable build minutes from started_at and finished_at timestamps.
///
/// Guards against NULL or inverted intervals by clamping at zero.
/// Rounds up partial minutes (ceiling integer division) so every started minute is metered.
pub fn calculate_build_minutes(
    started_at: Option<DateTime<Utc>>,
    finished_at: Option<DateTime<Utc>>,
) -> i64 {
    match (started_at, finished_at) {
        (Some(start), Some(finish)) => {
            let duration_secs = (finish - start).num_seconds();
            if duration_secs <= 0 {
                0
            } else {
                // Integer ceiling division: (duration_secs + 59) / 60
                duration_secs.saturating_add(59) / 60
            }
        }
        _ => 0,
    }
}

/// Compute prorated amount in integer cents for a partial billing period.
///
/// Formula: `(total_amount_cents * used_seconds) / total_period_seconds`.
/// Rounding choice: Standard integer division (truncation toward zero), documented explicitly.
/// Uses 128-bit integer intermediate multiplication to avoid overflow.
pub fn calculate_prorated_amount(
    total_amount_cents: i64,
    used_seconds: i64,
    total_period_seconds: i64,
) -> i64 {
    if total_amount_cents <= 0 || used_seconds <= 0 || total_period_seconds <= 0 {
        return 0;
    }
    let clamped_used = used_seconds.min(total_period_seconds);
    let numerator = (total_amount_cents as i128).saturating_mul(clamped_used as i128);
    let denominator = total_period_seconds as i128;
    (numerator / denominator) as i64
}

/// Returns `true` when `from -> to` is a valid subscription lifecycle transition.
pub fn can_transition_subscription(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("trialing", "active")
            | ("trialing", "past_due")
            | ("trialing", "cancelled")
            | ("active", "past_due")
            | ("active", "locked")
            | ("active", "cancelled")
            | ("past_due", "active")
            | ("past_due", "locked")
            | ("past_due", "cancelled")
            | ("locked", "active")
            | ("locked", "cancelled")
            | ("cancelled", "active")
            | ("cancelled", "trialing")
    )
}

/// Validate subscription upgrade request parameters and target plan pricing.
///
/// Returns `(provider_name, price_minor, currency)` on success.
/// Rejects non-positive prices on paid plans and unknown provider strings.
pub fn validate_subscription_upgrade(
    target_plan: &Plan,
    provider: Option<&str>,
) -> Result<(&'static str, i64, String), BillingError> {
    if target_plan.name == "free" {
        return Ok(("none", 0, "USD".to_string()));
    }

    if target_plan.price_minor <= 0 {
        return Err(BillingError::InvalidAmount(format!(
            "Paid plan '{}' must have a positive price_minor, got {}",
            target_plan.name, target_plan.price_minor
        )));
    }

    let provider_name = match provider {
        None | Some("bachs") => "bachs",
        Some("paystack") => "paystack",
        Some(other) => {
            return Err(BillingError::ValidationError(format!(
                "Unsupported payment provider: '{other}'. Valid providers are 'bachs' and 'paystack'."
            )));
        }
    };

    Ok((
        provider_name,
        target_plan.price_minor,
        target_plan.currency.clone(),
    ))
}

/// Pure state transformation on successful charge initiation for a paid plan upgrade.
///
/// Transitions subscription to `past_due`, records `pending_plan_id`, and leaves `plan_id` unchanged.
///
/// The billing period is deliberately NOT advanced here. Metered usage is counted since
/// `current_period_start`, so resetting it on mere charge initiation would let a caller wipe
/// their own quota by starting an upgrade and abandoning the payment page. The period moves
/// only once payment confirms, in [`apply_payment_success`].
pub fn apply_charge_initiation(
    sub: &mut Subscription,
    target_plan_id: i64,
    reference: &str,
    now: DateTime<Utc>,
) -> Result<(), BillingError> {
    if sub.status != "past_due" && !can_transition_subscription(&sub.status, "past_due") {
        return Err(BillingError::InvalidStatusTransition {
            from: sub.status.clone(),
            to: "past_due".to_string(),
        });
    }

    sub.status = "past_due".to_string();
    sub.pending_plan_id = Some(target_plan_id);
    sub.stripe_subscription_id = Some(reference.to_string());
    sub.updated_at = now;

    Ok(())
}

/// Pure state transformation for immediate free-tier downgrade.
///
/// Applies the free plan immediately without pending state or charge.
pub fn apply_free_downgrade(
    sub: &mut Subscription,
    free_plan_id: i64,
    now: DateTime<Utc>,
    period_end: DateTime<Utc>,
) {
    sub.plan_id = ForeignKey::new(free_plan_id);
    sub.pending_plan_id = None;
    sub.status = "active".to_string();
    sub.current_period_start = now;
    sub.current_period_end = period_end;
    sub.updated_at = now;
}

/// Pure state transition upon successful payment confirmation (from webhook).
///
/// Applies the `pending_plan_id` to `plan_id`, transitions status to `active`,
/// and updates `activated_at`. Returns `true` if any change occurred (idempotency check).
///
/// This is also where the billing period advances, because metered usage is counted since
/// `current_period_start` and must only reset against confirmed payment. The period is moved
/// exactly once per payment, guarded by the same pending-plan check that makes redelivered
/// webhooks idempotent.
pub fn apply_payment_success(
    sub: &mut Subscription,
    now: DateTime<Utc>,
    period_end: DateTime<Utc>,
) -> bool {
    let mut changed = false;

    if let Some(pending_id) = sub.pending_plan_id.take() {
        sub.plan_id = ForeignKey::new(pending_id);
        sub.current_period_start = now;
        sub.current_period_end = period_end;
        changed = true;
    }

    if sub.status != "active" && can_transition_subscription(&sub.status, "active") {
        sub.status = "active".to_string();
        changed = true;
    }

    if sub.activated_at.is_none() {
        sub.activated_at = Some(now);
        changed = true;
    }

    if changed {
        sub.updated_at = now;
    }

    changed
}

// ---------------------------------------------------------------------------
// Domain result structures
// ---------------------------------------------------------------------------

/// Aggregated usage state for an organization.
#[derive(Debug, Clone)]
pub struct UsageSummary {
    /// Active plan tier name.
    pub plan_name: String,
    /// Billing period start timestamp.
    pub current_period_start: DateTime<Utc>,
    /// Billing period end timestamp.
    pub current_period_end: DateTime<Utc>,
    /// Build minutes consumed in period.
    pub build_minutes_used: i64,
    /// Build minutes quota limit.
    pub build_minutes_limit: i64,
    /// Storage currently used in GB.
    pub artifact_storage_gb_used: i64,
    /// Storage quota limit in GB.
    pub artifact_storage_gb_limit: i64,
    /// Web bandwidth consumed in GB.
    pub web_bandwidth_gb_used: i64,
    /// Web bandwidth quota limit in GB.
    pub web_bandwidth_gb_limit: i64,
    /// Total deployments created in period.
    pub deploy_count: i64,
    /// Composite enforcement decision across all metrics.
    pub overall_decision: EnforcementDecision,
    /// Decision for build minutes quota.
    pub build_minutes_decision: EnforcementDecision,
    /// Decision for storage quota.
    pub storage_decision: EnforcementDecision,
    /// Decision for bandwidth quota.
    pub bandwidth_decision: EnforcementDecision,
}

/// Result of a subscription creation or change.
#[derive(Debug, Clone)]
pub struct SubscribeOutcome {
    /// The updated or created subscription.
    pub subscription: Subscription,
    /// Linked plan.
    pub plan: Plan,
    /// Optional authorization URL for checkout.
    pub authorization_url: Option<String>,
    /// Optional transaction reference.
    pub reference: Option<String>,
}

/// Outcome of processing an inbound webhook delivery.
#[derive(Debug, Clone)]
pub enum WebhookDeliveryOutcome {
    /// Webhook verified and state updated.
    Processed {
        /// Provider event type string.
        event_type: String,
        /// Informational message.
        message: String,
        /// Associated transaction or reference identifier.
        reference: Option<String>,
    },
    /// Webhook was ignored (e.g. unhandled event type or duplicate delivery).
    Ignored {
        /// Provider event type string.
        event_type: String,
    },
}

// ---------------------------------------------------------------------------
// Event emission helper
// ---------------------------------------------------------------------------

/// Emit an event to the `events` app log.
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

// ---------------------------------------------------------------------------
// High-level billing service operations
// ---------------------------------------------------------------------------

/// List all active plans available for subscription with pagination.
pub async fn list_plans(
    db: &Database,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Plan>, i64), BillingError> {
    repositories::list_plans_query(db, limit, offset)
        .await
        .map_err(Into::into)
}

/// Retrieve or create the default `free` plan subscription for an organization.
pub async fn get_or_create_subscription(
    db: &Database,
    organization_id: i64,
) -> Result<(Subscription, Plan, Entitlements), BillingError> {
    if let Some(sub) = repositories::subscription_for_organization(db, organization_id).await? {
        let plan = repositories::plan_by_id(db, sub.plan_id.id)
            .await?
            .ok_or(BillingError::PlanNotFound)?;
        let entitlements = parse_entitlements_json(&plan.entitlements);
        return Ok((sub, plan, entitlements));
    }

    // Find free plan or fallback to creating default free plan
    let plan = match repositories::plan_by_name(db, "free").await? {
        Some(p) => p,
        None => {
            let free_entitlements = Entitlements {
                max_projects: 3,
                max_apps: 5,
                max_seats: 10,
                build_minutes_monthly: 500,
                artifact_storage_gb: 50,
                web_bandwidth_gb: 100,
                features: FeatureEntitlements {
                    testflight_deployments: true,
                    google_play_deployments: true,
                    web_hosting: true,
                    shorebird: false,
                    workflows: false,
                    priority_support: false,
                },
            };
            let new_plan = Plan {
                id: 0,
                public_id: Uuid::new_v4().to_string(),
                name: "free".to_string(),
                description: Some("Bloom Cloud Free Tier".to_string()),
                price_minor: 0,
                currency: "USD".to_string(),
                entitlements: serde_json::to_string(&free_entitlements)
                    .unwrap_or_else(|_| "{}".to_string()),
                active: true,
                created_at: Utc::now(),
            };
            repositories::insert_plan(db, new_plan).await?
        }
    };

    let now = Utc::now();
    let period_end = now + Duration::days(30);

    let new_sub = Subscription {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(organization_id),
        plan_id: ForeignKey::new(plan.id),
        pending_plan_id: None,
        status: "active".to_string(),
        trial_ends_at: None,
        activated_at: Some(now),
        current_period_start: now,
        current_period_end: period_end,
        stripe_customer_id: None,
        stripe_subscription_id: None,
        created_at: now,
        updated_at: now,
    };

    let saved_sub = repositories::insert_subscription(db, new_sub).await?;
    let entitlements = parse_entitlements_json(&plan.entitlements);

    emit_event(
        db,
        "billing.subscription.created",
        Some(organization_id),
        None,
        None,
        None,
        serde_json::json!({
            "subscription_id": saved_sub.public_id,
            "plan_name": plan.name,
            "status": saved_sub.status,
        }),
    )
    .await;

    Ok((saved_sub, plan, entitlements))
}

/// Retrieve current subscription and plan for an organization.
pub async fn get_current_subscription(
    db: &Database,
    organization_id: i64,
) -> Result<(Subscription, Plan, Entitlements), BillingError> {
    get_or_create_subscription(db, organization_id).await
}

/// Subscribe an organization to a new plan (e.g. Pro or Enterprise) or initiate payment checkout.
pub async fn subscribe_to_plan(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: SubscribeRequest,
    bachs_settings: Option<&BachsSettings>,
    paystack_settings: Option<&PaystackSettings>,
    user_email: &str,
) -> Result<SubscribeOutcome, BillingError> {
    // 1. Resolve target plan by public UUID or name
    let target_plan = if let Some(p) = repositories::plan_by_public_id(db, &req.plan_id).await? {
        p
    } else if let Some(p) = repositories::plan_by_name(db, &req.plan_id).await? {
        p
    } else {
        return Err(BillingError::PlanNotFound);
    };

    let (mut sub, current_plan, _) = get_or_create_subscription(db, organization_id).await?;

    if target_plan.id == current_plan.id && sub.status == "active" {
        return Ok(SubscribeOutcome {
            subscription: sub,
            plan: target_plan,
            authorization_url: None,
            reference: None,
        });
    }

    let now = Utc::now();
    let period_end = now + Duration::days(30);

    // If free tier switch, update immediately
    if target_plan.name == "free" {
        apply_free_downgrade(&mut sub, target_plan.id, now, period_end);
        repositories::update_subscription(db, &sub).await?;

        emit_event(
            db,
            "billing.subscription.updated",
            Some(organization_id),
            None,
            None,
            Some(user_id),
            serde_json::json!({
                "subscription_id": sub.public_id,
                "plan_name": target_plan.name,
                "status": sub.status,
            }),
        )
        .await;

        return Ok(SubscribeOutcome {
            subscription: sub,
            plan: target_plan,
            authorization_url: None,
            reference: None,
        });
    }

    // Validate pricing and provider
    let (provider_name, price_minor, currency) =
        validate_subscription_upgrade(&target_plan, req.provider.as_deref())?;

    let reference = format!("sub_{}_{}", organization_id, Uuid::new_v4());

    // 2. Initiate charge via configured payment provider (Bachs or Paystack)
    let mut auth_url = None;

    if provider_name == "paystack" {
        let settings = paystack_settings.ok_or(BillingError::PaymentProviderNotConfigured)?;
        let secret = settings
            .secret_key
            .as_deref()
            .ok_or(BillingError::PaymentProviderNotConfigured)?;

        let provider = if let Some(base_url) = &settings.base_url {
            PaystackProvider::with_base_url(secret.to_string(), base_url.clone())
        } else {
            PaystackProvider::new(secret.to_string())
        };

        let charge_req = InitiateChargeRequest {
            email: user_email.to_string(),
            amount_minor: price_minor,
            currency,
            reference: reference.clone(),
            callback_url: req.callback_url.clone(),
        };

        let res = provider
            .initiate(&charge_req)
            .await
            .map_err(|e| BillingError::PaymentProviderError(format!("paystack: {e}")))?;
        auth_url = Some(res.authorization_url);
    } else if provider_name == "bachs" {
        let settings = bachs_settings.ok_or(BillingError::PaymentProviderNotConfigured)?;
        let secret = settings
            .secret_key
            .as_deref()
            .ok_or(BillingError::PaymentProviderNotConfigured)?;

        let provider = if let Some(base_url) = &settings.base_url {
            BachsProvider::with_base_url(secret.to_string(), base_url.clone())
        } else {
            BachsProvider::new(secret.to_string())
        };

        let charge_req = InitiateChargeRequest {
            email: user_email.to_string(),
            amount_minor: price_minor,
            currency,
            reference: reference.clone(),
            callback_url: req.callback_url.clone(),
        };

        let res = provider
            .initiate(&charge_req)
            .await
            .map_err(|e| BillingError::PaymentProviderError(format!("bachs: {e}")))?;
        auth_url = Some(res.authorization_url);
    }

    // Apply charge initiation state (status becomes past_due, plan_id UNCHANGED, pending_plan_id set)
    apply_charge_initiation(&mut sub, target_plan.id, &reference, now)?;
    repositories::update_subscription(db, &sub).await?;

    emit_event(
        db,
        "billing.subscription.updated",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        serde_json::json!({
            "subscription_id": sub.public_id,
            "plan_name": current_plan.name,
            "pending_plan_name": target_plan.name,
            "status": sub.status,
            "reference": reference,
        }),
    )
    .await;

    Ok(SubscribeOutcome {
        subscription: sub,
        plan: current_plan,
        authorization_url: auth_url,
        reference: Some(reference),
    })
}

/// Cancel an active subscription for an organization.
pub async fn cancel_subscription(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: CancelSubscriptionRequest,
) -> Result<Subscription, BillingError> {
    let (mut sub, _, _) = get_or_create_subscription(db, organization_id).await?;

    if sub.status == "cancelled" {
        return Ok(sub);
    }

    if !can_transition_subscription(&sub.status, "cancelled") {
        return Err(BillingError::InvalidStatusTransition {
            from: sub.status,
            to: "cancelled".to_string(),
        });
    }

    let now = Utc::now();
    sub.status = "cancelled".to_string();
    sub.updated_at = now;
    repositories::update_subscription(db, &sub).await?;

    emit_event(
        db,
        "billing.subscription.cancelled",
        Some(organization_id),
        None,
        None,
        Some(user_id),
        serde_json::json!({
            "subscription_id": sub.public_id,
            "immediately": req.immediately.unwrap_or(false),
            "reason": req.reason,
        }),
    )
    .await;

    Ok(sub)
}

/// List all invoices for an organization with pagination and batch subscription lookup.
pub async fn list_invoices(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<(Invoice, String)>, i64), BillingError> {
    let (invoices, total) = repositories::list_invoices_query(db, organization_id, limit, offset)
        .await
        .map_err(BillingError::from)?;

    if invoices.is_empty() {
        return Ok((Vec::new(), total));
    }

    let mut sub_ids: Vec<i64> = invoices.iter().map(|i| i.subscription_id.id).collect();
    sub_ids.sort_unstable();
    sub_ids.dedup();
    let sub_map = repositories::subscription_public_ids_by_ids(db, &sub_ids)
        .await
        .map_err(BillingError::from)?;

    let mut results = Vec::with_capacity(invoices.len());
    for inv in invoices {
        let sub_pub = sub_map
            .get(&inv.subscription_id.id)
            .cloned()
            .unwrap_or_else(|| "unknown".to_string());
        results.push((inv, sub_pub));
    }

    Ok((results, total))
}

/// Calculate current usage summary and evaluate enforcement against plan quotas.
pub async fn get_usage_summary(
    db: &Database,
    organization_id: i64,
) -> Result<UsageSummary, BillingError> {
    let (sub, plan, entitlements) = get_or_create_subscription(db, organization_id).await?;

    let period_start = sub.current_period_start;
    let period_end = sub.current_period_end;

    let build_minutes_used = repositories::total_usage_for_org_metric_since(
        db,
        organization_id,
        "build_minutes",
        period_start,
    )
    .await?;

    let storage_records =
        repositories::usage_records_for_org(db, organization_id, "artifact_storage_gb").await?;
    let artifact_storage_gb_used = storage_records.first().map(|r| r.value).unwrap_or(0);

    let bandwidth_used = repositories::total_usage_for_org_metric_since(
        db,
        organization_id,
        "web_bandwidth_gb",
        period_start,
    )
    .await?;

    let deploy_count = repositories::total_usage_for_org_metric_since(
        db,
        organization_id,
        "deploy_count",
        period_start,
    )
    .await?;

    let context = EnforcementContext {
        plan_name: plan.name.clone(),
        subscription_status: sub.status.clone(),
        grace_days_elapsed: 0,
        max_grace_days: DEFAULT_FREE_TIER_GRACE_DAYS,
    };

    let build_minutes_decision =
        check_build_minutes_entitlement(&entitlements, build_minutes_used, 0, &context);

    let storage_decision =
        check_storage_entitlement(&entitlements, artifact_storage_gb_used, 0, &context);

    let bandwidth_decision =
        check_bandwidth_entitlement(&entitlements, bandwidth_used, 0, &context);

    // Overall decision is the most restrictive of the individual decisions
    let overall_decision = match (build_minutes_decision, storage_decision, bandwidth_decision) {
        (EnforcementDecision::HardLock, _, _)
        | (_, EnforcementDecision::HardLock, _)
        | (_, _, EnforcementDecision::HardLock) => EnforcementDecision::HardLock,
        (EnforcementDecision::SoftBlock, _, _)
        | (_, EnforcementDecision::SoftBlock, _)
        | (_, _, EnforcementDecision::SoftBlock) => EnforcementDecision::SoftBlock,
        (EnforcementDecision::Warn, _, _)
        | (_, EnforcementDecision::Warn, _)
        | (_, _, EnforcementDecision::Warn) => EnforcementDecision::Warn,
        _ => EnforcementDecision::Allow,
    };

    Ok(UsageSummary {
        plan_name: plan.name,
        current_period_start: period_start,
        current_period_end: period_end,
        build_minutes_used,
        build_minutes_limit: entitlements.build_minutes_monthly,
        artifact_storage_gb_used,
        artifact_storage_gb_limit: entitlements.artifact_storage_gb,
        web_bandwidth_gb_used: bandwidth_used,
        web_bandwidth_gb_limit: entitlements.web_bandwidth_gb,
        deploy_count,
        overall_decision,
        build_minutes_decision,
        storage_decision,
        bandwidth_decision,
    })
}

/// Record a usage event for an organization and emit event log.
pub async fn record_usage(
    db: &Database,
    organization_id: i64,
    metric: &str,
    value: i64,
    metadata: Option<serde_json::Value>,
) -> Result<UsageRecord, BillingError> {
    if !VALID_METRICS.contains(&metric) {
        return Err(BillingError::InvalidMetric(metric.to_string()));
    }

    let record = UsageRecord {
        id: 0,
        organization_id: ForeignKey::new(organization_id),
        metric: metric.to_string(),
        value: value.max(0),
        recorded_at: Utc::now(),
        metadata: metadata
            .as_ref()
            .map(|m| m.to_string())
            .unwrap_or_else(|| "{}".to_string()),
    };

    let saved = repositories::insert_usage_record(db, record).await?;

    emit_event(
        db,
        "billing.usage.recorded",
        Some(organization_id),
        None,
        None,
        None,
        serde_json::json!({
            "metric": metric,
            "value": value,
        }),
    )
    .await;

    Ok(saved)
}

// ---------------------------------------------------------------------------
// Payment provider webhook handlers (Bachs & Paystack)
// ---------------------------------------------------------------------------

/// Handle inbound webhook deliveries from Bachs (`api.bachs.io`).
///
/// Signature is strictly verified over raw bytes and timestamp.
/// Rejects without side effect on missing or invalid signature.
pub async fn handle_bachs_webhook(
    db: &Database,
    bachs_settings: Option<&BachsSettings>,
    raw_body: &[u8],
    timestamp: Option<&str>,
    signature: Option<&str>,
) -> Result<WebhookDeliveryOutcome, BillingError> {
    let settings = bachs_settings.ok_or(BillingError::MissingWebhookSecret)?;
    let secret = settings
        .webhook_secret
        .as_deref()
        .or(settings.secret_key.as_deref())
        .ok_or(BillingError::MissingWebhookSecret)?;

    let sig = signature.ok_or(BillingError::InvalidWebhookSignature)?;

    let provider = if let Some(base_url) = &settings.base_url {
        BachsProvider::with_base_url(secret, base_url)
    } else {
        BachsProvider::new(secret)
    };

    if !provider.verify_webhook_signature_with_timestamp(raw_body, timestamp, sig) {
        return Err(BillingError::InvalidWebhookSignature);
    }

    let payload: serde_json::Value = serde_json::from_slice(raw_body)
        .map_err(|e| BillingError::ValidationError(format!("Malformed webhook JSON: {e}")))?;

    let event_type = payload
        .get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");

    if event_type == "collection.succeeded" || event_type == "charge.succeeded" {
        let reference = payload
            .get("data")
            .and_then(|d| d.get("reference").or_else(|| d.get("checkout_id")))
            .and_then(|v| v.as_str());

        if let Some(ref_str) = reference {
            if let Some(mut sub) =
                repositories::subscription_by_provider_subscription_id(db, ref_str).await?
            {
                let now = Utc::now();
                let period_end = now + Duration::days(30);
                if apply_payment_success(&mut sub, now, period_end) {
                    repositories::update_subscription(db, &sub).await?;

                    emit_event(
                        db,
                        "billing.subscription.activated",
                        Some(sub.organization_id.id),
                        None,
                        None,
                        None,
                        serde_json::json!({
                            "subscription_id": sub.public_id,
                            "reference": ref_str,
                        }),
                    )
                    .await;
                }
            }

            if let Some(mut inv) = repositories::invoice_by_provider_invoice_id(db, ref_str).await?
            {
                if inv.status != "paid" {
                    inv.status = "paid".to_string();
                    inv.paid_at = Some(Utc::now());
                    repositories::update_invoice(db, &inv).await?;

                    emit_event(
                        db,
                        "billing.invoice.paid",
                        Some(inv.organization_id.id),
                        None,
                        None,
                        None,
                        serde_json::json!({
                            "invoice_id": inv.public_id,
                            "reference": ref_str,
                        }),
                    )
                    .await;
                }
            }
        }

        Ok(WebhookDeliveryOutcome::Processed {
            event_type: event_type.to_string(),
            message: "Bachs webhook processed successfully".to_string(),
            reference: reference.map(|s| s.to_string()),
        })
    } else {
        Ok(WebhookDeliveryOutcome::Ignored {
            event_type: event_type.to_string(),
        })
    }
}

/// Handle inbound webhook deliveries from Paystack (`api.paystack.co`).
///
/// Signature is strictly verified over raw bytes using HMAC-SHA512.
/// Rejects without side effect on missing or invalid signature.
pub async fn handle_paystack_webhook(
    db: &Database,
    paystack_settings: Option<&PaystackSettings>,
    raw_body: &[u8],
    signature: Option<&str>,
) -> Result<WebhookDeliveryOutcome, BillingError> {
    let settings = paystack_settings.ok_or(BillingError::MissingWebhookSecret)?;
    let secret = settings
        .webhook_secret
        .as_deref()
        .or(settings.secret_key.as_deref())
        .ok_or(BillingError::MissingWebhookSecret)?;

    let sig = signature.ok_or(BillingError::InvalidWebhookSignature)?;

    let provider = if let Some(base_url) = &settings.base_url {
        PaystackProvider::with_base_url(secret, base_url)
    } else {
        PaystackProvider::new(secret)
    };

    if !provider.verify_webhook_signature(raw_body, sig) {
        return Err(BillingError::InvalidWebhookSignature);
    }

    let payload: serde_json::Value = serde_json::from_slice(raw_body)
        .map_err(|e| BillingError::ValidationError(format!("Malformed webhook JSON: {e}")))?;

    let event_type = payload
        .get("event")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");

    if event_type == "charge.success" {
        let reference = payload
            .get("data")
            .and_then(|d| d.get("reference"))
            .and_then(|v| v.as_str());

        if let Some(ref_str) = reference {
            if let Some(mut sub) =
                repositories::subscription_by_provider_subscription_id(db, ref_str).await?
            {
                let now = Utc::now();
                let period_end = now + Duration::days(30);
                if apply_payment_success(&mut sub, now, period_end) {
                    repositories::update_subscription(db, &sub).await?;

                    emit_event(
                        db,
                        "billing.subscription.activated",
                        Some(sub.organization_id.id),
                        None,
                        None,
                        None,
                        serde_json::json!({
                            "subscription_id": sub.public_id,
                            "reference": ref_str,
                        }),
                    )
                    .await;
                }
            }

            if let Some(mut inv) = repositories::invoice_by_provider_invoice_id(db, ref_str).await?
            {
                if inv.status != "paid" {
                    inv.status = "paid".to_string();
                    inv.paid_at = Some(Utc::now());
                    repositories::update_invoice(db, &inv).await?;

                    emit_event(
                        db,
                        "billing.invoice.paid",
                        Some(inv.organization_id.id),
                        None,
                        None,
                        None,
                        serde_json::json!({
                            "invoice_id": inv.public_id,
                            "reference": ref_str,
                        }),
                    )
                    .await;
                }
            }
        }

        Ok(WebhookDeliveryOutcome::Processed {
            event_type: event_type.to_string(),
            message: "Paystack webhook processed successfully".to_string(),
            reference: reference.map(|s| s.to_string()),
        })
    } else {
        Ok(WebhookDeliveryOutcome::Ignored {
            event_type: event_type.to_string(),
        })
    }
}

// ---------------------------------------------------------------------------
// Cross-app enforcement gates (docs/PHASES.md Phase 7, deliverable 2)
// ---------------------------------------------------------------------------

/// Gate a new build against the organization's build-minutes quota.
///
/// Only `HardLock` blocks: `SoftBlock` and `Warn` deliberately let the request through so a
/// free-tier organization inside its grace period is nudged, not stopped. Callers map the
/// returned [`BillingError::QuotaExceeded`] onto their own error type (HTTP 402).
///
/// `estimated_build_minutes` is the caller's projection for the job about to be queued.
pub async fn ensure_build_allowed(
    db: &Database,
    organization_id: i64,
    estimated_build_minutes: i64,
) -> Result<EnforcementDecision, BillingError> {
    let summary = get_usage_summary(db, organization_id).await?;
    let (sub, plan, entitlements) = get_or_create_subscription(db, organization_id).await?;

    let context = EnforcementContext {
        plan_name: plan.name,
        subscription_status: sub.status,
        grace_days_elapsed: 0,
        max_grace_days: DEFAULT_FREE_TIER_GRACE_DAYS,
    };

    let decision = check_build_minutes_entitlement(
        &entitlements,
        summary.build_minutes_used,
        estimated_build_minutes,
        &context,
    );

    if decision == EnforcementDecision::HardLock {
        return Err(BillingError::QuotaExceeded {
            metric: "build_minutes".to_string(),
            limit: entitlements.build_minutes_monthly,
            current: summary.build_minutes_used,
        });
    }
    Ok(decision)
}

/// Gate a new deployment against the plan's feature entitlements for the requested target.
///
/// Targets map onto the plan feature flags: `app_store`/`testflight` require
/// `testflight_deployments`, `play_store`/`internal_testing` require `google_play_deployments`,
/// `web` requires `web_hosting`, and `shorebird` requires `shorebird`. Any other target
/// (e.g. an internal artifact download) carries no feature gate and is checked only against
/// subscription status. Only `HardLock` blocks, as in [`ensure_build_allowed`].
pub async fn ensure_deployment_allowed(
    db: &Database,
    organization_id: i64,
    target: &str,
) -> Result<EnforcementDecision, BillingError> {
    let (sub, plan, entitlements) = get_or_create_subscription(db, organization_id).await?;

    let context = EnforcementContext {
        plan_name: plan.name,
        subscription_status: sub.status,
        grace_days_elapsed: 0,
        max_grace_days: DEFAULT_FREE_TIER_GRACE_DAYS,
    };

    let (feature_name, feature_enabled) = match target {
        "app_store" | "testflight" => (
            "testflight_deployments",
            entitlements.features.testflight_deployments,
        ),
        "play_store" | "internal_testing" => (
            "google_play_deployments",
            entitlements.features.google_play_deployments,
        ),
        "web" => ("web_hosting", entitlements.features.web_hosting),
        "shorebird" => ("shorebird", entitlements.features.shorebird),
        // Ungated target: still refuse when the subscription itself is locked/cancelled.
        _ => ("subscription", true),
    };

    let decision = evaluate_feature_enforcement(feature_enabled, &context);

    if decision == EnforcementDecision::HardLock {
        if feature_name == "subscription" {
            return Err(BillingError::AccountLocked);
        }
        return Err(BillingError::FeatureNotEntitled(feature_name.to_string()));
    }
    Ok(decision)
}
