//! Business rules, authentication, device-code flow, and token operations for `accounts`.

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine as _;
use chrono::Utc;
use djangors_auth::{AuthBackend, ModelBackend, User};
use djangors_db::Database;
use rand::RngCore;
use sha2::{Digest, Sha256};

use super::contracts::{
    ApiTokenCreateRequest, ApiTokenResponse, DeviceFlowInitResponse, MeResponse, RegisterRequest,
    TokenResponse,
};
use super::errors::AccountError;
use super::models::{ApiToken, DeviceFlowRequest, UserProfile};
use super::{repositories, serializers};

/// Fixed allow-list of valid permission scopes.
pub const VALID_SCOPES: &[&str] = &[
    "*",
    "builds:read",
    "builds:write",
    "deployments:read",
    "deployments:write",
    "billing:read",
    "billing:write",
    "organizations:read",
    "organizations:write",
    "secrets:read",
    "secrets:write",
];

/// Checks if granted scopes satisfy the required permission scope.
/// Returns true if `granted` contains `"*"` or contains `required` exactly.
pub fn token_scope_allows(granted: &[String], required: &str) -> bool {
    granted.iter().any(|s| s == "*" || s == required)
}

/// Resolved identity and permission metadata for a successfully authenticated API token.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthenticatedApiToken {
    /// Associated user ID.
    pub user_id: i64,
    /// Granted permission scope strings.
    pub scopes: Vec<String>,
    /// Optional organization restriction.
    pub organization_id: Option<i64>,
    /// Public UUID identifier of the token.
    pub token_public_id: String,
}

/// Minimum password length enforced across the application.
pub const MIN_PASSWORD_LENGTH: usize = 8;

/// Lifetime of a device-flow authorization request in minutes.
pub const DEVICE_FLOW_TTL_MINUTES: i64 = 10;

/// Default polling interval in seconds recommended to the CLI.
pub const DEVICE_FLOW_POLL_INTERVAL_SECS: i64 = 5;

/// Register a new user account and associated profile.
pub async fn register_user(
    db: &Database,
    req: RegisterRequest,
) -> Result<(User, UserProfile), AccountError> {
    if req.password.len() < MIN_PASSWORD_LENGTH {
        return Err(AccountError::WeakPassword);
    }

    if repositories::user_by_email(db, &req.email).await?.is_some() {
        return Err(AccountError::EmailTaken);
    }

    if repositories::user_by_username(db, &req.username)
        .await?
        .is_some()
    {
        return Err(AccountError::UsernameTaken);
    }

    let hashed = djangors_auth::hash_password(&req.password)?;
    let now = Utc::now();

    let user = User {
        id: 0,
        username: req.username,
        email: req.email,
        password: hashed,
        is_active: true,
        is_staff: false,
        is_superuser: false,
        date_joined: now,
        last_login: None,
    };
    let user = repositories::insert_user(db, user).await?;

    let profile = UserProfile {
        id: 0,
        user_id: user.id,
        public_id: uuid::Uuid::new_v4().to_string(),
        display_name: None,
        avatar_url: None,
        timezone: "UTC".to_string(),
        created_at: now,
        updated_at: now,
    };
    let profile = repositories::insert_profile(db, profile).await?;

    Ok((user, profile))
}

/// Authenticate username and password, issuing access and refresh JWTs.
pub async fn login_user(
    db: &Database,
    username: &str,
    password: &str,
    secret: &str,
) -> Result<TokenResponse, AccountError> {
    let backend = ModelBackend;
    let user = backend
        .authenticate(db, username, password)
        .await?
        .ok_or(AccountError::InvalidCredentials)?;

    if !user.is_active {
        return Err(AccountError::InvalidCredentials);
    }

    let access_token = djangors_rest::encode_jwt(user.id, secret);

    // Issue refresh token (standard HS256 JWT containing user_id)
    let refresh_token = djangors_rest::encode_jwt(user.id, secret);

    Ok(TokenResponse {
        access_token,
        refresh_token,
        token_type: "Bearer".to_string(),
        expires_in: 3600,
    })
}

/// Refresh an existing JWT session using a valid refresh token.
pub async fn refresh_jwt(
    db: &Database,
    refresh_token: &str,
    secret: &str,
) -> Result<TokenResponse, AccountError> {
    let user_id = djangors_rest::decode_jwt(refresh_token, secret)
        .map_err(|_| AccountError::InvalidCredentials)?;

    let user = repositories::user_by_id(db, user_id)
        .await?
        .ok_or(AccountError::InvalidCredentials)?;

    if !user.is_active {
        return Err(AccountError::InvalidCredentials);
    }

    let access_token = djangors_rest::encode_jwt(user.id, secret);

    let new_refresh_token = djangors_rest::encode_jwt(user.id, secret);

    Ok(TokenResponse {
        access_token,
        refresh_token: new_refresh_token,
        token_type: "Bearer".to_string(),
        expires_in: 3600,
    })
}

