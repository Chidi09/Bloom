use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use async_trait::async_trait;
use bloom_cloud_backend::infra::executor::{
    CommandExecutor, CommandOutput, CommandSpec, ExecutorError,
};
use bloom_cloud_backend::infra::testflight::{
    build_altool_upload_args, classify_altool_error, extract_json_from_output,
    parse_altool_errors_from_output, AltoolJsonResponse, AltoolProductError, AltoolUploadOptions,
    AppStoreBuildResource, AppStoreBuildsResponse, AppStoreJwtClaims, AppStoreJwtHeader,
    BetaGroupBuildLinkage, BetaGroupBuildsRequest, TestFlightClient, TestFlightConfig,
    TestFlightError, TestFlightPlatform, TestFlightProcessingState, ALTOOL_PASSWORD_ENV_VAR,
    APP_STORE_CONNECT_AUDIENCE, DEFAULT_APP_STORE_CONNECT_BASE_URL, DEFAULT_JWT_LIFETIME_SECS,
    IPA_UPLOAD_TIMEOUT, MAX_JWT_LIFETIME_SECS,
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

/// Test fake CommandExecutor recording invocations and playing back responses.
#[derive(Clone, Default)]
struct FakeCommandExecutor {
    recorded: Arc<Mutex<Vec<CommandSpec>>>,
    responses: Arc<Mutex<Vec<Result<CommandOutput, ExecutorError>>>>,
}

impl FakeCommandExecutor {
    fn new() -> Self {
        Self {
            recorded: Arc::new(Mutex::new(Vec::new())),
            responses: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn push_success(&self, stdout: impl Into<String>, stderr: impl Into<String>) {
        self.responses.lock().unwrap().push(Ok(CommandOutput {
            exit_code: Some(0),
            stdout: stdout.into(),
            stderr: stderr.into(),
            duration: Duration::from_millis(10),
        }));
    }

    fn push_error(&self, err: ExecutorError) {
        self.responses.lock().unwrap().push(Err(err));
    }

    fn recorded_specs(&self) -> Vec<CommandSpec> {
        self.recorded.lock().unwrap().clone()
    }
}

#[async_trait]
impl CommandExecutor for FakeCommandExecutor {
    async fn run(&self, spec: &CommandSpec) -> Result<CommandOutput, ExecutorError> {
        self.recorded.lock().unwrap().push(spec.clone());
        let mut responses = self.responses.lock().unwrap();
        if !responses.is_empty() {
            responses.remove(0)
        } else {
            Ok(CommandOutput {
                exit_code: Some(0),
                stdout: String::new(),
                stderr: String::new(),
                duration: Duration::from_millis(10),
            })
        }
    }
}

#[test]
fn test_altool_platform_constants_and_parsing() {
    assert_eq!(IPA_UPLOAD_TIMEOUT, Duration::from_secs(1800));
    assert_eq!(ALTOOL_PASSWORD_ENV_VAR, "ALTOOL_PASSWORD");

    assert_eq!(TestFlightPlatform::Ios.as_str(), "ios");
    assert_eq!(TestFlightPlatform::Macos.as_str(), "macos");
    assert_eq!(TestFlightPlatform::AppletvOs.as_str(), "appletvos");
    assert_eq!(TestFlightPlatform::VisionOs.as_str(), "visionos");

    assert_eq!(
        TestFlightPlatform::from_str_opt("ios"),
        Some(TestFlightPlatform::Ios)
    );
    assert_eq!(
        TestFlightPlatform::from_str_opt("iOS"),
        Some(TestFlightPlatform::Ios)
    );
    assert_eq!(
        TestFlightPlatform::from_str_opt("macos"),
        Some(TestFlightPlatform::Macos)
    );
    assert_eq!(
        TestFlightPlatform::from_str_opt("appletvos"),
        Some(TestFlightPlatform::AppletvOs)
    );
    assert_eq!(
        TestFlightPlatform::from_str_opt("tvos"),
        Some(TestFlightPlatform::AppletvOs)
    );
    assert_eq!(
        TestFlightPlatform::from_str_opt("visionos"),
        Some(TestFlightPlatform::VisionOs)
    );
    assert_eq!(TestFlightPlatform::from_str_opt("android"), None);
}

#[test]
fn test_altool_argv_construction_platforms() {
    // 1. iOS
    let args_ios = build_altool_upload_args(
        "/tmp/build/Runner.ipa",
        TestFlightPlatform::Ios,
        "dev@example.com",
        ALTOOL_PASSWORD_ENV_VAR,
    );
    assert_eq!(
        args_ios,
        vec![
            "altool",
            "--upload-app",
            "-f",
            "/tmp/build/Runner.ipa",
            "-t",
            "ios",
            "-u",
            "dev@example.com",
            "-p",
            "@env:ALTOOL_PASSWORD",
            "--output-format",
            "json"
        ]
    );

    // 2. macOS
    let args_macos = build_altool_upload_args(
        "/tmp/build/App.pkg",
        TestFlightPlatform::Macos,
        "dev@example.com",
        ALTOOL_PASSWORD_ENV_VAR,
    );
    assert_eq!(
        args_macos,
        vec![
            "altool",
            "--upload-app",
            "-f",
            "/tmp/build/App.pkg",
            "-t",
            "macos",
            "-u",
            "dev@example.com",
            "-p",
            "@env:ALTOOL_PASSWORD",
            "--output-format",
            "json"
        ]
    );

    // 3. tvOS
    let args_tvos = build_altool_upload_args(
        "/tmp/build/TvApp.ipa",
        TestFlightPlatform::AppletvOs,
        "dev@example.com",
        ALTOOL_PASSWORD_ENV_VAR,
    );
    assert_eq!(
        args_tvos,
        vec![
            "altool",
            "--upload-app",
            "-f",
            "/tmp/build/TvApp.ipa",
            "-t",
            "appletvos",
            "-u",
            "dev@example.com",
            "-p",
            "@env:ALTOOL_PASSWORD",
            "--output-format",
            "json"
        ]
    );

    // 4. visionOS
    let args_visionos = build_altool_upload_args(
        "/tmp/build/VisionApp.ipa",
        TestFlightPlatform::VisionOs,
        "dev@example.com",
        ALTOOL_PASSWORD_ENV_VAR,
    );
    assert_eq!(
        args_visionos,
        vec![
            "altool",
            "--upload-app",
            "-f",
            "/tmp/build/VisionApp.ipa",
            "-t",
            "visionos",
            "-u",
            "dev@example.com",
            "-p",
            "@env:ALTOOL_PASSWORD",
            "--output-format",
            "json"
        ]
    );
}

#[tokio::test]
async fn test_altool_password_in_env_never_in_argv() {
    let executor = FakeCommandExecutor::new();
    executor.push_success(
        r#"{"tool-version":"16.0","os-version":"15.0","product-errors":[]}"#,
        "",
    );

    let client = TestFlightClient::unconfigured();
    let secret_password = "app-specific-secret-password-xyz-987";

    let result = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "apple-dev@example.com",
            secret_password,
        )
        .await;

    assert!(result.is_ok());

    let specs = executor.recorded_specs();
    assert_eq!(specs.len(), 1);
    let spec = &specs[0];

    // Program must be xcrun
    assert_eq!(spec.program, "xcrun");

    // Argv check: must contain "@env:ALTOOL_PASSWORD", and MUST NEVER contain the actual password
    assert!(spec.args.contains(&"@env:ALTOOL_PASSWORD".to_string()));
    for arg in &spec.args {
        assert!(
            !arg.contains(secret_password),
            "Secret password leaked into argv argument: {arg}"
        );
    }

    // Environment check: password appears in env overlay
    assert_eq!(
        spec.env,
        vec![(
            ALTOOL_PASSWORD_ENV_VAR.to_string(),
            secret_password.to_string()
        )]
    );

    // CommandSpec manual Debug redaction verification
    let debug_repr = format!("{spec:?}");
    assert!(
        !debug_repr.contains(secret_password),
        "Secret password leaked in CommandSpec Debug representation: {debug_repr}"
    );
    assert!(debug_repr.contains("[redacted]"));
}

#[tokio::test]
async fn test_altool_successful_upload_json() {
    let executor = FakeCommandExecutor::new();
    executor.push_success(
        r#"{
            "tool-version": "16.0",
            "os-version": "15.0",
            "tool-path": "/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework",
            "product-errors": []
        }"#,
        "",
    );

    let client = TestFlightClient::unconfigured();
    let res = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "dev@example.com",
            "app-spec-pass",
        )
        .await;

    assert!(res.is_ok());
}

