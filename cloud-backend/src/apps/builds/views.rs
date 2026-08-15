//! HTTP view handlers for the `builds` domain app.

use std::sync::Arc;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::{BuildCreateRequest, CompleteBuildRequest, StageUpdateRequest};
use super::errors::BuildError;
use super::permissions::{require_job_token, OrganizationPermission};
use super::{serializers, services};
use crate::apps::accounts::permissions::{require_authenticated, CurrentOrganizationId};
use crate::infra::queue::JobQueue;
use crate::infra::storage::ObjectStorage;

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

/// GET `/api/v1/builds` — List builds in the current organization (optionally filtered
/// by `app_id` or `environment_id` query params).
///
/// Uses `PageNumberPagination` because users typically browse builds by page numbers in
/// dashboard interfaces, where total page count and jumping to specific pages are expected.
pub async fn list_builds(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(BuildError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_filter = req.query("app_id");
    let environment_filter = req.query("environment_id");

    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    // Preliminary count to calculate page slice
    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (builds, total) = services::list_builds(
        db,
        org_id,
        app_filter,
        environment_filter,
        Some(limit),
        Some(offset),
    )
    .await
    .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = builds
        .iter()
        .map(|detail| {
            let resp = serializers::serialize_build(
                &detail.build,
                &detail.stages,
                &detail.app_public_id,
                &detail.environment_public_id,
                &detail.organization_public_id,
            );
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/builds` — Create a new build and enqueue its execution job.
pub async fn create_build(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(BuildError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let queue = req.require_state::<JobQueue>()?;
    let Json(body) = Json::<BuildCreateRequest>::from_request(&req).await?;

    let (build, stages, app, env, org) =
        // A build started through the API belongs to no workflow step.
        services::create_build(db, org_id, Some(user.id), queue, body, None)
            .await
            .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_build(
        &build,
        &stages,
        &app.public_id,
        &env.public_id,
        &org.public_id,
    );
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/builds/{id}` — Retrieve a build (with its stages) by its public UUID.
pub async fn retrieve_build(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(BuildError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let build_id = params
        .get("id")
        .ok_or_else(|| BuildError::ValidationError("Missing build id".to_string()))?;

    let detail = services::get_build(db, org_id, build_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_build(
        &detail.build,
        &detail.stages,
        &detail.app_public_id,
        &detail.environment_public_id,
        &detail.organization_public_id,
    );
    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/builds/{id}/cancel` — Cancel a pending/queued build (or signal a running one).
pub async fn cancel_build(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(BuildError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let build_id = params
        .get("id")
        .ok_or_else(|| BuildError::ValidationError("Missing build id".to_string()))?;

    // A running build is stopped by a cancel flag the worker observes between stages, so the
    // queue is required here; without it a cancel would only mark the row and let the build
    // keep burning billable minutes.
    let queue = req.require_state::<JobQueue>()?;

    let detail = services::cancel_build(db, org_id, Some(user.id), build_id, Some(queue))
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_build(
        &detail.build,
        &detail.stages,
        &detail.app_public_id,
        &detail.environment_public_id,
        &detail.organization_public_id,
    );
    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/builds/{id}/logs` — Return a short-lived presigned URL for the build log.
pub async fn build_logs(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(BuildError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let storage = get_storage(&req).ok_or_else(|| {
        DjangorsError::api(
            StatusCode::INTERNAL_SERVER_ERROR,
            "storage_unavailable",
            "Object storage is not configured.",
        )
    })?;

    let build_id = params
        .get("id")
        .ok_or_else(|| BuildError::ValidationError("Missing build id".to_string()))?;

    let payload = services::build_logs(db, &*storage, org_id, build_id)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/workers/jobs/{id}/stage` — Internal worker endpoint reporting a stage update.
pub async fn update_build_stage(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    require_job_token(&req).map_err(DjangorsError::from)?;

    let db = get_db(&req)?;

    let build_id = params
        .get("id")
        .ok_or_else(|| BuildError::ValidationError("Missing build id".to_string()))?;

    let Json(body) = Json::<StageUpdateRequest>::from_request(&req).await?;

    services::update_stage(db, build_id, body)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}

/// POST `/api/v1/workers/jobs/{id}/complete` — Internal worker endpoint marking a build
/// complete/failed.
pub async fn complete_build(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    require_job_token(&req).map_err(DjangorsError::from)?;

    let db = get_db(&req)?;

    let build_id = params
        .get("id")
        .ok_or_else(|| BuildError::ValidationError("Missing build id".to_string()))?;

    let Json(body) = Json::<CompleteBuildRequest>::from_request(&req).await?;

    services::complete_build(db, build_id, body)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
