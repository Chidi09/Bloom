//! HTTP view handlers for the `marketplace` domain app.

use std::str::FromStr;
use std::sync::Arc;

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;

use super::contracts::{
    CreateSellerOnboardingLinkRequest, PurchaseTemplateRequest, RefundPurchaseRequest,
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
use crate::infra::stripe::{HttpStripeClient, MockStripeClient, StripeClient};

/// Retrieve the database handle from request state.
fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Retrieve the Stripe client from request state or initialize from environment/mock fallback.
fn get_stripe_client(req: &Request) -> Arc<dyn StripeClient> {
    if let Some(client) = req.state::<Arc<dyn StripeClient>>() {
        return client.clone();
    }

    if let Ok(client) = HttpStripeClient::from_env() {
        return Arc::new(client);
    }

    Arc::new(MockStripeClient::new())
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

// =========================================================================
// Template Version Views
// =========================================================================

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

// =========================================================================
// Seller Onboarding & Payout Views
// =========================================================================

/// GET `/api/v1/marketplace/seller/account` — View seller payout account status.
pub async fn retrieve_seller_account(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let stripe = get_stripe_client(&req);

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let account =
        services::get_or_create_seller_account(db, stripe.as_ref(), org.id, user.id, None, None)
            .await
            .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_seller_account(&account, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/marketplace/seller/onboarding` — Create Stripe AccountLink for seller onboarding.
pub async fn create_seller_onboarding(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let stripe = get_stripe_client(&req);

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let Json(body) = Json::<CreateSellerOnboardingLinkRequest>::from_request(&req).await?;

    let link = services::create_seller_onboarding_link(db, stripe.as_ref(), org.id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &link)
}

/// POST `/api/v1/marketplace/seller/refresh` — Refresh payouts_enabled state from Stripe.
pub async fn refresh_seller_status(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let stripe = get_stripe_client(&req);

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let account = services::refresh_seller_payout_status(db, stripe.as_ref(), org.id, user.id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_seller_account(&account, &org.public_id);
    Response::json(StatusCode::OK, &payload)
}

// =========================================================================
// Purchases & Entitlements Views
// =========================================================================

/// POST `/api/v1/marketplace/templates/{id}/purchase` — Purchase a paid template.
pub async fn purchase_template(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let stripe = get_stripe_client(&req);

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Developer).map_err(DjangorsError::from)?;

    let template_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing template id".to_string()))?;

    let body = if req.body_bytes().await.is_empty() {
        PurchaseTemplateRequest::default()
    } else {
        Json::<PurchaseTemplateRequest>::from_request(&req)
            .await
            .map(|Json(b)| b)
            .unwrap_or_default()
    };

    let outcome =
        services::purchase_template(db, stripe.as_ref(), org.id, user.id, template_id, body)
            .await
            .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_purchase(
        &outcome.purchase,
        &outcome.buyer_org_public_id,
        &outcome.template_public_id,
        &outcome.template_name,
        outcome.version_public_id,
        &outcome.seller_org_public_id,
        outcome.client_secret,
    );

    Response::json(StatusCode::CREATED, &payload)
}

/// GET `/api/v1/marketplace/purchases` — List all purchases made by the current organization.
pub async fn list_purchases(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let outcomes = services::list_organization_purchases(db, org.id)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<_> = outcomes
        .iter()
        .map(|o| {
            serializers::serialize_purchase(
                &o.purchase,
                &o.buyer_org_public_id,
                &o.template_public_id,
                &o.template_name,
                o.version_public_id.clone(),
                &o.seller_org_public_id,
                o.client_secret.clone(),
            )
        })
        .collect();

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/marketplace/purchases/{id}` — Retrieve a purchase record.
pub async fn retrieve_purchase(
    req: Request,
    params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Viewer).map_err(DjangorsError::from)?;

    let purchase_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing purchase id".to_string()))?;

    let o = services::get_organization_purchase(db, org.id, purchase_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_purchase(
        &o.purchase,
        &o.buyer_org_public_id,
        &o.template_public_id,
        &o.template_name,
        o.version_public_id,
        &o.seller_org_public_id,
        o.client_secret,
    );

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/marketplace/purchases/{id}/refund` — Refund a purchase.
pub async fn refund_purchase(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let stripe = get_stripe_client(&req);

    let (org, membership) = resolve_org_context(&req, db, user.id)
        .await
        .map_err(DjangorsError::from)?;
    require_role(&membership, OrganizationRole::Admin).map_err(DjangorsError::from)?;

    let purchase_id = params
        .get("id")
        .ok_or_else(|| MarketplaceError::ValidationError("Missing purchase id".to_string()))?;

    let body = if req.body_bytes().await.is_empty() {
        RefundPurchaseRequest::default()
    } else {
        Json::<RefundPurchaseRequest>::from_request(&req)
            .await
            .map(|Json(b)| b)
            .unwrap_or_default()
    };

    let outcome =
        services::refund_purchase(db, stripe.as_ref(), org.id, user.id, purchase_id, body)
            .await
            .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_refund(
        &outcome.purchase_public_id,
        &outcome.stripe_refund_id,
        outcome.amount,
        &outcome.currency,
        &outcome.status,
    );

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/templates/{id}/download` — Verify entitlement before template download.
pub async fn download_template(
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

    let decision = services::check_template_access(db, org.id, template_id, None)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_access(
        decision.has_access,
        &decision.reason,
        &decision.template_public_id,
        decision.version_public_id,
    );

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/templates/{id}/versions/{version_id}/download` — Verify entitlement before version download.
pub async fn download_template_version(
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

    let decision = services::check_template_access(db, org.id, template_id, Some(version_id))
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_access(
        decision.has_access,
        &decision.reason,
        &decision.template_public_id,
        decision.version_public_id,
    );

    Response::json(StatusCode::OK, &payload)
}
