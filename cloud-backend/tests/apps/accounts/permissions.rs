use bytes::Bytes;
use chrono::Utc;
use hyper::http::{HeaderMap, HeaderValue, Method, Uri};

use bloom_cloud_backend::apps::accounts::contracts::ApiTokenCreateRequest;
use bloom_cloud_backend::apps::accounts::errors::AccountError;
use bloom_cloud_backend::apps::accounts::permissions::{
    require_authenticated_with_scope, CurrentOrganizationId, CurrentUserId,
};
use bloom_cloud_backend::apps::accounts::services::create_api_token;
use djangors_auth::User;
use djangors_core::Request;
use djangors_db::{Database, DatabaseConfig};

#[test]
fn test_accounts_permissions_extension_types() {
    let uid = CurrentUserId(42);
    assert_eq!(uid.0, 42);

    let org_id = CurrentOrganizationId(100);
    assert_eq!(org_id.0, 100);
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
                public_id VARCHAR(36) NOT NULL UNIQUE,
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
async fn test_require_authenticated_with_scope_enforcement() {
    let db = setup_test_db().await;

    let user = User {
        id: 1,
        username: "dev_scoped".to_string(),
        email: "scoped@bloom.dev".to_string(),
        password: "hashed_password".to_string(),
        is_active: true,
        is_staff: false,
        is_superuser: false,
        date_joined: Utc::now(),
        last_login: None,
    };
    user.save(&db).await.unwrap();

    // Create a token with only "builds:read"
    let req = ApiTokenCreateRequest {
        name: "Builds Read Only".to_string(),
        scopes: Some(vec!["builds:read".to_string()]),
        expires_in_days: None,
        organization_id: None,
    };
    let (_, raw_token, _) = create_api_token(&db, user.id, req).await.unwrap();

    // 1. Request matching allowed scope -> OK
    let mut headers = HeaderMap::new();
    headers.insert(
        "authorization",
        HeaderValue::from_str(&format!("Bearer {raw_token}")).unwrap(),
    );
    let app_state = djangors_core::AppState::new().insert(db.clone());
    let http_req = Request::new(Method::GET, Uri::from_static("/api/v1/builds"), headers, Bytes::new())
        .with_state(app_state.clone());

    let auth_user = require_authenticated_with_scope(&http_req, "builds:read")
        .await
        .expect("builds:read scope should be allowed");
    assert_eq!(auth_user.id, user.id);

    // 2. Request requiring unauthorized scope -> Forbidden
    let err = require_authenticated_with_scope(&http_req, "builds:write")
        .await
        .expect_err("builds:write scope should be denied");
    assert_eq!(err, AccountError::Forbidden);
}

#[tokio::test]
async fn test_org_scoped_token_rejected_against_different_org() {
    let db = setup_test_db().await;

    let user = User {
        id: 10,
        username: "multi_org_user".to_string(),
        email: "multi@bloom.dev".to_string(),
        password: "hashed_password".to_string(),
        is_active: true,
        is_staff: false,
        is_superuser: false,
        date_joined: Utc::now(),
        last_login: None,
    };
    // The primary key is `#[djangors(auto)]`, so `save()` ignores whatever `id` is set on the
    // struct literal and lets the database assign the real one — always rebind from the
    // returned row (via `RETURNING *`) rather than trusting the pre-save struct's `id`.
    let user = user.save(&db).await.unwrap();

    // Insert Org 1 and Org 2 into database
    let org1 = bloom_cloud_backend::apps::organizations::models::Organization {
        id: 101,
        public_id: "org-uuid-1".to_string(),
        name: "Org One".to_string(),
        slug: "org-one".to_string(),
        plan: "pro".to_string(),
        billing_email: None,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };
    let org1 = org1.save(&db).await.unwrap();

    let org2 = bloom_cloud_backend::apps::organizations::models::Organization {
        id: 102,
        public_id: "org-uuid-2".to_string(),
        name: "Org Two".to_string(),
        slug: "org-two".to_string(),
        plan: "pro".to_string(),
        billing_email: None,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };
    let org2 = org2.save(&db).await.unwrap();

    // User is member of Org 1
    let membership = bloom_cloud_backend::apps::organizations::models::UserOrganizationMembership {
        id: 1,
        public_id: "membership-uuid-1".to_string(),
        organization_id: org1.id,
        user_id: user.id,
        role: "admin".to_string(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };
    let _membership = membership.save(&db).await.unwrap();

    // Create a token restricted to Org 1
    let create_req = ApiTokenCreateRequest {
        name: "Org1 Only Token".to_string(),
        scopes: Some(vec!["*".to_string()]),
        expires_in_days: None,
        organization_id: Some(org1.public_id.clone()),
    };
    let (token_model, raw_token, _) = create_api_token(&db, user.id, create_req).await.unwrap();
    assert_eq!(token_model.organization_id, Some(org1.id));

    let app_state = djangors_core::AppState::new().insert(db.clone());

    // Request with CurrentOrganizationId set to Org 1 -> Allowed
    let mut headers = HeaderMap::new();
    headers.insert(
        "authorization",
        HeaderValue::from_str(&format!("Bearer {raw_token}")).unwrap(),
    );
    let mut ext_org1 = hyper::http::Extensions::new();
    ext_org1.insert(CurrentOrganizationId(org1.id));
    let req_org1 = Request::new(Method::GET, Uri::from_static("/api/v1/builds"), headers.clone(), Bytes::new())
        .with_state(app_state.clone())
        .with_extensions(ext_org1);

    let res1 = require_authenticated_with_scope(&req_org1, "builds:read").await;
    assert!(res1.is_ok(), "Request targeting token's org must succeed");

    let scope_res1 = bloom_cloud_backend::apps::accounts::permissions::require_token_scope(&req_org1, "builds:read", org1.id).await;
    assert!(scope_res1.is_ok(), "require_token_scope on target org must succeed");

    // Request with CurrentOrganizationId set to Org 2 -> Rejected with Forbidden
    let mut ext_org2 = hyper::http::Extensions::new();
    ext_org2.insert(CurrentOrganizationId(org2.id));
    let req_org2 = Request::new(Method::GET, Uri::from_static("/api/v1/builds"), headers, Bytes::new())
        .with_state(app_state.clone())
        .with_extensions(ext_org2);

    let res2 = require_authenticated_with_scope(&req_org2, "builds:read").await;
    assert_eq!(res2.unwrap_err(), AccountError::Forbidden, "Request targeting different org must be rejected");

    let scope_res2 = bloom_cloud_backend::apps::accounts::permissions::require_token_scope(&req_org2, "builds:read", org2.id).await;
    assert_eq!(scope_res2.unwrap_err(), AccountError::Forbidden, "require_token_scope on different org must be rejected");
}
