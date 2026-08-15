//! Domain error types and HTTP response status mappings for `webhosting`.

use std::fmt;

use djangors_core::error::DjangorsError;
use djangors_core::StatusCode;
use djangors_orm::OrmError;

use crate::infra::caddy::CaddyError;
use crate::infra::dns::DnsError;
use crate::infra::storage::StorageError;

/// Domain error enum for the `webhosting` app.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WebHostingError {
    /// Web deployment was not found in the database or organization.
    DeploymentNotFound,
    /// Custom domain was not found in the database or organization.
    DomainNotFound,
    /// Parent app was not found in the database or organization.
    AppNotFound,
    /// Parent project was not found in the database or organization.
    ProjectNotFound,
    /// Target environment was not found in the database or organization.
    EnvironmentNotFound,
    /// Target artifact was not found in the database or organization.
    ArtifactNotFound,
    /// Artifact is not a web bundle artifact.
    InvalidArtifactKind,
    /// Associated release was not found in the database or organization.
    ReleaseNotFound,
    /// Tenant organization was not found.
    OrganizationNotFound,
    /// Specified deployment target is invalid (must be `preview` or `production`).
    InvalidTarget,
    /// Status transition is invalid or illegal.
    InvalidStatus,
    /// Domain format is invalid.
    InvalidDomain,
    /// Custom domain already exists for this application.
    DomainAlreadyExists,
    /// Domain ownership verification failed.
    VerificationFailed(String),
    /// Domain is not verified and cannot be provisioned or served.
    DomainNotVerified(String),
    /// No previous live deployment was found to rollback to.
    NoPreviousDeployment,
    /// Metadata JSON text is invalid.
    InvalidMetadata(String),
    /// Caller lacks necessary permissions.
    Forbidden,
    /// Request validation failed.
    ValidationError(String),
    /// DNS resolution error during domain verification.
    DnsError(String),
    /// Caddy reverse proxy admin API operation failed.
    CaddyError(String),
    /// Object storage operation failed.
    StorageError(String),
    /// Database query/persistence operation failed.
    OrmError(String),
}

impl fmt::Display for WebHostingError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DeploymentNotFound => write!(f, "Web deployment not found."),
            Self::DomainNotFound => write!(f, "Custom domain not found."),
            Self::AppNotFound => write!(f, "App not found."),
            Self::ProjectNotFound => write!(f, "Project not found."),
            Self::EnvironmentNotFound => write!(f, "Environment not found."),
            Self::ArtifactNotFound => write!(f, "Artifact not found."),
            Self::InvalidArtifactKind => {
                write!(f, "Artifact is not a valid web bundle ('web_bundle').")
            }
            Self::ReleaseNotFound => write!(f, "Release not found."),
            Self::OrganizationNotFound => write!(f, "Organization not found."),
            Self::InvalidTarget => {
                write!(
                    f,
                    "Invalid target. Allowed values: 'preview', 'production'."
                )
            }
            Self::InvalidStatus => write!(f, "Invalid deployment status transition."),
            Self::InvalidDomain => write!(f, "Invalid custom domain format."),
            Self::DomainAlreadyExists => {
                write!(f, "This custom domain is already registered for this app.")
            }
            Self::VerificationFailed(msg) => write!(f, "DNS verification failed: {msg}"),
            Self::DomainNotVerified(msg) => write!(f, "Domain is not verified: {msg}"),
            Self::NoPreviousDeployment => {
                write!(f, "No previous deployment found to restore on rollback.")
            }
            Self::InvalidMetadata(msg) => write!(f, "Invalid deployment metadata: {msg}"),
            Self::Forbidden => write!(f, "Permission denied for this operation."),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::DnsError(msg) => write!(f, "DNS resolution error: {msg}"),
            Self::CaddyError(msg) => write!(f, "Caddy proxy error: {msg}"),
            Self::StorageError(msg) => write!(f, "Object storage error: {msg}"),
            Self::OrmError(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for WebHostingError {}

impl From<OrmError> for WebHostingError {
    fn from(err: OrmError) -> Self {
        Self::OrmError(err.to_string())
    }
}

impl From<StorageError> for WebHostingError {
    fn from(err: StorageError) -> Self {
        Self::StorageError(err.to_string())
    }
}

impl From<DnsError> for WebHostingError {
    fn from(err: DnsError) -> Self {
        Self::DnsError(err.to_string())
    }
}

impl From<CaddyError> for WebHostingError {
    fn from(err: CaddyError) -> Self {
        Self::CaddyError(err.to_string())
    }
}

impl From<WebHostingError> for DjangorsError {
    fn from(err: WebHostingError) -> Self {
        match &err {
            WebHostingError::DeploymentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "deployment_not_found",
                "Web deployment not found.",
            ),
            WebHostingError::DomainNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "domain_not_found",
                "Custom domain not found.",
            ),
            WebHostingError::AppNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "app_not_found",
                "Application not found.",
            ),
            WebHostingError::ProjectNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "project_not_found",
                "Project not found.",
            ),
            WebHostingError::EnvironmentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "environment_not_found",
                "Environment not found.",
            ),
            WebHostingError::ArtifactNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "artifact_not_found",
                "Artifact not found.",
            ),
            WebHostingError::InvalidArtifactKind => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_artifact_kind",
                "Artifact must be a web bundle ('web_bundle').",
            ),
            WebHostingError::ReleaseNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "release_not_found",
                "Release not found.",
            ),
            WebHostingError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization not found.",
            ),
            WebHostingError::InvalidTarget => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_target",
                "Invalid target. Allowed values: 'preview', 'production'.",
            ),
            WebHostingError::InvalidStatus => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_status",
                "Invalid deployment status transition.",
            ),
            WebHostingError::InvalidDomain => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_domain",
                "Invalid domain format.",
            ),
            WebHostingError::DomainAlreadyExists => DjangorsError::api(
                StatusCode::CONFLICT,
                "domain_already_exists",
                "This custom domain is already registered for this app.",
            ),
            WebHostingError::VerificationFailed(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "verification_failed", msg.clone())
            }
            WebHostingError::DomainNotVerified(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "domain_not_verified", msg.clone())
            }
            WebHostingError::NoPreviousDeployment => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "no_previous_deployment",
                "No previous deployment found to restore on rollback.",
            ),
            WebHostingError::InvalidMetadata(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_metadata",
                format!("Invalid metadata: {msg}"),
            ),
            WebHostingError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            WebHostingError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg.clone())
            }
            WebHostingError::DnsError(msg) => {
                DjangorsError::api(StatusCode::BAD_GATEWAY, "dns_error", msg.clone())
            }
            WebHostingError::CaddyError(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "caddy_error",
                msg.clone(),
            ),
            WebHostingError::StorageError(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "storage_error",
                msg.clone(),
            ),
            WebHostingError::OrmError(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database_error",
                msg.clone(),
            ),
        }
    }
}
