//! Request and response data contracts for the `credentials` app.

use serde::{Deserialize, Serialize};

/// Non-secret provider-specific metadata.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "provider", rename_all = "snake_case")]
pub enum CredentialMetadata {
    /// Apple App Store Connect API Key metadata.
    #[serde(rename = "apple")]
    Apple {
        key_id: String,
        issuer_id: String,
        team_id: String,
    },
    /// Google Play Console API service account metadata.
    #[serde(rename = "google_play")]
    GooglePlay { client_email: String },
    /// Shorebird CodePush app metadata.
    #[serde(rename = "shorebird")]
    Shorebird { app_id: String },
    /// GitHub App installation metadata.
    #[serde(rename = "github")]
    GitHub { installation_id: String },
    /// GitLab application metadata.
    #[serde(rename = "gitlab")]
    GitLab { application_id: String },
    /// Bitbucket workspace metadata.
    #[serde(rename = "bitbucket")]
    Bitbucket { workspace: String },
}

/// Request payload to create a new credential vault record.
#[derive(Debug, Clone, Deserialize)]
pub struct CredentialCreateRequest {
    /// Provider identifier: `apple`, `google_play`, `shorebird`, `github`, `gitlab`, `bitbucket`.
    pub provider: String,
    /// Human-readable label for this credential.
    pub name: String,
    /// Plaintext token or private key string to encrypt.
    pub token: String,
    /// Non-secret structured metadata for this provider.
    pub metadata: CredentialMetadata,
    /// Optional ISO-8601 expiration timestamp.
    #[serde(default)]
    pub expires_at: Option<String>,
}

/// Response payload representing a stored credential (metadata-only, never secret).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CredentialResponse {
    /// Public UUID identifier.
    pub id: String,
    /// Public UUID of the owning organization.
    pub organization_id: String,
    /// Provider identifier.
    pub provider: String,
    /// Human-readable label.
    pub name: String,
    /// Non-secret metadata JSON value.
    pub metadata: serde_json::Value,
    /// Optional ISO-8601 expiration timestamp.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expires_at: Option<String>,
    /// Optional ISO-8601 last-used timestamp.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_used_at: Option<String>,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}

/// Response payload returned after successfully validating/testing a credential connection.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CredentialTestResponse {
    /// Public UUID of the tested credential.
    pub id: String,
    /// Provider name.
    pub provider: String,
    /// Whether connection test was successful.
    pub success: bool,
    /// Descriptive status message (without leaking secrets).
    pub message: String,
}
