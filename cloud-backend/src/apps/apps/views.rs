//! HTTP view handlers for the `apps` domain app.

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::{AppCreateRequest, AppLinkRequest, AppUpdateRequest};
use super::errors::AppError;
use super::permissions::OrganizationPermission;
use super::{serializers, services};
use crate::apps::accounts::permissions::{require_authenticated, CurrentOrganizationId};

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

/// GET `/api/v1/apps` — List apps in the current organization (optionally filtered by `project_id` query param).
///
/// Uses `PageNumberPagination` for bounded browsing of applications within an organization.
pub async fn list_apps(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(AppError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let project_filter = req.query("project_id");

    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (app_tuples, total) =
        services::list_apps(db, org_id, project_filter, Some(limit), Some(offset))
            .await
            .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = app_tuples
        .iter()
        .map(|(app, project, org)| {
            let resp = serializers::serialize_app(app, &project.public_id, &org.public_id);
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/apps` — Create a new app within a project.
pub async fn create_app(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(AppError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let Json(body) = Json::<AppCreateRequest>::from_request(&req).await?;

    let (app, project, org) = services::create_app(db, org_id, Some(user.id), body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_app(&app, &project.public_id, &org.public_id);
    Response::json(StatusCode::CREATED, &payload)
}

/// POST `/api/v1/apps/link` — Link a local project/app by slugs (CLI flow).
pub async fn link_app(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(AppError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let Json(body) = Json::<AppLinkRequest>::from_request(&req).await?;

    let (app, project, org) = services::link_app(db, org_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_app(&app, &project.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/apps/{id}` — Retrieve an app by its public UUID.
pub async fn retrieve_app(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(AppError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_id = params
        .get("id")
        .ok_or_else(|| AppError::ValidationError("Missing app id".to_string()))?;

    let (app, project, org) = services::get_app(db, org_id, app_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_app(&app, &project.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/apps/{id}` — Partially update an app.
pub async fn update_app(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(AppError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_id = params
        .get("id")
        .ok_or_else(|| AppError::ValidationError("Missing app id".to_string()))?;

    let Json(body) = Json::<AppUpdateRequest>::from_request(&req).await?;

    let (app, project, org) = services::update_app(db, org_id, Some(user.id), app_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_app(&app, &project.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/apps/{id}` — Delete an app.
pub async fn delete_app(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(AppError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_id = params
        .get("id")
        .ok_or_else(|| AppError::ValidationError("Missing app id".to_string()))?;

    services::delete_app(db, org_id, Some(user.id), app_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
