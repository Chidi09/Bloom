//! HTTP handler functions for the `accounts` domain app.

use djangors_core::extract::{FromRequest, Json};
use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use serde_json::json;

use super::contracts::{
    ApiTokenCreateRequest, DeviceAuthorizeRequest, LoginRequest, RefreshRequest, RegisterRequest,
};
use super::errors::AccountError;
use super::{permissions, serializers, services};
use crate::settings::BloomSettings;

/// Retrieve the database handle from request state.
fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Retrieve the JWT secret key and API base URL from settings.
fn get_settings(req: &Request) -> (String, String) {
    if let Some(bloom) = req.state::<BloomSettings>() {
        (bloom.jwt_secret.clone(), bloom.api_url.clone())
    } else if let Some(core) = req.state::<djangors_core::DjangorsSettings>() {
        (core.secret_key.clone(), "http://localhost:8000".to_string())
    } else {
        (
            "bloom-default-secret-key-32-bytes-long".to_string(),
            "http://localhost:8000".to_string(),
        )
    }
}

/// POST `/api/v1/auth/register` — Register a new user account and profile.
pub async fn register(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let Json(body) = Json::<RegisterRequest>::from_request(&req).await?;

    let (user, profile) = services::register_user(db, body)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_me(&user, &profile);
    Response::json(StatusCode::CREATED, &payload)
}

/// POST `/api/v1/auth/login` — Authenticate with username and password.
pub async fn login(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let (secret, _) = get_settings(&req);
    let Json(body) = Json::<LoginRequest>::from_request(&req).await?;

    let tokens = services::login_user(db, &body.username, &body.password, &secret)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &tokens)
}

/// POST `/api/v1/auth/device` — Initiate CLI device-code flow.
pub async fn device_flow_init(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let (_, api_url) = get_settings(&req);

    let res = services::initiate_device_flow(db, &api_url)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &res)
}

/// GET `/api/v1/auth/device/token` — Poll for authorization token using device_code.
pub async fn device_flow_poll(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let (secret, _) = get_settings(&req);

    let device_code = req
        .query("device_code")
        .map(|s| s.to_string())
        .ok_or(AccountError::NotFound("device_code query parameter"))?;

    let tokens = services::poll_device_flow(db, &device_code, &secret)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &tokens)
}

/// POST `/api/v1/auth/device/authorize` — Authorize a device-code flow from browser dashboard.
pub async fn device_flow_authorize(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = permissions::require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let Json(body) = Json::<DeviceAuthorizeRequest>::from_request(&req).await?;

    services::authorize_device_flow(db, &body.user_code, user.id)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &json!({ "status": "authorized" }))
}

/// POST `/api/v1/auth/token` — Create a new machine API token.
pub async fn create_api_token(
    req: Request,
    _params: PathParams,
) -> Result<Response, DjangorsError> {
    let user = permissions::require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let Json(body) = Json::<ApiTokenCreateRequest>::from_request(&req).await?;

    let (token, raw_token) = services::create_api_token(db, user.id, &body.name)
        .await
        .map_err(DjangorsError::from)?;

    let payload = serializers::serialize_api_token(&token, Some(raw_token));
    Response::json(StatusCode::CREATED, &payload)
}

/// DELETE `/api/v1/auth/token/{id}` — Revoke an API token by public UUID.
pub async fn revoke_api_token(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    let user = permissions::require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let token_id = params
        .get("id")
        .ok_or(AccountError::NotFound("token id path parameter"))?;

    services::revoke_api_token(db, user.id, token_id, user.is_superuser)
        .await
        .map_err(DjangorsError::from)?;

    Ok(Response::text(StatusCode::NO_CONTENT, ""))
}

/// POST `/api/v1/auth/refresh` — Refresh access token using a refresh token.
pub async fn refresh_token(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let db = get_db(&req)?;
    let (secret, _) = get_settings(&req);
    let Json(body) = Json::<RefreshRequest>::from_request(&req).await?;

    let tokens = services::refresh_jwt(db, &body.refresh_token, &secret)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &tokens)
}

/// GET `/api/v1/auth/me` — Retrieve current authenticated user details.
pub async fn me(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    let user = permissions::require_authenticated(&req).await?;
    let db = get_db(&req)?;

    let payload = services::me(db, user.id)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &payload)
}

/// POST `/api/v1/auth/logout` — Invalidate user session.
pub async fn logout(_req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    Response::json(StatusCode::OK, &json!({ "message": "logged out" }))
}
