//! Role, identity, and authentication policies for the `accounts` app.

use djangors_auth::User;
use djangors_core::Request;
use djangors_rest::current_user;

use super::errors::AccountError;

/// Strong typed wrapper for current authenticated user's ID stored in request extensions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CurrentUserId(pub i64);

/// Strong typed wrapper for current organization's ID stored in request extensions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CurrentOrganizationId(pub i64);

/// Require a validly authenticated user (session, token, or JWT).
pub async fn require_authenticated(req: &Request) -> Result<User, AccountError> {
    current_user(req)
        .await
        .ok_or(AccountError::InvalidCredentials)
}
