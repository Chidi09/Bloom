//! HTTP request handlers for the `secrets` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;

use super::contracts::{SecretCreateRequest, SecretRollbackRequest, SecretUpdateRequest};
use super::errors::SecretError;
use super::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationRole,
};
use super::{serializers, services};
use crate::apps::accounts::permissions::require_authenticated;
use crate::apps::organizations::models::{Organization, UserOrganizationMembership};
use crate::apps::organizations::repositories as org_repos;

/// Retrieve the database handle from request state.
fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Resolve the active organization context and verify the caller's membership.
async fn resolve_org_context(
    req: &Request,
    db: &Database,
    user_id: i64,
) -> Result<(Organization, UserOrganizationMembership), SecretError> {
    // 1. If full resolution layer extensions are present
    if let (Some(org_id_ext), Some(_pub_id_ext), Some(role_ext)) = (
        req.ext::<CurrentOrganizationId>(),
        req.ext::<CurrentOrganizationPublicId>(),
        req.ext::<CurrentOrganizationRole>(),
    ) {
        if let Ok(Some(org)) = org_repos::organization_by_id(db, org_id_ext.0).await {
            let membership = UserOrganizationMembership {
                id: 0,
                public_id: String::new(),
                user_id,
                organization_id: org.id,
                role: role_ext.0.clone(),
                created_at: chrono::Utc::now(),
                updated_at: chrono::Utc::now(),
            };
            return Ok((org, membership));
        }
    }

    // 2. Check X-Bloom-Organization-Id header or public id extension
    let org_public_id = req
        .ext::<CurrentOrganizationPublicId>()
        .map(|ext| ext.0.clone())
        .or_else(|| {
            req.header("x-bloom-organization-id")
                .and_then(|v| v.to_str().ok())
                .map(|s| s.to_string())
        });

    if let Some(public_id) = org_public_id {
        let org = org_repos::organization_by_public_id(db, &public_id)
            .await?
            .ok_or(SecretError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(SecretError::Forbidden)?;
        return Ok((org, membership));
    }

    // 3. If CurrentOrganizationId was set alone
    if let Some(org_id_ext) = req.ext::<CurrentOrganizationId>() {
        let org = org_repos::organization_by_id(db, org_id_ext.0)
            .await?
            .ok_or(SecretError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(SecretError::Forbidden)?;
        return Ok((org, membership));
    }

    Err(SecretError::OrganizationRequired)
}

/// Enforce minimum required role for the operation.
fn require_role(
    membership: &UserOrganizationMembership,
    min_role: OrganizationRole,
) -> Result<(), SecretError> {
    let role =
        OrganizationRole::from_str(&membership.role).map_err(|_| SecretError::InsufficientRole)?;
    if role >= min_role {
        Ok(())
    } else {
        Err(SecretError::InsufficientRole)
    }
}

/// GET `/api/v1/secrets` — List secrets within the active organization (optionally filtered by environment).
pub async fn list_secrets(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let env_filter = req.query("environment_id");
    let secrets = services::list_secrets(db, org.id, env_filter)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = secrets
        .iter()
        .map(|(s, env, org)| serializers::serialize_secret(s, &env.public_id, &org.public_id))
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/secrets` — Create a new secret or update existing under `(environment_id, key)`.
pub async fn create_or_update_secret(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::ReleaseManager).map_err(DjangorsError::from)?;

    let Json(body) = Json::<SecretCreateRequest>::from_request(&req).await?;

    let (secret, env, org) = services::create_or_update_secret(db, org.id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_secret(&secret, &env.public_id, &org.public_id);
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/secrets/{id}` — Retrieve secret metadata by public UUID.
pub async fn retrieve_secret(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let secret_id = params
        .get("id")
        .ok_or_else(|| SecretError::ValidationError("Missing secret id".to_string()))?;

    let (secret, env, org) = services::get_secret(db, org.id, secret_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_secret(&secret, &env.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/secrets/{id}` — Partially update a secret's value or flags.
pub async fn update_secret(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::ReleaseManager).map_err(DjangorsError::from)?;

    let secret_id = params
        .get("id")
        .ok_or_else(|| SecretError::ValidationError("Missing secret id".to_string()))?;

    let Json(body) = Json::<SecretUpdateRequest>::from_request(&req).await?;

    let (secret, env, org) = services::update_secret(db, org.id, user.id, secret_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_secret(&secret, &env.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/secrets/{id}/rollback` — Rollback a secret to a previous version.
pub async fn rollback_secret(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::ReleaseManager).map_err(DjangorsError::from)?;

    let secret_id = params
        .get("id")
        .ok_or_else(|| SecretError::ValidationError("Missing secret id".to_string()))?;

    let Json(body) = Json::<SecretRollbackRequest>::from_request(&req).await?;

    let (secret, env, org) =
        services::rollback_secret(db, org.id, user.id, secret_id, body.version)
            .await
            .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_secret(&secret, &env.public_id, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/secrets/{id}` — Delete a secret.
pub async fn delete_secret(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::ReleaseManager).map_err(DjangorsError::from)?;

    let secret_id = params
        .get("id")
        .ok_or_else(|| SecretError::ValidationError("Missing secret id".to_string()))?;

    services::delete_secret(db, org.id, user.id, secret_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
