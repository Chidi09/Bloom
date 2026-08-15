//! Persistence models for the `emails` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// Valid status values for email logs.
pub const VALID_EMAIL_STATUSES: &[&str] = &["queued", "sent", "failed", "bounced", "complained"];

/// Valid category values for notification preferences.
pub const VALID_PREFERENCE_CATEGORIES: &[&str] = &[
    "builds",
    "deployments",
    "releases",
    "security",
    "billing",
    "product",
];

/// Valid values for notification preference settings.
pub const VALID_PREFERENCE_VALUES: &[&str] = &["all", "mine_only", "digest", "none"];

/// Valid reasons for email address suppression.
pub const VALID_SUPPRESSION_REASONS: &[&str] =
    &["hard_bounce", "spam_complaint", "manual", "unsubscribed"];

/// Valid promotional campaign keys from the campaign catalogue.
pub const VALID_CAMPAIGN_KEYS: &[&str] = &[
    "promo.first_build_success",
    "promo.git_not_connected",
    "promo.web_hosting_unused",
    "promo.custom_domain_unused",
    "promo.workflows_unused",
    "promo.shorebird_unused",
    "promo.approaching_limit",
    "promo.team_of_one",
    "promo.marketplace_publish",
    "promo.reactivation",
];

/// Valid transactional email template keys from the catalogue.
pub const VALID_TRANSACTIONAL_KEYS: &[&str] = &[
    "auth.device_login",
    "auth.token_created",
    "org.invitation",
    "org.member_joined",
    "build.failed",
    "build.recovered",
    "deploy.succeeded",
    "deploy.failed",
    "deploy.rolled_back",
    "release.approval_requested",
    "workflow.approval_requested",
    "domain.verification_failed",
    "domain.certificate_failed",
    "credential.expiring",
    "billing.receipt",
    "billing.payment_failed",
    "billing.quota_warning",
    "billing.hard_lock",
    "billing.trial_ending",
];

/// An email audit log record tracking every outgoing transactional and promotional message.
///
/// Stores delivery status, provider references, error payloads, and timestamps.
/// Serves as both an audit trail and the primary input to promotional frequency cap evaluation.
#[derive(Model, Debug, Clone)]
#[djangors(app = "emails", table_name = "emails_emaillog")]
pub struct EmailLog {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Template identifier key (e.g. `build.failed`, `billing.receipt`, `promo.git_not_connected`).
    #[djangors(max_length = 128, db_index)]
    pub template_key: String,

    /// Recipient email address.
    #[djangors(max_length = 254, db_index)]
    pub recipient: String,

    /// Optional foreign key referencing the tenant organization for scoped queries.
    #[djangors(nullable, db_index)]
    pub organization_id: Option<i64>,

    /// Email subject line rendered and sent.
    #[djangors(max_length = 255)]
    pub subject: String,

    /// Delivery status: `queued`, `sent`, `failed`, `bounced`, or `complained`.
    #[djangors(max_length = 32, db_index)]
    pub status: String,

    /// External message ID assigned by the upstream SMTP/mail provider.
    #[djangors(max_length = 255, nullable)]
    pub provider_message_id: Option<String>,

    /// Optional error description if dispatch or delivery failed.
    #[djangors(nullable)]
    pub error: Option<String>,

    /// Optional campaign key if this send was triggered by a promotional campaign.
    #[djangors(max_length = 128, nullable, db_index)]
    pub campaign_key: Option<String>,

    /// Flag indicating whether this email is promotional (true) or transactional (false).
    #[djangors(default = false, db_index)]
    pub is_promotional: bool,

    /// Creation timestamp (time queued).
    #[djangors(auto_now_add, db_index)]
    pub created_at: DateTime<Utc>,

