//! Serializers and representation adapters for `billing` API responses.

use super::contracts::{
    Entitlements, InvoiceLineItem, InvoiceResponse, PlanResponse, SubscriptionResponse,
    UsageEnforcementSummary, UsageOverageSummary, UsageSummaryResponse,
};
use super::models::{Invoice, Plan, Subscription};
use super::services::UsageSummary;

/// Parse entitlements JSON string into a strongly-typed `Entitlements` struct.
///
/// Falls back to restrictive defaults on missing or malformed JSON (zero quotas, no paid features).
pub fn parse_entitlements_json(raw: &str) -> Entitlements {
    serde_json::from_str(raw).unwrap_or_default()
}

/// Parse an invoice's `line_items` JSON array column into typed line items.
///
/// Falls back to an empty list on missing or malformed JSON (never panics).
pub fn parse_line_items_json(raw: &str) -> Vec<InvoiceLineItem> {
    serde_json::from_str(raw).unwrap_or_default()
}

/// Convert a `Plan` database model into a wire-ready `PlanResponse` DTO.
pub fn serialize_plan(plan: &Plan) -> PlanResponse {
    PlanResponse {
        id: plan.public_id.clone(),
        name: plan.name.clone(),
        description: plan.description.clone(),
        price_minor: plan.price_minor,
        currency: plan.currency.clone(),
        entitlements: parse_entitlements_json(&plan.entitlements),
        active: plan.active,
        created_at: plan.created_at,
    }
}

/// Convert a `Subscription` model and linked `Plan` into a `SubscriptionResponse` DTO.
pub fn serialize_subscription(
    sub: &Subscription,
    plan: &Plan,
    org_public_id: &str,
) -> SubscriptionResponse {
    SubscriptionResponse {
        id: sub.public_id.clone(),
        organization_id: org_public_id.to_string(),
        plan_id: plan.public_id.clone(),
        plan_name: plan.name.clone(),
        status: sub.status.clone(),
        trial_ends_at: sub.trial_ends_at,
        activated_at: sub.activated_at,
        current_period_start: sub.current_period_start,
        current_period_end: sub.current_period_end,
        provider_customer_id: sub.stripe_customer_id.clone(),
        provider_subscription_id: sub.stripe_subscription_id.clone(),
        created_at: sub.created_at,
        updated_at: sub.updated_at,
    }
}

/// Convert an `Invoice` model into an `InvoiceResponse` DTO.
pub fn serialize_invoice(
    invoice: &Invoice,
    sub_public_id: &str,
    org_public_id: &str,
) -> InvoiceResponse {
    InvoiceResponse {
        id: invoice.public_id.clone(),
        subscription_id: sub_public_id.to_string(),
        organization_id: org_public_id.to_string(),
        amount_cents: invoice.amount_cents,
        status: invoice.status.clone(),
        due_date: invoice.due_date,
        paid_at: invoice.paid_at,
        provider_invoice_id: invoice.stripe_invoice_id.clone(),
        created_at: invoice.created_at,
        line_items: parse_line_items_json(&invoice.line_items),
    }
}

/// Convert domain `UsageSummary` into a `UsageSummaryResponse` DTO.
pub fn serialize_usage_summary(
    summary: &UsageSummary,
    org_public_id: &str,
) -> UsageSummaryResponse {
    UsageSummaryResponse {
        organization_id: org_public_id.to_string(),
        plan_name: summary.plan_name.clone(),
        current_period_start: summary.current_period_start,
        current_period_end: summary.current_period_end,
        build_minutes_used: summary.build_minutes_used,
        build_minutes_limit: summary.build_minutes_limit,
        artifact_storage_gb_used: summary.artifact_storage_gb_used,
        artifact_storage_gb_limit: summary.artifact_storage_gb_limit,
        web_bandwidth_gb_used: summary.web_bandwidth_gb_used,
        web_bandwidth_gb_limit: summary.web_bandwidth_gb_limit,
        deploy_count: summary.deploy_count,
        enforcement: UsageEnforcementSummary {
            overall_decision: summary.overall_decision,
            build_minutes_decision: summary.build_minutes_decision,
            storage_decision: summary.storage_decision,
            bandwidth_decision: summary.bandwidth_decision,
        },
        overage: UsageOverageSummary {
            enabled: summary.overage.enabled,
            build_minutes_over: summary.overage.build_minutes_over,
            storage_gb_over: summary.overage.storage_gb_over,
            bandwidth_gb_over: summary.overage.bandwidth_gb_over,
            build_minutes_cost_cents: summary.overage.build_minutes_cost_cents,
            storage_cost_cents: summary.overage.storage_cost_cents,
            bandwidth_cost_cents: summary.overage.bandwidth_cost_cents,
            total_cost_cents: summary.overage.total_cost_cents,
        },
    }
}
