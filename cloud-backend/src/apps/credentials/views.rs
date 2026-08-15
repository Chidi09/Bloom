//! HTTP view handlers for the `credentials` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;

use super::contracts::{CredentialCreateRequest, CredentialTestResponse};
use super::errors::CredentialError;
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

/// Resolve the active organization and verify the user's membership.
async fn resolve_org_context(
    req: &Request,
    db: &Database,
    user_id: i64,
) -> Result<(Organization, UserOrganizationMembership), CredentialError> {
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
            .ok_or(CredentialError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(CredentialError::Forbidden)?;
        return Ok((org, membership));
    }

    // 3. If CurrentOrganizationId was set alone
    if let Some(org_id_ext) = req.ext::<CurrentOrganizationId>() {
        let org = org_repos::organization_by_id(db, org_id_ext.0)
            .await?
            .ok_or(CredentialError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(CredentialError::Forbidden)?;
        return Ok((org, membership));
    }

    Err(CredentialError::OrganizationRequired)
}

/// Enforce minimum role in the organization.
fn require_role(
    membership: &UserOrganizationMembership,
    min_role: OrganizationRole,
) -> Result<(), CredentialError> {
    let role = OrganizationRole::from_str(&membership.role)
        .map_err(|_| CredentialError::InsufficientRole)?;
    if role >= min_role {
        Ok(())
    } else {
        Err(CredentialError::InsufficientRole)
    }
}

/// GET `/api/v1/credentials` — List all credentials in the active organization (metadata-only).
pub async fn list_credentials(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let credentials = services::list_credentials_for_organization(db, org.id)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = credentials
        .iter()
        .map(|c| serializers::serialize_credential(c, &org.public_id))
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/credentials` — Create a new encrypted credential in the active organization.
pub async fn create_credential(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let Json(body) = Json::<CredentialCreateRequest>::from_request(&req).await?;

    let credential = services::create_credential(db, org.id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_credential(&credential, &org.public_id);
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/credentials/{id}` — Retrieve credential metadata by public UUID.
pub async fn retrieve_credential(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let credential_id = params
        .get("id")
        .ok_or_else(|| CredentialError::ValidationError("Missing credential id".to_string()))?;

    let credential = services::get_credential(db, org.id, credential_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_credential(&credential, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/credentials/{id}/test` — Test a credential connection without leaking secrets.
pub async fn test_credential(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let credential_id = params
        .get("id")
        .ok_or_else(|| CredentialError::ValidationError("Missing credential id".to_string()))?;

    let credential = services::get_credential(db, org.id, credential_id)
        .await
        .map_err(DjangorsError::from)?;

    let message = services::test_credential(db, &credential)
        .await
        .map_err(DjangorsError::from)?;

    let payload = CredentialTestResponse {
        id: credential.public_id.clone(),
        provider: credential.provider.clone(),
        success: true,
        message,
    };

    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/credentials/{id}` — Delete a credential (requires Admin or above).
pub async fn delete_credential(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let credential_id = params
        .get("id")
        .ok_or_else(|| CredentialError::ValidationError("Missing credential id".to_string()))?;

    let credential = services::get_credential(db, org.id, credential_id)
        .await
        .map_err(DjangorsError::from)?;

    services::delete_credential(db, &credential)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
