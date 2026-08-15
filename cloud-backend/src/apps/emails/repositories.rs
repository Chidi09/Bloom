//! Database queries and QuerySets for the `emails` domain app.

use chrono::{DateTime, Utc};
use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{
    Campaign, CampaignSend, EmailLog, EmailSuppression, EmailTemplateVersion,
    NotificationPreference,
};
use super::serializers::CampaignAggregatedStats;

// ---------------------------------------------------------------------------
// Cross-App Summaries (COMMON_RULES §8(a), (n))
// ---------------------------------------------------------------------------

/// Lightweight projection of a user record from `djangors_auth::User`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserSummary {
    /// Internal primary key.
    pub id: i64,
    /// Recipient email address.
    pub email: String,
    /// Whether user account is active.
    pub is_active: bool,
    /// Whether user has staff privileges.
    pub is_staff: bool,
    /// Whether user is a superuser.
    pub is_superuser: bool,
    /// Registration date.
    pub date_joined: DateTime<Utc>,
    /// Last login timestamp if recorded.
    pub last_login: Option<DateTime<Utc>>,
}

/// Lightweight projection of an organization record from `organizations`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID string.
    pub public_id: String,
    /// Organization name.
    pub name: String,
    /// Subscription plan name tier.
    pub plan: String,
    /// Optional billing email.
    pub billing_email: Option<String>,
    /// Creation timestamp.
    pub created_at: DateTime<Utc>,
}

/// Fetch an organization summary by internal primary key.
pub async fn organization_summary_by_id(
    db: &Database,
    org_id: i64,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let org = crate::apps::organizations::models::Organization::objects()
        .filter(q!(id = org_id))?
        .first(db)
        .await?;

    Ok(org.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
        name: o.name,
        plan: o.plan,
        billing_email: o.billing_email,
        created_at: o.created_at,
    }))
}

/// Fetch an organization summary by external public UUID.
pub async fn organization_summary_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let org = crate::apps::organizations::models::Organization::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await?;

    Ok(org.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
        name: o.name,
        plan: o.plan,
        billing_email: o.billing_email,
        created_at: o.created_at,
    }))
}

/// Fetch user profile summary by user ID.
pub async fn user_summary_by_id(
    db: &Database,
    user_id: i64,
) -> Result<Option<UserSummary>, OrmError> {
    let user = djangors_auth::User::objects()
        .filter(q!(id = user_id))?
        .first(db)
        .await?;

    Ok(user.map(|u| UserSummary {
        id: u.id,
        email: u.email,
        is_active: u.is_active,
        is_staff: u.is_staff,
        is_superuser: u.is_superuser,
        date_joined: u.date_joined,
        last_login: u.last_login,
    }))
}

// ---------------------------------------------------------------------------
// NotificationPreference queries
// ---------------------------------------------------------------------------

/// Fetch a user's notification preference for a specific organization and category.
pub async fn preference_by_user_org_category(
    db: &Database,
    user_id: i64,
    organization_id: i64,
    category: &str,
) -> Result<Option<NotificationPreference>, OrmError> {
    NotificationPreference::objects()
        .filter(q!(user_id = user_id))?
        .filter(q!(organization_id = organization_id))?
        .filter(q!(category = category.to_owned()))?
        .first(db)
        .await
}

/// Fetch all notification preferences for a user in a specific organization.
pub async fn preferences_for_user_in_org(
    db: &Database,
    user_id: i64,
    organization_id: i64,
) -> Result<Vec<NotificationPreference>, OrmError> {
    NotificationPreference::objects()
        .filter(q!(user_id = user_id))?
        .filter(q!(organization_id = organization_id))?
        .order_by("category")?
        .all(db)
        .await
}

/// Insert a new notification preference record.
pub async fn insert_preference(
    db: &Database,
    preference: NotificationPreference,
) -> Result<NotificationPreference, OrmError> {
    preference.save(db).await
}

