//! HTTP view handlers for the `environments` domain app.

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_rest::Permission;

use super::contracts::{EnvironmentCreateRequest, EnvironmentUpdateRequest};
use super::errors::EnvironmentError;
use super::permissions::OrganizationPermission;
use super::{serializers, services};
use crate::apps::accounts::permissions::require_authenticated;
use crate::apps::common::request::{get_db, get_org_id};

/// GET `/api/v1/environments` — List all environments in the current organization (optionally filtered by `app_id` query param).
///
/// Uses `PageNumberPagination` for bounded browsing of environments.
pub async fn list_environments(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(EnvironmentError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_filter = req.query("app_id");

    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (env_tuples, total) =
        services::list_environments(db, org_id, app_filter, Some(limit), Some(offset))
            .await
            .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = env_tuples
        .iter()
        .map(|(env, app, org)| {
            let resp = serializers::serialize_environment(env, &app.public_id, &org.public_id);
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/environments` — Create a new environment within an app.
pub async fn create_environment(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(EnvironmentError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let Json(body) = Json::<EnvironmentCreateRequest>::from_request(&req).await?;

    let (env, app, org) = services::create_environment(db, org_id, Some(user.id), body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_environment(&env, &app.public_id, &org.public_id);
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/environments/{id}` — Retrieve an environment by its public UUID.
pub async fn retrieve_environment(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(EnvironmentError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let env_id = params
        .get("id")
        .ok_or_else(|| EnvironmentError::ValidationError("Missing environment id".to_string()))?;

    let (env, app, org) = services::get_environment(db, org_id, env_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_environment(&env, &app.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/environments/{id}` — Partially update an environment.
pub async fn update_environment(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(EnvironmentError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let env_id = params
        .get("id")
        .ok_or_else(|| EnvironmentError::ValidationError("Missing environment id".to_string()))?;

    let Json(body) = Json::<EnvironmentUpdateRequest>::from_request(&req).await?;

    let (env, app, org) = services::update_environment(db, org_id, Some(user.id), env_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_environment(&env, &app.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/environments/{id}` — Delete an environment.
pub async fn delete_environment(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(EnvironmentError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let env_id = params
        .get("id")
        .ok_or_else(|| EnvironmentError::ValidationError("Missing environment id".to_string()))?;

    services::delete_environment(db, org_id, Some(user.id), env_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
