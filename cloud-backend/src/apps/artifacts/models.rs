//! Persistence models for the `artifacts` domain app.

use chrono::{DateTime, Utc};
use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_macros::Model;
use djangors_orm::QuerySet;
use djangors_rest::Scoped;

/// A build artifact (IPA, AAB, APK, web bundle, dSYM, source map, mapping, or log)
/// stored privately in object storage and downloadable via short-lived presigned URLs.
///
/// Artifact bytes never live in the database; only metadata and the canonical storage
/// key (built with `crate::infra::storage::artifact_storage_key`) are persisted here.
#[derive(Model, Debug, Clone)]
#[djangors(app = "artifacts", table_name = "artifacts_artifact")]
pub struct Artifact {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key referencing the parent build's internal primary key.
    ///
    /// NOTE: the `builds` app lands in the same phase (parallel dispatch). Once it does
    /// this should become `ForeignKey<crate::apps::builds::models::Build>`; it is stored
    /// as a plain `i64` today so this model compiles before that app exists.
    #[djangors(db_index)]
    pub build_id: i64,

    /// Denormalized foreign key referencing the tenant organization for direct scoping.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Target platform: `android`, `ios`, or `web`.
    #[djangors(max_length = 32)]
    pub platform: String,

    /// Artifact kind: `ipa`, `aab`, `apk`, `web_bundle`, `dsym`, `source_map`, `mapping`, or `log`.
    #[djangors(max_length = 32)]
    pub kind: String,

    /// Canonical object-storage key built via `crate::infra::storage::artifact_storage_key`.
    #[djangors(max_length = 500)]
    pub storage_key: String,

    /// Name of the storage bucket holding the object.
    #[djangors(max_length = 255)]
    pub storage_bucket: String,

    /// Original uploaded file name.
    #[djangors(max_length = 255)]
    pub file_name: String,

    /// Object size in bytes.
    pub file_size: i64,

    /// SHA-256 hex digest of the artifact bytes.
    #[djangors(max_length = 64)]
    pub checksum: String,

    /// Application version this artifact was built from.
    #[djangors(max_length = 64)]
    pub version: String,

    /// Integer build number.
    pub build_number: i64,

    /// JSON text holding worker-provided artifact metadata (e.g. code signing, Dart SDK).
    pub metadata: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

impl Scoped for Artifact {
    fn scope(req: &Request, qs: QuerySet<Self>) -> Result<QuerySet<Self>, DjangorsError> {
        crate::apps::common::scoping::organization_scope(req, qs, "organization_id")
    }
}
