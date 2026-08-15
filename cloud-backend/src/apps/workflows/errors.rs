//! Domain errors and HTTP status mappings for the `workflows` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions for workflow and workflow run operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WorkflowError {
    /// Workflow was not found by public ID within the scoped context.
    WorkflowNotFound,
    /// Workflow run was not found by public ID within the scoped context.
    WorkflowRunNotFound,
    /// Workflow run step was not found.
    StepNotFound,
    /// Application referenced by public ID was not found or does not belong to the organization.
    AppNotFound,
    /// Organization context is missing or organization was not found.
    OrganizationNotFound,
    /// Caller lacks necessary permissions.
    Forbidden,
    /// The requested workflow run status transition is not valid.
    InvalidStatus(String),
    /// Request validation failed.
    ValidationError(String),
    /// Workflow slug already exists in this application.
    DuplicateSlug(String),
    /// Approval gate is in an invalid state or already decided.
    GateAlreadyDecided,
    /// The background job queue rejected the job.
    QueueError(String),
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for WorkflowError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::WorkflowNotFound => write!(f, "Workflow was not found."),
            Self::WorkflowRunNotFound => write!(f, "Workflow run was not found."),
            Self::StepNotFound => write!(f, "Workflow run step was not found."),
            Self::AppNotFound => write!(f, "App was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::Forbidden => write!(f, "You do not have permission to perform this action."),
            Self::InvalidStatus(msg) => write!(f, "Invalid workflow status transition: {msg}"),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::DuplicateSlug(slug) => {
                write!(
                    f,
                    "A workflow with slug '{slug}' already exists in this app."
                )
            }
            Self::GateAlreadyDecided => {
                write!(
                    f,
                    "This approval gate has already been decided and cannot be re-evaluated."
                )
            }
            Self::QueueError(msg) => write!(f, "Failed to enqueue workflow job: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for WorkflowError {}

impl From<WorkflowError> for DjangorsError {
    fn from(error: WorkflowError) -> Self {
        match error {
            WorkflowError::WorkflowNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                "Workflow was not found.",
            ),
            WorkflowError::WorkflowRunNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                "Workflow run was not found.",
            ),
            WorkflowError::StepNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                "Workflow run step was not found.",
            ),
            WorkflowError::AppNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "App was not found.")
            }
            WorkflowError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            WorkflowError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            WorkflowError::InvalidStatus(msg) => {
                DjangorsError::api(StatusCode::CONFLICT, "invalid_status", msg)
            }
            WorkflowError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            WorkflowError::DuplicateSlug(slug) => DjangorsError::api(
                StatusCode::CONFLICT,
                "duplicate_slug",
                format!("A workflow with slug '{slug}' already exists in this app."),
            ),
            WorkflowError::GateAlreadyDecided => DjangorsError::api(
                StatusCode::CONFLICT,
                "gate_already_decided",
                "This approval gate has already been decided and cannot be re-evaluated.",
            ),
            WorkflowError::QueueError(msg) => {
                DjangorsError::api(StatusCode::BAD_GATEWAY, "queue_error", msg)
            }
            WorkflowError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for WorkflowError {
    fn from(err: djangors_orm::OrmError) -> Self {
        WorkflowError::Database(err.to_string())
    }
}
