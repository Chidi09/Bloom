//! Unit tests for App Store Connect / TestFlight infra client.

use bloom_cloud_backend::infra::testflight::{
    AppStoreBuildResource, AppStoreBuildsResponse, AppStoreJwtClaims, AppStoreJwtHeader,
    BetaGroupBuildLinkage, BetaGroupBuildsRequest, TestFlightClient, TestFlightConfig,
    TestFlightError, TestFlightProcessingState, APP_STORE_CONNECT_AUDIENCE,
    DEFAULT_APP_STORE_CONNECT_BASE_URL, DEFAULT_JWT_LIFETIME_SECS, MAX_JWT_LIFETIME_SECS,
};
use bloom_cloud_backend::settings::TestFlightSettings;

/// Test-only EC P-256 (prime256v1) PKCS#8 PEM private key for verifying ES256 JWT signing.
/// A REAL, throwaway P-256 private key, generated solely for these tests.
///
/// It must be a genuine key: ES256 signing rejects a structurally-plausible but invalid one,
/// and an earlier hand-written constant here (a PEM whose private scalar was all zeros) failed
/// with `InvalidEcdsaKey`. Never point this at a key used anywhere real.
const TEST_EC_PRIVATE_KEY_PEM: &str = concat!(
    "-----BEGIN PRIVATE KEY-----\n",
    "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg0eKOBO999/e6aK9r\n",
    "14ES1WjXYddeY03nzPyh12oYlqqhRANCAAQVBh6XExzG5+QhVBmlOVqd5lKvDIaH\n",
    "Xwsjt//oXwYYgy+lzLQDqX9ENEYqGk/K+F0fI7lcpHpTYn5UfaKP35As\n",
    "-----END PRIVATE KEY-----\n"
);

/// The matching public key. Signature verification needs the PUBLIC half; passing the private
/// PEM to `from_ec_pem` fails with `InvalidKeyFormat`.
const TEST_EC_PUBLIC_KEY_PEM: &str = concat!(
    "-----BEGIN PUBLIC KEY-----\n",
    "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEFQYelxMcxufkIVQZpTlaneZSrwyG\n",
    "h18LI7f/6F8GGIMvpcy0A6l/RDRGKhpPyvhdHyO5XKR6U2J+VH2ij9+QLA==\n",
    "-----END PUBLIC KEY-----\n"
);

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

    // 3. Exactly 20 minutes (1200s) -> valid (at most 1200 seconds / 20 minutes per Apple spec)
    let valid_20m = AppStoreJwtClaims::new(issuer, now, now + 1200);
    assert!(valid_20m.is_ok());

    // 4. Over 20 minutes (1201s) -> rejected
    let rejected_over = AppStoreJwtClaims::new(issuer, now, now + 1201);
    assert!(matches!(
        rejected_over,
        Err(TestFlightError::InvalidLifetime(_))
    ));

    // 5. 1800s -> rejected
    let rejected_1800 = AppStoreJwtClaims::new(issuer, now, now + 1800);
    assert!(matches!(
        rejected_1800,
        Err(TestFlightError::InvalidLifetime(_))
    ));

    // 6. Exp <= iat -> rejected
    let rejected_past = AppStoreJwtClaims::new(issuer, now, now - 10);
    assert!(matches!(
        rejected_past,
        Err(TestFlightError::InvalidLifetime(_))
    ));
}

#[test]
fn test_apple_jwt_minting_header_and_claims() {
    let issuer_id = "87654321-4321-4321-4321-cba987654321";
    let key_id = "ABC123XYZ4";
    let now = 1700000000_i64;

    let token =
        TestFlightClient::create_signed_jwt(issuer_id, key_id, TEST_EC_PRIVATE_KEY_PEM, now)
            .expect("minting ES256 JWT should succeed");

    // 1. Verify header via jsonwebtoken::decode_header
    let header = jsonwebtoken::decode_header(&token).expect("decode JWT header");
    assert_eq!(header.alg, jsonwebtoken::Algorithm::ES256);
    assert_eq!(header.typ.as_deref(), Some("JWT"));
    assert_eq!(header.kid.as_deref(), Some(key_id));

    // 2. Decode claims payload and verify fields
    let decoding_key = jsonwebtoken::DecodingKey::from_ec_pem(TEST_EC_PUBLIC_KEY_PEM.as_bytes())
        .expect("build decoding key from EC test public PEM");
    let mut validation = jsonwebtoken::Validation::new(jsonwebtoken::Algorithm::ES256);
    validation.set_audience(&["appstoreconnect-v1"]);
    validation.validate_exp = false;

    let token_data = jsonwebtoken::decode::<AppStoreJwtClaims>(&token, &decoding_key, &validation)
        .expect("decode and verify token signature");

    assert_eq!(token_data.claims.iss, issuer_id);
    assert_eq!(token_data.claims.aud, "appstoreconnect-v1");
    assert_eq!(token_data.claims.iat, now);
    assert_eq!(token_data.claims.exp, now + 900);
    assert!(token_data.claims.exp - token_data.claims.iat <= 1200);

    // 3. Confirm no "scope" claim is present in claims payload for team keys
    let claims_json = serde_json::to_string(&token_data.claims).expect("serialize claims");
    assert!(!claims_json.contains("scope"));
}

