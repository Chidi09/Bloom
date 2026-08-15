//! Persistence models for the `credentials` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// Platform API credentials vault: Apple App Store Connect, Google Play,
/// Shorebird, GitHub, GitLab, Bitbucket.
#[derive(Model, Debug, Clone)]
#[djangors(app = "credentials", table_name = "credentials_credential")]
pub struct Credential {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key pointing to `organizations_organization.id`.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: djangors_orm::ForeignKey<crate::apps::organizations::models::Organization>,

    /// Provider identifier: `apple`, `google_play`, `shorebird`, `github`, `gitlab`, `bitbucket`.
    #[djangors(max_length = 32)]
    pub provider: String,

    /// Human-readable label for this credential.
    #[djangors(max_length = 255)]
    pub name: String,

    /// Ciphertext encrypted with AES-256-GCM envelope encryption.
    pub encrypted_token: String,

    /// Non-secret provider metadata serialized as JSON string.
    pub metadata: String,

    /// Optional expiration timestamp.
    #[djangors(nullable)]
    pub expires_at: Option<DateTime<Utc>>,

    /// Timestamp of last successful usage.
    #[djangors(nullable)]
    pub last_used_at: Option<DateTime<Utc>>,

    /// User ID of creator (`auth_user.id`).
    pub created_by_id: i64,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for Credential {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
