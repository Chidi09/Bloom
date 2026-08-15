//! HTTP view handlers for the `releases` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::{
    ReleaseApproveRequest, ReleaseCreateRequest, ReleaseRollbackRequest, ReleaseUpdateRequest,
};
use super::errors::ReleaseError;
use super::permissions::{
    CurrentOrganizationId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};
use super::{serializers, services};
use crate::apps::accounts::permissions::require_authenticated;

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

/// Extract the user's role in the active organization.
fn get_user_role(req: &Request) -> OrganizationRole {
    req.ext::<CurrentOrganizationRole>()
        .and_then(|ext| OrganizationRole::from_str(&ext.0).ok())
        .unwrap_or(OrganizationRole::Developer)
}

/// GET `/api/v1/releases` — List releases in the current organization.
pub async fn list_releases(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ReleaseError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_filter = req.query("app_id");
    let environment_filter = req.query("environment_id");
    let status_filter = req.query("status");

    let releases =
        services::list_releases(db, org_id, app_filter, environment_filter, status_filter)
            .await
            .map_err(DjangorsError::from)?;

    let payload: Vec<_> = releases
        .iter()
        .map(|detail| {
            serializers::serialize_release(
                &detail.release,
                &detail.app_public_id,
                &detail.organization_public_id,
                detail.environment_public_id.as_deref(),
                &detail.created_by_public_id,
                detail.artifacts.clone(),
            )
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/releases` — Create a new release in `draft` status.
pub async fn create_release(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ReleaseError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let Json(body) = Json::<ReleaseCreateRequest>::from_request(&req).await?;

    let detail = services::create_release(db, org_id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_release(
        &detail.release,
        &detail.app_public_id,
        &detail.organization_public_id,
        detail.environment_public_id.as_deref(),
        &detail.created_by_public_id,
        detail.artifacts,
    );

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/releases/{id}` — Retrieve a release by public UUID.
pub async fn retrieve_release(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ReleaseError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let release_id = params
        .get("id")
        .ok_or_else(|| ReleaseError::ValidationError("Missing release id".to_string()))?;

    let detail = services::get_release(db, org_id, release_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_release(
        &detail.release,
        &detail.app_public_id,
        &detail.organization_public_id,
        detail.environment_public_id.as_deref(),
        &detail.created_by_public_id,
        detail.artifacts,
    );

    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/releases/{id}` — Update a release (changelog, rollout state, status).
pub async fn update_release(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ReleaseError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let user_role = get_user_role(&req);

    let release_id = params
        .get("id")
        .ok_or_else(|| ReleaseError::ValidationError("Missing release id".to_string()))?;

    let Json(body) = Json::<ReleaseUpdateRequest>::from_request(&req).await?;

    let detail = services::update_release(db, org_id, user.id, user_role, release_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_release(
        &detail.release,
        &detail.app_public_id,
        &detail.organization_public_id,
        detail.environment_public_id.as_deref(),
        &detail.created_by_public_id,
        detail.artifacts,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/releases/{id}/approve` — Approve or reject a release.
pub async fn approve_release(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::release_manager();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ReleaseError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let user_role = get_user_role(&req);

    let release_id = params
        .get("id")
        .ok_or_else(|| ReleaseError::ValidationError("Missing release id".to_string()))?;

    let Json(body) = Json::<ReleaseApproveRequest>::from_request(&req).await?;

    let detail = services::approve_release(db, org_id, user.id, user_role, release_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_release(
        &detail.release,
        &detail.app_public_id,
        &detail.organization_public_id,
        detail.environment_public_id.as_deref(),
        &detail.created_by_public_id,
        detail.artifacts,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/releases/{id}/rollback` — Roll back a release.
pub async fn rollback_release(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::release_manager();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ReleaseError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let user_role = get_user_role(&req);

    let release_id = params
        .get("id")
        .ok_or_else(|| ReleaseError::ValidationError("Missing release id".to_string()))?;

    let body = Json::<ReleaseRollbackRequest>::from_request(&req)
        .await
        .map(|Json(b)| b)
        .ok();

    let detail = services::rollback_release(db, org_id, user.id, user_role, release_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_release(
        &detail.release,
        &detail.app_public_id,
        &detail.organization_public_id,
        detail.environment_public_id.as_deref(),
        &detail.created_by_public_id,
        detail.artifacts,
    );

    Response::json(StatusCode::OK, &payload)
}
