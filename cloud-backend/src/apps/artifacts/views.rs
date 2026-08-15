//! HTTP view handlers for the `artifacts` domain app.

use std::sync::Arc;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::ArtifactRegisterRequest;
use super::errors::ArtifactError;
use super::permissions::{require_job_token, OrganizationPermission};
use super::{serializers, services};
use crate::apps::accounts::permissions::{require_authenticated, CurrentOrganizationId};
use crate::infra::storage::{ObjectStorage, DEFAULT_PRESIGNED_EXPIRY};

/// Retrieve the database handle from request state.
fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Retrieve the active organization ID from request extensions.
fn get_org_id(req: &Request) -> Result<i64, DjangorsError> {
    req.ext::<CurrentOrganizationId>()
        .map(|ext| ext.0)
        .ok_or_else(|| {
            DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            )
        })
}

/// Retrieve the object-storage backend from request state.
///
/// The reviewer wires an `Arc<dyn ObjectStorage>` into router state when composing the
/// app (via `Router::with_state`); state is inherited by mounted sub-routers.
fn get_storage(req: &Request) -> Option<Arc<dyn ObjectStorage>> {
    req.state::<Arc<dyn ObjectStorage>>().cloned()
}

/// GET `/api/v1/artifacts` — List artifacts in the current organization (optionally filtered by `build_id` query param).
pub async fn list_artifacts(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ArtifactError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let build_filter = req.query("build_id");

    let artifact_tuples = services::list_artifacts(db, org_id, build_filter)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = artifact_tuples
        .iter()
        .map(|(artifact, build, org)| {
            serializers::serialize_artifact(artifact, &build.public_id, &org.public_id, None)
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/artifacts/{id}` — Retrieve an artifact by its public UUID, including a fresh short-lived presigned download URL when storage is wired.
pub async fn retrieve_artifact(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ArtifactError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let artifact_id = params
        .get("id")
        .ok_or_else(|| ArtifactError::ValidationError("Missing artifact id".to_string()))?;

    let (artifact, build, org) = services::get_artifact(db, org_id, artifact_id)
        .await
        .map_err(DjangorsError::from)?;

    // `presigned_download_url` is async, so `.map(..)` yields an Option<Future>, not an
    // Option<Result>; await inside the match rather than transposing.
    let download_url = match get_storage(&req) {
        Some(storage) => Some(
            services::presigned_download_url(&*storage, &artifact, DEFAULT_PRESIGNED_EXPIRY)
                .await
                .map_err(DjangorsError::from)?,
        ),
        None => None,
    };

    let payload =
        serializers::serialize_artifact(&artifact, &build.public_id, &org.public_id, download_url);
    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/artifacts/{id}/download` — Redirect to a short-lived presigned download URL.
pub async fn download_artifact(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ArtifactError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let artifact_id = params
        .get("id")
        .ok_or_else(|| ArtifactError::ValidationError("Missing artifact id".to_string()))?;

    // Org-scoped lookup: an artifact belonging to another organization is not found.
    let (artifact, _, _) = services::get_artifact(db, org_id, artifact_id)
        .await
        .map_err(DjangorsError::from)?;

    let storage = get_storage(&req).ok_or_else(|| {
        DjangorsError::api(
            StatusCode::INTERNAL_SERVER_ERROR,
            "storage_unavailable",
            "Object storage is not configured.",
        )
    })?;

    let url =
        services::artifact_download_url(&*storage, &artifact, org_id, DEFAULT_PRESIGNED_EXPIRY)
            .await
            .map_err(DjangorsError::from)?;

    Ok(Response::redirect(&url))
}

/// POST `/api/v1/workers/jobs/{id}/artifact` — Internal worker endpoint registering artifact metadata.
pub async fn register_artifact(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    require_job_token(&req).map_err(DjangorsError::from)?;

    let db = get_db(&req)?;
    let storage = get_storage(&req).ok_or_else(|| {
        DjangorsError::api(
            StatusCode::INTERNAL_SERVER_ERROR,
            "storage_unavailable",
            "Object storage is not configured.",
        )
    })?;

    let Json(body) = Json::<ArtifactRegisterRequest>::from_request(&req).await?;

    // The request carries the parent build's and owning organization's public UUIDs,
    // so the response can be rendered without re-resolving them.
    let build_public_id = body.build_id.clone();
    let organization_public_id = body.organization_id.clone();

    let artifact = services::register_artifact(db, &*storage, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload =
        serializers::serialize_artifact(&artifact, &build_public_id, &organization_public_id, None);
    Response::json(StatusCode::CREATED, &payload)
}
