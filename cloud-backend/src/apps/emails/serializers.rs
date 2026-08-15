//! Serialization and deserialization helpers for the `emails` app.

use super::contracts::{
    CampaignResponse, CampaignStatsResponse, EmailLogResponse, PreferenceResponse,
};
use super::models::{Campaign, EmailLog, NotificationPreference};

/// Internal aggregated statistics for a campaign.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct CampaignAggregatedStats {
    /// Total sends count.
    pub total_sends: i64,
    /// Total opens count.
    pub opened_count: i64,
    /// Total clicks count.
    pub clicked_count: i64,
    /// Total conversions count.
    pub converted_count: i64,
}

/// Safely parse a JSON string into `serde_json::Value`, falling back to `{}` on error.
pub fn parse_json_safely(raw: &str) -> serde_json::Value {
    serde_json::from_str(raw).unwrap_or_else(|_| serde_json::json!({}))
}

/// Serializes a [`NotificationPreference`] model into [`PreferenceResponse`].
pub fn serialize_preference(model: &NotificationPreference) -> PreferenceResponse {
    PreferenceResponse {
        id: model.public_id.clone(),
        category: model.category.clone(),
        value: model.value.clone(),
        created_at: model.created_at,
        updated_at: model.updated_at,
    }
}

/// Serializes an [`EmailLog`] model into [`EmailLogResponse`].
pub fn serialize_email_log(model: &EmailLog, org_public_id: Option<String>) -> EmailLogResponse {
    EmailLogResponse {
        id: model.public_id.clone(),
        template_key: model.template_key.clone(),
        recipient: model.recipient.clone(),
        organization_id: org_public_id,
        subject: model.subject.clone(),
        status: model.status.clone(),
        provider_message_id: model.provider_message_id.clone(),
        error: model.error.clone(),
        campaign_key: model.campaign_key.clone(),
        is_promotional: model.is_promotional,
        created_at: model.created_at,
        sent_at: model.sent_at,
    }
}

/// Serializes a [`Campaign`] model into [`CampaignResponse`].
pub fn serialize_campaign(model: &Campaign) -> CampaignResponse {
    CampaignResponse {
        id: model.public_id.clone(),
        key: model.key.clone(),
        name: model.name.clone(),
        subject_template: model.subject_template.clone(),
        body_template: model.body_template.clone(),
        active: model.active,
        trigger_rule: parse_json_safely(&model.trigger_rule),
        score_floor_override: model.score_floor_override,
        created_at: model.created_at,
        updated_at: model.updated_at,
    }
}

/// Serializes a [`Campaign`] model and its aggregated stats into [`CampaignStatsResponse`].
///
/// Implements the rule from Phase 14.4:
/// "A campaign converting below 2% over 500 sends is automatically disabled and flagged for review"
pub fn serialize_campaign_stats(
    model: &Campaign,
    stats: &CampaignAggregatedStats,
) -> CampaignStatsResponse {
    let (open_rate, click_rate, conversion_rate) = if stats.total_sends > 0 {
        let o_rate = (stats.opened_count.saturating_mul(100)) / stats.total_sends;
        let c_rate = (stats.clicked_count.saturating_mul(100)) / stats.total_sends;
        let conv_rate = (stats.converted_count.saturating_mul(100)) / stats.total_sends;
        (o_rate, c_rate, conv_rate)
    } else {
        (0, 0, 0)
    };

    // Under 2% conversion over 500 sends => automatically disabled
    let auto_disabled = stats.total_sends >= 500 && conversion_rate < 2;

    CampaignStatsResponse {
        id: model.public_id.clone(),
        key: model.key.clone(),
        name: model.name.clone(),
        active: model.active && !auto_disabled,
        total_sends: stats.total_sends,
        opened_count: stats.opened_count,
        clicked_count: stats.clicked_count,
        converted_count: stats.converted_count,
        open_rate_percent: open_rate,
        click_rate_percent: click_rate,
        conversion_rate_percent: conversion_rate,
        automatically_disabled: auto_disabled,
    }
}