    /// Optional timestamp when the message was confirmed sent by provider.
    #[djangors(nullable)]
    pub sent_at: Option<DateTime<Utc>>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for EmailLog {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// User notification preferences per organization and category.
///
/// Categories include `builds`, `deployments`, `releases`, `security`, `billing`, and `product`.
/// Values include `all`, `mine_only`, `digest`, and `none`.
/// Security and billing notifications are mandatory and cannot be set to `none`.
#[derive(Model, Debug, Clone)]
#[djangors(app = "emails", table_name = "emails_notificationpreference")]
pub struct NotificationPreference {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key to `auth_user.id`.
    #[djangors(db_index)]
    pub user_id: i64,

    /// Foreign key to `organizations_organization.id`.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Notification category: `builds`, `deployments`, `releases`, `security`, `billing`, or `product`.
    #[djangors(max_length = 32)]
    pub category: String,

    /// Preference delivery value: `all`, `mine_only`, `digest`, or `none`.
    #[djangors(max_length = 32)]
    pub value: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for NotificationPreference {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// Suppression list entry for addresses that hard-bounced, filed spam complaints, or unsubscribed.
///
/// Checked before every send, including transactional messages.
#[derive(Model, Debug, Clone)]
#[djangors(app = "emails", table_name = "emails_emailsuppression")]
pub struct EmailSuppression {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Suppressed email address (normalized lowercase).
    #[djangors(max_length = 254, unique)]
    pub address: String,

    /// Reason for suppression: `hard_bounce`, `spam_complaint`, `manual`, or `unsubscribed`.
    #[djangors(max_length = 32)]
    pub reason: String,

    /// Timestamp when suppression was recorded.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

/// Version tracking and content checksum metadata for registered email templates.
#[derive(Model, Debug, Clone)]
#[djangors(app = "emails", table_name = "emails_emailtemplateversion")]
pub struct EmailTemplateVersion {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Template key identifier.
    #[djangors(max_length = 128, db_index)]
    pub template_key: String,

    /// Semver version or generation identifier.
    #[djangors(max_length = 64)]
    pub version: String,

    /// SHA-256 checksum of the combined text and HTML template content.
    #[djangors(max_length = 64)]
    pub checksum: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

/// A promotional or lifecycle email campaign configuration.
#[derive(Model, Debug, Clone)]
#[djangors(app = "emails", table_name = "emails_campaign")]
pub struct Campaign {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Unique campaign key identifier (e.g. `promo.first_build_success`).
    #[djangors(max_length = 128, unique)]
    pub key: String,

    /// Human-readable campaign name.
    #[djangors(max_length = 255)]
    pub name: String,

    /// Subject line template string.
    #[djangors(max_length = 255)]
    pub subject_template: String,

    /// Email body template text (or template reference).
    pub body_template: String,

    /// Whether this campaign is active and eligible for automated daily selection.
    #[djangors(default = true)]
    pub active: bool,

    /// JSON rule string defining the campaign trigger conditions and parameters.
    #[djangors(default = "{}")]
    pub trigger_rule: String,

    /// Optional override for the standard score floor (defaults to 60 if null).
    #[djangors(nullable)]
    pub score_floor_override: Option<i64>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

/// Record of a promotional campaign sent to a specific user and organization.
#[derive(Model, Debug, Clone)]
#[djangors(app = "emails", table_name = "emails_campaignsend")]
pub struct CampaignSend {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent Campaign.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub campaign_id: ForeignKey<Campaign>,

    /// Foreign key to `auth_user.id`.
    #[djangors(db_index)]
    pub user_id: i64,

    /// Foreign key to `organizations_organization.id`.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Score calculated by `score_campaign` at the moment of selection.
    pub score_at_send: i64,

    /// Timestamp when the message was dispatched.
    #[djangors(auto_now_add)]
    pub sent_at: DateTime<Utc>,

    /// Optional timestamp when open pixel was fetched.
    #[djangors(nullable)]
    pub opened_at: Option<DateTime<Utc>>,

    /// Optional timestamp when any link was clicked.
    #[djangors(nullable)]
    pub clicked_at: Option<DateTime<Utc>>,

    /// Optional timestamp when conversion goal was completed within 14 days.
    #[djangors(nullable)]
    pub converted_at: Option<DateTime<Utc>>,

    /// Optional identifier of the specific conversion event triggered.
    #[djangors(max_length = 128, nullable)]
    pub conversion_event: Option<String>,
}

impl Scoped for CampaignSend {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
