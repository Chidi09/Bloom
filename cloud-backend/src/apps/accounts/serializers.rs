//! Serializers and representation helpers for the `accounts` app.

use djangors_auth::User;

use super::contracts::{ApiTokenResponse, MeResponse};
use super::models::{ApiToken, UserProfile};

/// Serializes a `UserProfile` and its associated `User` into a `MeResponse`.
pub fn serialize_me(user: &User, profile: &UserProfile) -> MeResponse {
    MeResponse {
        id: profile.public_id.clone(),
        email: user.email.clone(),
        username: user.username.clone(),
        display_name: profile.display_name.clone(),
        avatar_url: profile.avatar_url.clone(),
        timezone: profile.timezone.clone(),
    }
}

/// Parse scopes JSON string into a list of scope strings.
///
/// Falls back to restrictive defaults (empty list, zero permissions) on missing or malformed JSON.
pub fn parse_scopes_json(raw: &str) -> Vec<String> {
    serde_json::from_str(raw).unwrap_or_default()
}

/// Serializes an `ApiToken` row into its API response representation.
/// If `raw_token` is provided (upon creation), it is included once.
/// If `org_public_id` is provided (when organization-scoped), it is included.
pub fn serialize_api_token(
    token: &ApiToken,
    raw_token: Option<String>,
    org_public_id: Option<String>,
) -> ApiTokenResponse {
    ApiTokenResponse {
        id: token.public_id.clone(),
        name: token.name.clone(),
        token: raw_token,
        scopes: parse_scopes_json(&token.scopes),
        expires_at: token.expires_at.map(|t| t.to_rfc3339()),
        organization_id: org_public_id,
        last_used_at: token.last_used_at.map(|t| t.to_rfc3339()),
        created_at: token.created_at.to_rfc3339(),
    }
}
