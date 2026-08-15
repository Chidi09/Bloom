//! HTTP view handlers for the `marketplace` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;

use super::contracts::{
    TemplateCreateRequest, TemplatePublishRequest, TemplateUpdateRequest,
    TemplateVersionCreateRequest,
};
use super::errors::MarketplaceError;
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
) -> Result<(Organization, UserOrganizationMembership), MarketplaceError> {
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
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::Forbidden)?;
        return Ok((org, membership));
    }

    // 3. If CurrentOrganizationId was set alone
    if let Some(org_id_ext) = req.ext::<CurrentOrganizationId>() {
        let org = org_repos::organization_by_id(db, org_id_ext.0)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await
            .map_err(|e| MarketplaceError::DatabaseError(e.to_string()))?
            .ok_or(MarketplaceError::Forbidden)?;
        return Ok((org, membership));
    }

    Err(MarketplaceError::OrganizationRequired)
}

/// Enforce minimum role in the organization.
fn require_role(
    membership: &UserOrganizationMembership,
    min_role: OrganizationRole,
) -> Result<(), MarketplaceError> {
    let role = OrganizationRole::from_str(&membership.role)
        .map_err(|_| MarketplaceError::InsufficientRole)?;
    if role >= min_role {
        Ok(())
    } else {
        Err(MarketplaceError::InsufficientRole)
    }
}

// =========================================================================
// Public Marketplace Discovery Views (No organization required)
// =========================================================================

/// GET `/api/v1/marketplace/templates` — List public published templates.
pub async fn list_marketplace_templates(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let search = req.query("search").or_else(|| req.query("q"));

    let templates = services::list_public_templates(db, search)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = templates
        .iter()
        .map(|t| {
            serializers::serialize_template(
                &t.template,
                &t.organization_public_id,
                t.latest_version.clone(),
                t.versions_count,
            )
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/marketplace/templates/{id}` — Retrieve a public published template.
pub async fn retrieve_marketplace_template(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let detail = services::get_public_template(db, template_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_template_detail(
        &detail.template,
        &detail.organization_public_id,
        &detail.versions,
    );

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/marketplace/templates/{id}/versions/{version_id}` — Retrieve a public template version.
pub async fn retrieve_marketplace_template_version(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;
    let version_id = params
        .get("version_id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing version id".to_string()))?;

    let detail = services::get_public_template_version(db, template_id, version_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload =
        serializers::serialize_template_version(&detail.version, &detail.template_public_id);
    Response::json(StatusCode::OK, &payload)
}

// =========================================================================
// Organization-Scoped Template Views
// =========================================================================

/// GET `/api/v1/templates` — List all templates in the current organization.
pub async fn list_templates(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let templates = services::list_org_templates(db, org.id)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = templates
        .iter()
        .map(|t| {
            serializers::serialize_template(
                &t.template,
                &t.organization_public_id,
                t.latest_version.clone(),
                t.versions_count,
            )
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/templates` — Create a new template in the current organization.
pub async fn create_template(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let Json(body) = Json::<TemplateCreateRequest>::from_request(&req).await?;

    let detail = services::create_template(db, org.id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_template(
        &detail.template,
        &detail.organization_public_id,
        detail.latest_version,
        detail.versions_count,
    );

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/templates/{id}` — Retrieve an organization template by public UUID.
pub async fn retrieve_template(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let detail = services::get_org_template(db, org.id, template_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_template_detail(
        &detail.template,
        &detail.organization_public_id,
        &detail.versions,
    );

    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/templates/{id}` — Partially update an organization template.
pub async fn update_template(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let Json(body) = Json::<TemplateUpdateRequest>::from_request(&req).await?;

    let detail = services::update_template(db, org.id, user.id, template_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_template_detail(
        &detail.template,
        &detail.organization_public_id,
        &detail.versions,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/templates/{id}/publish` — Explicitly publish a template.
pub async fn publish_template(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let req_body = if req.body_bytes().await.is_empty() {
        TemplatePublishRequest::default()
    } else {
        Json::<TemplatePublishRequest>::from_request(&req)
            .await
            .map(|Json(b)| b)
            .unwrap_or_default()
    };

    let detail = services::publish_template(db, org.id, user.id, template_id, req_body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_template_detail(
        &detail.template,
        &detail.organization_public_id,
        &detail.versions,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/templates/{id}/archive` — Explicitly archive a template.
pub async fn archive_template(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let detail = services::archive_template(db, org.id, user.id, template_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_template_detail(
        &detail.template,
        &detail.organization_public_id,
        &detail.versions,
    );

    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/templates/{id}` — Delete a template and its versions.
pub async fn delete_template(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    services::delete_template(db, org.id, user.id, template_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}

/// GET `/api/v1/templates/{id}/versions` — List all versions of a template.
pub async fn list_template_versions(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let versions = services::list_template_versions(db, org.id, template_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = versions
        .iter()
        .map(|v| serializers::serialize_template_version(&v.version, &v.template_public_id))
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/templates/{id}/versions` — Publish a new version for a template.
pub async fn create_template_version(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let Json(body) = Json::<TemplateVersionCreateRequest>::from_request(&req).await?;

    let detail = services::create_template_version(db, org.id, user.id, template_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload =
        serializers::serialize_template_version(&detail.version, &detail.template_public_id);

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/templates/{id}/versions/{version_id}` — Retrieve a template version by public UUID.
pub async fn retrieve_template_version(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;
    let version_id = params
        .get("version_id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing version id".to_string()))?;

    let detail = services::get_template_version(db, org.id, template_id, version_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload =
        serializers::serialize_template_version(&detail.version, &detail.template_public_id);

    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/templates/{id}/versions/{version_id}` — Delete a template version.
pub async fn delete_template_version(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;
    let version_id = params
        .get("version_id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing version id".to_string()))?;

    services::delete_template_version(db, org.id, user.id, template_id, version_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
