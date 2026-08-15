//! Business logic, domain rules, and workflows for `releases`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{
    ReleaseApproveRequest, ReleaseCreateRequest, ReleaseRollbackRequest, ReleaseUpdateRequest,
};
use super::errors::ReleaseError;
use super::models::Release;
use super::permissions::OrganizationRole;
use super::repositories;
use crate::apps::artifacts::contracts::ArtifactResponse;

/// Valid platforms for releases.
pub const VALID_PLATFORMS: &[&str] = &["ios", "android", "web"];

/// All valid release lifecycle statuses.
pub const VALID_STATUSES: &[&str] = &[
    "draft",
    "pending_approval",
    "approved",
    "rolling_out",
    "released",
    "rolled_back",
    "expired",
];

/// Returns `true` when `from -> to` is a legal release status transition.
///
/// The matrix is intentionally conservative:
/// - `draft`: can advance to `pending_approval` (submitted for review), `approved` (direct
///   manager approval), or `expired` (abandoned/timed out).
/// - `pending_approval`: can advance to `approved` (accepted by release manager), return to
///   `draft` (rejected / revisions requested), or `expired` (review timed out).
/// - `approved`: can advance to `rolling_out` (deployment started), `released` (direct release
///   completion), or `expired`.
/// - `rolling_out`: can advance to `released` (all platform deployments live), `rolled_back`
///   (rollout aborted/reverted), or `expired` (rollout timed out/failed).
/// - `released`: can transition to `rolled_back` (production rollback initiated) or `expired`
///   (artifact retention period exceeded).
/// - `rolled_back` and `expired`: terminal states that are strictly absorbing (no transitions out).
pub fn can_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("draft", "pending_approval")
            | ("draft", "approved")
            | ("draft", "expired")
            | ("pending_approval", "approved")
            | ("pending_approval", "draft")
            | ("pending_approval", "expired")
            | ("approved", "rolling_out")
            | ("approved", "released")
            | ("approved", "expired")
            | ("rolling_out", "released")
            | ("rolling_out", "rolled_back")
            | ("rolling_out", "expired")
            | ("released", "rolled_back")
            | ("released", "expired")
    )
}

/// Validate that a version string is semver-ish.
pub fn validate_version(version: &str) -> Result<(), ReleaseError> {
    let trimmed = version.trim();
    if trimmed.is_empty() {
        return Err(ReleaseError::ValidationError(
            "Version cannot be empty.".to_string(),
        ));
    }
    if trimmed.len() > 64 {
        return Err(ReleaseError::ValidationError(
            "Version string exceeds 64 characters.".to_string(),
        ));
    }
    let v_stripped = trimmed.strip_prefix('v').unwrap_or(trimmed);
    let parts: Vec<&str> = v_stripped.split('.').collect();
    if parts.is_empty() || !parts[0].chars().any(|c| c.is_ascii_digit()) {
        return Err(ReleaseError::ValidationError(format!(
            "Invalid version format: '{version}'. Must follow semantic versioning (e.g. 1.0.0)."
        )));
    }
    Ok(())
}

/// Validate a list of platforms against [`VALID_PLATFORMS`].
pub fn validate_platforms(platforms: &[String]) -> Result<(), ReleaseError> {
    if platforms.is_empty() {
        return Err(ReleaseError::ValidationError(
            "At least one platform must be specified.".to_string(),
        ));
    }
    for p in platforms {
        let p_trimmed = p.trim().to_lowercase();
        if !VALID_PLATFORMS.contains(&p_trimmed.as_str()) {
            return Err(ReleaseError::ValidationError(format!(
                "Invalid platform '{p}'. Allowed values: {}.",
                VALID_PLATFORMS.join(", ")
            )));
        }
    }
    Ok(())
}

/// Validate git commit SHA.
pub fn validate_commit(commit: &str) -> Result<(), ReleaseError> {
    let trimmed = commit.trim();
    if trimmed.is_empty() {
        return Err(ReleaseError::ValidationError(
            "Commit SHA cannot be empty.".to_string(),
        ));
    }
    if trimmed.len() > 40 || !trimmed.chars().all(|c| c.is_ascii_hexdigit()) {
        return Err(ReleaseError::ValidationError(format!(
            "Invalid git commit SHA: '{commit}'. Must be up to 40 hexadecimal characters."
        )));
    }
    Ok(())
}

