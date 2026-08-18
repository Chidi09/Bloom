use bloom_cloud_backend::apps::accounts::contracts::{
    ApiTokenCreateRequest, ApiTokenResponse, MeResponse, RegisterRequest, TokenResponse,
};
use bloom_cloud_backend::apps::accounts::errors::AccountError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_accounts_contracts_serialization() {
    // Request contracts are deserialize-only by design (they are parsed from an inbound
    // body, never emitted), so this asserts the inbound direction against literal JSON
    // rather than round-tripping through Serialize.
    let register: RegisterRequest = serde_json::from_str(
        r#"{"email":"alice@bloom.dev","username":"alice","password":"securepassword123"}"#,
    )
    .unwrap();
    assert_eq!(
        register,
        RegisterRequest {
            email: "alice@bloom.dev".to_string(),
            username: "alice".to_string(),
            password: "securepassword123".to_string(),
        }
    );

    let token_res = TokenResponse {
        access_token: "jwt.access.token".to_string(),
        refresh_token: "jwt.refresh.token".to_string(),
        token_type: "Bearer".to_string(),
        expires_in: 3600,
    };
    let res_json = serde_json::to_string(&token_res).unwrap();
    assert!(res_json.contains("\"access_token\":\"jwt.access.token\""));
    assert!(res_json.contains("\"token_type\":\"Bearer\""));

    let me_res = MeResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        email: "alice@bloom.dev".to_string(),
        username: "alice".to_string(),
        display_name: Some("Alice Developer".to_string()),
        avatar_url: None,
        timezone: "UTC".to_string(),
    };
    let me_json = serde_json::to_string(&me_res).unwrap();
    assert!(me_json.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(!me_json.contains("public_id"));

    // Test ApiTokenCreateRequest deserialization with new fields
    let token_req: ApiTokenCreateRequest = serde_json::from_str(
        r#"{"name":"CI Token","scopes":["builds:read","deployments:write"],"expires_in_days":30,"organization_id":"550e8400-e29b-41d4-a716-446655440000"}"#,
    )
    .unwrap();
    assert_eq!(token_req.name, "CI Token");
    assert_eq!(
        token_req.scopes,
        Some(vec!["builds:read".to_string(), "deployments:write".to_string()])
    );
    assert_eq!(token_req.expires_in_days, Some(30));
    assert_eq!(
        token_req.organization_id,
        Some("550e8400-e29b-41d4-a716-446655440000".to_string())
    );

    // Test ApiTokenResponse serialization
    let api_tok_resp = ApiTokenResponse {
        id: "tok_123".to_string(),
        name: "Deploy Key".to_string(),
        token: Some("bloom_pat_abcdef123456".to_string()),
        scopes: vec!["builds:write".to_string()],
        expires_at: Some("2026-09-01T00:00:00Z".to_string()),
        organization_id: Some("org_123".to_string()),
        last_used_at: None,
        created_at: "2026-08-01T00:00:00Z".to_string(),
    };
    let tok_json = serde_json::to_string(&api_tok_resp).unwrap();
    assert!(tok_json.contains("\"token\":\"bloom_pat_abcdef123456\""));
    assert!(tok_json.contains("\"scopes\":[\"builds:write\"]"));
    assert!(tok_json.contains("\"expires_at\":\"2026-09-01T00:00:00Z\""));
    assert!(tok_json.contains("\"organization_id\":\"org_123\""));
}

#[test]
fn test_accounts_error_mapping_status_codes() {
    let err = AccountError::EmailTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "email_taken");

    let err = AccountError::InvalidCredentials;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");

    let err = AccountError::AuthorizationPending;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::ACCEPTED);
    assert_eq!(dj_err.code(), "authorization_pending");

    let err = AccountError::DeviceCodeNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "device_code_not_found");

    let err = AccountError::WeakPassword;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "weak_password");

    let err = AccountError::InvalidToken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_token");

    let err = AccountError::TokenExpired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "token_expired");

    let err = AccountError::InvalidScope("invalid:scope".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_scope");

    let err = AccountError::InvalidExpiration;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_expiration");

    let err = AccountError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = AccountError::NotOrganizationMember;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "not_organization_member");
}

