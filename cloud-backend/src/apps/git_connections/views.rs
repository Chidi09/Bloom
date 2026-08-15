//! HTTP view handlers for the `git_connections` domain app.

use std::str::FromStr;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;

use super::contracts::{GitConnectionCreateRequest, WebhookResponse};
use super::errors::GitConnectionError;
use super::permissions::{
    CurrentOrganizationId, CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationRole,
};
use super::services::WebhookDeliveryOutcome;
use super::{serializers, services};
use crate::apps::accounts::permissions::require_authenticated;
use crate::apps::organizations::models::{Organization, UserOrganizationMembership};
use crate::apps::organizations::repositories as org_repos;
use crate::settings::GitHubSettings;
use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};

/// Retrieve the database handle from request state.
fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Resolve the active organization and verify the user's membership.
async fn resolve_org_context(
    req: &Request,
    db: &Database,
    user_id: i64,
) -> Result<(Organization, UserOrganizationMembership), GitConnectionError> {
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

    // 2. Check X-Bloom-Organization-Id header or public ID extension
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
            .ok_or(GitConnectionError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(GitConnectionError::Forbidden)?;
        return Ok((org, membership));
    }

    // 3. If CurrentOrganizationId was set alone
    if let Some(org_id_ext) = req.ext::<CurrentOrganizationId>() {
        let org = org_repos::organization_by_id(db, org_id_ext.0)
            .await?
            .ok_or(GitConnectionError::OrganizationNotFound)?;
        let membership = org_repos::membership_for_user_in_org(db, user_id, org.id)
            .await?
            .ok_or(GitConnectionError::Forbidden)?;
        return Ok((org, membership));
    }

    Err(GitConnectionError::OrganizationRequired)
}

/// Enforce minimum role in the organization.
fn require_role(
    membership: &UserOrganizationMembership,
    min_role: OrganizationRole,
) -> Result<(), GitConnectionError> {
    let role = OrganizationRole::from_str(&membership.role)
        .map_err(|_| GitConnectionError::InsufficientRole)?;
    if role >= min_role {
        Ok(())
    } else {
        Err(GitConnectionError::InsufficientRole)
    }
}

