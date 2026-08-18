//! Role, identity, and authentication policies for the `accounts` app.

use djangors_auth::User;
use djangors_core::Request;
use djangors_db::Database;
use djangors_rest::current_user;

use super::errors::AccountError;
pub use super::services::{token_scope_allows, AuthenticatedApiToken};

/// Strong typed wrapper for current authenticated user's ID stored in request extensions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CurrentUserId(pub i64);

/// Strong typed wrapper for current organization's ID stored in request extensions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CurrentOrganizationId(pub i64);

/// Authenticates a request via Bearer API token (`bloom_pat_...`) or falls back to JWT/session.
/// Returns the authenticated `User` and optionally the `AuthenticatedApiToken` if authenticated via PAT.
pub async fn authenticate_request(
    req: &Request,
) -> Result<(User, Option<AuthenticatedApiToken>), AccountError> {
    if let Some(auth_header) = req
        .headers()
        .get("authorization")
        .and_then(|v| v.to_str().ok())
    {
        let trimmed = auth_header.trim();
        let token_str = if let Some(stripped) = trimmed.strip_prefix("Bearer ") {
            stripped.trim()
        } else if let Some(stripped) = trimmed.strip_prefix("bearer ") {
            stripped.trim()
        } else {
            ""
        };

        if token_str.starts_with("bloom_pat_") {
            let db = req.state::<Database>().ok_or_else(|| {
                AccountError::Database("Database not found in request state".to_string())
            })?;

            let auth_token = super::services::authenticate_api_token(db, token_str).await?;
            let user = super::repositories::user_by_id(db, auth_token.user_id)
                .await?
                .ok_or(AccountError::InvalidCredentials)?;

            if !user.is_active {
                return Err(AccountError::InvalidCredentials);
            }

            return Ok((user, Some(auth_token)));
        }
    }

    let user = current_user(req)
        .await
        .ok_or(AccountError::InvalidCredentials)?;

    Ok((user, None))
}

/// Require a validly authenticated user (session, token, or JWT).
pub async fn require_authenticated(req: &Request) -> Result<User, AccountError> {
    let (user, _) = authenticate_request(req).await?;
    Ok(user)
}

/// Require an authenticated user and, if authenticated via an API token, enforce that the token
/// has the required scope and matches the active organization (if restricted).
pub async fn require_authenticated_with_scope(
    req: &Request,
    required_scope: &str,
) -> Result<User, AccountError> {
    let (user, maybe_token) = authenticate_request(req).await?;

    if let Some(token) = maybe_token {
        // 1. Enforce scope allow-list check
        if !token_scope_allows(&token.scopes, required_scope) {
            return Err(AccountError::Forbidden);
        }

        // 2. Enforce organization restriction if token is scoped to a specific org
        if let Some(token_org_id) = token.organization_id {
            if let Some(current_org) = req.ext::<CurrentOrganizationId>() {
                if token_org_id != current_org.0 {
                    return Err(AccountError::Forbidden);
                }
            }
        }
    }

    Ok(user)
}

/// Enforces scope and organization boundaries if the request was authenticated with an API token.
///
/// If authenticated via a normal JWT session, this check passes unconditionally.
/// If authenticated via an API token:
/// - Verifies `token_scope_allows(&token.scopes, required_scope)`
/// - If `token.organization_id` is restricted (`Some(id)`), ensures it matches `target_org_id`.
pub async fn require_token_scope(
    req: &Request,
    required_scope: &str,
    target_org_id: i64,
) -> Result<(), AccountError> {
    let (_, maybe_token) = authenticate_request(req).await?;
    if let Some(token) = maybe_token {
        if !token_scope_allows(&token.scopes, required_scope) {
            return Err(AccountError::Forbidden);
        }
        if let Some(token_org_id) = token.organization_id {
            if token_org_id != target_org_id {
                return Err(AccountError::Forbidden);
            }
        }
    }
    Ok(())
}