#[tokio::test]
async fn test_altool_binary_rejected_entitlement_error() {
    let executor = FakeCommandExecutor::new();
    let failure_json = r#"{
        "product-errors": [
            {
                "code": 90034,
                "message": "Missing or invalid entitlement for push notifications (ITMS-90034).",
                "userInfo": {
                    "NSLocalizedDescription": "Missing or invalid entitlement for push notifications (ITMS-90034)."
                }
            }
        ]
    }"#;
    executor.push_error(ExecutorError::NonZeroExit {
        code: Some(1),
        stderr: failure_json.to_string(),
    });

    let client = TestFlightClient::unconfigured();
    let err = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "dev@example.com",
            "app-spec-pass",
        )
        .await
        .unwrap_err();

    match &err {
        TestFlightError::BinaryRejected { code, message } => {
            assert_eq!(code.as_deref(), Some("90034"));
            assert!(message.contains("Missing or invalid entitlement"));
        }
        other => panic!("Expected BinaryRejected error variant, got: {other:?}"),
    }

    assert!(!err.is_retryable());
}

#[tokio::test]
async fn test_altool_binary_rejected_bundle_id_and_provisioning() {
    let executor = FakeCommandExecutor::new();
    let failure_json = r#"{
        "product-errors": [
            {
                "code": "ITMS-90189",
                "message": "Redundant or invalid provisioning profile detected.",
                "userInfo": {
                    "NSLocalizedDescription": "Redundant or invalid provisioning profile detected."
                }
            }
        ]
    }"#;
    executor.push_error(ExecutorError::NonZeroExit {
        code: Some(1),
        stderr: failure_json.to_string(),
    });

    let client = TestFlightClient::unconfigured();
    let err = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "dev@example.com",
            "app-spec-pass",
        )
        .await
        .unwrap_err();

    match &err {
        TestFlightError::BinaryRejected { code, message } => {
            assert_eq!(code.as_deref(), Some("ITMS-90189"));
            assert!(message.contains("Redundant or invalid provisioning profile"));
        }
        other => panic!("Expected BinaryRejected error variant, got: {other:?}"),
    }

    assert!(!err.is_retryable());
}

