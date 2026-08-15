//! Application exceptions and HTTP error translations for the `accounts` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain failures for account operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AccountError {
    /// Provided email is already in use.
    EmailTaken,
    /// Provided username is already in use.
    UsernameTaken,
    /// Invalid username, password, or inactive account.
    InvalidCredentials,
    /// Device code or user code does not exist.
    DeviceCodeNotFound,
    /// Device flow session expired.
    DeviceCodeExpired,
    /// Device code exists but user has not yet authorized it in the browser.
    AuthorizationPending,
    /// Password does not meet security requirements (< 8 characters).
    WeakPassword,
    /// Caller is not authorized for this resource or operation.
    Forbidden,
    /// Requested record not found.
    NotFound(&'static str),
    /// Underlying database or persistence error.
    Database(String),
}

impl std::fmt::Display for AccountError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EmailTaken => write!(f, "An account with this email already exists."),
            Self::UsernameTaken => write!(f, "An account with this username already exists."),
            Self::InvalidCredentials => write!(f, "Invalid username or password."),
            Self::DeviceCodeNotFound => write!(f, "Device flow request was not found."),
            Self::DeviceCodeExpired => write!(f, "Device code has expired."),
            Self::AuthorizationPending => write!(f, "Authorization is pending."),
            Self::WeakPassword => write!(f, "Password must be at least 8 characters."),
            Self::Forbidden => write!(f, "You do not have permission to perform this action."),
            Self::NotFound(resource) => write!(f, "No {resource} was found."),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for AccountError {}

impl From<AccountError> for DjangorsError {
    fn from(error: AccountError) -> Self {
        match error {
            AccountError::EmailTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "email_taken",
                "An account with this email already exists.",
            ),
            AccountError::UsernameTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "username_taken",
                "An account with this username already exists.",
            ),
            AccountError::InvalidCredentials => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Invalid username or password.",
            ),
            AccountError::DeviceCodeNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "device_code_not_found",
                "Device flow request was not found.",
            ),
            AccountError::DeviceCodeExpired => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "device_code_expired",
                "Device code has expired.",
            ),
            AccountError::AuthorizationPending => DjangorsError::api(
                StatusCode::ACCEPTED,
                "authorization_pending",
                "Authorization is pending.",
            ),
            AccountError::WeakPassword => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "weak_password",
                "Password must be at least 8 characters.",
            ),
            AccountError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            AccountError::NotFound(resource) => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "not_found",
                format!("{resource} was not found"),
            ),
            AccountError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for AccountError {
    fn from(err: djangors_orm::OrmError) -> Self {
        AccountError::Database(err.to_string())
    }
}

impl From<djangors_auth::AuthError> for AccountError {
    fn from(err: djangors_auth::AuthError) -> Self {
        match err {
            djangors_auth::AuthError::Database(e) => AccountError::Database(e.to_string()),
            djangors_auth::AuthError::Hashing(e) => AccountError::Database(e),
            _ => AccountError::InvalidCredentials,
        }
    }
}
