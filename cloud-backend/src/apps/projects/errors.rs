//! Application errors and HTTP status mappings for the `projects` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions that can arise during project operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProjectError {
    /// Project was not found by public ID or slug within the organization.
    ProjectNotFound,
    /// Project name is taken.
    NameTaken,
    /// Project slug is already in use within the organization.
    SlugTaken,
    /// Cannot delete project because it still contains active apps.
    ProjectNotEmpty,
    /// Organization was not found.
    OrganizationNotFound,
    /// No organization selected or context missing.
    OrganizationRequired,
    /// Caller lacks the necessary role for this operation.
    InsufficientRole,
    /// Request validation failed.
    ValidationError(String),
    /// Caller is unauthenticated.
    Unauthorized,
    /// Caller is forbidden from performing this action.
    Forbidden,
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for ProjectError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ProjectNotFound => write!(f, "Project was not found."),
            Self::NameTaken => write!(
                f,
                "A project with this name already exists in this organization."
            ),
            Self::SlugTaken => write!(
                f,
                "A project with this slug already exists in this organization."
            ),
            Self::ProjectNotEmpty => write!(f, "Cannot delete project containing active apps."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::OrganizationRequired => write!(f, "No organization selected."),
            Self::InsufficientRole => {
                write!(
                    f,
                    "You do not have sufficient permissions to perform this action."
                )
            }
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Unauthorized => write!(
                f,
                "Authentication credentials were not provided or are invalid."
            ),
            Self::Forbidden => write!(f, "You do not have permission to access this resource."),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for ProjectError {}

impl From<ProjectError> for DjangorsError {
    fn from(error: ProjectError) -> Self {
        match error {
            ProjectError::ProjectNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "project_not_found",
                "Project was not found.",
            ),
            ProjectError::NameTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "name_taken",
                "A project with this name already exists in this organization.",
            ),
            ProjectError::SlugTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "slug_taken",
                "A project with this slug already exists in this organization.",
            ),
            ProjectError::ProjectNotEmpty => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "project_not_empty",
                "Cannot delete project containing active apps.",
            ),
            ProjectError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            ProjectError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            ProjectError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "You do not have sufficient permissions to perform this action.",
            ),
            ProjectError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            ProjectError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication credentials were not provided or are invalid.",
            ),
            ProjectError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            ProjectError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for ProjectError {
    fn from(err: djangors_orm::OrmError) -> Self {
        ProjectError::Database(err.to_string())
    }
}

impl From<crate::apps::organizations::errors::OrganizationError> for ProjectError {
    fn from(err: crate::apps::organizations::errors::OrganizationError) -> Self {
        match err {
            crate::apps::organizations::errors::OrganizationError::OrganizationNotFound => {
                ProjectError::OrganizationNotFound
            }
            crate::apps::organizations::errors::OrganizationError::InsufficientRole => {
                ProjectError::InsufficientRole
            }
            crate::apps::organizations::errors::OrganizationError::Unauthorized => {
                ProjectError::Unauthorized
            }
            crate::apps::organizations::errors::OrganizationError::Forbidden => {
                ProjectError::Forbidden
            }
            crate::apps::organizations::errors::OrganizationError::ValidationError(msg) => {
                ProjectError::ValidationError(msg)
            }
            crate::apps::organizations::errors::OrganizationError::Database(msg) => {
                ProjectError::Database(msg)
            }
            other => ProjectError::Database(other.to_string()),
        }
    }
}
