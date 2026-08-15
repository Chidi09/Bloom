//! Application errors and HTTP status mappings for the `git_connections` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions that can arise during Git connection and webhook operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GitConnectionError {
    /// Git connection was not found by public ID within the active organization.
    ConnectionNotFound,
    /// A Git connection for this provider and installation already exists in this organization.
    ConnectionAlreadyExists,
    /// Unsupported Git provider requested.
    InvalidProvider(String),
    /// Installation ID is invalid or empty.
    InvalidInstallationId(String),
    /// Access token is invalid or empty.
    InvalidToken(String),
    /// Webhook HMAC signature verification failed.
    InvalidSignature,
    /// Webhook signature header is missing.
    MissingSignature,
    /// Webhook shared signing secret is not configured.
    MissingSecret,
    /// Webhook signature format is invalid.
    InvalidSignatureFormat,
    /// Webhook signature scheme for this provider is unverified and rejected for security.
    UnverifiedProviderSignature(String),
    /// Webhook delivery ID header is missing.
    MissingDeliveryId,
    /// Webhook JSON payload is malformed or invalid.
    InvalidPayload(String),
    /// Cryptographic encryption or decryption failed.
    Crypto(String),
    /// Provider remote API error.
    RemoteApi(String),
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

impl std::fmt::Display for GitConnectionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ConnectionNotFound => write!(f, "Git connection was not found."),
            Self::ConnectionAlreadyExists => {
                write!(
                    f,
                    "A Git connection for this provider and installation already exists."
                )
            }
            Self::InvalidProvider(p) => write!(f, "Unsupported Git provider: {p}"),
            Self::InvalidInstallationId(msg) => write!(f, "Invalid installation ID: {msg}"),
            Self::InvalidToken(msg) => write!(f, "Invalid access token: {msg}"),
            Self::InvalidSignature => write!(f, "Webhook signature verification failed."),
            Self::MissingSignature => write!(f, "Missing webhook signature header."),
            Self::MissingSecret => write!(f, "Webhook signing secret is not configured."),
            Self::InvalidSignatureFormat => write!(
                f,
                "Invalid webhook signature format; expected 'sha256=<hex>'."
            ),
            Self::UnverifiedProviderSignature(provider) => {
                write!(
                    f,
                    "Webhook signature verification for '{provider}' is unverified."
                )
            }
            Self::MissingDeliveryId => write!(f, "Missing webhook delivery ID header."),
            Self::InvalidPayload(msg) => write!(f, "Invalid webhook payload: {msg}"),
            Self::Crypto(msg) => write!(f, "Cryptographic operation failed: {msg}"),
            Self::RemoteApi(msg) => write!(f, "Git provider API error: {msg}"),
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

impl std::error::Error for GitConnectionError {}

impl From<GitConnectionError> for DjangorsError {
    fn from(error: GitConnectionError) -> Self {
        match error {
            GitConnectionError::ConnectionNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "connection_not_found",
                "Git connection was not found.",
            ),
            GitConnectionError::ConnectionAlreadyExists => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "connection_already_exists",
                "A Git connection for this provider and installation already exists.",
            ),
            GitConnectionError::InvalidProvider(p) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_provider",
                format!("Unsupported Git provider: {p}"),
            ),
            GitConnectionError::InvalidInstallationId(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_installation_id",
                format!("Invalid installation ID: {msg}"),
            ),
            GitConnectionError::InvalidToken(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_token",
                format!("Invalid access token: {msg}"),
            ),
            GitConnectionError::InvalidSignature => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_signature",
                "Webhook signature verification failed.",
            ),
            GitConnectionError::MissingSignature => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "missing_signature",
                "Missing webhook signature header.",
            ),
            GitConnectionError::MissingSecret => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "missing_secret",
                "Webhook signing secret is not configured.",
            ),
            GitConnectionError::InvalidSignatureFormat => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_signature_format",
                "Invalid webhook signature format; expected 'sha256=<hex>'.",
            ),
            GitConnectionError::UnverifiedProviderSignature(provider) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "unverified_provider_signature",
                format!("Webhook signature verification for '{provider}' is unverified."),
            ),
            GitConnectionError::MissingDeliveryId => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "missing_delivery_id",
                "Missing webhook delivery ID header.",
            ),
            GitConnectionError::InvalidPayload(msg) => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_payload",
                format!("Invalid webhook payload: {msg}"),
            ),
            GitConnectionError::Crypto(msg) => DjangorsError::api(
                StatusCode::INTERNAL_SERVER_ERROR,
                "crypto_error",
                format!("Cryptographic error: {msg}"),
            ),
            GitConnectionError::RemoteApi(msg) => DjangorsError::api(
                StatusCode::BAD_GATEWAY,
                "remote_api_error",
                format!("Git provider API error: {msg}"),
            ),
            GitConnectionError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            GitConnectionError::OrganizationRequired => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            ),
            GitConnectionError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "You do not have sufficient permissions to perform this action.",
            ),
            GitConnectionError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            GitConnectionError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication credentials were not provided or are invalid.",
            ),
            GitConnectionError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            GitConnectionError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for GitConnectionError {
    fn from(err: djangors_orm::OrmError) -> Self {
        GitConnectionError::Database(err.to_string())
    }
}

impl From<crate::infra::crypto::CryptoError> for GitConnectionError {
    fn from(err: crate::infra::crypto::CryptoError) -> Self {
        GitConnectionError::Crypto(err.to_string())
    }
}

impl From<crate::apps::organizations::errors::OrganizationError> for GitConnectionError {
    fn from(err: crate::apps::organizations::errors::OrganizationError) -> Self {
        match err {
            crate::apps::organizations::errors::OrganizationError::OrganizationNotFound => {
                GitConnectionError::OrganizationNotFound
            }
            crate::apps::organizations::errors::OrganizationError::InsufficientRole => {
                GitConnectionError::InsufficientRole
            }
            crate::apps::organizations::errors::OrganizationError::Unauthorized => {
                GitConnectionError::Unauthorized
            }
            crate::apps::organizations::errors::OrganizationError::Forbidden => {
                GitConnectionError::Forbidden
            }
            crate::apps::organizations::errors::OrganizationError::ValidationError(msg) => {
                GitConnectionError::ValidationError(msg)
            }
            crate::apps::organizations::errors::OrganizationError::Database(msg) => {
                GitConnectionError::Database(msg)
            }
            other => GitConnectionError::Database(other.to_string()),
        }
    }
}
