//! Domain errors and HTTP status mappings for the `apps` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions for application entity operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AppError {
    /// App slug is already in use within the project.
    SlugTaken,
    /// App was not found by public ID or slug.
    AppNotFound,
    /// Project referenced by public ID or slug was not found.
    ProjectNotFound,
    /// Organization context is missing or organization was not found.
    OrganizationNotFound,
    /// Cannot delete app because it has associated environments, builds, or releases.
    AppNotEmpty,
    /// Caller lacks necessary permissions.
    Forbidden,
    /// Request validation failed.
    ValidationError(String),
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SlugTaken => write!(f, "An app with this slug already exists in this project."),
            Self::AppNotFound => write!(f, "App was not found."),
            Self::ProjectNotFound => write!(f, "Project was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::AppNotEmpty => write!(
                f,
                "Cannot delete app with associated environments, builds, or releases."
            ),
            Self::Forbidden => write!(f, "You do not have permission to access this resource."),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for AppError {}

impl From<AppError> for DjangorsError {
    fn from(error: AppError) -> Self {
        match error {
            AppError::SlugTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "slug_taken",
                "An app with this slug already exists in this project.",
            ),
            AppError::AppNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "App was not found.")
            }
            AppError::ProjectNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "Project was not found.")
            }
            AppError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            AppError::AppNotEmpty => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "app_not_empty",
                "Cannot delete app with associated environments, builds, or releases.",
            ),
            AppError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            AppError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            AppError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for AppError {
    fn from(err: djangors_orm::OrmError) -> Self {
        AppError::Database(err.to_string())
    }
}
