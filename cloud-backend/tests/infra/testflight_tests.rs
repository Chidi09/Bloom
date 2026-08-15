//! Unit tests for App Store Connect / TestFlight infra client.

use bloom_cloud_backend::infra::testflight::{
    AppStoreBuildResource, AppStoreBuildsResponse, AppStoreJwtClaims, AppStoreJwtHeader,
    BetaGroupBuildLinkage, BetaGroupBuildsRequest, TestFlightClient, TestFlightConfig,
    TestFlightError, TestFlightProcessingState, APP_STORE_CONNECT_AUDIENCE,
    DEFAULT_APP_STORE_CONNECT_BASE_URL, DEFAULT_JWT_LIFETIME_SECS, MAX_JWT_LIFETIME_SECS,
};
use bloom_cloud_backend::settings::TestFlightSettings;

#[test]
fn test_testflight_constants() {
    assert_eq!(
        DEFAULT_APP_STORE_CONNECT_BASE_URL,
        "https://api.appstoreconnect.apple.com"
    );
    assert_eq!(APP_STORE_CONNECT_AUDIENCE, "appstoreconnect-v1");
    // Hard ceiling enforced by Apple is 20 minutes (1200 seconds)
    assert_eq!(MAX_JWT_LIFETIME_SECS, 1200);
    // Default lifetime must be strictly under 1200 seconds
    assert_eq!(DEFAULT_JWT_LIFETIME_SECS, 900);
    // A const block makes this a compile-time guarantee: a future edit that raises the
    // default to Apple's ceiling would fail to build rather than fail at runtime with 401s.
    const { assert!(DEFAULT_JWT_LIFETIME_SECS < MAX_JWT_LIFETIME_SECS) };
}

#[test]
fn test_endpoint_url_construction() {
    let base = "https://api.appstoreconnect.apple.com";
    let app_id = "app-uuid-12345";
    let version = "1.0.3";
    let build_id = "build-id-67890";
    let beta_group_id = "group-id-54321";

    // 1. Builds query URL
    let query_url = TestFlightClient::builds_query_url(base, app_id, version);
    assert_eq!(
        query_url,
        "https://api.appstoreconnect.apple.com/v1/builds?filter[app]=app-uuid-12345&filter[version]=1.0.3"
    );

    // 2. Build by ID URL
    let single_url = TestFlightClient::build_by_id_url(base, build_id);
    assert_eq!(
        single_url,
        "https://api.appstoreconnect.apple.com/v1/builds/build-id-67890"
    );

    // 3. Beta group builds assignment URL
    let beta_url = TestFlightClient::beta_group_builds_url(base, beta_group_id);
    assert_eq!(
        beta_url,
        "https://api.appstoreconnect.apple.com/v1/betaGroups/group-id-54321/builds"
    );
}

