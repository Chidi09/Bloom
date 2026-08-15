//! Domain errors and HTTP status mappings for the `releases` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions for release operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReleaseError {
    /// Release was not found by public UUID within the scoped organization.
    ReleaseNotFound,
    /// Application referenced by public UUID was not found or does not belong to the organization.
    AppNotFound,
    /// Environment referenced by public UUID was not found or does not belong to the organization.
    EnvironmentNotFound,
    /// Artifact referenced by public UUID was not found or does not belong to the organization.
    ArtifactNotFound(String),
    /// Organization context is missing or organization was not found.
    OrganizationNotFound,
    /// Authenticated user was not found.
    UserNotFound,
    /// Caller lacks necessary permissions (e.g. role too low).
    Forbidden,
    /// The requested release status transition is not permitted.
    InvalidStatus,
    /// Request validation failed.
    ValidationError(String),
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for ReleaseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ReleaseNotFound => write!(f, "Release was not found."),
            Self::AppNotFound => write!(f, "App was not found."),
            Self::EnvironmentNotFound => write!(f, "Environment was not found."),
            Self::ArtifactNotFound(id) => {
                write!(f, "Artifact '{id}' was not found in organization.")
            }
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::UserNotFound => write!(f, "User was not found."),
            Self::Forbidden => write!(f, "You do not have permission to perform this action."),
            Self::InvalidStatus => write!(f, "Invalid release status transition."),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for ReleaseError {}

impl From<ReleaseError> for DjangorsError {
    fn from(error: ReleaseError) -> Self {
        match error {
            ReleaseError::ReleaseNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "Release was not found.")
            }
            ReleaseError::AppNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "App was not found.")
            }
            ReleaseError::EnvironmentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                "Environment was not found.",
            ),
            ReleaseError::ArtifactNotFound(id) => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                format!("Artifact '{id}' was not found in organization."),
            ),
            ReleaseError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            ReleaseError::UserNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "User was not found.")
            }
            ReleaseError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            ReleaseError::InvalidStatus => DjangorsError::api(
                StatusCode::CONFLICT,
                "invalid_status",
                "Invalid release status transition.",
            ),
            ReleaseError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            ReleaseError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for ReleaseError {
    fn from(err: djangors_orm::OrmError) -> Self {
        ReleaseError::Database(err.to_string())
    }
}
