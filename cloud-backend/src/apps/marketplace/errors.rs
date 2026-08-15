//! Typed domain errors and HTTP response mapping for `marketplace`.

use djangors_core::{DjangorsError, StatusCode};

use crate::infra::stripe::StripeError;

/// Domain errors encountered in `marketplace` workflows.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MarketplaceError {
    /// The requested template was not found.
    TemplateNotFound,

    /// The requested template version was not found.
    TemplateVersionNotFound,

    /// A template with this slug already exists in the organization.
    SlugTaken,

    /// A template version with this semver string already exists.
    VersionAlreadyExists,

    /// Invalid state transition attempted.
    InvalidStateTransition {
        /// Current lifecycle status.
        from: String,
        /// Requested target status.
        to: String,
    },

    /// The template is not published and cannot be accessed via the public marketplace.
    TemplateNotPublished,

    /// The template is private and cannot be accessed publicly.
    TemplatePrivate,

    /// The seller payout account was not found.
    SellerAccountNotFound,

    /// The seller's payouts are not enabled on Stripe Connect.
    SellerPayoutsNotEnabled,

    /// The seller organization has not configured a Stripe payout account.
    SellerNotConfigured,

    /// An organization attempted to purchase a template it already owns.
    CannotPurchaseOwnTemplate,

    /// A paid template was requested without an active purchase entitlement.
    PaymentRequired,

    /// Payment execution or card charge failed.
    PaymentFailed(String),

    /// The requested template purchase was not found.
    PurchaseNotFound,

    /// The purchase was already refunded.
    PurchaseAlreadyRefunded,

    /// Invalid state for issuing a refund.
    InvalidRefundState(String),

    /// A rating score was outside the required 1..=5 star range.
    InvalidRating(i64),

    /// A review was attempted without a verified purchase or installation entitlement.
    ReviewNotAllowedNoPurchaseOrInstall,

    /// A template author attempted to edit or delete reviews on their own template.
    AuthorCannotModerateReviews,

    /// A template author attempted to review their own template.
    AuthorCannotReviewOwnTemplate,

    /// The requested review was not found.
    ReviewNotFound,

    /// The requested review abuse report was not found.
    ReviewReportNotFound,

    /// An author reply already exists on this review.
    AuthorReplyAlreadyExists,

    /// Invalid review moderation status.
    InvalidReviewStatus(String),

    /// Invalid featured placement type.
    InvalidFeaturedType(String),

    /// Stripe infrastructure error.
    Stripe(String),

    /// Field or payload validation error.
    ValidationError(String),

    /// The active organization context is missing or required.
    OrganizationRequired,

    /// The organization was not found.
    OrganizationNotFound,

    /// Caller does not possess the required role in the organization.
    InsufficientRole,

    /// General access denied.
    Forbidden,

    /// Unauthenticated caller.
    Unauthorized,

    /// Database or persistence layer error.
    DatabaseError(String),
}

impl From<StripeError> for MarketplaceError {
    fn from(err: StripeError) -> Self {
        match err {
            StripeError::CardDeclined(msg) => MarketplaceError::PaymentFailed(msg),
            StripeError::InvalidRequest(msg) => MarketplaceError::ValidationError(msg),
            StripeError::NotFound(_) => MarketplaceError::PurchaseNotFound,
            other => MarketplaceError::Stripe(other.to_string()),
        }
    }
}

impl From<MarketplaceError> for DjangorsError {
    fn from(err: MarketplaceError) -> Self {
        match err {
            MarketplaceError::TemplateNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "template_not_found",
                "The requested template does not exist.",
            ),
            MarketplaceError::TemplateVersionNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "template_version_not_found",
                "The requested template version does not exist.",
            ),
            MarketplaceError::SlugTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "slug_taken",
                "A template with this slug already exists in the organization.",
            ),
            MarketplaceError::VersionAlreadyExists => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "version_already_exists",
                "A template version with this semver string already exists.",
            ),
            MarketplaceError::InvalidStateTransition { from, to } => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_state_transition",
                format!("Cannot transition template from '{from}' to '{to}'."),
            ),
            MarketplaceError::TemplateNotPublished => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "template_not_found",
                "The requested template is not published.",
            ),
            MarketplaceError::TemplatePrivate => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "template_not_found",
                "The requested template is private.",
            ),
            MarketplaceError::SellerAccountNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "seller_account_not_found",
                "Seller payout account has not been set up.",
            ),
            MarketplaceError::SellerPayoutsNotEnabled => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "seller_payouts_not_enabled",
                "Seller must complete Stripe onboarding and have payouts_enabled=true before listing a paid template.",
            ),
            MarketplaceError::SellerNotConfigured => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "seller_not_configured",
                "Seller organization has not connected a Stripe payout account.",
            ),
            MarketplaceError::CannotPurchaseOwnTemplate => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "cannot_purchase_own_template",
                "Organizations cannot purchase templates they own.",
            ),
            MarketplaceError::PaymentRequired => DjangorsError::api(
                StatusCode::PAYMENT_REQUIRED,
                "payment_required",
                "Access requires purchasing this paid template.",
            ),
            MarketplaceError::PaymentFailed(msg) => {
                DjangorsError::api(StatusCode::PAYMENT_REQUIRED, "payment_failed", msg)
            }
            MarketplaceError::PurchaseNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "purchase_not_found",
                "The requested template purchase was not found.",
            ),
            MarketplaceError::PurchaseAlreadyRefunded => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "purchase_already_refunded",
                "This purchase has already been refunded.",
            ),
            MarketplaceError::InvalidRefundState(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_refund_state", msg)
            }
            MarketplaceError::InvalidRating(r) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_rating",
                format!("Rating {r} is invalid. Rating must be an integer between 1 and 5 stars."),
            ),
            MarketplaceError::ReviewNotAllowedNoPurchaseOrInstall => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "review_not_allowed",
                "Reviews require a verified purchase or recorded installation.",
            ),
            MarketplaceError::AuthorCannotModerateReviews => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "author_cannot_moderate_reviews",
                "Template authors cannot edit, hide, or delete reviews on their own templates.",
            ),
            MarketplaceError::AuthorCannotReviewOwnTemplate => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "author_cannot_review_own_template",
                "Template authors cannot submit reviews for their own templates.",
            ),
            MarketplaceError::ReviewNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "review_not_found",
                "The requested review does not exist.",
            ),
            MarketplaceError::ReviewReportNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "review_report_not_found",
                "The requested review abuse report does not exist.",
            ),
            MarketplaceError::AuthorReplyAlreadyExists => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "author_reply_already_exists",
                "An author reply has already been submitted for this review.",
            ),
            MarketplaceError::InvalidReviewStatus(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_review_status", msg)
            }
            MarketplaceError::InvalidFeaturedType(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_featured_type", msg)
            }
            MarketplaceError::Stripe(msg) => {
                DjangorsError::api(StatusCode::BAD_GATEWAY, "stripe_error", msg)
            }
            MarketplaceError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            MarketplaceError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            MarketplaceError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization not found.",
            ),
            MarketplaceError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "Insufficient role to perform this action.",
            ),
            MarketplaceError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "Permission denied.",
            ),
            MarketplaceError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication required.",
            ),
            MarketplaceError::DatabaseError(msg) => DjangorsError::Internal(msg),
        }
    }
}
