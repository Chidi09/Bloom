//! Database queries and persistence operations for the `accounts` app.

use chrono::{DateTime, Utc};
use djangors_auth::User;
use djangors_db::Database;
use djangors_orm::expr::IntoSetExpr;
use djangors_orm::{q, Model, OrmError};

use super::models::{ApiToken, DeviceFlowRequest, UserProfile};

/// Fetch a `User` by primary key.
pub async fn user_by_id(db: &Database, id: i64) -> Result<Option<User>, OrmError> {
    User::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `User` by unique username.
pub async fn user_by_username(db: &Database, username: &str) -> Result<Option<User>, OrmError> {
    User::objects()
        .filter(q!(username = username.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `User` by unique email.
pub async fn user_by_email(db: &Database, email: &str) -> Result<Option<User>, OrmError> {
    User::objects()
        .filter(q!(email = email.to_owned()))?
        .first(db)
        .await
}

/// Persist a new `User` record.
pub async fn insert_user(db: &Database, user: User) -> Result<User, OrmError> {
    user.save(db).await
}

/// Fetch a `UserProfile` by its associated `user_id`.
pub async fn profile_by_user_id(
    db: &Database,
    user_id: i64,
) -> Result<Option<UserProfile>, OrmError> {
    UserProfile::objects()
        .filter(q!(user_id = user_id))?
        .first(db)
        .await
}

/// Fetch a `UserProfile` by public UUID.
pub async fn profile_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<UserProfile>, OrmError> {
    UserProfile::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Persist a new `UserProfile`.
pub async fn insert_profile(db: &Database, profile: UserProfile) -> Result<UserProfile, OrmError> {
    profile.save(db).await
}

/// Update an existing `UserProfile`.
pub async fn update_profile(db: &Database, profile: &UserProfile) -> Result<(), OrmError> {
    profile.update(db).await
}

/// Persist a new `ApiToken`.
pub async fn insert_api_token(db: &Database, token: ApiToken) -> Result<ApiToken, OrmError> {
    token.save(db).await
}

/// Fetch an `ApiToken` by public UUID.
pub async fn api_token_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<ApiToken>, OrmError> {
    ApiToken::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch an `ApiToken` by SHA-256 hash.
pub async fn api_token_by_hash(
    db: &Database,
    token_hash: &str,
) -> Result<Option<ApiToken>, OrmError> {
    ApiToken::objects()
        .filter(q!(token_hash = token_hash.to_owned()))?
        .first(db)
        .await
}

/// Fetch all `ApiToken`s belonging to a user.
pub async fn api_tokens_for_user(db: &Database, user_id: i64) -> Result<Vec<ApiToken>, OrmError> {
    ApiToken::objects()
        .filter(q!(user_id = user_id))?
        .all(db)
        .await
}

/// Delete an `ApiToken` by primary key.
pub async fn delete_api_token_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    ApiToken::objects().filter(q!(id = id))?.delete(db).await
}

/// Update the `last_used_at` timestamp of an `ApiToken`.
pub async fn update_api_token_last_used(
    db: &Database,
    id: i64,
    last_used: DateTime<Utc>,
) -> Result<u64, OrmError> {
    ApiToken::objects()
        .filter(q!(id = id))?
        .update(db, vec![("last_used_at", last_used.into_set_expr())])
        .await
}

/// Persist a new `DeviceFlowRequest`.
pub async fn insert_device_flow(
    db: &Database,
    request: DeviceFlowRequest,
) -> Result<DeviceFlowRequest, OrmError> {
    request.save(db).await
}

/// Fetch a `DeviceFlowRequest` by its opaque `device_code`.
pub async fn device_flow_by_device_code(
    db: &Database,
    device_code: &str,
) -> Result<Option<DeviceFlowRequest>, OrmError> {
    DeviceFlowRequest::objects()
        .filter(q!(device_code = device_code.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `DeviceFlowRequest` by its short `user_code`.
pub async fn device_flow_by_user_code(
    db: &Database,
    user_code: &str,
) -> Result<Option<DeviceFlowRequest>, OrmError> {
    DeviceFlowRequest::objects()
        .filter(q!(user_code = user_code.to_owned()))?
        .first(db)
        .await
}

/// Update status and optional user_id for a device flow request.
/// Marks every still-pending device-flow request whose deadline has passed as `expired`,
/// returning how many rows changed.
///
/// Backs the `expire_device_flows` recurring task. The poll endpoint expires a request lazily
/// when asked about it, so a request the CLI abandons stays `pending` forever and the table
/// accumulates rows that look actionable but never are.
pub async fn expire_stale_device_flows(db: &Database) -> Result<u64, OrmError> {
    DeviceFlowRequest::objects()
        .filter(q!(status = "pending".to_string()))?
        .filter(q!(expires_at__lt = Utc::now()))?
        .update(db, vec![("status", "expired".to_string().into_set_expr())])
        .await
}

pub async fn update_device_flow_status(
    db: &Database,
    id: i64,
    status: &str,
    user_id: Option<i64>,
) -> Result<u64, OrmError> {
    let mut updates = vec![("status", status.to_owned().into_set_expr())];
    if let Some(uid) = user_id {
        updates.push(("user_id", uid.into_set_expr()));
    }
    DeviceFlowRequest::objects()
        .filter(q!(id = id))?
        .update(db, updates)
        .await
}
