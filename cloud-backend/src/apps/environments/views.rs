//! HTTP view handlers for the `environments` domain app.

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::{EnvironmentCreateRequest, EnvironmentUpdateRequest};
use super::errors::EnvironmentError;
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

/// GET `/api/v1/environments` — List all environments in the current organization (optionally filtered by `app_id` query param).
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

    // Parse optional query param: ?app_id=...
    let app_filter = req.raw_query().and_then(|q| {
        q.split('&').find_map(|pair| {
            let mut parts = pair.split('=');
            if parts.next() == Some("app_id") {
                parts.next()
            } else {
                None
            }
        })
    });

    let env_tuples = services::list_environments(db, org_id, app_filter)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = env_tuples
        .iter()
        .map(|(env, app, org)| {
            serializers::serialize_environment(env, &app.public_id, &org.public_id)
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
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
