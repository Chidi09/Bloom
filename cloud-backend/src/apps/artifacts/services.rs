//! Business logic, domain rules, and transactional workflows for `artifacts`.

use chrono::Utc;
use djangors_db::Database;
use std::time::Duration;
use uuid::Uuid;

use super::contracts::ArtifactRegisterRequest;
use super::errors::ArtifactError;
use super::models::Artifact;
use super::repositories::{self, BuildSummary, OrganizationSummary};
use crate::infra::storage::{artifact_storage_key, ObjectStorage};

/// Valid target platforms.
pub const VALID_PLATFORMS: &[&str] = &["android", "ios", "web"];

/// Valid artifact kinds.
pub const VALID_ARTIFACT_KINDS: &[&str] = &[
    "ipa",
    "aab",
    "apk",
    "web_bundle",
    "dsym",
    "source_map",
    "mapping",
    "log",
];

/// Validate that a platform is one of `android`, `ios`, or `web`.
pub fn validate_platform(platform: &str) -> Result<(), ArtifactError> {
    if VALID_PLATFORMS.contains(&platform) {
        Ok(())
    } else {
        Err(ArtifactError::InvalidPlatform)
    }
}

/// Validate that a kind is one of the known artifact kinds.
pub fn validate_kind(kind: &str) -> Result<(), ArtifactError> {
    if VALID_ARTIFACT_KINDS.contains(&kind) {
        Ok(())
    } else {
        Err(ArtifactError::InvalidKind)
    }
}

/// Builds the canonical object-storage key for an artifact.
///
/// Delegates to `crate::infra::storage::artifact_storage_key`; kept as the single
/// construction point used by [`register_artifact`] so the key layout is testable.
pub fn build_artifact_storage_key(
    org_public_id: &str,
    project_public_id: &str,
    app_public_id: &str,
    build_public_id: &str,
    artifact_public_id: &str,
    file_name: &str,
) -> String {
    artifact_storage_key(
        org_public_id,
        project_public_id,
        app_public_id,
        build_public_id,
        artifact_public_id,
        file_name,
    )
}

/// Emits an event to the events log.
///
/// Delegates to the `events` app's public service interface, which swallows and logs any
/// recording failure so that emitting an event never fails this app's own write.
pub async fn emit_event(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) {
    crate::apps::events::emit(
        db,
        event_type,
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload,
    )
    .await;
}

/// Returns `true` when the artifact belongs to `organization_id`.
pub fn artifact_belongs_to_org(artifact: &Artifact, organization_id: i64) -> bool {
    artifact.organization_id == organization_id
}

/// Generates a short-lived presigned GET URL for a private artifact.
///
/// The default TTL is 15 minutes (see `crate::infra::storage::DEFAULT_PRESIGNED_EXPIRY`);
/// callers may pass an explicit `expires_in`. The artifact bytes stay private: this
/// never returns a bare bucket URL or the raw storage key as a download link.
pub async fn presigned_download_url(
    storage: &dyn ObjectStorage,
    artifact: &Artifact,
    expires_in: Duration,
) -> Result<String, ArtifactError> {
    storage
        .presigned_url(&artifact.storage_key, expires_in)
        .await
        .map_err(ArtifactError::from)
}

/// Generates a presigned download URL for an artifact, refusing when the artifact does
/// not belong to `organization_id` (cross-organization downloads are forbidden).
pub async fn artifact_download_url(
    storage: &dyn ObjectStorage,
    artifact: &Artifact,
    organization_id: i64,
    expires_in: Duration,
) -> Result<String, ArtifactError> {
    if !artifact_belongs_to_org(artifact, organization_id) {
        return Err(ArtifactError::ArtifactNotFound);
    }
    presigned_download_url(storage, artifact, expires_in).await
}