#[tokio::test]
async fn test_altool_auth_rejected_error() {
    let executor = FakeCommandExecutor::new();
    let auth_failure_json = r#"{
        "product-errors": [
            {
                "code": -1011,
                "message": "Unable to authenticate with App Store Connect.",
                "userInfo": {
                    "NSLocalizedDescription": "Unable to authenticate with App Store Connect.",
                    "NSLocalizedFailureReason": "Invalid Apple ID username or App-Specific Password."
                }
            }
        ]
    }"#;
    executor.push_error(ExecutorError::NonZeroExit {
        code: Some(1),
        stderr: auth_failure_json.to_string(),
    });

    let client = TestFlightClient::unconfigured();
    let err = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "dev@example.com",
            "app-spec-pass",
        )
        .await
        .unwrap_err();

    match &err {
        TestFlightError::Auth(msg) => {
            assert!(msg.contains("Unable to authenticate"));
        }
        other => panic!("Expected Auth error variant, got: {other:?}"),
    }

    assert!(!err.is_retryable());
}

#[tokio::test]
async fn test_altool_transport_retryable_error() {
    // The code below is deliberately NOT in the numerically-matched transient set: retry
    // classification must come from the message text, because Apple publishes no exhaustive
    // list of transient upload codes.
    let executor = FakeCommandExecutor::new();
    let transport_json = r#"{
        "product-errors": [
            {
                "code": 1519,
                "message": "Connection to the ingest server timed out. Please try again later.",
                "userInfo": {
                    "NSLocalizedDescription": "Connection to the ingest server timed out. Please try again later."
                }
            }
        ]
    }"#;
    executor.push_error(ExecutorError::NonZeroExit {
        code: Some(1),
        stderr: transport_json.to_string(),
    });

    let client = TestFlightClient::unconfigured();
    let err = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "dev@example.com",
            "app-spec-pass",
        )
        .await
        .unwrap_err();

    match &err {
        TestFlightError::Transport { message, retryable } => {
            assert!(*retryable);
            assert!(message.contains("timed out"));
        }
        other => panic!("Expected Transport error variant, got: {other:?}"),
    }

    assert!(err.is_retryable());
}