/// Validate a status string against [`VALID_STATUSES`].
pub fn validate_status(status: &str) -> Result<(), ReleaseError> {
    if VALID_STATUSES.contains(&status) {
        Ok(())
    } else {
        Err(ReleaseError::ValidationError(format!(
            "Invalid status '{status}'. Allowed values: {}.",
            VALID_STATUSES.join(", ")
        )))
    }
}

/// A release record with its ancestor public identifiers and resolved artifacts,
/// ready for wire serialization.
#[derive(Debug, Clone)]
pub struct ReleaseDetail {
    /// The release model record.
    pub release: Release,
    /// External public UUID of the parent application.
    pub app_public_id: String,
    /// External public UUID of the owning organization.
    pub organization_public_id: String,
    /// External public UUID of the optional target environment.
    pub environment_public_id: Option<String>,
    /// External public UUID of the user who created this release.
    pub created_by_public_id: String,
    /// Resolved artifact wire representations.
    pub artifacts: Vec<ArtifactResponse>,
}

/// Helper function to resolve foreign entities and artifacts for a release.
async fn resolve_release_detail(
    db: &Database,
    release: Release,
    organization_id: i64,
) -> Result<ReleaseDetail, ReleaseError> {
    let app = repositories::app_summary_by_id(db, release.app_id.id)
        .await?
        .ok_or(ReleaseError::AppNotFound)?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(ReleaseError::OrganizationNotFound)?;

    let environment_public_id = match release.environment_id {
        Some(env_fk) => {
            let env = repositories::environment_summary_by_id(db, env_fk)
                .await?
                .ok_or(ReleaseError::EnvironmentNotFound)?;
            Some(env.public_id)
        }
        None => None,
    };

    let created_by_public_id = repositories::user_public_id_by_id(db, release.created_by_id)
        .await?
        .unwrap_or_else(|| release.created_by_id.to_string());

    // Resolve artifacts from JSON list of public IDs
    let artifact_ids: Vec<String> = serde_json::from_str(&release.artifacts).unwrap_or_default();
    let mut artifacts = Vec::with_capacity(artifact_ids.len());

    for art_id in &artifact_ids {
        if let Some(art) =
            repositories::artifact_by_public_id_and_org(db, art_id, organization_id).await?
        {
            let build_public_id = repositories::build_public_id_by_id(db, art.build_id)
                .await?
                .unwrap_or_default();
            let art_resp = crate::apps::artifacts::serializers::serialize_artifact(
                &art,
                &build_public_id,
                &org.public_id,
                None,
            );
            artifacts.push(art_resp);
        }
    }

    Ok(ReleaseDetail {
        release,
        app_public_id: app.public_id,
        organization_public_id: org.public_id,
        environment_public_id,
        created_by_public_id,
        artifacts,
    })
}

