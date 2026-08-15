//! HTTP view handlers for the `emails` domain app.

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_rest::Permission;

use super::contracts::{
    CampaignResponse, CreateCampaignRequest, EmailLogListResponse, PreferencesListResponse,
    PreviewCampaignRequest, UnsubscribeRequest, UnsubscribeResponse, UpdateCampaignRequest,
    UpdatePreferencesRequest,
};
use super::errors::EmailsError;
use super::permissions::{
    require_authenticated, require_staff, CurrentOrganizationId, CurrentOrganizationPublicId,
    OrganizationPermission,
};
use super::{repositories, serializers, services};

use crate::settings::BloomSettings;

/// Retrieve database handle from request state.
fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Retrieve active organization ID from request extensions.
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

/// Retrieve active organization public ID from request extensions or repository lookup.
async fn get_org_public_id(
    req: &Request,
    db: &Database,
    org_id: i64,
) -> Result<String, DjangorsError> {
    if let Some(pub_id_ext) = req.ext::<CurrentOrganizationPublicId>() {
        return Ok(pub_id_ext.0.clone());
    }

    let summary = repositories::organization_summary_by_id(db, org_id)
        .await
        .map_err(EmailsError::from)?
        .ok_or(EmailsError::OrganizationNotFound)?;

    Ok(summary.public_id)
}

/// Retrieve canonical 32-byte signing key for token verification from typed settings.
fn get_signing_key(req: &Request) -> Result<Vec<u8>, DjangorsError> {
    let settings = req.require_state::<BloomSettings>()?;

    // Decode through crypto.rs rather than a second hex loop here: the master key must be
    // interpreted identically everywhere it is read, and two independent decoders can drift
    // on length or case handling without anything failing loudly.
    let key = crate::infra::crypto::decode_hex_key(settings.encryption_key.trim())
        .map_err(|e| DjangorsError::Internal(format!("invalid encryption_key: {e}")))?;

    Ok(key.to_vec())
}

/// GET `/api/v1/notifications/preferences/` — List notification preferences for current user in organization.
pub async fn list_preferences(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let prefs = services::get_user_preferences(db, user.id, org_id)
        .await
        .map_err(DjangorsError::from)?;

    let org_public_id = get_org_public_id(&req, db, org_id).await?;

    let payload = PreferencesListResponse {
        organization_id: org_public_id,
        preferences: prefs
            .iter()
            .map(serializers::serialize_preference)
            .collect(),
    };

    Response::json(StatusCode::OK, &payload)
}

