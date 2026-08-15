//! Domain errors and HTTP status code mappings for the `emails` app.

use djangors_core::{DjangorsError, StatusCode};
use djangors_orm::OrmError;

/// Domain error conditions for email delivery, preferences, suppression, and campaign selection.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EmailsError {
    /// Requested email log entry was not found.
    EmailLogNotFound,

    /// Notification preference record was not found.
    PreferenceNotFound,

    /// Campaign was not found.
    CampaignNotFound,

    /// Organization context was not found.
    OrganizationNotFound,

    /// Organization context is required for this operation.
    OrganizationRequired,

    /// Caller does not have permission to perform this action.
    Forbidden,

    /// Staff or superuser privileges are required.
    StaffRequired,

    /// Caller's role within the organization is insufficient.
    InsufficientRole,

    /// Unrecognized notification preference category.
    InvalidCategory(String),

    /// Unrecognized notification preference value.
    InvalidPreferenceValue(String),

    /// Unrecognized suppression reason.
    InvalidSuppressionReason(String),

    /// Unrecognized email status.
    InvalidStatus(String),

    /// Unrecognized campaign key.
    InvalidCampaignKey(String),

    /// Mandatory category cannot be disabled (security and billing notifications are required).
    ImmutableCategoryPreference(String),

    /// Recipient address is currently suppressed.
    AddressSuppressed(String),

    /// Unsubscribe token is invalid or corrupted.
    InvalidUnsubscribeToken(String),

    /// Promotional frequency cap was exceeded for this recipient.
    FrequencyCapExceeded(String),

    /// Target campaign is inactive.
    CampaignInactive(String),

    /// Organization is locked or past due, suppressing promotional outreach.
    OrganizationLocked,

    /// Input validation failed.
    ValidationError(String),

    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for EmailsError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EmailLogNotFound => write!(f, "Email log record was not found."),
            Self::PreferenceNotFound => write!(f, "Notification preference was not found."),
            Self::CampaignNotFound => write!(f, "Campaign was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::OrganizationRequired => write!(f, "An organization context is required."),
            Self::Forbidden => {
                write!(f, "You do not have permission to perform this action.")
            }
            Self::StaffRequired => write!(f, "Staff privileges are required for this action."),
            Self::InsufficientRole => write!(
                f,
                "Managing email logs requires Owner or Admin role in the organization."
            ),
            Self::InvalidCategory(cat) => write!(f, "Invalid notification category: '{cat}'."),
            Self::InvalidPreferenceValue(val) => {
                write!(f, "Invalid notification preference value: '{val}'.")
            }
            Self::InvalidSuppressionReason(r) => {
                write!(f, "Invalid suppression reason: '{r}'.")
            }
            Self::InvalidStatus(s) => write!(f, "Invalid email status: '{s}'."),
            Self::InvalidCampaignKey(k) => write!(f, "Invalid campaign key: '{k}'."),
            Self::ImmutableCategoryPreference(cat) => write!(
                f,
                "Category '{cat}' cannot be disabled (security and billing notifications are mandatory)."
            ),
            Self::AddressSuppressed(addr) => {
                write!(f, "Recipient address '{addr}' is suppressed.")
            }
            Self::InvalidUnsubscribeToken(msg) => {
                write!(f, "Invalid or expired unsubscribe token: {msg}")
            }
            Self::FrequencyCapExceeded(msg) => {
                write!(f, "Email sending frequency cap exceeded: {msg}")
            }
            Self::CampaignInactive(k) => write!(f, "Campaign '{k}' is currently inactive."),
            Self::OrganizationLocked => write!(
                f,
                "Organization is locked or past due. Promotional sending is disabled."
            ),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for EmailsError {}

impl From<EmailsError> for DjangorsError {
    fn from(err: EmailsError) -> Self {
        match err {
            EmailsError::EmailLogNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "email_log_not_found",
                "Email log record was not found.",
            ),
            EmailsError::PreferenceNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "preference_not_found",
                "Notification preference was not found.",
            ),
            EmailsError::CampaignNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "campaign_not_found",
                "Campaign was not found.",
            ),
            EmailsError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            EmailsError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            EmailsError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            EmailsError::StaffRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "staff_required",
                "Staff privileges are required for this action.",
            ),
            EmailsError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "Managing email logs requires Owner or Admin role.",
            ),
            EmailsError::InvalidCategory(cat) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_category",
                format!("Invalid notification category '{cat}'."),
            ),
            EmailsError::InvalidPreferenceValue(val) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_preference_value",
                format!("Invalid notification preference value '{val}'."),
            ),
            EmailsError::InvalidSuppressionReason(r) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_suppression_reason",
                format!("Invalid suppression reason '{r}'."),
            ),
            EmailsError::InvalidStatus(s) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_status",
                format!("Invalid email status '{s}'."),
            ),
            EmailsError::InvalidCampaignKey(k) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_campaign_key",
                format!("Invalid campaign key '{k}'."),
            ),
            EmailsError::ImmutableCategoryPreference(cat) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "immutable_preference",
                format!("Category '{cat}' cannot be disabled (security and billing notifications are mandatory)."),
            ),
            EmailsError::AddressSuppressed(addr) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "address_suppressed",
                format!("Recipient address '{addr}' is suppressed."),
            ),
            EmailsError::InvalidUnsubscribeToken(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_unsubscribe_token",
                format!("Invalid unsubscribe token: {msg}"),
            ),
            EmailsError::FrequencyCapExceeded(msg) => DjangorsError::api(
                StatusCode::TOO_MANY_REQUESTS,
                "frequency_cap_exceeded",
                msg,
            ),
            EmailsError::CampaignInactive(k) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "campaign_inactive",
                format!("Campaign '{k}' is currently inactive."),
            ),
            EmailsError::OrganizationLocked => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "organization_locked",
                "Organization is locked or past due; promotional sends are suppressed.",
            ),
            EmailsError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            EmailsError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<OrmError> for EmailsError {
    fn from(err: OrmError) -> Self {
        EmailsError::Database(err.to_string())
    }
}