#[test]
fn test_jwt_header_shape() {
    let header = AppStoreJwtHeader::new("KEY1234567");
    let json = serde_json::to_string(&header).expect("serialize JWT header");
    assert_eq!(json, r#"{"alg":"ES256","kid":"KEY1234567","typ":"JWT"}"#);
}

#[test]
fn test_jwt_claims_construction_and_expiry_validation() {
    let issuer = "12345678-1234-1234-1234-123456789abc";
    let now = 1700000000_i64;

    // 1. Default lifetime (900s) -> valid
    let default_claims = AppStoreJwtClaims::for_current_time(issuer, now).unwrap();
    assert_eq!(default_claims.iss, issuer);
    assert_eq!(default_claims.iat, now);
    assert_eq!(default_claims.exp, now + 900);
    assert_eq!(default_claims.aud, "appstoreconnect-v1");

    // 2. Sub-20 minute explicit lifetime (1199s) -> valid
    let valid_claims = AppStoreJwtClaims::new(issuer, now, now + 1199).unwrap();
    assert_eq!(valid_claims.exp, now + 1199);

    // 3. Exactly 20 minutes (1200s) -> rejected per Apple spec (EXTERNAL_APIS.txt: exp >= 20 mins is 401)
    let rejected_20m = AppStoreJwtClaims::new(issuer, now, now + 1200);
    assert!(matches!(
        rejected_20m,
        Err(TestFlightError::InvalidLifetime(_))
    ));

    // 4. Over 20 minutes (1800s) -> rejected
    let rejected_over = AppStoreJwtClaims::new(issuer, now, now + 1800);
    assert!(matches!(
        rejected_over,
        Err(TestFlightError::InvalidLifetime(_))
    ));

    // 5. Exp <= iat -> rejected
    let rejected_past = AppStoreJwtClaims::new(issuer, now, now - 10);
    assert!(matches!(
        rejected_past,
        Err(TestFlightError::InvalidLifetime(_))
    ));
}

#[test]
fn test_request_body_json_shapes() {
    let req = BetaGroupBuildsRequest {
        data: vec![BetaGroupBuildLinkage::new("build-uuid-789")],
    };

    let json = serde_json::to_string(&req).expect("serialize BetaGroupBuildsRequest");
    assert_eq!(
        json,
        r#"{"data":[{"id":"build-uuid-789","type":"builds"}]}"#
    );
}

#[test]
fn test_unverified_processing_state_mapping() {
    // 1. Valid (case-insensitive)
    let state_upper = TestFlightProcessingState::from_raw("VALID");
    assert_eq!(state_upper, TestFlightProcessingState::Valid);
    assert!(state_upper.is_ready());
    assert!(!state_upper.is_in_progress());

    let state_lower = TestFlightProcessingState::from_raw("valid");
    assert_eq!(state_lower, TestFlightProcessingState::Valid);
    assert!(state_lower.is_ready());

    // 2. Processing
    let state_proc = TestFlightProcessingState::from_raw("PROCESSING");
    assert_eq!(state_proc, TestFlightProcessingState::Processing);
    assert!(!state_proc.is_ready());
    assert!(state_proc.is_in_progress());

    // 3. Failed
    let state_fail = TestFlightProcessingState::from_raw("FAILED");
    assert_eq!(state_fail, TestFlightProcessingState::Failed);
    assert!(!state_fail.is_ready());
    assert!(!state_fail.is_in_progress());

    // 4. Unknown / unverified variants MUST map to Unknown (in-progress) and NEVER fail healthy deployments
    let unknown_state1 = TestFlightProcessingState::from_raw("READY_FOR_TESTING");
    assert_eq!(
        unknown_state1,
        TestFlightProcessingState::Unknown("READY_FOR_TESTING".to_string())
    );
    assert!(unknown_state1.is_in_progress());
    assert!(!unknown_state1.is_ready());

    let unknown_state2 = TestFlightProcessingState::from_raw("QUEUED_FOR_EXPORT");
    assert_eq!(
        unknown_state2,
        TestFlightProcessingState::Unknown("QUEUED_FOR_EXPORT".to_string())
    );
    assert!(unknown_state2.is_in_progress());
}

#[test]
fn test_builds_response_parsing() {
    let raw = r#"{
        "data": [
            {
                "id": "bld-111",
                "type": "builds",
                "attributes": {
                    "version": "1.0.3",
                    "processingState": "VALID",
                    "uploadedDate": "2026-08-15T12:00:00Z"
                }
            }
        ]
    }"#;

    let response: AppStoreBuildsResponse =
        serde_json::from_str(raw).expect("parse Builds response");
    assert_eq!(response.data.len(), 1);
    let build: &AppStoreBuildResource = &response.data[0];
    assert_eq!(build.id, "bld-111");
    assert_eq!(build.r#type, "builds");

    let attrs = build.attributes.as_ref().unwrap();
    assert_eq!(attrs.version.as_deref(), Some("1.0.3"));
    assert_eq!(attrs.processing_state.as_deref(), Some("VALID"));

    let state = TestFlightProcessingState::from_raw(attrs.processing_state.as_deref().unwrap());
    assert_eq!(state, TestFlightProcessingState::Valid);
}

#[test]
fn test_redacted_debug_does_not_print_secrets() {
    let config = TestFlightConfig {
        base_url: "https://api.appstoreconnect.apple.com".to_string(),
        issuer_id: Some("12345678-1234-1234-1234-123456789abc".to_string()),
        key_id: Some("KEY1234567".to_string()),
        private_key: Some("-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEH\n-----END PRIVATE KEY-----".to_string()),
        bearer_token: Some("eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IktFWTEyMzQ1NjcifQ.eyJpc3MiOiIxMjM0NTY3OC0xMjM0LTEyMzQtMTIzNC0xMjM0NTY3ODlhYmMiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MTcwMDAwMDkwMCwiYXVkIjoiYXBwc3RvcmVjb25uZWN0LXYxIn0.secret_sig".to_string()),
    };

    let debug_str = format!("{config:?}");
    assert!(!debug_str.contains("BEGIN PRIVATE KEY"));
    assert!(!debug_str.contains("secret_sig"));
    assert!(!debug_str.contains("eyJhbGci"));
    assert!(debug_str.contains("[REDACTED]"));
}

#[test]
fn test_unconfigured_client() {
    let settings = TestFlightSettings {
        api_url: "https://api.appstoreconnect.apple.com".to_string(),
        issuer_id: None,
        key_id: None,
        private_key: None,
    };

    let client = TestFlightClient::new(&settings, None);
    assert!(!client.is_configured());

    let client_unconfigured = TestFlightClient::unconfigured();
    assert!(!client_unconfigured.is_configured());
}
