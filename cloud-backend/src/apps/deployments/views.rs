//! HTTP view handlers for the `deployments` domain app.

use std::str::FromStr;
use std::sync::Arc;

use djangors_auth::User;
use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_rest::Permission;

use super::contracts::DeploymentCreateRequest;
use super::errors::DeploymentError;
use super::permissions::{
    require_authenticated, require_token_scope, CurrentOrganizationRole, OrganizationPermission,
    OrganizationRole,
};
use super::{serializers, services};
use crate::apps::common::request::{get_db, get_org_id};
use crate::infra::queue::JobQueue;

/// Retrieve the job queue from request state if available.
fn get_queue(req: &Request) -> Option<Arc<JobQueue>> {
    req.state::<Arc<JobQueue>>().cloned()
}

/// Resolves the authenticated user's organization role.
fn get_user_role(req: &Request, user: &User) -> OrganizationRole {
    if user.is_superuser {
        return OrganizationRole::Owner;
    }
    if let Some(role_ext) = req.ext::<CurrentOrganizationRole>() {
        if let Ok(role) = OrganizationRole::from_str(&role_ext.0) {
            return role;
        }
    }
    OrganizationRole::Viewer
}

/// GET `/api/v1/deployments` — List deployments in current organization.
///
/// Uses `CursorPagination` because deployments form an unbounded, append-heavy operational log
/// where concurrency is high and stable keyset ordering without table-scanning COUNTs is desired.
pub async fn list_deployments(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(DeploymentError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    require_token_scope(&req, "deployments:read", org_id).await?;

    let release_filter = req.query("release_id");
    let env_filter = req.query("environment_id");
    let platform_filter = req.query("platform");
    let target_filter = req.query("target");
    let status_filter = req.query("status");

    use djangors_rest::pagination::{CursorPagination, Pagination, REST_PER_PAGE};
    let pagination = CursorPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    // page_size, not slice: the framework documents page_size as the cursor path's size
    // source precisely because that path must not need a row count first.
    let limit = Pagination::page_size(&pagination, &req);

    let (details, next_cursor) = services::list_deployments_cursor(
        db,
        org_id,
        &services::DeploymentListQuery {
            release_public_id: release_filter,
            environment_public_id: env_filter,
            platform_filter,
            target_filter,
            status_filter,
        },
        req.query("cursor"),
        limit,
    )
    .await
    .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = details
        .iter()
        .map(|d| {
            let resp = serializers::serialize_deployment(
                &d.deployment,
                d.release_public_id.as_deref(),
                d.artifact_public_id.as_deref(),
                &d.environment_public_id,
                &d.organization_public_id,
                &d.created_by_public_id,
            );
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    // `count` is omitted rather than fabricated, matching the events endpoint: reporting it
    // would cost the full scan keyset paging exists to avoid.
    Response::json(
        StatusCode::OK,
        &serde_json::json!({
            "results": results,
            "next_cursor": next_cursor,
            "previous_cursor": serde_json::Value::Null,
        }),
    )
}

/// POST `/api/v1/deployments` — Create a new deployment.
pub async fn create_deployment(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    require_token_scope(&req, "deployments:write", org_id).await?;

    let queue = get_queue(&req);
    let user_role = get_user_role(&req, &user);

    let Json(body) = Json::<DeploymentCreateRequest>::from_request(&req).await?;

    let is_prod = services::is_production_target(&body.target.trim().to_ascii_lowercase());
    if is_prod {
        let perm = OrganizationPermission::release_manager();
        if !perm.has_permission(&req).await {
            return Err(DjangorsError::from(DeploymentError::Forbidden));
        }
    } else {
        let perm = OrganizationPermission::developer();
        if !perm.has_permission(&req).await {
            return Err(DjangorsError::from(DeploymentError::Forbidden));
        }
    }

    let detail =
        // A deployment started through the API belongs to no workflow step.
        services::create_deployment(db, queue.as_deref(), org_id, user.id, user_role, body, None)
            .await
            .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_deployment(
        &detail.deployment,
        detail.release_public_id.as_deref(),
        detail.artifact_public_id.as_deref(),
        &detail.environment_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
    );

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/deployments/{id}` — Retrieve a deployment by public UUID.
pub async fn retrieve_deployment(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(DeploymentError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let deployment_id = params
        .get("id")
        .ok_or_else(|| DeploymentError::ValidationError("Missing deployment id".to_string()))?;

    let detail = services::get_deployment(db, org_id, deployment_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_deployment(
        &detail.deployment,
        detail.release_public_id.as_deref(),
        detail.artifact_public_id.as_deref(),
        &detail.environment_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/deployments/{id}/rollback` — Rollback a deployment.
pub async fn rollback_deployment(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let user_role = get_user_role(&req, &user);

    let deployment_id = params
        .get("id")
        .ok_or_else(|| DeploymentError::ValidationError("Missing deployment id".to_string()))?;

    let detail = services::rollback_deployment(db, org_id, user.id, user_role, deployment_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_deployment(
        &detail.deployment,
        detail.release_public_id.as_deref(),
        detail.artifact_public_id.as_deref(),
        &detail.environment_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
    );

    Response::json(StatusCode::OK, &payload)
}
