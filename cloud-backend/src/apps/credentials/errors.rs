//! Application errors and HTTP status mappings for the `credentials` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions that can arise during credential vault operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CredentialError {
    /// Credential was not found by public ID within the active organization.
    CredentialNotFound,
    /// Credential name is already in use within the organization for this provider.
    NameTaken,
    /// Unsupported provider requested.
    InvalidProvider(String),
    /// Metadata shape does not match requested provider.
    InvalidMetadata(String),
    /// Token/Secret value is empty or invalid.
    InvalidToken(String),
    /// Cryptographic encryption or decryption failed.
    Crypto(String),
    /// Remote validation or connection test failed.
    ValidationFailed(String),
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

impl std::fmt::Display for CredentialError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::CredentialNotFound => write!(f, "Credential was not found."),
            Self::NameTaken => write!(
                f,
                "A credential with this name already exists in this organization."
            ),
            Self::InvalidProvider(p) => {
                write!(f, "Unsupported or invalid credential provider: {p}")
            }
            Self::InvalidMetadata(msg) => write!(f, "Invalid credential metadata: {msg}"),
            Self::InvalidToken(msg) => write!(f, "Invalid token: {msg}"),
            Self::Crypto(msg) => write!(f, "Cryptographic operation failed: {msg}"),
            Self::ValidationFailed(msg) => write!(f, "Credential validation test failed: {msg}"),
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

impl std::error::Error for CredentialError {}

impl From<CredentialError> for DjangorsError {
    fn from(error: CredentialError) -> Self {
        match error {
            CredentialError::CredentialNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "credential_not_found",
                "Credential was not found.",
            ),
            CredentialError::NameTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "name_taken",
                "A credential with this name already exists in this organization.",
            ),
            CredentialError::InvalidProvider(p) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_provider",
                format!("Unsupported or invalid credential provider: {p}"),
            ),
            CredentialError::InvalidMetadata(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_metadata",
                format!("Invalid credential metadata: {msg}"),
            ),
            CredentialError::InvalidToken(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_token",
                format!("Invalid token: {msg}"),
            ),
            CredentialError::Crypto(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "crypto_error",
                format!("Cryptographic error: {msg}"),
            ),
            CredentialError::ValidationFailed(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "validation_failed",
                format!("Credential test failed: {msg}"),
            ),
            CredentialError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            CredentialError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            CredentialError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "You do not have sufficient permissions to perform this action.",
            ),
            CredentialError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            CredentialError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication credentials were not provided or are invalid.",
            ),
            CredentialError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            CredentialError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for CredentialError {
    fn from(err: djangors_orm::OrmError) -> Self {
        CredentialError::Database(err.to_string())
    }
}

impl From<crate::infra::crypto::CryptoError> for CredentialError {
    fn from(err: crate::infra::crypto::CryptoError) -> Self {
        CredentialError::Crypto(err.to_string())
    }
}

impl From<crate::apps::organizations::errors::OrganizationError> for CredentialError {
    fn from(err: crate::apps::organizations::errors::OrganizationError) -> Self {
        match err {
            crate::apps::organizations::errors::OrganizationError::OrganizationNotFound => {
                CredentialError::OrganizationNotFound
            }
            crate::apps::organizations::errors::OrganizationError::InsufficientRole => {
                CredentialError::InsufficientRole
            }
            crate::apps::organizations::errors::OrganizationError::Unauthorized => {
                CredentialError::Unauthorized
            }
            crate::apps::organizations::errors::OrganizationError::Forbidden => {
                CredentialError::Forbidden
            }
            crate::apps::organizations::errors::OrganizationError::ValidationError(msg) => {
                CredentialError::ValidationError(msg)
            }
            crate::apps::organizations::errors::OrganizationError::Database(msg) => {
                CredentialError::Database(msg)
            }
            other => CredentialError::Database(other.to_string()),
        }
    }
}
