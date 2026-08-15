//! Application errors and HTTP status mappings for the `signing` app.

use djangors_core::{DjangorsError, StatusCode};

use crate::infra::crypto::CryptoError;

/// Domain error conditions for signing operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SigningError {
    /// Signing identity record not found.
    SigningIdentityNotFound,

    /// Organization was not found.
    OrganizationNotFound,

    /// No organization context was provided in the request.
    OrganizationRequired,

    /// Caller's role is insufficient for this operation.
    InsufficientRole,

    /// Caller is unauthenticated.
    Unauthorized,

    /// Caller is forbidden from accessing this resource.
    Forbidden,

    /// Invalid platform specified (must be `android` or `ios`).
    InvalidPlatform(String),

    /// Invalid kind specified (must be `keystore`, `certificate`, `provisioning_profile`, or `api_key`).
    InvalidKind(String),

    /// Metadata kind does not match the kind field.
    MetadataMismatch(String),

    /// Base64 material is empty or invalid.
    InvalidMaterial(String),

    /// Expiry date format is invalid.
    InvalidExpiryDate(String),

    /// Validation error for fields.
    ValidationError(String),

    /// Cryptographic encryption or decryption failed.
    Crypto(String),

    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for SigningError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SigningIdentityNotFound => write!(f, "Signing identity was not found."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::OrganizationRequired => write!(f, "An organization context is required."),
            Self::InsufficientRole => {
                write!(
                    f,
                    "You do not have sufficient permissions to perform this action."
                )
            }
            Self::Unauthorized => {
                write!(
                    f,
                    "Authentication credentials were not provided or are invalid."
                )
            }
            Self::Forbidden => write!(f, "You do not have permission to access this resource."),
            Self::InvalidPlatform(msg) => write!(f, "Invalid platform: {msg}"),
            Self::InvalidKind(msg) => write!(f, "Invalid signing kind: {msg}"),
            Self::MetadataMismatch(msg) => write!(f, "Metadata mismatch: {msg}"),
            Self::InvalidMaterial(msg) => write!(f, "Invalid signing material: {msg}"),
            Self::InvalidExpiryDate(msg) => write!(f, "Invalid expiry date: {msg}"),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Crypto(msg) => write!(f, "Cryptographic operation failed: {msg}"),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for SigningError {}

impl From<SigningError> for DjangorsError {
    fn from(error: SigningError) -> Self {
        match error {
            SigningError::SigningIdentityNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "signing_identity_not_found",
                "Signing identity was not found.",
            ),
            SigningError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            SigningError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            SigningError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "You do not have sufficient permissions to perform this action.",
            ),
            SigningError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication credentials were not provided or are invalid.",
            ),
            SigningError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            SigningError::InvalidPlatform(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_platform", msg)
            }
            SigningError::InvalidKind(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_kind", msg)
            }
            SigningError::MetadataMismatch(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "metadata_mismatch", msg)
            }
            SigningError::InvalidMaterial(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_material", msg)
            }
            SigningError::InvalidExpiryDate(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_expiry_date", msg)
            }
            SigningError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            SigningError::Crypto(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "cryptographic_error",
                msg,
            ),
            SigningError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for SigningError {
    fn from(err: djangors_orm::OrmError) -> Self {
        SigningError::Database(err.to_string())
    }
}

impl From<CryptoError> for SigningError {
    fn from(err: CryptoError) -> Self {
        SigningError::Crypto(err.to_string())
    }
}

impl From<crate::apps::organizations::errors::OrganizationError> for SigningError {
    fn from(err: crate::apps::organizations::errors::OrganizationError) -> Self {
        match err {
            crate::apps::organizations::errors::OrganizationError::OrganizationNotFound => {
                SigningError::OrganizationNotFound
            }
            crate::apps::organizations::errors::OrganizationError::InsufficientRole => {
                SigningError::InsufficientRole
            }
            crate::apps::organizations::errors::OrganizationError::Unauthorized => {
                SigningError::Unauthorized
            }
            crate::apps::organizations::errors::OrganizationError::Forbidden => {
                SigningError::Forbidden
            }
            crate::apps::organizations::errors::OrganizationError::ValidationError(msg) => {
                SigningError::ValidationError(msg)
            }
            crate::apps::organizations::errors::OrganizationError::Database(msg) => {
                SigningError::Database(msg)
            }
            other => SigningError::Database(other.to_string()),
        }
    }
}