/// Create a new `Release` record in `draft` status (per `docs/apps/releases.md` §3).
///
/// 1. Resolve app and verify organization.
/// 2. Validate version semver-ish, platforms, commit, and build number.
/// 3. Resolve optional environment and verify it belongs to the app and organization.
/// 4. Resolve artifacts and verify they belong to the app/organization.
/// 5. Insert `Release` with `status = "draft"`.
/// 6. Emit `release.created` event.
pub async fn create_release(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    req: ReleaseCreateRequest,
) -> Result<ReleaseDetail, ReleaseError> {
    // 1. Resolve app and verify organization.
    let app = repositories::app_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(ReleaseError::AppNotFound)?;

    // 2. Validate version, platforms, commit, and build number.
    validate_version(&req.version)?;
    validate_platforms(&req.platforms)?;
    validate_commit(&req.commit)?;
    if req.build_number <= 0 {
        return Err(ReleaseError::ValidationError(
            "Build number must be a positive integer.".to_string(),
        ));
    }

    // 3. Resolve environment if provided.
    let environment = if let Some(ref env_id) = req.environment_id {
        let env = repositories::environment_by_public_id_and_org(db, env_id, organization_id)
            .await?
            .ok_or(ReleaseError::EnvironmentNotFound)?;
        if env.app_id != app.id {
            return Err(ReleaseError::EnvironmentNotFound);
        }
        Some(env)
    } else {
        None
    };

    // 4. Resolve artifacts and verify they belong to the organization.
    let mut resolved_artifacts = Vec::with_capacity(req.artifact_ids.len());
    let mut valid_artifact_ids = Vec::with_capacity(req.artifact_ids.len());

    for art_pub_id in &req.artifact_ids {
        let art = repositories::artifact_by_public_id_and_org(db, art_pub_id, organization_id)
            .await?
            .ok_or_else(|| ReleaseError::ArtifactNotFound(art_pub_id.clone()))?;
        valid_artifact_ids.push(art.public_id.clone());
        resolved_artifacts.push(art);
    }

    let platforms_json = serde_json::to_string(&req.platforms)
        .map_err(|e| ReleaseError::ValidationError(e.to_string()))?;
    let artifacts_json = serde_json::to_string(&valid_artifact_ids)
        .map_err(|e| ReleaseError::ValidationError(e.to_string()))?;
    let changelog = req.changelog.unwrap_or_default();

    // 5. Insert `Release` with `status = draft`.
    let now = Utc::now();
    let release = Release {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        app_id: ForeignKey::new(app.id),
        organization_id,
        version: req.version.clone(),
        build_number: req.build_number,
        commit: req.commit.clone(),
        changelog,
        environment_id: environment.as_ref().map(|e| e.id),
        status: "draft".to_string(),
        platforms: platforms_json,
        artifacts: artifacts_json,
        rollout_status: "{}".to_string(),
        created_by_id: user_id,
        created_at: now,
        updated_at: now,
    };

    let saved_release = repositories::insert_release(db, release).await?;

    // 6. Emit `release.created` event.
    crate::apps::events::emit(
        db,
        "release.created",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        Some(user_id),
        serde_json::json!({
            "release_id": saved_release.public_id,
            "app_id": app.public_id,
            "version": saved_release.version,
            "build_number": saved_release.build_number,
        }),
    )
    .await;

    resolve_release_detail(db, saved_release, organization_id).await
}

/// Approve or reject a release (per `docs/apps/releases.md` §3).
///
/// Only `ReleaseManager` or above (`Admin`, `Owner`) can approve or reject.
/// If approved, transitions status to `approved`.
/// If rejected, transitions status back to `draft` and emits `release.rejected`.
pub async fn approve_release(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    release_public_id: &str,
    req: ReleaseApproveRequest,
) -> Result<ReleaseDetail, ReleaseError> {
    if user_role < OrganizationRole::ReleaseManager {
        return Err(ReleaseError::Forbidden);
    }

    let release =
        repositories::release_by_public_id_and_org(db, release_public_id, organization_id)
            .await?
            .ok_or(ReleaseError::ReleaseNotFound)?;

    let user_public_id = repositories::user_public_id_by_id(db, user_id)
        .await?
        .unwrap_or_else(|| user_id.to_string());

    let target_status = if req.approved { "approved" } else { "draft" };

    if !can_transition(&release.status, target_status) {
        return Err(ReleaseError::InvalidStatus);
    }

    let mut updated = release.clone();
    updated.status = target_status.to_string();
    updated.updated_at = Utc::now();
    repositories::update_release(db, &updated).await?;

    if req.approved {
        crate::apps::events::emit(
            db,
            "release.approved",
            Some(organization_id),
            None,
            Some(updated.app_id.id),
            Some(user_id),
            serde_json::json!({
                "release_id": updated.public_id,
                "approved_by": user_public_id,
            }),
        )
        .await;
    } else {
        crate::apps::events::emit(
            db,
            "release.rejected",
            Some(organization_id),
            None,
            Some(updated.app_id.id),
            Some(user_id),
            serde_json::json!({
                "release_id": updated.public_id,
                "rejected_by": user_public_id,
                "reason": req.reason,
            }),
        )
        .await;
    }

    resolve_release_detail(db, updated, organization_id).await
}

