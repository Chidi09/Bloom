//! HTTP view handlers for the `observability` domain app.

use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_rest::Permission;

use super::errors::ObservabilityError;
use super::permissions::OrganizationPermission;
use super::services;
use crate::apps::accounts::permissions::require_authenticated;
use crate::apps::common::request::{get_db, get_org_id};

/// GET `/api/v1/observability/releases/:id/health` — Retrieve aggregated health metrics for a release.
pub async fn release_health(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ObservabilityError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let release_id = params
        .get("id")
        .ok_or_else(|| ObservabilityError::ValidationError("Missing release id".to_string()))?;

    let response = services::get_release_health(db, release_id, org_id)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &response)
}

/// GET `/api/v1/observability/apps/:id/status` — Retrieve live deployment status and health for an application.
pub async fn app_status(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(ObservabilityError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_id = params
        .get("id")
        .ok_or_else(|| ObservabilityError::ValidationError("Missing app id".to_string()))?;

    let response = services::get_app_status(db, app_id, org_id)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &response)
}

/// GET `/api/v1/observability/apps/:id/health` — Alias for application status and release health dashboard data.
pub async fn app_health(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    app_status(req, params).await
}