/// PATCH `/api/v1/notifications/preferences/` — Update notification preferences for current user in organization.
pub async fn update_preferences(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let org_id = get_org_id(&req)?;

    let Json(body) = Json::<UpdatePreferencesRequest>::from_request(&req)
        .await
        .map_err(|e| DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_json", e.to_string()))?;

    let prefs = services::update_user_preferences(db, user.id, org_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let org_public_id = get_org_public_id(&req, db, org_id).await?;

    let payload = PreferencesListResponse {
        organization_id: org_public_id,
        preferences: prefs
            .iter()
            .map(serializers::serialize_preference)
            .collect(),
    };

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/notifications/unsubscribe/` — One-click token-authenticated unsubscribe (no session required).
pub async fn unsubscribe(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;

    let Json(body) = Json::<UnsubscribeRequest>::from_request(&req)
        .await
        .map_err(|e| DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_json", e.to_string()))?;

    let signing_key = get_signing_key(&req)?;
    let payload = services::process_unsubscribe(db, &body.token, &signing_key)
        .await
        .map_err(DjangorsError::from)?;

    let res = UnsubscribeResponse {
        success: true,
        message: format!(
            "Successfully unsubscribed from category '{}'.",
            payload.category
        ),
        user_id: Some(payload.user_public_id),
        category: Some(payload.category),
    };

    Response::json(StatusCode::OK, &res)
}

/// GET `/api/v1/organizations/{id}/email-log/` — Retrieve audit email logs for an organization (Admin only).
pub async fn list_email_logs(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let _user = require_authenticated(&req).await?;

    let perm = OrganizationPermission::admin();
    if !perm.has_permission(&req).await {
        return Err(EmailsError::InsufficientRole.into());
    }

    let db = get_db(&req)?;
    let org_param = params.get("id").ok_or_else(|| {
        DjangorsError::api(
            StatusCode::BAD_REQUEST,
            "missing_organization_id",
            "Missing organization ID parameter",
        )
    })?;

    // Find organization by public_id or fallback to request extension org_id
    let org_summary = repositories::organization_summary_by_public_id(db, org_param)
        .await
        .map_err(EmailsError::from)?;

    let org_id = if let Some(os) = org_summary {
        os.id
    } else {
        get_org_id(&req)?
    };

    let (items, total) = services::list_organization_email_logs(db, org_id, 50, 0)
        .await
        .map_err(DjangorsError::from)?;

    let payload = EmailLogListResponse {
        items: items
            .iter()
            .map(|l| serializers::serialize_email_log(l, Some(org_param.to_string())))
            .collect(),
        total,
    };

    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/admin/campaigns/` — List all campaigns (Staff only).
pub async fn list_campaigns(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    require_staff(&user).map_err(DjangorsError::from)?;

    let db = get_db(&req)?;
    let campaigns = services::list_campaigns(db)
        .await
        .map_err(DjangorsError::from)?;

    let payload: Vec<CampaignResponse> = campaigns
        .iter()
        .map(serializers::serialize_campaign)
        .collect();
    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/admin/campaigns/` — Create a new campaign (Staff only).
pub async fn create_campaign(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    require_staff(&user).map_err(DjangorsError::from)?;

    let Json(body) = Json::<CreateCampaignRequest>::from_request(&req)
        .await
        .map_err(|e| DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_json", e.to_string()))?;

    let db = get_db(&req)?;

    let campaign = services::create_campaign(db, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_campaign(&campaign);
    Response::json(StatusCode::CREATED, &payload)
}

/// PATCH `/api/v1/admin/campaigns/{id}/` — Update campaign configuration (Staff only).
pub async fn update_campaign(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    require_staff(&user).map_err(DjangorsError::from)?;

    let campaign_id = params.get("id").ok_or_else(|| {
        DjangorsError::api(
            StatusCode::BAD_REQUEST,
            "missing_campaign_id",
            "Missing campaign ID parameter",
        )
    })?;

    let Json(body) = Json::<UpdateCampaignRequest>::from_request(&req)
        .await
        .map_err(|e| DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_json", e.to_string()))?;

    let db = get_db(&req)?;
    let campaign = services::update_campaign(db, campaign_id, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_campaign(&campaign);
    Response::json(StatusCode::OK, &payload)
}

/// GET `/api/v1/admin/campaigns/{id}/stats/` — Retrieve campaign statistics (Staff only).
pub async fn campaign_stats(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    require_staff(&user).map_err(DjangorsError::from)?;

    let campaign_id = params.get("id").ok_or_else(|| {
        DjangorsError::api(
            StatusCode::BAD_REQUEST,
            "missing_campaign_id",
            "Missing campaign ID parameter",
        )
    })?;

    let db = get_db(&req)?;
    let (campaign, stats) = services::get_campaign_stats(db, campaign_id)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_campaign_stats(&campaign, &stats);
    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/admin/campaigns/{id}/preview/` — Preview a campaign render against a user snapshot without sending (Staff only).
pub async fn preview_campaign(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = require_authenticated(&req).await?;
    require_staff(&user).map_err(DjangorsError::from)?;

    let campaign_id = params.get("id").ok_or_else(|| {
        DjangorsError::api(
            StatusCode::BAD_REQUEST,
            "missing_campaign_id",
            "Missing campaign ID parameter",
        )
    })?;

    let Json(body) = Json::<PreviewCampaignRequest>::from_request(&req)
        .await
        .map_err(|e| DjangorsError::api(StatusCode::BAD_REQUEST, "invalid_json", e.to_string()))?;

    let db = get_db(&req)?;
    let res = services::preview_campaign(db, campaign_id, body)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &res)
}