#[tokio::test]
async fn test_altool_executor_timeout_retryable() {
    let executor = FakeCommandExecutor::new();
    executor.push_error(ExecutorError::Timeout { seconds: 1800 });

    let client = TestFlightClient::unconfigured();
    let err = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "dev@example.com",
            "app-spec-pass",
        )
        .await
        .unwrap_err();

    match &err {
        TestFlightError::Transport { message, retryable } => {
            assert!(*retryable);
            assert!(message.contains("1800 seconds"));
        }
        other => panic!("Expected Transport error variant, got: {other:?}"),
    }

    assert!(err.is_retryable());
}

#[tokio::test]
async fn test_altool_tooling_absent_maps_to_not_configured() {
    // 1. Spawn failure (binary missing)
    let exec1 = FakeCommandExecutor::new();
    exec1.push_error(ExecutorError::Spawn(
        "Failed to spawn 'xcrun': No such file or directory".to_string(),
    ));

    let client = TestFlightClient::unconfigured();
    let err1 = client
        .upload_ipa_tooling(&exec1, "/tmp/app.ipa", "dev@example.com", "app-spec-pass")
        .await
        .unwrap_err();

    assert!(matches!(err1, TestFlightError::NotConfigured(_)));

    // 2. xcrun error diagnostic in stderr
    let exec2 = FakeCommandExecutor::new();
    exec2.push_error(ExecutorError::NonZeroExit {
        code: Some(72),
        stderr: "xcrun: error: unable to find utility \"altool\", not a developer tool or in PATH"
            .to_string(),
    });

    let err2 = client
        .upload_ipa_tooling(&exec2, "/tmp/app.ipa", "dev@example.com", "app-spec-pass")
        .await
        .unwrap_err();

    assert!(matches!(err2, TestFlightError::NotConfigured(_)));
}

#[tokio::test]
async fn test_altool_non_zero_exit_unparseable_output() {
    let executor = FakeCommandExecutor::new();
    executor.push_error(ExecutorError::NonZeroExit {
        code: Some(137),
        stderr: "FATAL: Process killed by SIGKILL (OOM or runner signal)".to_string(),
    });

    let client = TestFlightClient::unconfigured();
    let err = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "dev@example.com",
            "app-spec-pass",
        )
        .await
        .unwrap_err();

    match &err {
        TestFlightError::ExecutionFailed { exit_code, stderr } => {
            assert_eq!(*exit_code, Some(137));
            assert_eq!(
                stderr,
                "FATAL: Process killed by SIGKILL (OOM or runner signal)"
            );
        }
        other => panic!("Expected ExecutionFailed error variant, got: {other:?}"),
    }

    assert!(!err.is_retryable());
}

#[tokio::test]
async fn test_altool_credential_redacted_from_error_strings() {
    let secret_pwd = "super-secret-cleartext-password-999";
    let executor = FakeCommandExecutor::new();
    executor.push_error(ExecutorError::NonZeroExit {
        code: Some(1),
        stderr: format!(
            "Authentication failed for user developer@example.com with password {secret_pwd}."
        ),
    });

    let client = TestFlightClient::unconfigured();
    let err = client
        .upload_ipa_tooling(
            &executor,
            "/tmp/app.ipa",
            "developer@example.com",
            secret_pwd,
        )
        .await
        .unwrap_err();

    let display_str = err.to_string();
    let debug_str = format!("{err:?}");

    assert!(
        !display_str.contains(secret_pwd),
        "Secret password leaked in TestFlightError Display: {display_str}"
    );
    assert!(
        !debug_str.contains(secret_pwd),
        "Secret password leaked in TestFlightError Debug: {debug_str}"
    );
    assert!(display_str.contains("[redacted]"));
}

