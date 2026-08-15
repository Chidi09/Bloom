//! HTTP view handlers for the `organizations` domain app.

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use serde_json::json;

use super::contracts::{
    AcceptInviteRequest, ChangeRoleRequest, InviteRequest, OrganizationCreateRequest,
    OrganizationUpdateRequest,
};
use super::errors::OrganizationError;
use super::permissions::CurrentOrganizationPublicId;
use super::{serializers, services};
use crate::apps::accounts::permissions::require_authenticated;
use crate::apps::common::request::get_db;

/// GET `/api/v1/organizations` — List all organizations the authenticated user belongs to.
///
/// Uses `PageNumberPagination` for browsing organizations.
pub async fn list_organizations(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (org_pairs, total) =
        services::list_user_organizations(db, user.id, Some(limit), Some(offset))
            .await
            .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = org_pairs
        .iter()
        .map(|(org, membership)| {
            let resp = serializers::serialize_organization(org, &membership.role);
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/organizations` — Create a new organization with the user as owner.
pub async fn create_organization(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let Json(body) = Json::<OrganizationCreateRequest>::from_request(&req).await?;

    let org = services::create_organization(db, user.id, &body.name)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_organization(&org, "owner");
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/organizations/current` — Retrieve currently selected organization from context.
pub async fn current_organization(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_public_id = req
        .ext::<CurrentOrganizationPublicId>()
        .map(|ext| ext.0.clone())
        .or_else(|| {
            req.header("x-bloom-organization-id")
                .and_then(|v| v.to_str().ok())
                .map(|s| s.to_string())
        })
        .ok_or_else(|| {
            DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            )
        })?;

    let (org, membership) = services::get_organization(db, user.id, &org_public_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_organization(&org, &membership.role);
    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/organizations/{id}` — Retrieve organization details by public UUID.
pub async fn retrieve_organization(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_id = params
        .get("id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing organization id".to_string()))?;

    let (org, membership) = services::get_organization(db, user.id, org_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_organization(&org, &membership.role);
    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/organizations/{id}` — Partially update organization details.
pub async fn update_organization(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_id = params
        .get("id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing organization id".to_string()))?;

    let Json(body) = Json::<OrganizationUpdateRequest>::from_request(&req).await?;

    let updated = services::update_organization(db, user.id, org_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let (_, membership) = services::get_organization(db, user.id, org_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_organization(&updated, &membership.role);
    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/organizations/{id}` — Delete an organization (owner only).
pub async fn delete_organization(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_id = params
        .get("id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing organization id".to_string()))?;

    services::delete_organization(db, user.id, org_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}

/// GET `/api/v1/organizations/{id}/members` — List all members of an organization.
///
/// Uses `PageNumberPagination` for bounded browsing of organization members.
pub async fn list_members(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_id = params
        .get("id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing organization id".to_string()))?;

    let (_org, _) = services::get_organization(db, user.id, org_id)
        .await
        .map_err(DjangorsError::from)?;

    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (members, total) = services::list_members(db, user.id, org_id, Some(limit), Some(offset))
        .await
        .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = members
        .iter()
        .map(|(membership, auth_user, profile)| {
            let user_public_id = profile
                .as_ref()
                .map(|p| p.public_id.as_str())
                .unwrap_or_default();
            let resp = serializers::serialize_membership(
                membership,
                user_public_id,
                &auth_user.email,
                &auth_user.username,
            );
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/organizations/{id}/members` — Invite a new member to an organization.
pub async fn invite_member(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_id = params
        .get("id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing organization id".to_string()))?;

    let Json(body) = Json::<InviteRequest>::from_request(&req).await?;

    let invite = services::add_member(db, user.id, org_id, &body.email, &body.role)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_invite(&invite);
    Response::json(StatusCode::CREATED, &payload)
}

/// PATCH `/api/v1/organizations/{id}/members/{member_id}` — Change a member's role.
pub async fn change_role(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_id = params
        .get("id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing organization id".to_string()))?;

    let member_id = params
        .get("member_id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing member id".to_string()))?;

    let Json(body) = Json::<ChangeRoleRequest>::from_request(&req).await?;

    services::change_member_role(db, user.id, org_id, member_id, &body.role)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &json!({ "status": "updated" }))
}

/// DELETE `/api/v1/organizations/{id}/members/{member_id}` — Remove a member from the organization.
pub async fn remove_member(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let org_id = params
        .get("id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing organization id".to_string()))?;

    let member_id = params
        .get("member_id")
        .ok_or_else(|| OrganizationError::ValidationError("Missing member id".to_string()))?;

    services::remove_member(db, user.id, org_id, member_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}

/// POST `/api/v1/organizations/invites/accept` — Accept an outstanding organization invite.
pub async fn accept_invite(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let Json(body) = Json::<AcceptInviteRequest>::from_request(&req).await?;

    let membership = services::accept_invite(db, &body.token, user.id)
        .await
        .map_err(DjangorsError::from)?;

    let profile = crate::apps::accounts::repositories::profile_by_user_id(db, user.id)
        .await
        .map_err(OrganizationError::from)?;

    let user_public_id = profile
        .as_ref()
        .map(|p| p.public_id.as_str())
        .unwrap_or_default();

    let payload =
        serializers::serialize_membership(&membership, user_public_id, &user.email, &user.username);

    Response::json(StatusCode::OK, &payload)
}
