//! Typed domain errors and HTTP response mapping for `marketplace`.

use djangors_core::{DjangorsError, StatusCode};

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
