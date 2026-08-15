//! HTTP view handlers for the `workflows` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::{WorkflowApproveRequest, WorkflowCreateRequest, WorkflowRunCreateRequest};
use super::errors::WorkflowError;
use super::permissions::{
    CurrentOrganizationId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};
use super::{serializers, services};
use crate::apps::accounts::permissions::require_authenticated;
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

/// Extract the user's role in the active organization.
fn get_user_role(req: &Request) -> OrganizationRole {
    req.ext::<CurrentOrganizationRole>()
        .and_then(|ext| OrganizationRole::from_str(&ext.0).ok())
        .unwrap_or(OrganizationRole::Developer)
}

/// GET `/api/v1/workflows` — List workflows in the current organization (optionally filtered by `app_id`).
pub async fn list_workflows(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WorkflowError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_filter = req.query("app_id");

    let workflows = services::list_workflows(db, org_id, app_filter)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = workflows
        .iter()
        .map(|detail| {
            serializers::serialize_workflow(
                &detail.workflow,
                &detail.app_public_id,
                &detail.organization_public_id,
                &detail.created_by_public_id,
            )
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/workflows` — Create a new workflow definition.
pub async fn create_workflow(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WorkflowError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let Json(body) = Json::<WorkflowCreateRequest>::from_request(&req).await?;

    let detail = services::create_workflow(db, org_id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_workflow(
        &detail.workflow,
        &detail.app_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
    );

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/workflows/{id}` — Retrieve a workflow by its public UUID.
pub async fn retrieve_workflow(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WorkflowError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let workflow_id = params
        .get("id")
        .ok_or_else(|| WorkflowError::ValidationError("Missing workflow id".to_string()))?;

    let detail = services::get_workflow(db, org_id, workflow_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_workflow(
        &detail.workflow,
        &detail.app_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
    );

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/workflows/{id}/runs` — List execution runs for a workflow.
pub async fn list_workflow_runs(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WorkflowError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let workflow_id = params
        .get("id")
        .ok_or_else(|| WorkflowError::ValidationError("Missing workflow id".to_string()))?;

    let runs = services::list_workflow_runs(db, org_id, workflow_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = runs
        .iter()
        .map(|detail| {
            serializers::serialize_workflow_run(
                &detail.run,
                &detail.steps,
                &detail.workflow_public_id,
                &detail.organization_public_id,
                &detail.created_by_public_id,
                detail.approved_by_public_id.as_deref(),
            )
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/workflows/{id}/runs` — Trigger a new workflow execution run.
pub async fn create_workflow_run(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WorkflowError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let queue = req.state::<JobQueue>();

    let workflow_id = params
        .get("id")
        .ok_or_else(|| WorkflowError::ValidationError("Missing workflow id".to_string()))?;

    let body = Json::<WorkflowRunCreateRequest>::from_request(&req)
        .await
        .map(|Json(b)| b)
        .unwrap_or_else(|_| WorkflowRunCreateRequest {
            git_commit: None,
            git_branch: None,
            git_ref: None,
            trigger_event: "manual".to_string(),
        });

    let detail = services::create_workflow_run(db, queue, org_id, user.id, workflow_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_workflow_run(
        &detail.run,
        &detail.steps,
        &detail.workflow_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
        detail.approved_by_public_id.as_deref(),
    );

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/workflows/runs/{id}` — Retrieve a specific workflow run with its ordered steps.
pub async fn retrieve_workflow_run(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WorkflowError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let run_id = params
        .get("id")
        .ok_or_else(|| WorkflowError::ValidationError("Missing workflow run id".to_string()))?;

    let detail = services::get_workflow_run(db, org_id, run_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_workflow_run(
        &detail.run,
        &detail.steps,
        &detail.workflow_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
        detail.approved_by_public_id.as_deref(),
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/workflows/runs/{id}/approve` — Approve or reject a workflow run waiting at an approval gate.
pub async fn approve_workflow_run(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::release_manager();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WorkflowError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let user_role = get_user_role(&req);

    let run_id = params
        .get("id")
        .ok_or_else(|| WorkflowError::ValidationError("Missing workflow run id".to_string()))?;

    let Json(body) = Json::<WorkflowApproveRequest>::from_request(&req).await?;

    let detail = services::approve_workflow_run(db, org_id, user.id, user_role, run_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_workflow_run(
        &detail.run,
        &detail.steps,
        &detail.workflow_public_id,
        &detail.organization_public_id,
        &detail.created_by_public_id,
        detail.approved_by_public_id.as_deref(),
    );

    Response::json(StatusCode::OK, &payload)
}
