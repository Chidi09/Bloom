use bloom_cloud_backend::apps::secrets::contracts::{
    SecretCreateRequest, SecretResponse, SecretRollbackRequest, SecretUpdateRequest, WorkerSecret,
    WorkerSecretsResponse,
};
use bloom_cloud_backend::apps::secrets::errors::SecretError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_secret_response_never_contains_raw_value_or_ciphertext() {
    let secret_res = SecretResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        environment_id: "660e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "770e8400-e29b-41d4-a716-446655440000".to_string(),
        key: "DATABASE_URL".to_string(),
        is_json: false,
        version: 1,
        updated_at: "2026-08-15T00:00:00Z".to_string(),
    };

    let serialized = serde_json::to_string(&secret_res).unwrap();

    // Verify expected fields are present
    assert!(serialized.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"environment_id\":\"660e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"organization_id\":\"770e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"key\":\"DATABASE_URL\""));
    assert!(serialized.contains("\"version\":1"));

    // Critical security assertion: secret value and ciphertext must NEVER appear
    assert!(!serialized.contains("value"));
    assert!(!serialized.contains("encrypted_value"));
    assert!(!serialized.contains("ciphertext"));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_worker_secrets_bundle_contract() {
    let bundle = WorkerSecretsResponse {
        env_vars: vec![
            WorkerSecret {
                key: "API_KEY".to_string(),
                value: "decrypted-api-key-123".to_string(),
                is_json: false,
            },
            WorkerSecret {
                key: "CONFIG_JSON".to_string(),
                value: r#"{"timeout":30}"#.to_string(),
                is_json: true,
            },
        ],
    };

    let serialized = serde_json::to_string(&bundle).unwrap();
    assert!(serialized.contains("decrypted-api-key-123"));
    assert!(serialized.contains("CONFIG_JSON"));

    let deserialized: WorkerSecretsResponse = serde_json::from_str(&serialized).unwrap();
    assert_eq!(deserialized.env_vars.len(), 2);
    assert_eq!(deserialized.env_vars[0].value, "decrypted-api-key-123");
}

#[test]
fn test_secret_create_and_update_contracts() {
    let create_json = r#"{
        "environment_id": "env-uuid-1",
        "key": "FIREBASE_CONFIG",
        "value": "{\"apiKey\":\"xyz\"}",
        "is_json": true
    }"#;
    let create_req: SecretCreateRequest = serde_json::from_str(create_json).unwrap();
    assert_eq!(create_req.key, "FIREBASE_CONFIG");
    assert!(create_req.is_json);

    let partial_patch = r#"{"is_json":false}"#;
    let patch_req: SecretUpdateRequest = serde_json::from_str(partial_patch).unwrap();
    assert_eq!(patch_req.value, None);
    assert_eq!(patch_req.is_json, Some(false));

    let rollback_json = r#"{"version":4}"#;
    let rollback_req: SecretRollbackRequest = serde_json::from_str(rollback_json).unwrap();
    assert_eq!(rollback_req.version, 4);
}

#[test]
fn test_secret_error_http_mappings() {
    let err = SecretError::SecretNotFound;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj.code(), "secret_not_found");

    let err = SecretError::VersionNotFound;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj.code(), "version_not_found");

    let err = SecretError::EnvironmentNotFound;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj.code(), "environment_not_found");

    let err = SecretError::OrganizationNotFound;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj.code(), "organization_not_found");

    let err = SecretError::OrganizationRequired;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj.code(), "organization_required");

    let err = SecretError::InsufficientRole;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj.code(), "insufficient_role");

    let err = SecretError::Forbidden;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj.code(), "permission_denied");

    let err = SecretError::Unauthorized;
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj.code(), "invalid_credentials");

    let err = SecretError::InvalidKeyFormat("bad key".to_string());
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj.code(), "invalid_key_format");

    let err = SecretError::InvalidJsonValue("bad json".to_string());
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj.code(), "invalid_json_value");

    let err = SecretError::Crypto("tag mismatch".to_string());
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj.code(), "crypto_error");

    let err = SecretError::ValidationError("field required".to_string());
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj.code(), "validation_error");

    let err = SecretError::Database("connection lost".to_string());
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj.code(), "database_error");

    let err = SecretError::InvalidJobToken("expired token".to_string());
    let dj: DjangorsError = err.into();
    assert_eq!(dj.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj.code(), "invalid_job_token");
}
