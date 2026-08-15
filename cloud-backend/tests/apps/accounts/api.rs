use bloom_cloud_backend::apps::accounts::contracts::{MeResponse, RegisterRequest, TokenResponse};
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
}
