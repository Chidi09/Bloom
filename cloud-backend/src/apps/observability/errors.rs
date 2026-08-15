//! Application errors and HTTP status mappings for the `observability` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions that can arise during observability operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ObservabilityError {
    /// The requested application was not found within the organization.
    AppNotFound,
    /// The requested release was not found within the organization.
    ReleaseNotFound,
    /// No organization context was provided on the request.
    OrganizationRequired,
    /// Authentication credentials were not provided or are invalid.
    Unauthorized,
    /// Caller does not have permission to view observability data.
    Forbidden,
    /// Request validation failed.
    ValidationError(String),
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for ObservabilityError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::AppNotFound => write!(f, "Application was not found."),
            Self::ReleaseNotFound => write!(f, "Release was not found."),
            Self::OrganizationRequired => write!(f, "No organization selected."),
            Self::Unauthorized => write!(
                f,
                "Authentication credentials were not provided or are invalid."
            ),
            Self::Forbidden => write!(f, "You do not have permission to access this resource."),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for ObservabilityError {}

impl From<ObservabilityError> for DjangorsError {
    fn from(error: ObservabilityError) -> Self {
        match error {
            ObservabilityError::AppNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "app_not_found",
                "Application was not found.",
            ),
            ObservabilityError::ReleaseNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "release_not_found",
                "Release was not found.",
            ),
            ObservabilityError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            ObservabilityError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication credentials were not provided or are invalid.",
            ),
            ObservabilityError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to access this resource.",
            ),
            ObservabilityError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            ObservabilityError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for ObservabilityError {
    fn from(err: djangors_orm::OrmError) -> Self {
        ObservabilityError::Database(err.to_string())
    }
}