/// Update an existing notification preference record.
pub async fn update_preference(
    db: &Database,
    preference: &NotificationPreference,
) -> Result<(), OrmError> {
    preference.update(db).await
}

// ---------------------------------------------------------------------------
// EmailSuppression queries
// ---------------------------------------------------------------------------

/// Check if an email address is in the suppression list.
pub async fn suppression_by_address(
    db: &Database,
    address: &str,
) -> Result<Option<EmailSuppression>, OrmError> {
    let normalized = address.trim().to_lowercase();
    EmailSuppression::objects()
        .filter(q!(address = normalized))?
        .first(db)
        .await
}

/// Insert a new suppression entry.
pub async fn insert_suppression(
    db: &Database,
    suppression: EmailSuppression,
) -> Result<EmailSuppression, OrmError> {
    suppression.save(db).await
}

// ---------------------------------------------------------------------------
// EmailLog queries
// ---------------------------------------------------------------------------

/// Fetch an email log by its internal primary key.
pub async fn email_log_by_id(db: &Database, id: i64) -> Result<Option<EmailLog>, OrmError> {
    EmailLog::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch an email log by its external public UUID.
pub async fn email_log_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<EmailLog>, OrmError> {
    EmailLog::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch paginated email logs for an organization.
pub async fn email_logs_for_organization(
    db: &Database,
    organization_id: i64,
    limit: i64,
    offset: i64,
) -> Result<Vec<EmailLog>, OrmError> {
    EmailLog::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .limit(limit)
        .offset(offset)
        .all(db)
        .await
}

/// Count total email logs for an organization.
pub async fn count_email_logs_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<i64, OrmError> {
    EmailLog::objects()
        .filter(q!(organization_id = organization_id))?
        .count(db)
        .await
}

/// Insert a new email log entry.
pub async fn insert_email_log(db: &Database, log: EmailLog) -> Result<EmailLog, OrmError> {
    log.save(db).await
}

/// Update status and provider reference of an email log.
pub async fn update_email_log(db: &Database, log: &EmailLog) -> Result<(), OrmError> {
    log.update(db).await
}

/// Count promotional emails sent to a recipient since a specific timestamp.
pub async fn count_promotional_emails_since(
    db: &Database,
    recipient: &str,
    since: DateTime<Utc>,
) -> Result<i64, OrmError> {
    let normalized = recipient.trim().to_lowercase();
    EmailLog::objects()
        .filter(q!(recipient = normalized))?
        .filter(q!(is_promotional = true))?
        .filter(q!(created_at__gte = since))?
        .count(db)
        .await
}

/// Fetch the most recent promotional email sent to a recipient.
pub async fn last_promotional_email_for_recipient(
    db: &Database,
    recipient: &str,
) -> Result<Option<EmailLog>, OrmError> {
    let normalized = recipient.trim().to_lowercase();
    EmailLog::objects()
        .filter(q!(recipient = normalized))?
        .filter(q!(is_promotional = true))?
        .order_by("-created_at")?
        .first(db)
        .await
}

/// Fetch the most recent transactional email sent to a recipient.
pub async fn last_transactional_email_for_recipient(
    db: &Database,
    recipient: &str,
) -> Result<Option<EmailLog>, OrmError> {
    let normalized = recipient.trim().to_lowercase();
    EmailLog::objects()
        .filter(q!(recipient = normalized))?
        .filter(q!(is_promotional = false))?
        .order_by("-created_at")?
        .first(db)
        .await
}

// ---------------------------------------------------------------------------
// Campaign queries
// ---------------------------------------------------------------------------

/// Fetch a campaign by internal primary key.
pub async fn campaign_by_id(db: &Database, id: i64) -> Result<Option<Campaign>, OrmError> {
    Campaign::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a campaign by its external public UUID.
pub async fn campaign_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Campaign>, OrmError> {
    Campaign::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a campaign by its unique key.
pub async fn campaign_by_key(db: &Database, key: &str) -> Result<Option<Campaign>, OrmError> {
    Campaign::objects()
        .filter(q!(key = key.to_owned()))?
        .first(db)
        .await
}

/// List all campaigns ordered by creation date.
pub async fn list_campaigns(db: &Database) -> Result<Vec<Campaign>, OrmError> {
    Campaign::objects().order_by("-created_at")?.all(db).await
}

/// List all active campaigns available for daily selection.
pub async fn list_active_campaigns(db: &Database) -> Result<Vec<Campaign>, OrmError> {
    Campaign::objects()
        .filter(q!(active = true))?
        .order_by("key")?
        .all(db)
        .await
}

/// Insert a new campaign record.
pub async fn insert_campaign(db: &Database, campaign: Campaign) -> Result<Campaign, OrmError> {
    campaign.save(db).await
}

/// Update an existing campaign record.
pub async fn update_campaign(db: &Database, campaign: &Campaign) -> Result<(), OrmError> {
    campaign.update(db).await
}

// ---------------------------------------------------------------------------
// CampaignSend queries
// ---------------------------------------------------------------------------

/// Insert a new campaign send record.
pub async fn insert_campaign_send(
    db: &Database,
    send: CampaignSend,
) -> Result<CampaignSend, OrmError> {
    send.save(db).await
}

/// Fetch all sends for a specific campaign.
pub async fn sends_for_campaign(
    db: &Database,
    campaign_id: i64,
) -> Result<Vec<CampaignSend>, OrmError> {
    CampaignSend::objects()
        .filter(q!(campaign_id = campaign_id))?
        .order_by("-sent_at")?
        .all(db)
        .await
}

/// Fetch aggregated metrics for a campaign.
pub async fn aggregate_campaign_stats(
    db: &Database,
    campaign_id: i64,
) -> Result<CampaignAggregatedStats, OrmError> {
    let sends = CampaignSend::objects()
        .filter(q!(campaign_id = campaign_id))?
        .all(db)
        .await?;

    let total = sends.len() as i64;
    let mut opened = 0_i64;
    let mut clicked = 0_i64;
    let mut converted = 0_i64;

    for s in &sends {
        if s.opened_at.is_some() {
            opened = opened.saturating_add(1);
        }
        if s.clicked_at.is_some() {
            clicked = clicked.saturating_add(1);
        }
        if s.converted_at.is_some() {
            converted = converted.saturating_add(1);
        }
    }

    Ok(CampaignAggregatedStats {
        total_sends: total,
        opened_count: opened,
        clicked_count: clicked,
        converted_count: converted,
    })
}

/// Fetch the most recent send of a specific campaign to a given user.
pub async fn last_send_for_user_and_campaign(
    db: &Database,
    user_id: i64,
    campaign_id: i64,
) -> Result<Option<CampaignSend>, OrmError> {
    CampaignSend::objects()
        .filter(q!(user_id = user_id))?
        .filter(q!(campaign_id = campaign_id))?
        .order_by("-sent_at")?
        .first(db)
        .await
}

/// Fetch the last N campaign sends to a given user.
pub async fn last_n_campaign_sends_for_user(
    db: &Database,
    user_id: i64,
    limit: i64,
) -> Result<Vec<CampaignSend>, OrmError> {
    CampaignSend::objects()
        .filter(q!(user_id = user_id))?
        .order_by("-sent_at")?
        .limit(limit)
        .all(db)
        .await
}

// ---------------------------------------------------------------------------
// EmailTemplateVersion queries
// ---------------------------------------------------------------------------

/// Fetch the latest template version for a template key.
pub async fn latest_template_version(
    db: &Database,
    template_key: &str,
) -> Result<Option<EmailTemplateVersion>, OrmError> {
    EmailTemplateVersion::objects()
        .filter(q!(template_key = template_key.to_owned()))?
        .order_by("-created_at")?
        .first(db)
        .await
}

/// Insert a template version record.
pub async fn insert_template_version(
    db: &Database,
    ver: EmailTemplateVersion,
) -> Result<EmailTemplateVersion, OrmError> {
    ver.save(db).await
}
