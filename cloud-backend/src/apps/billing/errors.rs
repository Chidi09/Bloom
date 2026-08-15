//! Domain errors and HTTP status code mappings for the `billing` app.

use djangors_contrib_payments::PaymentError;
use djangors_core::{DjangorsError, StatusCode};
use djangors_orm::OrmError;

/// Domain error conditions for billing, subscriptions, invoices, quotas, and payment processing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BillingError {
    /// Requested billing plan does not exist.
    PlanNotFound,

    /// Subscription not found for the specified organization or identifier.
    SubscriptionNotFound,

    /// Requested invoice does not exist or does not belong to the organization.
    InvoiceNotFound,

    /// Referenced organization does not exist.
    OrganizationNotFound,

    /// Organization context is missing from the request.
    OrganizationRequired,

    /// Caller does not have permission to view or manage billing.
    Forbidden,

    /// Caller's role within the organization is insufficient for billing actions (requires Owner or Admin).
    InsufficientRole,

    /// Subscription status transition is not permitted.
    InvalidStatusTransition {
        /// Current lifecycle status.
        from: String,
        /// Requested target status.
        to: String,
    },

    /// Unrecognized or unsupported usage metric name.
    InvalidMetric(String),

    /// Monetary amount is invalid (e.g. negative or non-integer calculation).
    InvalidAmount(String),

    /// Error returned by the payment gateway (Bachs or Paystack).
    PaymentProviderError(String),

    /// Inbound payment webhook signature verification failed.
    InvalidWebhookSignature,

    /// Webhook secret is not configured on the server.
    MissingWebhookSecret,

    /// Usage has exceeded the allocated quota and hard lock is enforced.
    QuotaExceeded {
        /// Metric that exceeded limit.
        metric: String,
        /// Maximum allowed quota.
        limit: i64,
        /// Current usage value.
        current: i64,
    },

    /// Requested feature is not enabled by the organization's plan entitlements.
    FeatureNotEntitled(String),

    /// Account or subscription is locked due to overdue payments or explicit restriction.
    AccountLocked,

    /// Input validation failed.
    ValidationError(String),

    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for BillingError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::PlanNotFound => write!(f, "Billing plan was not found."),
            Self::SubscriptionNotFound => write!(f, "Subscription was not found."),
            Self::InvoiceNotFound => write!(f, "Invoice was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::OrganizationRequired => write!(f, "An organization context is required."),
            Self::Forbidden => write!(
                f,
                "You do not have permission to perform this billing action."
            ),
            Self::InsufficientRole => write!(
                f,
                "Managing billing requires Owner or Admin role in the organization."
            ),
            Self::InvalidStatusTransition { from, to } => {
                write!(f, "Cannot transition subscription from '{from}' to '{to}'.")
            }
            Self::InvalidMetric(m) => write!(f, "Invalid usage metric: '{m}'."),
            Self::InvalidAmount(msg) => write!(f, "Invalid monetary amount: {msg}."),
            Self::PaymentProviderError(msg) => write!(f, "Payment provider error: {msg}."),
            Self::InvalidWebhookSignature => write!(f, "Invalid or missing webhook signature."),
            Self::MissingWebhookSecret => {
                write!(f, "Payment provider webhook secret is not configured.")
            }
            Self::QuotaExceeded {
                metric,
                limit,
                current,
            } => {
                write!(f, "Quota exceeded for metric '{metric}': current {current} exceeds limit {limit}.")
            }
            Self::FeatureNotEntitled(feature) => {
                write!(
                    f,
                    "Feature '{feature}' is not enabled in your current plan entitlements."
                )
            }
            Self::AccountLocked => write!(
                f,
                "Subscription is locked. Please resolve overdue invoices or upgrade."
            ),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for BillingError {}

impl From<BillingError> for DjangorsError {
    fn from(err: BillingError) -> Self {
        match err {
            BillingError::PlanNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "plan_not_found", "Billing plan not found.")
            }
            BillingError::SubscriptionNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "subscription_not_found",
                "Subscription not found.",
            ),
            BillingError::InvoiceNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "invoice_not_found", "Invoice not found.")
            }
            BillingError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization not found.",
            ),
            BillingError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            BillingError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            BillingError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "Managing billing requires Owner or Admin role.",
            ),
            BillingError::InvalidStatusTransition { from, to } => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_status_transition",
                format!("Cannot transition subscription status from '{from}' to '{to}'."),
            ),
            BillingError::InvalidMetric(m) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_metric",
                format!("Invalid usage metric '{m}'."),
            ),
            BillingError::InvalidAmount(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_amount", msg)
            }
            BillingError::PaymentProviderError(msg) => {
                DjangorsError::api(StatusCode::BAD_GATEWAY, "payment_provider_error", msg)
            }
            BillingError::InvalidWebhookSignature => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_webhook_signature",
                "Webhook signature verification failed.",
            ),
            BillingError::MissingWebhookSecret => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "missing_webhook_secret",
                "Payment webhook secret is not configured.",
            ),
            BillingError::QuotaExceeded {
                metric,
                limit,
                current,
            } => DjangorsError::api(
                StatusCode::PAYMENT_REQUIRED,
                "quota_exceeded",
                format!("Usage limit exceeded for {metric} ({current}/{limit}). Upgrade plan to continue."),
            ),
            BillingError::FeatureNotEntitled(feature) => DjangorsError::api(
                StatusCode::PAYMENT_REQUIRED,
                "feature_not_entitled",
                format!("Feature '{feature}' is not included in current plan."),
            ),
            BillingError::AccountLocked => DjangorsError::api(
                StatusCode::PAYMENT_REQUIRED,
                "account_locked",
                "Subscription is locked due to overdue payments.",
            ),
            BillingError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            BillingError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<OrmError> for BillingError {
    fn from(err: OrmError) -> Self {
        BillingError::Database(err.to_string())
    }
}

impl From<PaymentError> for BillingError {
    fn from(err: PaymentError) -> Self {
        match err {
            PaymentError::InvalidWebhookSignature => BillingError::InvalidWebhookSignature,
            other => BillingError::PaymentProviderError(other.to_string()),
        }
    }
}
