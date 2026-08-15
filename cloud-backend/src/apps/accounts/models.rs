//! Persistence models for the `accounts` domain app.

use chrono::{DateTime, Utc};
use djangors_macros::Model;

/// Extends Djangors built-in `djangors_auth::User` with Bloom Cloud-specific fields.
/// One-to-one with `auth_user.id` on `user_id`.
#[derive(Model, Debug, Clone)]
#[djangors(app = "accounts", table_name = "accounts_userprofile")]
pub struct UserProfile {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// Unique foreign key pointing to `auth_user.id`.
    #[djangors(unique)]
    pub user_id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Optional human-readable display name.
    #[djangors(max_length = 255, nullable)]
    pub display_name: Option<String>,

    /// Optional avatar URL.
    #[djangors(max_length = 500, nullable)]
    pub avatar_url: Option<String>,

    /// User's preferred timezone, default "UTC".
    #[djangors(max_length = 64, default = "UTC")]
    pub timezone: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

/// Long-lived machine token for CI and integrations.
#[derive(Model, Debug, Clone)]
#[djangors(app = "accounts", table_name = "accounts_apitoken")]
pub struct ApiToken {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier.
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key to `auth_user.id`.
    #[djangors(db_index)]
    pub user_id: i64,

    /// Human-readable label for this token.
    #[djangors(max_length = 255)]
    pub name: String,

    /// SHA-256 hash of the raw token (64 hex characters).
    #[djangors(max_length = 64, unique)]
    pub token_hash: String,

    /// Timestamp of last successful authentication with this token.
    #[djangors(nullable)]
    pub last_used_at: Option<DateTime<Utc>>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}

/// Device-code flow request for CLI authentication.
#[derive(Model, Debug, Clone)]
#[djangors(app = "accounts", table_name = "accounts_deviceflowrequest")]
pub struct DeviceFlowRequest {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// Opaque device identifier sent by the CLI.
    #[djangors(max_length = 80, unique)]
    pub device_code: String,

    /// Short human-friendly code entered by the user in the browser.
    #[djangors(max_length = 16, db_index)]
    pub user_code: String,

    /// Flow status: `pending`, `authorized`, `expired`, `cancelled`.
    #[djangors(max_length = 32)]
    pub status: String,

    /// Authenticated user ID, set upon authorization in browser.
    #[djangors(nullable)]
    pub user_id: Option<i64>,

    /// Expiration timestamp for this device-code request.
    #[djangors(db_index)]
    pub expires_at: DateTime<Utc>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}