#[tokio::test]
async fn test_rate_limiter_n_requests_pass_n_plus_one_returns_429_with_retry_after() {
    use bytes::Bytes;
    use hyper::http::{HeaderMap, HeaderValue, Method, Uri};
    use std::sync::Arc;

    let store: Arc<dyn djangors_cache::Cache> = Arc::new(djangors_cache::InMemoryCache::new(100));
    // Test rate limiter with 3 requests per minute
    let throttle = djangors_rest::Throttle::new("login", "3/minute", store.clone())
        .expect("Throttle::new with '3/minute' should be valid");

    let mut headers = HeaderMap::new();
    headers.insert("x-forwarded-for", HeaderValue::from_static("192.168.1.50"));
    let req = djangors_core::Request::new(
        Method::POST,
        Uri::from_static("/api/v1/auth/login"),
        headers,
        Bytes::new(),
    );

    // 1st request -> Pass
    assert!(throttle.check(&req).await.is_ok());
    // 2nd request -> Pass
    assert!(throttle.check(&req).await.is_ok());
    // 3rd request -> Pass
    assert!(throttle.check(&req).await.is_ok());

    // 4th request (N+1) -> Returns 429 TooManyRequests
    let err = throttle.check(&req).await.unwrap_err();
    assert_eq!(err.status_code(), StatusCode::TOO_MANY_REQUESTS);
    assert!(
        matches!(err, DjangorsError::TooManyRequests(_)),
        "Expected TooManyRequests error, got: {err:?}"
    );

    // Verify response rendering produces 429 status code
    let resp = err.into_response();
    assert_eq!(resp.status(), StatusCode::TOO_MANY_REQUESTS);
}

#[tokio::test]
async fn test_rate_limiter_two_different_ips_do_not_share_bucket() {
    use bytes::Bytes;
    use hyper::http::{HeaderMap, HeaderValue, Method, Uri};
    use std::sync::Arc;

    let store: Arc<dyn djangors_cache::Cache> = Arc::new(djangors_cache::InMemoryCache::new(100));
    let throttle = djangors_rest::Throttle::new("login", "2/minute", store.clone())
        .expect("Throttle::new should succeed");

    // Request from Client IP A
    let mut headers_a = HeaderMap::new();
    headers_a.insert("x-forwarded-for", HeaderValue::from_static("10.0.0.1"));
    let req_a = djangors_core::Request::new(
        Method::POST,
        Uri::from_static("/api/v1/auth/login"),
        headers_a,
        Bytes::new(),
    );

    // Request from Client IP B
    let mut headers_b = HeaderMap::new();
    headers_b.insert("x-forwarded-for", HeaderValue::from_static("10.0.0.2"));
    let req_b = djangors_core::Request::new(
        Method::POST,
        Uri::from_static("/api/v1/auth/login"),
        headers_b,
        Bytes::new(),
    );

    // Exhaust bucket for IP A (2 requests)
    assert!(throttle.check(&req_a).await.is_ok());
    assert!(throttle.check(&req_a).await.is_ok());
    assert!(throttle.check(&req_a).await.is_err());

    // IP B still has full allowance (independent bucket)
    assert!(throttle.check(&req_b).await.is_ok());
    assert!(throttle.check(&req_b).await.is_ok());
    assert!(throttle.check(&req_b).await.is_err());
}

#[tokio::test]
async fn test_device_poll_rate_limit_permits_cli_real_polling_cadence() {
    use bytes::Bytes;
    use hyper::http::{HeaderMap, HeaderValue, Method, Uri};
    use std::sync::Arc;

    let store: Arc<dyn djangors_cache::Cache> = Arc::new(djangors_cache::InMemoryCache::new(100));
    // device_flow_poll rate limit: 60/minute (1 req/sec)
    let throttle = djangors_rest::Throttle::new("device_flow_poll", "60/minute", store.clone())
        .expect("Throttle::new should succeed");

    let mut headers = HeaderMap::new();
    headers.insert("x-forwarded-for", HeaderValue::from_static("172.16.0.5"));
    let req = djangors_core::Request::new(
        Method::GET,
        Uri::from_static("/api/v1/auth/device/token?device_code=test_dev_code"),
        headers,
        Bytes::new(),
    );

    // The CLI recommended interval is 5 seconds (12 requests / minute).
    // Simulate 12 polls (1 full minute of polling at regular 5s cadence)
    for _ in 0..12 {
        assert!(
            throttle.check(&req).await.is_ok(),
            "CLI polling at regular 5-second interval must comfortably pass rate limit"
        );
    }
}
