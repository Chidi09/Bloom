//! HTTP view handlers for the `deployments` domain app.

use std::str::FromStr;
use std::sync::Arc;

use djangors_auth::User;
use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::DeploymentCreateRequest;
use super::errors::DeploymentError;
use super::permissions::{
    require_authenticated, CurrentOrganizationId, CurrentOrganizationRole, OrganizationPermission,
    OrganizationRole,
};
use super::{serializers, services};
use crate::infra::queue::JobQueue;

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

    let release_filter = req.query("release_id");
    let env_filter = req.query("environment_id");
    let platform_filter = req.query("platform");
    let target_filter = req.query("target");
    let status_filter = req.query("status");

    let details = services::list_deployments(
        db,
        org_id,
        release_filter,
        env_filter,
        platform_filter,
        target_filter,
        status_filter,
    )
    .await
    .map_err(DjangorsError::from)?;

    let payload: Vec<_> = details
        .iter()
        .map(|d| {
            serializers::serialize_deployment(
                &d.deployment,
                d.release_public_id.as_deref(),
                d.artifact_public_id.as_deref(),
                &d.environment_public_id,
                &d.organization_public_id,
                &d.created_by_public_id,
            )
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/deployments` — Create a new deployment.
pub async fn create_deployment(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
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
        services::create_deployment(db, queue.as_deref(), org_id, user.id, user_role, body)
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
