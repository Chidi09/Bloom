//! HTTP view handlers for the `billing` domain app.

use std::str::FromStr;

use djangors_auth::User;
use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_rest::Permission;

use super::contracts::{
    CancelSubscriptionRequest, SubscribeRequest, SubscribeResponse, WebhookResponse,
};
use super::errors::BillingError;
use super::permissions::{
    require_authenticated, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};
use super::services::WebhookDeliveryOutcome;
use super::{repositories, serializers, services};
use crate::apps::common::request::{get_db, get_org_id};
use crate::settings::{BachsSettings, PaystackSettings};
use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};

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

/// GET `/billing/plans` — List available billing plans.
pub async fn list_plans(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (plans, total) = services::list_plans(db, Some(limit), Some(offset))
        .await
        .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = plans
        .iter()
        .map(|p| {
            let resp = serializers::serialize_plan(p);
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// GET `/billing/subscription` — Retrieve current organization's subscription details.
pub async fn current_subscription(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(BillingError::Forbidden.into());
    }

    let (sub, plan, _) = services::get_current_subscription(db, org_id)
        .await
        .map_err(DjangorsError::from)?;

    let org_summary = repositories::organization_summary_by_id(db, org_id)
        .await
        .map_err(BillingError::from)?
        .ok_or(BillingError::OrganizationNotFound)?;

    let payload = serializers::serialize_subscription(&sub, &plan, &org_summary.public_id);
    let _ = user;
    Response::json(StatusCode::OK, &payload)
}

/// POST `/billing/subscribe` — Subscribe or change subscription tier (requires Admin or Owner).
pub async fn create_subscription(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let user_role = get_user_role(&req, &user);
    if user_role < OrganizationRole::Admin {
        return Err(BillingError::InsufficientRole.into());
    }

    let Json(body) = Json::<SubscribeRequest>::from_request(&req).await?;

    let bachs_settings = req.state::<BachsSettings>();
    let paystack_settings = req.state::<PaystackSettings>();

    let outcome = services::subscribe_to_plan(
        db,
        org_id,
        user.id,
        body,
        bachs_settings,
        paystack_settings,
        &user.email,
    )
    .await
    .map_err(DjangorsError::from)?;

    let org_summary = repositories::organization_summary_by_id(db, org_id)
        .await
        .map_err(BillingError::from)?
        .ok_or(BillingError::OrganizationNotFound)?;

    let sub_dto = serializers::serialize_subscription(
        &outcome.subscription,
        &outcome.plan,
        &org_summary.public_id,
    );

    let response_dto = SubscribeResponse {
        subscription: sub_dto,
        authorization_url: outcome.authorization_url,
        reference: outcome.reference,
    };

    Response::json(StatusCode::OK, &response_dto)
}

/// POST `/billing/cancel` — Cancel active subscription (requires Admin or Owner).
pub async fn cancel_subscription(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let user_role = get_user_role(&req, &user);
    if user_role < OrganizationRole::Admin {
        return Err(BillingError::InsufficientRole.into());
    }

    let Json(body) = Json::<CancelSubscriptionRequest>::from_request(&req).await?;

    let sub = services::cancel_subscription(db, org_id, user.id, body)
        .await
        .map_err(DjangorsError::from)?;

    let plan = repositories::plan_by_id(db, sub.plan_id.id)
        .await
        .map_err(BillingError::from)?
        .ok_or(BillingError::PlanNotFound)?;

    let org_summary = repositories::organization_summary_by_id(db, org_id)
        .await
        .map_err(BillingError::from)?
        .ok_or(BillingError::OrganizationNotFound)?;

    let payload = serializers::serialize_subscription(&sub, &plan, &org_summary.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// GET `/billing/invoices` — List all invoices for the current organization.
pub async fn list_invoices(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(BillingError::Forbidden.into());
    }

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let (limit, offset) = crate::apps::common::pagination::page_window(&pagination, &req);

    let (invoices_with_subs, total) =
        services::list_invoices(db, org_id, Some(limit), Some(offset))
            .await
            .map_err(DjangorsError::from)?;

    let org_summary = repositories::organization_summary_by_id(db, org_id)
        .await
        .map_err(BillingError::from)?
        .ok_or(BillingError::OrganizationNotFound)?;

    let results: Vec<serde_json::Value> = invoices_with_subs
        .iter()
        .map(|(inv, sub_pub_id)| {
            let resp = serializers::serialize_invoice(inv, sub_pub_id, &org_summary.public_id);
            serde_json::to_value(resp).unwrap_or(serde_json::Value::Null)
        })
        .collect();

    Response::json(StatusCode::OK, &pagination.envelope(&req, total, results))
}

/// GET `/billing/usage` — Retrieve current usage summary and quota status.
pub async fn usage_summary(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let perm = OrganizationPermission::viewer();
    if !perm.has_permission(&req).await {
        return Err(BillingError::Forbidden.into());
    }

    let summary = services::get_usage_summary(db, org_id)
        .await
        .map_err(DjangorsError::from)?;

    let org_summary = repositories::organization_summary_by_id(db, org_id)
        .await
        .map_err(BillingError::from)?
        .ok_or(BillingError::OrganizationNotFound)?;

    let payload = serializers::serialize_usage_summary(&summary, &org_summary.public_id);
    Response::json(StatusCode::OK, &payload)
}

/// POST `/webhooks/bachs` — Inbound Bachs webhook endpoint.
pub async fn handle_bachs_webhook(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;

    let timestamp_header = req
        .header("x-bachs-timestamp")
        .and_then(|v| v.to_str().ok());

    let signature_header = req
        .header("x-bachs-signature")
        .and_then(|v| v.to_str().ok());

    let bachs_settings = req.state::<BachsSettings>();
    let raw_body = req.body_bytes().await;

    let outcome = services::handle_bachs_webhook(
        db,
        bachs_settings,
        raw_body,
        timestamp_header,
        signature_header,
    )
    .await
    .map_err(DjangorsError::from)?;

    let response_dto = match outcome {
        WebhookDeliveryOutcome::Processed {
            event_type: _,
            message,
            reference,
        } => WebhookResponse {
            success: true,
            message,
            reference,
        },
        WebhookDeliveryOutcome::Ignored { event_type } => WebhookResponse {
            success: true,
            message: format!("Event '{event_type}' ignored"),
            reference: None,
        },
    };

    Response::json(StatusCode::OK, &response_dto)
}

/// POST `/webhooks/paystack` — Inbound Paystack webhook endpoint.
pub async fn handle_paystack_webhook(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;

    let signature_header = req
        .header("x-paystack-signature")
        .and_then(|v| v.to_str().ok());

    let paystack_settings = req.state::<PaystackSettings>();
    let raw_body = req.body_bytes().await;

    let outcome =
        services::handle_paystack_webhook(db, paystack_settings, raw_body, signature_header)
            .await
            .map_err(DjangorsError::from)?;

    let response_dto = match outcome {
        WebhookDeliveryOutcome::Processed {
            event_type: _,
            message,
            reference,
        } => WebhookResponse {
            success: true,
            message,
            reference,
        },
        WebhookDeliveryOutcome::Ignored { event_type } => WebhookResponse {
            success: true,
            message: format!("Event '{event_type}' ignored"),
            reference: None,
        },
    };

    Response::json(StatusCode::OK, &response_dto)
}
