//! HTTP contracts (request and response DTOs) for the `accounts` app.

use serde::{Deserialize, Serialize};

/// Registration request payload.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct RegisterRequest {
    /// User's email address.
    pub email: String,
    /// Desired unique username.
    pub username: String,
    /// Plaintext password (min 8 chars).
    pub password: String,
}

/// Login request payload.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct LoginRequest {
    /// Username for authentication.
    pub username: String,
    /// Plaintext password.
    pub password: String,
}

/// JWT token response payload returned after successful authentication or refresh.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TokenResponse {
    /// Bearer access token.
    pub access_token: String,
    /// Refresh token for renewing the access token.
    pub refresh_token: String,
    /// Token authorization scheme (e.g. "Bearer").
    pub token_type: String,
    /// Token lifespan in seconds (e.g. 3600).
    pub expires_in: i64,
}

/// Refresh token request payload.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct RefreshRequest {
    /// The refresh token previously issued.
    pub refresh_token: String,
}

/// Device-code flow initialization response returned to the CLI.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DeviceFlowInitResponse {
    /// Opaque device code held by the CLI.
    pub device_code: String,
    /// Short code displayed by the CLI for the user to enter in the browser.
    pub user_code: String,
    /// Web URL where the user enters the code.
    pub verification_uri: String,
    /// Lifetime of the code in seconds.
    pub expires_in: i64,
    /// Polling interval suggestion in seconds.
    pub interval: i64,
}

/// Device-code authorization request payload submitted from browser.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct DeviceAuthorizeRequest {
    /// User-entered verification code.
    pub user_code: String,
}

/// Response payload for `/api/v1/auth/me/`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MeResponse {
    /// Public UUID of the user profile.
    pub id: String,
    /// User's email address.
    pub email: String,
    /// User's username.
    pub username: String,
    /// Optional display name.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub display_name: Option<String>,
    /// Optional avatar URL.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
    /// Configured timezone.
    pub timezone: String,
}

/// API token creation request payload.
#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct ApiTokenCreateRequest {
    /// Human-friendly label/name for the token.
    pub name: String,
}

/// API token response representation.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ApiTokenResponse {
    /// Public UUID of the token.
    pub id: String,
    /// Token label.
    pub name: String,
    /// Raw secret token (only present upon initial creation).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub token: Option<String>,
    /// ISO 8601 timestamp of last usage.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_used_at: Option<String>,
    /// ISO 8601 timestamp of creation.
    pub created_at: String,
}
