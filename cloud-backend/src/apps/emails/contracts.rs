//! Request, response, query, and path Data Transfer Objects (DTOs) for the `emails` app.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// An item representing a single notification preference update.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UpdatePreferenceItem {
    /// Notification category: `builds`, `deployments`, `releases`, `security`, `billing`, or `product`.
    pub category: String,

    /// Delivery value: `all`, `mine_only`, `digest`, or `none`.
    pub value: String,
}

/// Request payload to update user notification preferences.
///
/// Supports either single field updates (`category` and `value`) or bulk updates via `preferences`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct UpdatePreferencesRequest {
    /// Optional single category being updated.
    pub category: Option<String>,

    /// Optional single value to set.
    pub value: Option<String>,

    /// Optional list of category preference updates.
    pub preferences: Option<Vec<UpdatePreferenceItem>>,
}

/// Response payload representing a single notification preference.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreferenceResponse {
    /// External public UUID identifier of the preference record.
    pub id: String,

    /// Notification category identifier.
    pub category: String,

    /// Preference delivery setting value.
    pub value: String,

    /// Creation timestamp.
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    pub updated_at: DateTime<Utc>,
}

/// Response payload for listing all notification preferences of the authenticated user.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreferencesListResponse {
    /// External public UUID of the organization.
    pub organization_id: String,

    /// List of user preferences across all categories.
    pub preferences: Vec<PreferenceResponse>,
}

/// Request payload to unsubscribe using an HMAC-signed token (RFC 8058 one-click).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnsubscribeRequest {
    /// HMAC-signed token containing user, category, and issue time.
    pub token: String,
}

/// Response payload confirming unsubscribe action.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnsubscribeResponse {
    /// Whether the unsubscribe action was successfully processed.
    pub success: bool,

    /// Human-readable confirmation message.
    pub message: String,

    /// Public identifier of the unsubscribed user (if resolvable).
    pub user_id: Option<String>,

    /// Specific notification category unsubscribed from.
    pub category: Option<String>,
}

/// Response representation of an email audit log record.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EmailLogResponse {
    /// External public UUID identifier.
    pub id: String,

    /// Template identifier key.
    pub template_key: String,

    /// Recipient email address.
    pub recipient: String,

    /// External public UUID of the associated organization (if applicable).
    pub organization_id: Option<String>,

    /// Subject line sent.
    pub subject: String,

    /// Current delivery status: `queued`, `sent`, `failed`, `bounced`, or `complained`.
    pub status: String,

    /// Upstream provider message ID.
    pub provider_message_id: Option<String>,

    /// Error detail if delivery failed.
    pub error: Option<String>,

    /// Promotional campaign key if sent as part of a campaign.
    pub campaign_key: Option<String>,

    /// Whether this was a promotional email (true) or transactional (false).
    pub is_promotional: bool,

    /// Timestamp when email was created/queued.
    pub created_at: DateTime<Utc>,

    /// Optional timestamp when delivery was confirmed.
    pub sent_at: Option<DateTime<Utc>>,
}

/// Paginated or list response for organization email logs.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EmailLogListResponse {
    /// List of email log items.
    pub items: Vec<EmailLogResponse>,

    /// Total count of matching email logs for this organization.
    pub total: i64,
}

/// Request payload to create a new campaign.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CreateCampaignRequest {
    /// Unique campaign key identifier.
    pub key: String,

    /// Human-readable campaign name.
    pub name: String,

    /// Subject template string.
    pub subject_template: String,

    /// Body template string.
    pub body_template: String,

    /// Whether this campaign is active (defaults to true).
    pub active: Option<bool>,

    /// Optional JSON trigger rule object.
    pub trigger_rule: Option<serde_json::Value>,

    /// Optional score floor override.
    pub score_floor_override: Option<i64>,
}

/// Request payload to partially update an existing campaign.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct UpdateCampaignRequest {
    /// Optional updated name.
    pub name: Option<String>,

    /// Optional updated subject template.
    pub subject_template: Option<String>,

    /// Optional updated body template.
    pub body_template: Option<String>,

    /// Optional updated active status.
    pub active: Option<bool>,

    /// Optional updated trigger rule JSON object.
    pub trigger_rule: Option<serde_json::Value>,

    /// Optional updated score floor override.
    pub score_floor_override: Option<i64>,
}

/// Response payload representing a campaign.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CampaignResponse {
    /// External public UUID identifier.
    pub id: String,

    /// Unique campaign key identifier.
    pub key: String,

    /// Human-readable campaign name.
    pub name: String,

    /// Subject template string.
    pub subject_template: String,

    /// Body template string.
    pub body_template: String,

    /// Whether the campaign is active.
    pub active: bool,

    /// Parsed JSON trigger rule.
    pub trigger_rule: serde_json::Value,

    /// Score floor override if set.
    pub score_floor_override: Option<i64>,

    /// Creation timestamp.
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    pub updated_at: DateTime<Utc>,
}

/// Aggregated statistics and performance metrics for a campaign.
///
/// Integer percentages and minor units used throughout.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CampaignStatsResponse {
    /// External public UUID identifier of the campaign.
    pub id: String,

    /// Unique campaign key identifier.
    pub key: String,

    /// Human-readable campaign name.
    pub name: String,

    /// Whether the campaign is active.
    pub active: bool,

    /// Total number of messages dispatched for this campaign.
    pub total_sends: i64,

    /// Count of opened messages.
    pub opened_count: i64,

    /// Count of clicked messages.
    pub clicked_count: i64,

    /// Count of converted messages (completed target action within 14 days).
    pub converted_count: i64,

    /// Open rate as an integer percentage (e.g. 45 for 45%).
    pub open_rate_percent: i64,

    /// Click rate as an integer percentage (e.g. 12 for 12%).
    pub click_rate_percent: i64,

    /// Conversion rate as an integer percentage (e.g. 5 for 5%).
    pub conversion_rate_percent: i64,

    /// Whether this campaign is automatically disabled due to low conversion (<2% over 500+ sends).
    pub automatically_disabled: bool,
}

/// Request payload to preview a campaign for a given user or test snapshot without sending.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct PreviewCampaignRequest {
    /// Optional user public UUID to preview against.
    pub user_id: Option<String>,

    /// Optional organization public UUID to preview against.
    pub organization_id: Option<String>,

    /// Optional custom context overrides.
    pub custom_context: Option<serde_json::Value>,
}

/// Individual scoring factor breakdown item.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScoreFactorBreakdown {
    /// Name of the scoring factor.
    pub factor: String,

    /// Weight contributed to the score.
    pub weight: i64,

    /// Rationale / description of the factor.
    pub description: String,
}

/// Response payload containing rendered preview of a campaign.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PreviewCampaignResponse {
    /// Campaign key.
    pub campaign_key: String,

    /// Rendered subject line.
    pub subject: String,

    /// Rendered body content.
    pub body: String,

    /// Whether the user matches the eligibility filter.
    pub eligible: bool,

    /// Score computed by `score_campaign` (if eligible).
    pub score: Option<i64>,

    /// Detailed breakdown of score factors.
    pub score_breakdown: Option<Vec<ScoreFactorBreakdown>>,
}
