//! HTTP request handlers for the `signing` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;

use super::contracts::SigningIdentityCreateRequest;
use super::errors::SigningError;
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
) -> Result<(Organization, UserOrganizationMembership), SigningError> {
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
            .ok_or(SigningError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(SigningError::Forbidden)?;
        return Ok((org, membership));
    }

    // 3. If CurrentOrganizationId was set alone
    if let Some(org_id_ext) = req.ext::<CurrentOrganizationId>() {
        let org = org_repos::organization_by_id(db, org_id_ext.0)
            .await?
            .ok_or(SigningError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(SigningError::Forbidden)?;
        return Ok((org, membership));
    }

    Err(SigningError::OrganizationRequired)
}

/// Enforce minimum required role for the operation.
fn require_role(
    membership: &UserOrganizationMembership,
    min_role: OrganizationRole,
) -> Result<(), SigningError> {
    let role =
        OrganizationRole::from_str(&membership.role).map_err(|_| SigningError::InsufficientRole)?;
    if role >= min_role {
        Ok(())
    } else {
        Err(SigningError::InsufficientRole)
    }
}

/// GET `/api/v1/signing` — List signing identities within the active organization (optionally filtered by platform).
pub async fn list_signing_identities(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let platform_filter = req.query("platform");
    let identities = services::list_signing_identities(db, org.id, platform_filter)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = identities
        .iter()
        .map(|(identity, org_summary)| {
            serializers::serialize_signing_identity(identity, &org_summary.public_id)
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/signing` — Upload and store encrypted signing materials (requires ReleaseManager or above).
pub async fn upload_signing_identity(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::ReleaseManager).map_err(DjangorsError::from)?;

    let Json(body) = Json::<SigningIdentityCreateRequest>::from_request(&req).await?;

    let (identity, org_summary) = services::upload_signing_identity(db, org.id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_signing_identity(&identity, &org_summary.public_id);
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/signing/:id` — Retrieve signing identity metadata by public UUID (requires Viewer or above).
pub async fn retrieve_signing_identity(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let identity_id = params
        .get("id")
        .ok_or_else(|| SigningError::ValidationError("Missing signing identity id".to_string()))?;

    let (identity, org_summary) = services::get_signing_identity(db, org.id, identity_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_signing_identity(&identity, &org_summary.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/signing/:id` — Delete a signing identity (requires ReleaseManager or above).
pub async fn delete_signing_identity(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::ReleaseManager).map_err(DjangorsError::from)?;

    let identity_id = params
        .get("id")
        .ok_or_else(|| SigningError::ValidationError("Missing signing identity id".to_string()))?;

    services::delete_signing_identity(db, org.id, user.id, identity_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