/// GET `/api/v1/git-connections` — List all Git connections in the active organization.
pub async fn list_connections(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (connections, total) = services::list_connections(db, org.id, Some(limit), Some(offset))
        .await
        .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = connections
        .iter()
        .map(|c| {
            let resp = serializers::serialize_git_connection(c, &org.public_id);
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/git-connections` — Create/link a new Git connection (requires Admin role).
pub async fn create_connection(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let Json(body) = Json::<GitConnectionCreateRequest>::from_request(&req).await?;

    let connection = services::create_connection(db, org.id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_git_connection(&connection, &org.public_id);
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/git-connections/{id}` — Retrieve a Git connection by public UUID.
pub async fn retrieve_connection(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let connection_id = params
        .get("id")
        .ok_or_else(|| GitConnectionError::ValidationError("Missing connection id".to_string()))?;

    let connection = services::get_connection(db, org.id, connection_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_git_connection(&connection, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/git-connections/{id}/repositories` — List repositories available through this connection.
pub async fn list_repositories(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let connection_id = params
        .get("id")
        .ok_or_else(|| GitConnectionError::ValidationError("Missing connection id".to_string()))?;

    let connection = services::get_connection(db, org.id, connection_id)
        .await
        .map_err(DjangorsError::from)?;

    let repos = services::list_repositories(db, &connection)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &repos)
}

/// DELETE `/api/v1/git-connections/{id}` — Delete a Git connection (requires Admin role).
pub async fn delete_connection(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let connection_id = params
        .get("id")
        .ok_or_else(|| GitConnectionError::ValidationError("Missing connection id".to_string()))?;

    let connection = services::get_connection(db, org.id, connection_id)
        .await
        .map_err(DjangorsError::from)?;

    services::delete_connection(db, &connection, user.id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}

/// POST `/webhooks/github` — Inbound GitHub webhook endpoint.
///
/// Route is unauthenticated, but requests are strictly signature-verified via HMAC-SHA256
/// against raw request body bytes and deduplicated by delivery GUID.
pub async fn github_webhook(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;

    let signature_header = req
        .header("x-hub-signature-256")
        .and_then(|v| v.to_str().ok());

    let delivery_header = req
        .header("x-github-delivery")
        .and_then(|v| v.to_str().ok());

    let event_header = req.header("x-github-event").and_then(|v| v.to_str().ok());

    let configured_secret = req
        .state::<GitHubSettings>()
        .and_then(|s| s.webhook_secret.clone());

    let body_bytes = req.body_bytes().await;

    let outcome = services::handle_github_webhook(
        db,
        configured_secret.as_deref(),
        signature_header,
        delivery_header,
        event_header,
        body_bytes,
    )
    .await
    .map_err(DjangorsError::from)?;

    let response_dto = match outcome {
        WebhookDeliveryOutcome::Processed {
            event_type: _,
            message,
        } => WebhookResponse {
            success: true,
            message,
            delivery_id: delivery_header.map(|s| s.to_string()),
        },
        WebhookDeliveryOutcome::AlreadyProcessed { delivery_id } => WebhookResponse {
            success: true,
            message: "Delivery already processed".to_string(),
            delivery_id: Some(delivery_id),
        },
        WebhookDeliveryOutcome::Ignored { event_type } => WebhookResponse {
            success: true,
            message: format!("Event '{event_type}' ignored"),
            delivery_id: delivery_header.map(|s| s.to_string()),
        },
    };

    Response::json(StatusCode::OK, &response_dto)
}

/// POST `/webhooks/gitlab` — Inbound GitLab webhook endpoint.
///
/// Route is unauthenticated, but requests are strictly signature-verified via
/// GitLab Standard Webhooks (HMAC-SHA256) or Legacy token (constant-time comparison)
/// and deduplicated by delivery GUID.
pub async fn gitlab_webhook(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;

    let token_header = req.header("x-gitlab-token").and_then(|v| v.to_str().ok());

    let webhook_id = req.header("webhook-id").and_then(|v| v.to_str().ok());

    let webhook_timestamp = req
        .header("webhook-timestamp")
        .and_then(|v| v.to_str().ok());

    let webhook_signature = req
        .header("webhook-signature")
        .and_then(|v| v.to_str().ok());

    let event_header = req.header("x-gitlab-event").and_then(|v| v.to_str().ok());

    let delivery_header = webhook_id
        .or_else(|| {
            req.header("x-gitlab-delivery")
                .and_then(|v| v.to_str().ok())
        })
        .or_else(|| req.header("x-request-id").and_then(|v| v.to_str().ok()));

    let headers = services::GitLabWebhookHeaders {
        token: token_header,
        webhook_id,
        webhook_timestamp,
        webhook_signature,
        event_type: event_header,
        delivery_id: delivery_header,
    };

    let body_bytes = req.body_bytes().await;

    let outcome = services::handle_gitlab_webhook(db, None, headers, body_bytes)
        .await
        .map_err(DjangorsError::from)?;

    let response_dto = match outcome {
        WebhookDeliveryOutcome::Processed { message, .. } => WebhookResponse {
            success: true,
            message,
            delivery_id: delivery_header.map(|s| s.to_string()),
        },
        WebhookDeliveryOutcome::AlreadyProcessed { delivery_id } => WebhookResponse {
            success: true,
            message: "Delivery already processed".to_string(),
            delivery_id: Some(delivery_id),
        },
        WebhookDeliveryOutcome::Ignored { event_type } => WebhookResponse {
            success: true,
            message: format!("Event '{event_type}' ignored"),
            delivery_id: delivery_header.map(|s| s.to_string()),
        },
    };

    Response::json(StatusCode::OK, &response_dto)
}

/// POST `/webhooks/bitbucket` — Inbound Bitbucket webhook endpoint.
///
/// Route is unauthenticated, but requests are strictly signature-verified via HMAC-SHA256
/// against raw request body bytes and deduplicated by delivery GUID.
/// (Missing signature headers are rejected).
pub async fn bitbucket_webhook(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;

    let signature_header = req.header("x-hub-signature").and_then(|v| v.to_str().ok());

    let delivery_header = req
        .header("x-request-uuid")
        .or_else(|| req.header("x-hook-uuid"))
        .and_then(|v| v.to_str().ok());

    let event_header = req.header("x-event-key").and_then(|v| v.to_str().ok());

    let body_bytes = req.body_bytes().await;

    let outcome = services::handle_bitbucket_webhook(
        db,
        None,
        signature_header,
        delivery_header,
        event_header,
        body_bytes,
    )
    .await
    .map_err(DjangorsError::from)?;

    let response_dto = match outcome {
        WebhookDeliveryOutcome::Processed { message, .. } => WebhookResponse {
            success: true,
            message,
            delivery_id: delivery_header.map(|s| s.to_string()),
        },
        WebhookDeliveryOutcome::AlreadyProcessed { delivery_id } => WebhookResponse {
            success: true,
            message: "Delivery already processed".to_string(),
            delivery_id: Some(delivery_id),
        },
        WebhookDeliveryOutcome::Ignored { event_type } => WebhookResponse {
            success: true,
            message: format!("Event '{event_type}' ignored"),
            delivery_id: delivery_header.map(|s| s.to_string()),
        },
    };

    Response::json(StatusCode::OK, &response_dto)
}