/// Roll back a release (per `docs/apps/releases.md` §3).
///
/// Only `ReleaseManager` or above (`Admin`, `Owner`) can initiate a rollback.
/// Marks the release status as `rolled_back` and emits `release.rolled_back`.
pub async fn rollback_release(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    release_public_id: &str,
    _req: Option<ReleaseRollbackRequest>,
) -> Result<ReleaseDetail, ReleaseError> {
    if user_role < OrganizationRole::ReleaseManager {
        return Err(ReleaseError::Forbidden);
    }

    let release =
        repositories::release_by_public_id_and_org(db, release_public_id, organization_id)
            .await?
            .ok_or(ReleaseError::ReleaseNotFound)?;

    if !can_transition(&release.status, "rolled_back") {
        return Err(ReleaseError::InvalidStatus);
    }

    let user_public_id = repositories::user_public_id_by_id(db, user_id)
        .await?
        .unwrap_or_else(|| user_id.to_string());

    let mut updated = release.clone();
    updated.status = "rolled_back".to_string();
    updated.updated_at = Utc::now();
    repositories::update_release(db, &updated).await?;

    crate::apps::events::emit(
        db,
        "release.rolled_back",
        Some(organization_id),
        None,
        Some(updated.app_id.id),
        Some(user_id),
        serde_json::json!({
            "release_id": updated.public_id,
            "rolled_back_by": user_public_id,
        }),
    )
    .await;

    resolve_release_detail(db, updated, organization_id).await
}

/// Retrieve a release by public UUID within an organization.
pub async fn get_release(
    db: &Database,
    organization_id: i64,
    release_public_id: &str,
) -> Result<ReleaseDetail, ReleaseError> {
    let release =
        repositories::release_by_public_id_and_org(db, release_public_id, organization_id)
            .await?
            .ok_or(ReleaseError::ReleaseNotFound)?;

    resolve_release_detail(db, release, organization_id).await
}

/// List releases in an organization, optionally filtered by app, environment, or status.
///
/// Supports pagination via optional limit and offset.
/// Returns the list of releases alongside the total count of matching releases.
pub async fn list_releases(
    db: &Database,
    organization_id: i64,
    app_public_id: Option<&str>,
    environment_public_id: Option<&str>,
    status_filter: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<ReleaseDetail>, i64), ReleaseError> {
    let app_id = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(ReleaseError::AppNotFound)?;
        Some(app.id)
    } else {
        None
    };

    let environment_id = if let Some(env_pub_id) = environment_public_id {
        let env = repositories::environment_by_public_id_and_org(db, env_pub_id, organization_id)
            .await?
            .ok_or(ReleaseError::EnvironmentNotFound)?;
        Some(env.id)
    } else {
        None
    };

    let (releases, total) = repositories::list_releases_query(
        db,
        organization_id,
        app_id,
        environment_id,
        status_filter,
        limit,
        offset,
    )
    .await?;

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(ReleaseError::OrganizationNotFound)?;

    if releases.is_empty() {
        return Ok((Vec::new(), total));
    }

    let mut app_ids: Vec<i64> = releases.iter().map(|r| r.app_id.id).collect();
    app_ids.sort_unstable();
    app_ids.dedup();
    let app_map = repositories::app_summaries_by_ids(db, &app_ids).await?;

    let mut env_ids: Vec<i64> = releases.iter().filter_map(|r| r.environment_id).collect();
    env_ids.sort_unstable();
    env_ids.dedup();
    let env_map = repositories::environment_summaries_by_ids(db, &env_ids).await?;

    let mut user_ids: Vec<i64> = releases.iter().map(|r| r.created_by_id).collect();
    user_ids.sort_unstable();
    user_ids.dedup();
    let user_map = repositories::user_public_ids_by_ids(db, &user_ids).await?;

    // Collect all referenced artifact public UUIDs across all releases
    let mut all_art_ids = Vec::new();
    for r in &releases {
        let ids: Vec<String> = serde_json::from_str(&r.artifacts).unwrap_or_default();
        all_art_ids.extend(ids);
    }
    all_art_ids.sort_unstable();
    all_art_ids.dedup();
    let art_map =
        repositories::artifacts_by_public_ids_and_org(db, &all_art_ids, organization_id).await?;

    let mut all_build_ids: Vec<i64> = art_map.values().map(|a| a.build_id).collect();
    all_build_ids.sort_unstable();
    all_build_ids.dedup();
    let build_map = repositories::build_public_ids_by_ids(db, &all_build_ids).await?;

    let mut results = Vec::with_capacity(releases.len());
    for release in releases {
        let app = app_map
            .get(&release.app_id.id)
            .ok_or(ReleaseError::AppNotFound)?;

        let environment_public_id = match release.environment_id {
            Some(env_id) => {
                let env = env_map
                    .get(&env_id)
                    .ok_or(ReleaseError::EnvironmentNotFound)?;
                Some(env.public_id.clone())
            }
            None => None,
        };

        let created_by_public_id = user_map
            .get(&release.created_by_id)
            .cloned()
            .unwrap_or_else(|| release.created_by_id.to_string());

        let artifact_ids: Vec<String> =
            serde_json::from_str(&release.artifacts).unwrap_or_default();
        let mut artifacts = Vec::with_capacity(artifact_ids.len());
        for art_id in &artifact_ids {
            if let Some(art) = art_map.get(art_id) {
                let build_public_id = build_map.get(&art.build_id).cloned().unwrap_or_default();
                let art_resp = crate::apps::artifacts::serializers::serialize_artifact(
                    art,
                    &build_public_id,
                    &org.public_id,
                    None,
                );
                artifacts.push(art_resp);
            }
        }

        results.push(ReleaseDetail {
            release,
            app_public_id: app.public_id.clone(),
            organization_public_id: org.public_id.clone(),
            environment_public_id,
            created_by_public_id,
            artifacts,
        });
    }

    Ok((results, total))
}