/// Initiate a CLI device-code flow request.
pub async fn initiate_device_flow(
    db: &Database,
    api_url: &str,
) -> Result<DeviceFlowInitResponse, AccountError> {
    let mut dev_bytes = [0u8; 20];
    rand::rngs::OsRng.fill_bytes(&mut dev_bytes);
    let device_code = dev_bytes
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect::<String>();

    let mut user_bytes = [0u8; 4];
    rand::rngs::OsRng.fill_bytes(&mut user_bytes);
    let user_code = format!(
        "{:04X}-{:04X}",
        u16::from_be_bytes([user_bytes[0], user_bytes[1]]),
        u16::from_be_bytes([user_bytes[2], user_bytes[3]])
    );

    let now = Utc::now();
    let expires_at = now + chrono::Duration::minutes(DEVICE_FLOW_TTL_MINUTES);

    let request = DeviceFlowRequest {
        id: 0,
        device_code: device_code.clone(),
        user_code: user_code.clone(),
        status: "pending".to_string(),
        user_id: None,
        expires_at,
        created_at: now,
    };
    repositories::insert_device_flow(db, request).await?;

    let verification_uri = format!("{api_url}/device");

    Ok(DeviceFlowInitResponse {
        device_code,
        user_code,
        verification_uri,
        expires_in: DEVICE_FLOW_TTL_MINUTES * 60,
        interval: DEVICE_FLOW_POLL_INTERVAL_SECS,
    })
}

/// Poll the device-code flow status and return tokens once authorized.
pub async fn poll_device_flow(
    db: &Database,
    device_code: &str,
    secret: &str,
) -> Result<TokenResponse, AccountError> {
    let req = repositories::device_flow_by_device_code(db, device_code)
        .await?
        .ok_or(AccountError::DeviceCodeNotFound)?;

    let now = Utc::now();
    if req.expires_at < now {
        if req.status != "expired" {
            repositories::update_device_flow_status(db, req.id, "expired", None).await?;
        }
        return Err(AccountError::DeviceCodeExpired);
    }

    match req.status.as_str() {
        "pending" => Err(AccountError::AuthorizationPending),
        "authorized" => {
            let user_id = req.user_id.ok_or(AccountError::InvalidCredentials)?;
            let user = repositories::user_by_id(db, user_id)
                .await?
                .ok_or(AccountError::InvalidCredentials)?;

            if !user.is_active {
                return Err(AccountError::InvalidCredentials);
            }

            let access_token = djangors_rest::encode_jwt(user.id, secret);

            let refresh_token = djangors_rest::encode_jwt(user.id, secret);

            Ok(TokenResponse {
                access_token,
                refresh_token,
                token_type: "Bearer".to_string(),
                expires_in: 3600,
            })
        }
        "expired" => Err(AccountError::DeviceCodeExpired),
        _ => Err(AccountError::InvalidCredentials),
    }
}

/// Authorize a device-code flow using the human user-code.
pub async fn authorize_device_flow(
    db: &Database,
    user_code: &str,
    user_id: i64,
) -> Result<(), AccountError> {
    let trimmed = user_code.trim();
    let req = repositories::device_flow_by_user_code(db, trimmed)
        .await?
        .ok_or(AccountError::DeviceCodeNotFound)?;

    let now = Utc::now();
    if req.expires_at < now {
        repositories::update_device_flow_status(db, req.id, "expired", None).await?;
        return Err(AccountError::DeviceCodeExpired);
    }

    repositories::update_device_flow_status(db, req.id, "authorized", Some(user_id)).await?;
    Ok(())
}

