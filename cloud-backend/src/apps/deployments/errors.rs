//! Domain error types and HTTP response status mappings for `deployments`.

use std::fmt;

use djangors_core::error::DjangorsError;
use djangors_core::StatusCode;
use djangors_orm::OrmError;

use crate::infra::queue::QueueError;

/// Domain error enum for the `deployments` app.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeploymentError {
    /// Deployment was not found in the database or organization.
    DeploymentNotFound,
    /// Associated release was not found in the database or organization.
    ReleaseNotFound,
    /// Target artifact was not found in the database or organization.
    ArtifactNotFound,
    /// Target environment was not found in the database or organization.
    EnvironmentNotFound,
    /// Owning organization was not found.
    OrganizationNotFound,
    /// Caller lacks necessary permissions.
    Forbidden,
    /// Specified platform is invalid.
    InvalidPlatform(String),
    /// Specified target destination is invalid.
    InvalidTarget(String),
    /// Platform and target destination are incompatible.
    IncompatiblePlatformAndTarget {
        /// Target platform.
        platform: String,
        /// Destination target.
        target: String,
    },
    /// Deployment requires an approved release before deploying to production/app_store/shorebird.
    UnapprovedRelease,
    /// Status transition is invalid or illegal.
    InvalidStatus(String),
    /// Neither release_id nor artifact_id was provided.
    MissingReleaseOrArtifact,
    /// Request validation failed.
    ValidationError(String),
    /// Job queue operation failed.
    QueueError(String),
    /// Database query/persistence operation failed.
    OrmError(String),
    /// The organization's plan entitlements refuse this deployment target (billing hard lock).
    BillingBlocked(String),
}

impl fmt::Display for DeploymentError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DeploymentNotFound => write!(f, "Deployment not found."),
            Self::ReleaseNotFound => write!(f, "Release not found."),
            Self::ArtifactNotFound => write!(f, "Artifact not found."),
            Self::EnvironmentNotFound => write!(f, "Environment not found."),
            Self::OrganizationNotFound => write!(f, "Organization not found."),
            Self::Forbidden => write!(f, "Permission denied for this operation."),
            Self::InvalidPlatform(p) => write!(f, "Invalid platform: '{p}'."),
            Self::InvalidTarget(t) => write!(f, "Invalid target: '{t}'."),
            Self::IncompatiblePlatformAndTarget { platform, target } => {
                write!(
                    f,
                    "Incompatible platform '{platform}' and target '{target}'."
                )
            }
            Self::UnapprovedRelease => {
                write!(
                    f,
                    "Deployment requires an approved release for production/store targets."
                )
            }
            Self::InvalidStatus(msg) => write!(f, "Invalid deployment status transition: {msg}"),
            Self::MissingReleaseOrArtifact => {
                write!(f, "Either release_id or artifact_id must be provided.")
            }
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::QueueError(msg) => write!(f, "Job queue error: {msg}"),
            Self::OrmError(msg) => write!(f, "Database error: {msg}"),
            Self::BillingBlocked(msg) => write!(f, "{msg}"),
        }
    }
}

impl std::error::Error for DeploymentError {}

impl From<OrmError> for DeploymentError {
    fn from(err: OrmError) -> Self {
        Self::OrmError(err.to_string())
    }
}

impl From<QueueError> for DeploymentError {
    fn from(err: QueueError) -> Self {
        Self::QueueError(err.to_string())
    }
}

impl From<DeploymentError> for DjangorsError {
    fn from(err: DeploymentError) -> Self {
        match &err {
            DeploymentError::DeploymentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "deployment_not_found",
                "Deployment not found.",
            ),
            DeploymentError::ReleaseNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "release_not_found",
                "Release not found.",
            ),
            DeploymentError::ArtifactNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "artifact_not_found",
                "Artifact not found.",
            ),
            DeploymentError::EnvironmentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "environment_not_found",
                "Environment not found.",
            ),
            DeploymentError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization not found.",
            ),
            DeploymentError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            DeploymentError::InvalidPlatform(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_platform", msg.clone())
            }
            DeploymentError::InvalidTarget(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_target", msg.clone())
            }
            DeploymentError::IncompatiblePlatformAndTarget { platform, target } => {
                DjangorsError::api(
                    StatusCode::BAD_REQUEST,
                    "incompatible_platform_target",
                    format!("Incompatible platform '{platform}' and target '{target}'."),
                )
            }
            DeploymentError::UnapprovedRelease => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "unapproved_release",
                "Deployment requires an approved release for production/store targets.",
            ),
            DeploymentError::InvalidStatus(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_status", msg.clone())
            }
            DeploymentError::MissingReleaseOrArtifact => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "missing_release_or_artifact",
                "Either release_id or artifact_id must be provided.",
            ),
            DeploymentError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg.clone())
            }
            DeploymentError::QueueError(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "queue_error",
                msg.clone(),
            ),
            DeploymentError::OrmError(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database_error",
                msg.clone(),
            ),
            DeploymentError::BillingBlocked(msg) => {
                DjangorsError::api(StatusCode::PAYMENT_REQUIRED, "billing_blocked", msg.clone())
            }
        }
    }
}
