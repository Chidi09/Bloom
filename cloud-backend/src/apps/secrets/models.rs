//! Persistence models for the `secrets` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::{ForeignKey, QuerySet};
use djangors_rest::Scoped;

/// A per-environment secret key-value pair with version tracking.
/// The `encrypted_value` field stores AES-256-GCM ciphertext.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "secrets",
    table_name = "secrets_secret",
    unique_together = [["environment_id", "key"]]
)]
pub struct Secret {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent environment.
    ///
    /// Declared as a real relation (not a bare `i64`) so the model metadata matches the
    /// `ON DELETE CASCADE` constraint the migration actually creates.
    #[djangors(db_index)]
    pub environment_id: ForeignKey<crate::apps::environments::models::Environment>,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: ForeignKey<crate::apps::organizations::models::Organization>,

    /// Secret key name (e.g. `DATABASE_URL`, `API_KEY`).
    #[djangors(max_length = 255)]
    pub key: String,

    /// AES-256-GCM encrypted ciphertext payload.
    pub encrypted_value: String,

    /// Whether the secret value is a JSON string payload.
    #[djangors(default = false)]
    pub is_json: bool,

    /// Monotonically increasing version number for change history.
    #[djangors(default = 1)]
    pub version: i64,

    /// ID of the user who created or updated the secret to this version.
    pub created_by_id: i64,

    /// Creation or update timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

impl Scoped for Secret {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}

/// Historical version record for an environment secret.
/// Allows auditing and rollback to earlier versions.
#[derive(Model, Debug, Clone)]
#[djangors(app = "secrets", table_name = "secrets_secretversion")]
pub struct SecretVersion {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// Foreign key referencing the parent secret.
    #[djangors(db_index)]
    pub secret_id: ForeignKey<Secret>,

    /// AES-256-GCM encrypted ciphertext payload for this historical version.
    pub encrypted_value: String,

    /// Version number of this snapshot.
    pub version: i64,

    /// ID of the user who created this version.
    pub created_by_id: i64,

    /// Timestamp when this version was created.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}
