//! Domain error definitions and HTTP error translations for `secrets`.

use djangors_core::{DjangorsError, StatusCode};

use crate::infra::crypto::CryptoError;

/// Domain error variants for secrets operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SecretError {
    /// Secret record not found by ID or key.
    SecretNotFound,

    /// Target secret version record not found for rollback.
    VersionNotFound,

    /// Referenced environment does not exist.
    EnvironmentNotFound,

    /// Referenced organization does not exist.
    OrganizationNotFound,

    /// No organization context was provided in request.
    OrganizationRequired,

    /// User role does not satisfy the required permission level.
    InsufficientRole,

    /// User is not a member of the organization or access is denied.
    Forbidden,

    /// Request is unauthenticated.
    Unauthorized,

    /// Key format is invalid (must be alphanumeric/underscore, no leading digit, max 255 chars).
    InvalidKeyFormat(String),

    /// Secret value was flagged as JSON but could not be parsed as valid JSON.
    InvalidJsonValue(String),

    /// Cryptographic encryption or decryption failed.
    Crypto(String),

    /// General validation failure.
    ValidationError(String),

    /// Underlying database or ORM error.
    Database(String),

    /// Invalid or mismatched worker job token.
    InvalidJobToken(String),
}

impl std::fmt::Display for SecretError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SecretNotFound => write!(f, "Secret was not found."),
            Self::VersionNotFound => write!(f, "Specified secret version was not found."),
            Self::EnvironmentNotFound => write!(f, "Environment was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::OrganizationRequired => write!(f, "An organization context is required."),
            Self::InsufficientRole => write!(
                f,
                "Your role in this organization does not permit this action."
            ),
            Self::Forbidden => write!(f, "You do not have permission to perform this action."),
            Self::Unauthorized => write!(f, "Authentication is required."),
            Self::InvalidKeyFormat(msg) => write!(f, "Invalid secret key format: {msg}"),
            Self::InvalidJsonValue(msg) => write!(f, "Invalid JSON value: {msg}"),
            Self::Crypto(msg) => write!(f, "Cryptographic operation failed: {msg}"),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
            Self::InvalidJobToken(msg) => write!(f, "Invalid worker job token: {msg}"),
        }
    }
}

impl std::error::Error for SecretError {}

impl From<SecretError> for DjangorsError {
    fn from(err: SecretError) -> Self {
        match err {
            SecretError::SecretNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "secret_not_found",
                "Secret was not found.",
            ),
            SecretError::VersionNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "version_not_found",
                "Specified secret version was not found.",
            ),
            SecretError::EnvironmentNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "environment_not_found",
                "Environment was not found.",
            ),
            SecretError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            SecretError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "An organization context is required.",
            ),
            SecretError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "Your role in this organization does not permit this action.",
            ),
            SecretError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to access this resource.",
            ),
            SecretError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication is required.",
            ),
            SecretError::InvalidKeyFormat(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_key_format",
                format!("Invalid secret key format: {msg}"),
            ),
            SecretError::InvalidJsonValue(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_json_value",
                format!("Secret value must be valid JSON: {msg}"),
            ),
            SecretError::Crypto(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "crypto_error",
                format!("Cryptographic error: {msg}"),
            ),
            SecretError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            SecretError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
            SecretError::InvalidJobToken(msg) => {
                DjangorsError::api(StatusCode::UNAUTHORIZED, "invalid_job_token", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for SecretError {
    fn from(err: djangors_orm::OrmError) -> Self {
        SecretError::Database(err.to_string())
    }
}

impl From<CryptoError> for SecretError {
    fn from(err: CryptoError) -> Self {
        SecretError::Crypto(err.to_string())
    }
}