#[tokio::test]
async fn test_altool_empty_inputs_validation() {
    let executor = FakeCommandExecutor::new();
    let client = TestFlightClient::unconfigured();

    // 1. Empty IPA path
    let err_path = client
        .upload_ipa_tooling(&executor, "   ", "dev@example.com", "pass")
        .await;
    assert!(matches!(
        err_path,
        Err(TestFlightError::BinaryRejected { .. })
    ));

    // 2. Empty Apple ID
    let err_id = client
        .upload_ipa_tooling(&executor, "/tmp/app.ipa", "   ", "pass")
        .await;
    assert!(matches!(err_id, Err(TestFlightError::Auth(_))));

    // 3. Empty password
    let err_pwd = client
        .upload_ipa_tooling(&executor, "/tmp/app.ipa", "dev@example.com", "   ")
        .await;
    assert!(matches!(err_pwd, Err(TestFlightError::Auth(_))));

    // Executor was never invoked for input validation failures
    assert_eq!(executor.recorded_specs().len(), 0);
}

#[tokio::test]
async fn test_altool_custom_options() {
    let executor = FakeCommandExecutor::new();
    executor.push_success(
        r#"{"tool-version":"16.0","os-version":"15.0","product-errors":[]}"#,
        "",
    );

    let client = TestFlightClient::unconfigured();
    let options = AltoolUploadOptions {
        platform: TestFlightPlatform::Macos,
        working_dir: Some(PathBuf::from("/tmp/workspace")),
        timeout: Duration::from_secs(600),
    };

    let result = client
        .upload_ipa_tooling_with_options(
            &executor,
            "/tmp/app.pkg",
            "dev@example.com",
            "app-specific-pass",
            &options,
        )
        .await;

    assert!(result.is_ok());

    let specs = executor.recorded_specs();
    assert_eq!(specs.len(), 1);
    let spec = &specs[0];

    assert_eq!(spec.args[5], "macos");
    assert_eq!(spec.working_dir, PathBuf::from("/tmp/workspace"));
    assert_eq!(spec.timeout, Duration::from_secs(600));
}

#[test]
fn test_altool_json_extraction_and_classification() {
    // 1. JSON extraction with surrounding log noise
    let noisy_output = "2026-08-15 12:00:00 altool[123:456] Logging...\n{\n  \"tool-version\": \"16.0\",\n  \"product-errors\": [\n    {\n      \"code\": 90189,\n      \"message\": \"Invalid profile\"\n    }\n  ]\n}\nFinished.";
    let json_extracted = extract_json_from_output(noisy_output).expect("extract JSON");
    assert!(json_extracted.starts_with('{'));
    assert!(json_extracted.ends_with('}'));

    let errors = parse_altool_errors_from_output(noisy_output, "").expect("parse product errors");
    assert_eq!(errors.len(), 1);
    assert_eq!(errors[0].code_str().as_deref(), Some("90189"));
    assert_eq!(errors[0].resolved_message(), "Invalid profile");

    let classified = classify_altool_error(&errors[0]);
    match classified {
        TestFlightError::BinaryRejected { code, message } => {
            assert_eq!(code.as_deref(), Some("90189"));
            assert_eq!(message, "Invalid profile");
        }
        other => panic!("Expected BinaryRejected, got: {other:?}"),
    }

    // 2. Direct AltoolJsonResponse deserialization
    let raw_json =
        r#"{"tool-version":"16.0","os-version":"15.0","success-message":"UPLOAD SUCCEEDED"}"#;
    let parsed: AltoolJsonResponse = serde_json::from_str(raw_json).expect("deserialize JSON");
    assert_eq!(parsed.tool_version.as_deref(), Some("16.0"));
    assert_eq!(parsed.success_message.as_deref(), Some("UPLOAD SUCCEEDED"));

    // 3. UserInfo fallback message resolution
    let err_with_userinfo = AltoolProductError {
        code: Some(serde_json::json!(-1011)),
        message: None,
        user_info: Some(serde_json::json!({
            "NSLocalizedFailureReason": "Authentication rejected by upstream server."
        })),
    };
    assert_eq!(
        err_with_userinfo.resolved_message(),
        "Authentication rejected by upstream server."
    );
    let classified_auth = classify_altool_error(&err_with_userinfo);
    assert!(matches!(classified_auth, TestFlightError::Auth(_)));
}