#[test]
fn test_apple_jwt_malformed_inputs() {
    let now = 1700000000_i64;

    // 1. Empty issuer_id
    let err_iss = TestFlightClient::create_signed_jwt("", "KEY123", TEST_EC_PRIVATE_KEY_PEM, now);
    assert!(matches!(err_iss, Err(TestFlightError::Auth(_))));

    // 2. Empty key_id
    let err_kid = TestFlightClient::create_signed_jwt("uuid", "", TEST_EC_PRIVATE_KEY_PEM, now);
    assert!(matches!(err_kid, Err(TestFlightError::Auth(_))));

    // 3. Empty private_key PEM
    let err_key = TestFlightClient::create_signed_jwt("uuid", "KEY123", "", now);
    assert!(matches!(err_key, Err(TestFlightError::Auth(_))));

    // 4. Corrupt / invalid EC PEM
    let err_corrupt = TestFlightClient::create_signed_jwt(
        "uuid",
        "KEY123",
        "-----BEGIN PRIVATE KEY-----\nnot-a-valid-ec-key\n-----END PRIVATE KEY-----",
        now,
    );
    assert!(matches!(err_corrupt, Err(TestFlightError::Auth(_))));
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
fn test_processing_state_variants_and_mapping() {
    // 1. Valid (terminal success)
    let state_upper = TestFlightProcessingState::from_raw("VALID");
    assert_eq!(state_upper, TestFlightProcessingState::Valid);
    assert!(state_upper.is_ready());
    assert!(!state_upper.is_in_progress());
    assert!(!state_upper.is_failed());

    let state_lower = TestFlightProcessingState::from_raw("valid");
    assert_eq!(state_lower, TestFlightProcessingState::Valid);
    assert!(state_lower.is_ready());
    assert!(!state_lower.is_failed());

    // 2. Processing (in progress)
    let state_proc = TestFlightProcessingState::from_raw("PROCESSING");
    assert_eq!(state_proc, TestFlightProcessingState::Processing);
    assert!(!state_proc.is_ready());
    assert!(state_proc.is_in_progress());
    assert!(!state_proc.is_failed());

    let state_proc_lower = TestFlightProcessingState::from_raw("processing");
    assert_eq!(state_proc_lower, TestFlightProcessingState::Processing);
    assert!(state_proc_lower.is_in_progress());

    // 3. Failed (terminal failure)
    let state_fail = TestFlightProcessingState::from_raw("FAILED");
    assert_eq!(state_fail, TestFlightProcessingState::Failed);
    assert!(!state_fail.is_ready());
    assert!(!state_fail.is_in_progress());
    assert!(state_fail.is_failed());

    let state_fail_lower = TestFlightProcessingState::from_raw("failed");
    assert_eq!(state_fail_lower, TestFlightProcessingState::Failed);
    assert!(state_fail_lower.is_failed());

    // 4. Invalid (terminal failure)
    let state_invalid = TestFlightProcessingState::from_raw("INVALID");
    assert_eq!(state_invalid, TestFlightProcessingState::Failed);
    assert!(!state_invalid.is_ready());
    assert!(!state_invalid.is_in_progress());
    assert!(state_invalid.is_failed());

    let state_invalid_lower = TestFlightProcessingState::from_raw("invalid");
    assert_eq!(state_invalid_lower, TestFlightProcessingState::Failed);
    assert!(state_invalid_lower.is_failed());

    // 5. Unknown / unverified variants MUST map to Unknown (treated as in-progress) and NEVER fail healthy deployments
    let unknown_state1 = TestFlightProcessingState::from_raw("READY_FOR_TESTING");
    assert_eq!(
        unknown_state1,
        TestFlightProcessingState::Unknown("READY_FOR_TESTING".to_string())
    );
    assert!(unknown_state1.is_in_progress());
    assert!(!unknown_state1.is_ready());
    assert!(!unknown_state1.is_failed());

    let unknown_state2 = TestFlightProcessingState::from_raw("QUEUED_FOR_EXPORT");
    assert_eq!(
        unknown_state2,
        TestFlightProcessingState::Unknown("QUEUED_FOR_EXPORT".to_string())
    );
    assert!(unknown_state2.is_in_progress());
    assert!(!unknown_state2.is_ready());
    assert!(!unknown_state2.is_failed());
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
