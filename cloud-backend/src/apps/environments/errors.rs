//! Domain errors and HTTP status mappings for the `environments` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions for environment entity operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EnvironmentError {
    /// Environment slug is already in use within the parent app.
    SlugTaken,
    /// Environment was not found by public ID or slug within the scoped context.
    EnvironmentNotFound,
    /// Application referenced by public ID was not found or does not belong to the organization.
    AppNotFound,
    /// Organization context is missing or organization was not found.
    OrganizationNotFound,
    /// Build profile specified is invalid (must be `debug`, `profile`, or `release`).
    InvalidBuildProfile,
    /// Invalid JSON format or structure for `api_config`.
    InvalidApiConfig(String),
    /// Caller lacks necessary permissions.
    Forbidden,
    /// Request validation failed.
    ValidationError(String),
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for EnvironmentError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SlugTaken => write!(
                f,
                "An environment with this slug already exists in this application."
            ),
            Self::EnvironmentNotFound => write!(f, "Environment was not found."),
            Self::AppNotFound => write!(f, "App was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::InvalidBuildProfile => write!(
                f,
                "Invalid build profile. Allowed values: debug, profile, release."
            ),
            Self::InvalidApiConfig(msg) => write!(f, "Invalid api_config: {msg}"),
            Self::Forbidden => {
                write!(f, "You do not have permission to perform this action.")
            }
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for EnvironmentError {}

impl From<EnvironmentError> for DjangorsError {
    fn from(error: EnvironmentError) -> Self {
        match error {
            EnvironmentError::SlugTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "slug_taken",
                "An environment with this slug already exists in this application.",
            ),
            EnvironmentError::EnvironmentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                "Environment was not found.",
            ),
            EnvironmentError::AppNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "App was not found.")
            }
            EnvironmentError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            EnvironmentError::InvalidBuildProfile => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_build_profile",
                "Invalid build profile. Allowed values: debug, profile, release.",
            ),
            EnvironmentError::InvalidApiConfig(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_api_config",
                format!("Invalid api_config: {msg}"),
            ),
            EnvironmentError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            EnvironmentError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            EnvironmentError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for EnvironmentError {
    fn from(err: djangors_orm::OrmError) -> Self {
        EnvironmentError::Database(err.to_string())
    }
}