/// Create a new long-lived API token, returning the model instance, raw secret string, and optional org public UUID.
pub async fn create_api_token(
    db: &Database,
    user_id: i64,
    req: ApiTokenCreateRequest,
) -> Result<(ApiToken, String, Option<String>), AccountError> {
    // 1. Validate scopes
    let scopes_json = if let Some(ref scopes) = req.scopes {
        for scope in scopes {
            if !VALID_SCOPES.contains(&scope.as_str()) {
                return Err(AccountError::InvalidScope(scope.clone()));
            }
        }
        serde_json::to_string(scopes).map_err(|e| AccountError::Database(e.to_string()))?
    } else {
        "[\"*\"]".to_string()
    };

    // 2. Validate expiration days
    let expires_at = if let Some(days) = req.expires_in_days {
        if days <= 0 {
            return Err(AccountError::InvalidExpiration);
        }
        Some(Utc::now() + chrono::Duration::days(days))
    } else {
        None
    };

    // 3. Validate organization restriction (if specified)
    let (org_internal_id, org_public_id) = if let Some(ref org_pub_id) = req.organization_id {
        let org = crate::apps::organizations::repositories::organization_by_public_id(db, org_pub_id)
            .await?
            .ok_or(AccountError::OrganizationNotFound)?;
        let _membership = crate::apps::organizations::repositories::membership_for_user_in_org(
            db, user_id, org.id,
        )
        .await?
        .ok_or(AccountError::NotOrganizationMember)?;
        (Some(org.id), Some(org.public_id))
    } else {
        (None, None)
    };

    // 4. Generate raw token: bloom_pat_<43 random URL-safe base64 chars>
    let mut bytes = [0u8; 32];
    rand::rngs::OsRng.fill_bytes(&mut bytes);
    let raw_secret = URL_SAFE_NO_PAD.encode(bytes);
    let raw_token = format!("bloom_pat_{raw_secret}");

    // 5. Hash token: SHA-256 hex
    let mut hasher = Sha256::new();
    hasher.update(raw_token.as_bytes());
    let token_hash = format!("{:x}", hasher.finalize());

    let token = ApiToken {
        id: 0,
        public_id: uuid::Uuid::new_v4().to_string(),
        user_id,
        name: req.name.trim().to_string(),
        token_hash,
        scopes: scopes_json,
        expires_at,
        organization_id: org_internal_id,
        last_used_at: None,
        created_at: Utc::now(),
    };

    let saved = repositories::insert_api_token(db, token).await?;
    Ok((saved, raw_token, org_public_id))
}

/// Authenticate a raw API token string, enforcing hash validity, expiration, and updating last_used_at.
pub async fn authenticate_api_token(
    db: &Database,
    raw_token: &str,
) -> Result<AuthenticatedApiToken, AccountError> {
    let mut hasher = Sha256::new();
    hasher.update(raw_token.as_bytes());
    let token_hash = format!("{:x}", hasher.finalize());

    let token = repositories::api_token_by_hash(db, &token_hash)
        .await?
        .ok_or(AccountError::InvalidToken)?;

    if let Some(expires_at) = token.expires_at {
        if expires_at < Utc::now() {
            return Err(AccountError::TokenExpired);
        }
    }

    repositories::update_api_token_last_used(db, token.id, Utc::now()).await?;

    let scopes = serializers::parse_scopes_json(&token.scopes);

    Ok(AuthenticatedApiToken {
        user_id: token.user_id,
        scopes,
        organization_id: token.organization_id,
        token_public_id: token.public_id,
    })
}

/// Retrieve all API tokens for a user serialized with their organization public IDs.
pub async fn list_api_tokens(
    db: &Database,
    user_id: i64,
) -> Result<Vec<ApiTokenResponse>, AccountError> {
    let tokens = repositories::api_tokens_for_user(db, user_id).await?;
    let mut responses = Vec::with_capacity(tokens.len());
    for token in tokens {
        let org_pub_id = if let Some(org_id) = token.organization_id {
            crate::apps::organizations::repositories::organization_by_id(db, org_id)
                .await?
                .map(|o| o.public_id)
        } else {
            None
        };
        responses.push(serializers::serialize_api_token(&token, None, org_pub_id));
    }
    Ok(responses)
}

/// Revoke an API token by public UUID.
pub async fn revoke_api_token(
    db: &Database,
    user_id: i64,
    public_id: &str,
    is_superuser: bool,
) -> Result<(), AccountError> {
    let token = repositories::api_token_by_public_id(db, public_id)
        .await?
        .ok_or(AccountError::NotFound("api_token"))?;

    if token.user_id != user_id && !is_superuser {
        return Err(AccountError::Forbidden);
    }

    repositories::delete_api_token_by_id(db, token.id).await?;
    Ok(())
}

/// Retrieve the current user's profile and account information.
pub async fn me(db: &Database, user_id: i64) -> Result<MeResponse, AccountError> {
    let profile = repositories::profile_by_user_id(db, user_id)
        .await?
        .ok_or(AccountError::NotFound("user_profile"))?;

    let user = repositories::user_by_id(db, user_id)
        .await?
        .ok_or(AccountError::NotFound("user"))?;

    Ok(serializers::serialize_me(&user, &profile))
}
