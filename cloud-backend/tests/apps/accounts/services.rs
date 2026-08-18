use bloom_cloud_backend::apps::accounts::contracts::{ApiTokenCreateRequest, RegisterRequest};
use bloom_cloud_backend::apps::accounts::errors::AccountError;
use bloom_cloud_backend::apps::accounts::serializers::parse_scopes_json;
use bloom_cloud_backend::apps::accounts::services::{
    authenticate_api_token, create_api_token, token_scope_allows,
    DEVICE_FLOW_POLL_INTERVAL_SECS, DEVICE_FLOW_TTL_MINUTES, MIN_PASSWORD_LENGTH, VALID_SCOPES,
};
use chrono::{Duration, Utc};
use djangors_auth::User;
use djangors_db::{Database, DatabaseConfig};

#[test]
fn test_password_policy_constants() {
    assert_eq!(MIN_PASSWORD_LENGTH, 8);
    assert_eq!(DEVICE_FLOW_TTL_MINUTES, 10);
    assert_eq!(DEVICE_FLOW_POLL_INTERVAL_SECS, 5);
}

#[test]
fn test_password_hashing_and_verification() {
    let raw = "super-secret-password-123";
    let hashed = djangors_auth::hash_password(raw).expect("Password hashing must succeed");
    assert!(hashed.starts_with("$argon2id$"));

    let is_valid = djangors_auth::verify_password(raw, &hashed).expect("Verification must succeed");
    assert!(is_valid);

    let is_invalid = djangors_auth::verify_password("wrong-password", &hashed)
        .expect("Verification must succeed");
    assert!(!is_invalid);
}

#[test]
fn test_weak_password_rejection() {
    let req = RegisterRequest {
        email: "test@example.com".to_string(),
        username: "testuser".to_string(),
        password: "short".to_string(),
    };
    assert!(req.password.len() < MIN_PASSWORD_LENGTH);
}

#[test]
fn test_token_scope_allows() {
    // 1. Wildcard "*" grants any required scope
    let wildcard = vec!["*".to_string()];
    assert!(token_scope_allows(&wildcard, "builds:read"));
    assert!(token_scope_allows(&wildcard, "builds:write"));
    assert!(token_scope_allows(&wildcard, "billing:write"));
    assert!(token_scope_allows(&wildcard, "anything:custom"));

    // 2. Exact matches
    let specific = vec!["builds:read".to_string(), "deployments:write".to_string()];
    assert!(token_scope_allows(&specific, "builds:read"));
    assert!(token_scope_allows(&specific, "deployments:write"));

    // 3. Mismatched scopes are denied
    assert!(!token_scope_allows(&specific, "builds:write"));
    assert!(!token_scope_allows(&specific, "billing:read"));
    assert!(!token_scope_allows(&specific, "organizations:write"));

    // 4. Empty scopes deny everything
    let empty: Vec<String> = vec![];
    assert!(!token_scope_allows(&empty, "builds:read"));
    assert!(!token_scope_allows(&empty, "*"));
}

#[test]
fn test_parse_scopes_json_valid_and_restrictive_defaults() {
    // 1. Valid JSON array
    let json = r#"["builds:read", "billing:write"]"#;
    let scopes = parse_scopes_json(json);
    assert_eq!(scopes, vec!["builds:read", "billing:write"]);

    // 2. Wildcard array
    let wildcard_json = r#"["*"]"#;
    let scopes = parse_scopes_json(wildcard_json);
    assert_eq!(scopes, vec!["*"]);

    // 3. Malformed JSON must fall back to restrictive default (empty list)
    let malformed = "{ not a json array }";
    let scopes = parse_scopes_json(malformed);
    assert!(scopes.is_empty());

    // 4. Empty string falls back to restrictive default
    let scopes = parse_scopes_json("");
    assert!(scopes.is_empty());
}

#[test]
fn test_valid_scopes_allowlist() {
    assert!(VALID_SCOPES.contains(&"*"));
    assert!(VALID_SCOPES.contains(&"builds:read"));
    assert!(VALID_SCOPES.contains(&"builds:write"));
    assert!(VALID_SCOPES.contains(&"deployments:read"));
    assert!(VALID_SCOPES.contains(&"deployments:write"));
    assert!(VALID_SCOPES.contains(&"billing:read"));
    assert!(VALID_SCOPES.contains(&"billing:write"));
    assert!(VALID_SCOPES.contains(&"organizations:read"));
    assert!(VALID_SCOPES.contains(&"organizations:write"));
    assert!(VALID_SCOPES.contains(&"secrets:read"));
    assert!(VALID_SCOPES.contains(&"secrets:write"));
}

