//! Persistence models for the `signing` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// Encrypted signing material storage: Android keystores, iOS certificates,
/// provisioning profiles, and App Store Connect API keys.
#[derive(Model, Debug, Clone)]
#[djangors(app = "signing", table_name = "signing_signingidentity")]
pub struct SigningIdentity {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key pointing to `organizations_organization.id`.
    #[djangors(foreign_key(on_delete = "cascade"))]
    pub organization_id: djangors_orm::ForeignKey<crate::apps::organizations::models::Organization>,

    /// Platform target: `android` or `ios`.
    #[djangors(max_length = 32)]
    pub platform: String,

    /// Human-readable label for this signing identity.
    #[djangors(max_length = 255)]
    pub name: String,

    /// Material kind: `keystore`, `certificate`, `provisioning_profile`, or `api_key`.
    #[djangors(max_length = 32)]
    pub kind: String,

    /// Ciphertext encrypted with AES-256-GCM envelope encryption.
    pub encrypted_material: String,

    /// JSON metadata storing fingerprints, bundle IDs, expiry, team ID, etc.
    #[djangors(default = "{}")]
    pub metadata: String,

    /// Optional expiration timestamp.
    #[djangors(nullable)]
    pub expires_at: Option<DateTime<Utc>>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

impl Scoped for SigningIdentity {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
