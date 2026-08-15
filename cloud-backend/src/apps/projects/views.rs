//! HTTP view handlers for the `projects` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;

use super::contracts::{ProjectCreateRequest, ProjectUpdateRequest};
use super::errors::ProjectError;
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
) -> Result<(Organization, UserOrganizationMembership), ProjectError> {
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
            .ok_or(ProjectError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(ProjectError::Forbidden)?;
        return Ok((org, membership));
    }

    // 3. If CurrentOrganizationId was set alone
    if let Some(org_id_ext) = req.ext::<CurrentOrganizationId>() {
        let org = org_repos::organization_by_id(db, org_id_ext.0)
            .await?
            .ok_or(ProjectError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(ProjectError::Forbidden)?;
        return Ok((org, membership));
    }

    Err(ProjectError::OrganizationRequired)
}

/// Enforce minimum role in the organization.
fn require_role(
    membership: &UserOrganizationMembership,
    min_role: OrganizationRole,
) -> Result<(), ProjectError> {
    let role =
        OrganizationRole::from_str(&membership.role).map_err(|_| ProjectError::InsufficientRole)?;
    if role >= min_role {
        Ok(())
    } else {
        Err(ProjectError::InsufficientRole)
    }
}

/// GET `/api/v1/projects` — List all projects within the active organization.
///
/// Uses `PageNumberPagination` for bounded browsing of projects within an organization.
pub async fn list_projects(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (projects, total) =
        services::list_projects_for_organization(db, org.id, Some(limit), Some(offset))
            .await
            .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = projects
        .iter()
        .map(|p| {
            let resp = serializers::serialize_project(p, &org.public_id);
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/projects` — Create a new project in the active organization.
pub async fn create_project(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let Json(body) = Json::<ProjectCreateRequest>::from_request(&req).await?;

    let project = services::create_project(db, org.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_project(&project, &org.public_id);
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/projects/{id}` — Retrieve project details by public UUID.
pub async fn retrieve_project(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let project_id = params
        .get("id")
        .ok_or_else(|| ProjectError::ValidationError("Missing project id".to_string()))?;

    let project = services::get_project(db, org.id, project_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_project(&project, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/projects/{id}` — Partially update project details.
pub async fn update_project(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let project_id = params
        .get("id")
        .ok_or_else(|| ProjectError::ValidationError("Missing project id".to_string()))?;

    let mut project = services::get_project(db, org.id, project_id)
        .await
        .map_err(DjangorsError::from)?;

    let Json(body) = Json::<ProjectUpdateRequest>::from_request(&req).await?;

    let updated = services::update_project(db, &mut project, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_project(&updated, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/projects/{id}` — Delete a project (requires Admin or above).
pub async fn delete_project(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let project_id = params
        .get("id")
        .ok_or_else(|| ProjectError::ValidationError("Missing project id".to_string()))?;

    let project = services::get_project(db, org.id, project_id)
        .await
        .map_err(DjangorsError::from)?;

    services::delete_project(db, &project)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
