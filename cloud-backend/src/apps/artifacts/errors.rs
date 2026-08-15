//! Domain errors and HTTP status mappings for the `artifacts` app.

use djangors_core::{DjangorsError, StatusCode};

use crate::infra::storage::StorageError;

/// Domain error conditions for artifact entity operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ArtifactError {
    /// Artifact was not found by public ID within the scoped organization.
    ArtifactNotFound,
    /// Parent build referenced by public ID was not found or does not belong to the organization.
    BuildNotFound,
    /// Application referenced by the parent build was not found.
    AppNotFound,
    /// Project referenced by the application was not found.
    ProjectNotFound,
    /// Organization referenced by the request was not found.
    OrganizationNotFound,
    /// Platform is invalid (must be `android`, `ios`, or `web`).
    InvalidPlatform,
    /// Artifact kind is invalid.
    InvalidKind,
    /// `metadata` is not valid JSON.
    InvalidMetadata(String),
    /// The artifact object was not confirmed present in storage before registering metadata.
    UploadNotConfirmed,
    /// Object-storage operation failed.
    Storage(String),
    /// Invalid or missing worker job token.
    InvalidJobToken,
    /// Caller lacks necessary permissions.
    Forbidden,
    /// Request validation failed.
    ValidationError(String),
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for ArtifactError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ArtifactNotFound => write!(f, "Artifact was not found."),
            Self::BuildNotFound => write!(f, "Build was not found."),
            Self::AppNotFound => write!(f, "App was not found."),
            Self::ProjectNotFound => write!(f, "Project was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::InvalidPlatform => write!(
                f,
                "Invalid platform. Allowed values: android, ios, web."
            ),
            Self::InvalidKind => write!(
                f,
                "Invalid artifact kind. Allowed values: ipa, aab, apk, web_bundle, dsym, source_map, mapping, log."
            ),
            Self::InvalidMetadata(msg) => write!(f, "Invalid artifact metadata: {msg}"),
            Self::UploadNotConfirmed => write!(
                f,
                "Artifact bytes were not confirmed present in storage before registering metadata."
            ),
            Self::Storage(msg) => write!(f, "Storage error: {msg}"),
            Self::InvalidJobToken => write!(f, "Invalid worker job token."),
            Self::Forbidden => {
                write!(f, "You do not have permission to perform this action.")
            }
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for ArtifactError {}

impl From<ArtifactError> for DjangorsError {
    fn from(error: ArtifactError) -> Self {
        match error {
            ArtifactError::ArtifactNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                "Artifact was not found.",
            ),
            ArtifactError::BuildNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "Build was not found.")
            }
            ArtifactError::AppNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "App was not found.")
            }
            ArtifactError::ProjectNotFound => {
                DjangorsError::api(StatusCode::NOT_FOUND, "not_found", "Project was not found.")
            }
            ArtifactError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            ArtifactError::InvalidPlatform => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_platform",
                "Invalid platform. Allowed values: android, ios, web.",
            ),
            ArtifactError::InvalidKind => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_kind",
                "Invalid artifact kind. Allowed values: ipa, aab, apk, web_bundle, dsym, source_map, mapping, log.",
            ),
            ArtifactError::InvalidMetadata(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_metadata",
                format!("Invalid artifact metadata: {msg}"),
            ),
            ArtifactError::UploadNotConfirmed => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "upload_not_confirmed",
                "Artifact bytes were not confirmed present in storage before registering metadata.",
            ),
            ArtifactError::Storage(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "storage_error",
                msg,
            ),
            ArtifactError::InvalidJobToken => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_job_token",
                "Invalid worker job token.",
            ),
            ArtifactError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            ArtifactError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            ArtifactError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for ArtifactError {
    fn from(err: djangors_orm::OrmError) -> Self {
        ArtifactError::Database(err.to_string())
    }
}

impl From<StorageError> for ArtifactError {
    fn from(err: StorageError) -> Self {
        ArtifactError::Storage(err.to_string())
    }
}
