//! HTTP view handlers for the `webhosting` domain app.

use std::str::FromStr;
use std::sync::Arc;

use djangors_auth::User;
use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::{CreateCustomDomainRequest, DeployWebRequest};
use super::errors::WebHostingError;
use super::permissions::{
    require_authenticated, CurrentOrganizationId, CurrentOrganizationRole, OrganizationPermission,
    OrganizationRole,
};
use super::services::VerifyDomainParams;
use super::{serializers, services};
use crate::infra::caddy::CaddyClient;
use crate::infra::dns::{DnsResolver, SystemDnsResolver};
use crate::infra::storage::{InMemoryStorage, ObjectStorage};
use crate::settings::{CaddySettings, CloudflareSettings};
use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};

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

/// Retrieve the object-storage backend from request state, with fallback to in-memory storage.
fn get_storage(req: &Request) -> Arc<dyn ObjectStorage> {
    req.state::<Arc<dyn ObjectStorage>>()
        .cloned()
        .unwrap_or_else(|| Arc::new(InMemoryStorage::new()))
}

/// Retrieve the configured Cloudflare apex domain from request state if available.
fn get_apex_domain(req: &Request) -> Option<String> {
    req.state::<CloudflareSettings>()
        .and_then(|s| s.apex_domain.clone())
}

/// Retrieve the DNS resolver instance from request state, falling back to SystemDnsResolver.
fn get_dns_resolver(req: &Request) -> Arc<dyn DnsResolver> {
    req.state::<Arc<dyn DnsResolver>>()
        .cloned()
        .unwrap_or_else(|| Arc::new(SystemDnsResolver::new()))
}

