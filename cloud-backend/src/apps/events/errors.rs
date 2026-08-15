//! Application errors and HTTP status mappings for the `events` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions that can arise during event operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EventError {
    /// Event row was not found by public UUID within the organization.
    EventNotFound,
    /// No organization selected or context missing.
    OrganizationRequired,
    /// Caller is unauthenticated.
    Unauthorized,
    /// Caller is forbidden from performing this action.
    Forbidden,
    /// Request validation failed.
    ValidationError(String),
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for EventError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EventNotFound => write!(f, "Event was not found."),
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

impl std::error::Error for EventError {}

impl From<EventError> for DjangorsError {
    fn from(error: EventError) -> Self {
        match error {
            EventError::EventNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "event_not_found",
                "Event was not found.",
            ),
            EventError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            EventError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication credentials were not provided or are invalid.",
            ),
            EventError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to access this resource.",
            ),
            EventError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            EventError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for EventError {
    fn from(err: djangors_orm::OrmError) -> Self {
        EventError::Database(err.to_string())
    }
}