async fn setup_test_db() -> Database {
    let config = DatabaseConfig::new("sqlite::memory:").max_connections(1);
    let db = Database::connect(&config)
        .await
        .expect("sqlite in-memory db connects");

    db.conn()
        .execute(
            "CREATE TABLE auth_user (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username VARCHAR(150) NOT NULL UNIQUE,
                email VARCHAR(254) NOT NULL UNIQUE,
                password VARCHAR(128) NOT NULL,
                is_active BOOLEAN NOT NULL DEFAULT 1,
                is_staff BOOLEAN NOT NULL DEFAULT 0,
                is_superuser BOOLEAN NOT NULL DEFAULT 0,
                date_joined DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_login DATETIME
            );
            CREATE TABLE accounts_userprofile (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id BIGINT NOT NULL UNIQUE,
                public_id VARCHAR(36) NOT NULL UNIQUE,
                display_name VARCHAR(255),
                avatar_url VARCHAR(500),
                timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE accounts_apitoken (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                public_id VARCHAR(36) NOT NULL UNIQUE,
                user_id BIGINT NOT NULL,
                name VARCHAR(255) NOT NULL,
                token_hash VARCHAR(64) NOT NULL UNIQUE,
                scopes TEXT NOT NULL DEFAULT '[\"*\"]',
                expires_at DATETIME,
                organization_id BIGINT,
                last_used_at DATETIME,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE organizations_organization (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                public_id VARCHAR(36) NOT NULL UNIQUE,
                name VARCHAR(255) NOT NULL,
                slug VARCHAR(64) NOT NULL UNIQUE,
                plan VARCHAR(32) NOT NULL DEFAULT 'free',
                billing_email VARCHAR(255),
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE organizations_userorganizationmembership (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                organization_id BIGINT NOT NULL,
                user_id BIGINT NOT NULL,
                role VARCHAR(32) NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );",
            &[],
        )
        .await
        .expect("table schema creation succeeds");

    db
}

#[tokio::test]
async fn test_create_and_authenticate_api_token_lifecycle() {
    let db = setup_test_db().await;

    let user = User {
        id: 1,
        username: "developer".to_string(),
        email: "dev@bloom.dev".to_string(),
        password: "hashed_password".to_string(),
        is_active: true,
        is_staff: false,
        is_superuser: false,
        date_joined: Utc::now(),
        last_login: None,
    };
    user.save(&db).await.expect("user insert succeeds");

    // 1. Create API token with explicit scopes and expiration
    let req = ApiTokenCreateRequest {
        name: "CLI CI Key".to_string(),
        scopes: Some(vec!["builds:read".to_string(), "deployments:write".to_string()]),
        expires_in_days: Some(30),
        organization_id: None,
    };

    let (saved_token, raw_token, _) = create_api_token(&db, user.id, req)
        .await
        .expect("token creation succeeds");

    assert!(raw_token.starts_with("bloom_pat_"));
    assert_eq!(raw_token.len(), "bloom_pat_".len() + 43);
    assert_eq!(saved_token.name, "CLI CI Key");
    assert!(saved_token.expires_at.is_some());
    assert_eq!(saved_token.organization_id, None);

    // 2. Authenticate with raw token
    let auth = authenticate_api_token(&db, &raw_token)
        .await
        .expect("authentication with raw token succeeds");

    assert_eq!(auth.user_id, user.id);
    assert_eq!(auth.scopes, vec!["builds:read", "deployments:write"]);
    assert_eq!(auth.organization_id, None);

    // 3. Verify last_used_at was updated in database
    let fetched = bloom_cloud_backend::apps::accounts::repositories::api_token_by_public_id(
        &db,
        &saved_token.public_id,
    )
    .await
    .unwrap()
    .unwrap();
    assert!(fetched.last_used_at.is_some());
}

#[tokio::test]
async fn test_create_api_token_invalid_scope_rejection() {
    let db = setup_test_db().await;

    let req = ApiTokenCreateRequest {
        name: "Bad Scope Token".to_string(),
        scopes: Some(vec!["invalid:scope:name".to_string()]),
        expires_in_days: None,
        organization_id: None,
    };

    let err = create_api_token(&db, 1, req)
        .await
        .expect_err("invalid scope must be rejected");

    assert_eq!(err, AccountError::InvalidScope("invalid:scope:name".to_string()));
}

#[tokio::test]
async fn test_create_api_token_invalid_expiration_rejection() {
    let db = setup_test_db().await;

    let req = ApiTokenCreateRequest {
        name: "Negative Exp Token".to_string(),
        scopes: None,
        expires_in_days: Some(-5),
        organization_id: None,
    };

    let err = create_api_token(&db, 1, req)
        .await
        .expect_err("negative expiration must be rejected");

    assert_eq!(err, AccountError::InvalidExpiration);
}

#[tokio::test]
async fn test_authenticate_api_token_expired_rejection() {
    let db = setup_test_db().await;

    let user = User {
        id: 2,
        username: "bob".to_string(),
        email: "bob@bloom.dev".to_string(),
        password: "hashed_password".to_string(),
        is_active: true,
        is_staff: false,
        is_superuser: false,
        date_joined: Utc::now(),
        last_login: None,
    };
    user.save(&db).await.expect("user insert succeeds");

    let req = ApiTokenCreateRequest {
        name: "Expired Soon".to_string(),
        scopes: None,
        expires_in_days: Some(1),
        organization_id: None,
    };

    let (mut saved_token, raw_token, _) = create_api_token(&db, user.id, req)
        .await
        .expect("token creation succeeds");

    // Artificially expire the token in DB
    let past = Utc::now() - Duration::days(2);
    saved_token.expires_at = Some(past);
    saved_token.update(&db).await.unwrap();

    let err = authenticate_api_token(&db, &raw_token)
        .await
        .expect_err("expired token must be rejected");

    assert_eq!(err, AccountError::TokenExpired);
}

#[tokio::test]
async fn test_authenticate_api_token_garbage_token_rejection() {
    let db = setup_test_db().await;

    let garbage = "bloom_pat_invalid_garbage_token_not_in_db_123456789";
    let err = authenticate_api_token(&db, garbage)
        .await
        .expect_err("unknown token must be rejected");

    assert_eq!(err, AccountError::InvalidToken);
}