/// Retrieve the Caddy client from request state if configured.
fn get_caddy_client(req: &Request) -> Option<Arc<CaddyClient>> {
    req.state::<Arc<CaddyClient>>().cloned().or_else(|| {
        req.state::<CaddySettings>()
            .map(|s| Arc::new(CaddyClient::new(s)))
    })
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

/// GET `/api/v1/webhosting/deployments` — List web deployments in current organization.
pub async fn list_web_deployments(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WebHostingError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let app_filter = req.query("app_id");
    let env_filter = req.query("environment_id");
    let target_filter = req.query("target");
    let status_filter = req.query("status");

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (details, total) = services::list_web_deployments(
        db,
        org_id,
        services::WebDeploymentListFilters {
            app_public_id: app_filter,
            environment_public_id: env_filter,
            target: target_filter,
            status: status_filter,
        },
        Some(limit),
        Some(offset),
    )
    .await
    .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = details
        .iter()
        .map(|d| {
            let resp = serializers::serialize_web_deployment(
                &d.deployment,
                &d.app_public_id,
                &d.environment_public_id,
                d.release_public_id.as_deref(),
                &d.deployed_by_public_id,
            );
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/webhosting/deployments` — Initiate a new web deployment.
pub async fn deploy_web(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let storage = get_storage(&req);
    let apex_domain = get_apex_domain(&req);
    let user_role = get_user_role(&req, &user);

    let Json(body) = Json::<DeployWebRequest>::from_request(&req).await?;

    let is_production = body.target.trim().eq_ignore_ascii_case("production");
    if is_production {
        let perm = OrganizationPermission::release_manager();
        if !perm.has_permission(&req).await {
            return Err(DjangorsError::from(WebHostingError::Forbidden));
        }
    } else {
        let perm = OrganizationPermission::developer();
        if !perm.has_permission(&req).await {
            return Err(DjangorsError::from(WebHostingError::Forbidden));
        }
    }

    let detail = services::deploy_web(
        db,
        &*storage,
        org_id,
        user.id,
        user_role,
        apex_domain.as_deref(),
        body,
    )
    .await
    .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_web_deployment(
        &detail.deployment,
        &detail.app_public_id,
        &detail.environment_public_id,
        detail.release_public_id.as_deref(),
        &detail.deployed_by_public_id,
    );

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/webhosting/deployments/{id}` — Retrieve a web deployment by public UUID.
pub async fn retrieve_web_deployment(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WebHostingError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let deployment_id = params
        .get("id")
        .ok_or_else(|| WebHostingError::ValidationError("Missing deployment id".to_string()))?;

    let detail = services::get_web_deployment(db, org_id, deployment_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_web_deployment(
        &detail.deployment,
        &detail.app_public_id,
        &detail.environment_public_id,
        detail.release_public_id.as_deref(),
        &detail.deployed_by_public_id,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/webhosting/deployments/{id}/rollback` — Rollback to the previous live deployment.
pub async fn rollback_web_deployment(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let user_role = get_user_role(&req, &user);

    let deployment_id = params
        .get("id")
        .ok_or_else(|| WebHostingError::ValidationError("Missing deployment id".to_string()))?;

    let detail = services::rollback_web_deployment(db, org_id, user.id, user_role, deployment_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_web_deployment(
        &detail.deployment,
        &detail.app_public_id,
        &detail.environment_public_id,
        detail.release_public_id.as_deref(),
        &detail.deployed_by_public_id,
    );

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/webhosting/domains` — List custom domains in current organization.
pub async fn list_custom_domains(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WebHostingError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let apex_domain = get_apex_domain(&req);

    let app_filter = req.query("app_id");

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (details, total) = services::list_custom_domains(
        db,
        org_id,
        app_filter,
        apex_domain.as_deref(),
        Some(limit),
        Some(offset),
    )
    .await
    .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = details
        .iter()
        .map(|d| {
            let resp = serializers::serialize_custom_domain(
                &d.domain,
                &d.app_public_id,
                d.required_records.clone(),
            );
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// POST `/api/v1/webhosting/domains` — Register a custom domain.
pub async fn create_custom_domain(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WebHostingError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let apex_domain = get_apex_domain(&req);

    let Json(body) = Json::<CreateCustomDomainRequest>::from_request(&req).await?;

    let detail = services::create_custom_domain(db, org_id, apex_domain.as_deref(), body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_custom_domain(
        &detail.domain,
        &detail.app_public_id,
        detail.required_records,
    );
    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/webhosting/domains/{id}` — Retrieve a custom domain by public UUID.
pub async fn retrieve_custom_domain(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WebHostingError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let apex_domain = get_apex_domain(&req);

    let domain_id = params
        .get("id")
        .ok_or_else(|| WebHostingError::ValidationError("Missing domain id".to_string()))?;

    let detail = services::get_custom_domain(db, org_id, domain_id, apex_domain.as_deref())
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_custom_domain(
        &detail.domain,
        &detail.app_public_id,
        detail.required_records,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/webhosting/domains/{id}/verify` — Verify or re-verify domain ownership via DNS.
pub async fn verify_custom_domain(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WebHostingError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let dns = get_dns_resolver(&req);
    let caddy = get_caddy_client(&req);
    let apex_domain = get_apex_domain(&req);

    let cf_token = req
        .state::<CloudflareSettings>()
        .and_then(|s| s.api_token.clone());
    let acme_email = req
        .state::<CaddySettings>()
        .and_then(|s| s.acme_email.clone());

    let domain_id = params
        .get("id")
        .ok_or_else(|| WebHostingError::ValidationError("Missing domain id".to_string()))?;

    let verify_params = VerifyDomainParams {
        db,
        dns: &*dns,
        caddy: caddy.as_deref(),
        organization_id: org_id,
        domain_public_id: domain_id,
        apex_domain: apex_domain.as_deref(),
        cloudflare_api_token: cf_token.as_deref(),
        acme_email: acme_email.as_deref(),
    };

    let detail = services::verify_custom_domain(verify_params)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_custom_domain(
        &detail.domain,
        &detail.app_public_id,
        detail.required_records,
    );

    Response::json(StatusCode::OK, &payload)
}

/// DELETE `/api/v1/webhosting/domains/{id}` — Delete a custom domain.
pub async fn delete_custom_domain(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let perm = OrganizationPermission::developer();
    if !perm.has_permission(&req).await {
        return Err(DjangorsError::from(WebHostingError::Forbidden));
    }

    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;
    let caddy = get_caddy_client(&req);

    let domain_id = params
        .get("id")
        .ok_or_else(|| WebHostingError::ValidationError("Missing domain id".to_string()))?;

    services::delete_custom_domain(db, caddy.as_deref(), org_id, domain_id)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}
