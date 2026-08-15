//! Domain errors and HTTP status mappings for the `builds` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions for build operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BuildError {
    /// Build was not found by public ID within the scoped context.
    BuildNotFound,
    /// Application referenced by public ID was not found or does not belong to the organization.
    AppNotFound,
    /// Environment referenced by public ID was not found or does not belong to the organization.
    EnvironmentNotFound,
    /// Organization context is missing or organization was not found.
    OrganizationNotFound,
    /// Caller lacks necessary permissions.
    Forbidden,
    /// The requested build status transition is not valid.
    InvalidStatus,
    /// Request validation failed.
    ValidationError(String),
    /// The background job queue rejected the job.
    QueueError(String),
    /// The object-storage backend failed.
    Storage(String),
    /// The worker job token presented was invalid.
    InvalidJobToken,
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for BuildError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::BuildNotFound => write!(f, "Build was not found."),
            Self::AppNotFound => write!(f, "App was not found."),
            Self::EnvironmentNotFound => write!(f, "Environment was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::Forbidden => write!(f, "You do not have permission to perform this action."),
            Self::InvalidStatus => write!(f, "Invalid build status transition."),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::QueueError(msg) => write!(f, "Failed to enqueue build job: {msg}"),
            Self::Storage(msg) => write!(f, "Storage error: {msg}"),
            Self::InvalidJobToken => write!(f, "Invalid worker job token."),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for BuildError {}

impl From<BuildError> for DjangorsError {
    fn from(error: BuildError) -> Self {
        match error {
            BuildError::BuildNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "Build was not found.")
            }
            BuildError::AppNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "App was not found.")
            }
            BuildError::EnvironmentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                "Environment was not found.",
            ),
            BuildError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            BuildError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            BuildError::InvalidStatus => DjangorsError::api(
                StatusCode::CONFLICT,
                "invalid_status",
                "Invalid build status transition.",
            ),
            BuildError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            BuildError::QueueError(msg) => {
                DjangorsError::api(StatusCode::BAD_GATEWAY, "queue_error", msg)
            }
            BuildError::Storage(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "storage_error", msg)
            }
            BuildError::InvalidJobToken => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_job_token",
                "Invalid worker job token.",
            ),
            BuildError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for BuildError {
    fn from(err: djangors_orm::OrmError) -> Self {
        BuildError::Database(err.to_string())
    }
}

impl From<crate::infra::storage::StorageError> for BuildError {
    fn from(err: crate::infra::storage::StorageError) -> Self {
        BuildError::Storage(err.to_string())
    }
}