/// Registers artifact metadata after confirming the bytes exist in object storage.
///
/// Worker endpoint. Resolves the build/app/project/org public identifiers, builds the
/// canonical storage key via [`build_artifact_storage_key`], confirms the object is
/// present, inserts the artifact row, and emits `artifact.created` / `artifact.uploaded`.
pub async fn register_artifact(
    db: &Database,
    storage: &dyn ObjectStorage,
    req: ArtifactRegisterRequest,
) -> Result<Artifact, ArtifactError> {
    let trimmed_platform = req.platform.trim().to_string();
    let trimmed_kind = req.kind.trim().to_string();
    let trimmed_file_name = req.file_name.trim().to_string();
    let trimmed_checksum = req.checksum.trim().to_string();
    let trimmed_version = req.version.trim().to_string();
    let trimmed_bucket = req.storage_bucket.trim().to_string();

    if trimmed_file_name.is_empty() {
        return Err(ArtifactError::ValidationError(
            "Artifact file name cannot be empty.".to_string(),
        ));
    }
    if trimmed_checksum.is_empty() {
        return Err(ArtifactError::ValidationError(
            "Artifact checksum cannot be empty.".to_string(),
        ));
    }
    if trimmed_version.is_empty() {
        return Err(ArtifactError::ValidationError(
            "Artifact version cannot be empty.".to_string(),
        ));
    }
    if trimmed_bucket.is_empty() {
        return Err(ArtifactError::ValidationError(
            "Storage bucket cannot be empty.".to_string(),
        ));
    }
    if req.file_size < 0 {
        return Err(ArtifactError::ValidationError(
            "Artifact file size cannot be negative.".to_string(),
        ));
    }
    if req.build_number < 0 {
        return Err(ArtifactError::ValidationError(
            "Build number cannot be negative.".to_string(),
        ));
    }
    validate_platform(&trimmed_platform)?;
    validate_kind(&trimmed_kind)?;

    // 1. Resolve the owning organization by its public UUID.
    let org = repositories::organization_summary_by_public_id(db, &req.organization_id)
        .await?
        .ok_or(ArtifactError::OrganizationNotFound)?;

    // 2. Resolve the parent build by its public UUID within the organization.
    let build = repositories::build_summary_by_public_id_and_org(db, &req.build_id, org.id)
        .await?
        .ok_or(ArtifactError::BuildNotFound)?;

    // 3. Resolve the app and project ancestors needed for the canonical storage key.
    let app = repositories::app_summary_by_id(db, build.app_id)
        .await?
        .ok_or(ArtifactError::AppNotFound)?;
    let project = repositories::project_summary_by_id(db, app.project_id)
        .await?
        .ok_or(ArtifactError::ProjectNotFound)?;

    // 4. Build the canonical storage key and confirm the upload is present before
    //    persisting metadata.
    let artifact_public_id = Uuid::new_v4().to_string();
    let storage_key = build_artifact_storage_key(
        &org.public_id,
        &project.public_id,
        &app.public_id,
        &build.public_id,
        &artifact_public_id,
        &trimmed_file_name,
    );

    if !storage.exists(&storage_key).await? {
        return Err(ArtifactError::UploadNotConfirmed);
    }

    // 5. Serialize metadata to JSON text.
    let metadata_json = serde_json::to_string(&req.metadata)
        .map_err(|e| ArtifactError::InvalidMetadata(e.to_string()))?;

    // 6. Insert the artifact row.
    let now = Utc::now();
    let artifact = Artifact {
        id: 0,
        public_id: artifact_public_id,
        build_id: build.id,
        organization_id: org.id,
        platform: trimmed_platform,
        kind: trimmed_kind,
        storage_key: storage_key.clone(),
        storage_bucket: trimmed_bucket,
        file_name: trimmed_file_name,
        file_size: req.file_size,
        checksum: trimmed_checksum,
        version: trimmed_version,
        build_number: req.build_number,
        metadata: metadata_json,
        created_at: now,
    };
    let saved = repositories::insert_artifact(db, artifact).await?;

    // 7. Emit artifact events (payload keys per docs/events.md).
    emit_event(
        db,
        "artifact.created",
        Some(org.id),
        None,
        Some(app.id),
        None,
        serde_json::json!({
            "artifact_id": saved.public_id,
            "build_id": build.public_id,
            "platform": saved.platform,
            "kind": saved.kind,
        }),
    )
    .await;

    emit_event(
        db,
        "artifact.uploaded",
        Some(org.id),
        None,
        Some(app.id),
        None,
        serde_json::json!({
            "artifact_id": saved.public_id,
            "size": saved.file_size,
            "checksum": saved.checksum,
        }),
    )
    .await;

    Ok(saved)
}

/// Retrieve an artifact by its public UUID within an organization.
///
/// Scoped to the organization, so an artifact belonging to another organization is
/// reported as not found rather than exposed.
pub async fn get_artifact(
    db: &Database,
    organization_id: i64,
    artifact_public_id: &str,
) -> Result<(Artifact, BuildSummary, OrganizationSummary), ArtifactError> {
    let artifact =
        repositories::artifact_by_public_id_and_org(db, artifact_public_id, organization_id)
            .await?
            .ok_or(ArtifactError::ArtifactNotFound)?;

    let build = repositories::build_summary_by_id(db, artifact.build_id)
        .await?
        .ok_or(ArtifactError::BuildNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(ArtifactError::OrganizationNotFound)?;

    Ok((artifact, build, org))
}

/// List artifacts in an organization (optionally filtered by build public UUID).
pub async fn list_artifacts(
    db: &Database,
    organization_id: i64,
    build_public_id: Option<&str>,
) -> Result<Vec<(Artifact, BuildSummary, OrganizationSummary)>, ArtifactError> {
    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(ArtifactError::OrganizationNotFound)?;

    let artifacts = if let Some(build_pub_id) = build_public_id {
        let build =
            repositories::build_summary_by_public_id_and_org(db, build_pub_id, organization_id)
                .await?
                .ok_or(ArtifactError::BuildNotFound)?;
        repositories::artifacts_for_build(db, build.id, organization_id).await?
    } else {
        repositories::artifacts_for_organization(db, organization_id).await?
    };

    let mut results = Vec::with_capacity(artifacts.len());
    for artifact in artifacts {
        if let Some(build) = repositories::build_summary_by_id(db, artifact.build_id).await? {
            results.push((artifact, build, org.clone()));
        }
    }

    Ok(results)
}
