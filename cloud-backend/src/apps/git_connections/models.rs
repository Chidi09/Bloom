//! Persistence models for the `git_connections` domain app.

use std::fmt;

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// Git provider OAuth or GitHub App connection belonging to an organization.
#[derive(Model, Clone)]
#[djangors(app = "git_connections", table_name = "git_connections_gitconnection")]
pub struct GitConnection {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Owning organization relation.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: djangors_orm::ForeignKey<crate::apps::organizations::models::Organization>,

    /// Git provider identifier: `github`, `gitlab`, `bitbucket`.
    #[djangors(max_length = 32)]
    pub provider: String,

    /// External App or installation ID provided by the Git host.
    #[djangors(max_length = 255)]
    pub installation_id: String,

    /// Access token encrypted via AES-256-GCM envelope encryption.
    pub encrypted_access_token: String,

    /// Provider metadata serialized as JSON string.
    #[djangors(default = "{}")]
    pub metadata: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

// Redact encrypted access token in Debug representations to prevent secret leakage in logs.
impl fmt::Debug for GitConnection {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("GitConnection")
            .field("id", &self.id)
            .field("public_id", &self.public_id)
            .field("organization_id", &self.organization_id.id)
            .field("provider", &self.provider)
            .field("installation_id", &self.installation_id)
            .field("encrypted_access_token", &"[REDACTED]")
            .field("metadata", &self.metadata)
            .field("created_at", &self.created_at)
            .field("updated_at", &self.updated_at)
            .finish()
    }
}

impl Scoped for GitConnection {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// Webhook delivery record used for idempotency and delivery tracking.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "git_connections",
    table_name = "git_connections_webhookdelivery"
)]
pub struct WebhookDelivery {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Provider sending the webhook: `github`, `gitlab`, `bitbucket`.
    #[djangors(max_length = 32)]
    pub provider: String,

    /// Unique delivery GUID from provider header (e.g. `X-GitHub-Delivery`).
    #[djangors(max_length = 255)]
    pub delivery_id: String,

    /// Event name from provider header (e.g. `push`, `pull_request`, `ping`).
    #[djangors(max_length = 64)]
    pub event_type: String,

    /// Raw webhook payload text.
    #[djangors(default = "{}")]
    pub payload: String,

    /// Lifecycle status of delivery: `received`, `processed`, `ignored`, `failed`.
    #[djangors(max_length = 32, default = "received")]
    pub status: String,

    /// Timestamp of receipt.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}
