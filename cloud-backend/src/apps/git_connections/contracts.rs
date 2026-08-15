//! Request and response data contracts for the `git_connections` app.

use std::fmt;

use serde::{Deserialize, Serialize};

/// Request payload to establish or link a Git provider connection.
#[derive(Clone, Deserialize)]
pub struct GitConnectionCreateRequest {
    /// Git provider: `github`, `gitlab`, `bitbucket`.
    pub provider: String,
    /// External App or installation ID provided by the host.
    pub installation_id: String,
    /// OAuth access token or installation token to encrypt and store.
    pub access_token: String,
    /// Optional metadata describing account name, repositories, or permissions.
    #[serde(default)]
    pub metadata: Option<serde_json::Value>,
}

// Redact access token in Debug representations to avoid accidental logging of inbound credentials.
impl fmt::Debug for GitConnectionCreateRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("GitConnectionCreateRequest")
            .field("provider", &self.provider)
            .field("installation_id", &self.installation_id)
            .field("access_token", &"[REDACTED]")
            .field("metadata", &self.metadata)
            .finish()
    }
}

/// Response payload representing a stored Git connection (secret redacted).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GitConnectionResponse {
    /// Public UUID identifier.
    pub id: String,
    /// Public UUID of the owning organization.
    pub organization_id: String,
    /// Provider identifier: `github`, `gitlab`, `bitbucket`.
    pub provider: String,
    /// External app/installation ID.
    pub installation_id: String,
    /// Non-secret metadata JSON value.
    pub metadata: serde_json::Value,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}

/// Response payload representing a repository available through a Git connection.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepositoryResponse {
    /// Repository identifier (provider-specific or public UUID).
    pub id: String,
    /// Full repository name including owner (e.g. `owner/repo`).
    pub full_name: String,
    /// Default branch name (e.g. `main` or `master`).
    pub default_branch: String,
    /// Repository web or clone URL.
    pub url: String,
}

/// Response returned to Git hosts upon webhook receipt.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WebhookResponse {
    /// Whether the webhook was received and processed successfully.
    pub success: bool,
    /// Status description.
    pub message: String,
    /// Delivery identifier if provided.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub delivery_id: Option<String>,
}