/// Update changelog, rollout state, or advance lifecycle status of a release.
pub async fn update_release(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    release_public_id: &str,
    req: ReleaseUpdateRequest,
) -> Result<ReleaseDetail, ReleaseError> {
    let release =
        repositories::release_by_public_id_and_org(db, release_public_id, organization_id)
            .await?
            .ok_or(ReleaseError::ReleaseNotFound)?;

    let mut updated = release.clone();
    let mut status_changed = false;

    if let Some(target_status) = req.status {
        let target = target_status.trim().to_string();
        validate_status(&target)?;

        if target != release.status {
            if !can_transition(&release.status, &target) {
                return Err(ReleaseError::InvalidStatus);
            }

            // Production-affecting transitions require ReleaseManager or above
            if matches!(
                target.as_str(),
                "approved" | "rolling_out" | "released" | "rolled_back"
            ) && user_role < OrganizationRole::ReleaseManager
            {
                return Err(ReleaseError::Forbidden);
            }

            updated.status = target.clone();
            status_changed = true;

            if target == "released" {
                crate::apps::events::emit(
                    db,
                    "release.deployed",
                    Some(organization_id),
                    None,
                    Some(updated.app_id.id),
                    Some(user_id),
                    serde_json::json!({
                        "release_id": updated.public_id,
                        "deployment_ids": [],
                    }),
                )
                .await;
            } else if target == "expired" {
                crate::apps::events::emit(
                    db,
                    "release.expired",
                    Some(organization_id),
                    None,
                    Some(updated.app_id.id),
                    Some(user_id),
                    serde_json::json!({
                        "release_id": updated.public_id,
                    }),
                )
                .await;
            }
        }
    }

    if let Some(changelog) = req.changelog {
        updated.changelog = changelog;
    }

    if let Some(rollout_status) = req.rollout_status {
        updated.rollout_status = serde_json::to_string(&rollout_status)
            .map_err(|e| ReleaseError::ValidationError(e.to_string()))?;
    }

    updated.updated_at = Utc::now();
    repositories::update_release(db, &updated).await?;

    let _ = status_changed;

    resolve_release_detail(db, updated, organization_id).await
}
