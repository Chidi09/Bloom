use bloom_cloud_backend::apps::artifacts::contracts::{ArtifactRegisterRequest, ArtifactResponse};
use bloom_cloud_backend::apps::artifacts::errors::ArtifactError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_register_request_deserialization() {
    let register_json = r#"{
        "build_id": "550e8400-e29b-41d4-a716-446655440000",
        "organization_id": "123e4567-e89b-12d3-a456-426614174000",
        "platform": "android",
        "kind": "apk",
        "file_name": "app-release.apk",
        "file_size": 4194304,
        "checksum": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "version": "1.4.2",
        "build_number": 77,
        "metadata": {"dartSdk": "3.4.0"},
        "storage_bucket": "bloomcloud-artifacts"
    }"#;

    let req: ArtifactRegisterRequest = serde_json::from_str(register_json).unwrap();
    assert_eq!(req.build_id, "550e8400-e29b-41d4-a716-446655440000");
    assert_eq!(req.organization_id, "123e4567-e89b-12d3-a456-426614174000");
    assert_eq!(req.platform, "android");
    assert_eq!(req.kind, "apk");
    assert_eq!(req.file_name, "app-release.apk");
    assert_eq!(req.file_size, 4194304);
    assert_eq!(req.version, "1.4.2");
    assert_eq!(req.build_number, 77);
    assert_eq!(req.storage_bucket, "bloomcloud-artifacts");
    assert_eq!(req.metadata["dartSdk"], "3.4.0");
}

#[test]
fn test_register_request_metadata_defaults_to_null() {
    let register_json = r#"{
        "build_id": "build-1",
        "organization_id": "org-1",
        "platform": "web",
        "kind": "web_bundle",
        "file_name": "web.zip",
        "file_size": 1024,
        "checksum": "aaaabbbbccccddddeeeeffff00001111aaaabbbbccccddddeeeeffff00001111",
        "version": "1.0.0",
        "build_number": 1,
        "storage_bucket": "bloomcloud-artifacts"
    }"#;

    let req: ArtifactRegisterRequest = serde_json::from_str(register_json).unwrap();
    assert_eq!(req.metadata, serde_json::Value::Null);
}

#[test]
fn test_response_serialization() {
    let res = ArtifactResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        build_id: "build-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        platform: "ios".to_string(),
        kind: "ipa".to_string(),
        file_name: "app.ipa".to_string(),
        file_size: 2048,
        checksum: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef".to_string(),
        version: "1.2.3".to_string(),
        build_number: 55,
        metadata: serde_json::json!({"signing": "app-store"}),
        download_url: Some("https://storage.local/bloomcloud-artifacts/orgs/org-1/apps/app-1/artifacts/art-1/app.ipa?expires=1234".to_string()),
        created_at: "2026-08-15T00:00:00Z".to_string(),
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"build_id\":\"build-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"organization_id\":\"org-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"platform\":\"ios\""));
    assert!(serialized.contains("\"kind\":\"ipa\""));
    assert!(serialized.contains("\"download_url\":\"https://storage.local"));
    assert!(serialized.contains("\"metadata\":{\"signing\":\"app-store\"}"));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_artifact_error_mappings() {
    let err = ArtifactError::ArtifactNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = ArtifactError::BuildNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = ArtifactError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = ArtifactError::InvalidPlatform;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_platform");

    let err = ArtifactError::InvalidKind;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_kind");

    let err = ArtifactError::UploadNotConfirmed;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "upload_not_confirmed");

    let err = ArtifactError::InvalidJobToken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_job_token");

    let err = ArtifactError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = ArtifactError::ValidationError("Missing field".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");
}
