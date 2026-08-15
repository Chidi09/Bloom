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

/// Serializes an `ApiToken` row into its API response representation.
/// If `raw_token` is provided (upon creation), it is included once.
pub fn serialize_api_token(token: &ApiToken, raw_token: Option<String>) -> ApiTokenResponse {
    ApiTokenResponse {
        id: token.public_id.clone(),
        name: token.name.clone(),
        token: raw_token,
        last_used_at: token.last_used_at.map(|t| t.to_rfc3339()),
        created_at: token.created_at.to_rfc3339(),
    }
}
