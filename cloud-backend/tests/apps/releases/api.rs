use bloom_cloud_backend::apps::artifacts::contracts::ArtifactResponse;
use bloom_cloud_backend::apps::releases::contracts::{
    ReleaseApproveRequest, ReleaseCreateRequest, ReleaseResponse, ReleaseRollbackRequest,
    ReleaseUpdateRequest,
};
use bloom_cloud_backend::apps::releases::errors::ReleaseError;
use bloom_cloud_backend::apps::releases::serializers::{
    parse_artifact_ids, parse_platforms, parse_rollout_status,
};
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_release_create_request_deserialization() {
    let json = r#"{
        "app_id": "app-550e8400-e29b-41d4-a716-446655440000",
        "version": "1.0.0",
        "build_number": 42,
        "commit": "0123456789abcdef0123456789abcdef01234567",
        "changelog": "Initial production release.",
        "environment_id": "env-550e8400-e29b-41d4-a716-446655440000",
        "platforms": ["ios", "android", "web"],
        "artifact_ids": ["art-uuid-1", "art-uuid-2"]
    }"#;

    let req: ReleaseCreateRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.app_id, "app-550e8400-e29b-41d4-a716-446655440000");
    assert_eq!(req.version, "1.0.0");
    assert_eq!(req.build_number, 42);
    assert_eq!(req.commit, "0123456789abcdef0123456789abcdef01234567");
    assert_eq!(
        req.changelog,
        Some("Initial production release.".to_string())
    );
    assert_eq!(
        req.environment_id,
        Some("env-550e8400-e29b-41d4-a716-446655440000".to_string())
    );
    assert_eq!(req.platforms, vec!["ios", "android", "web"]);
    assert_eq!(req.artifact_ids, vec!["art-uuid-1", "art-uuid-2"]);
}

#[test]
fn test_release_create_request_defaults_optional_fields() {
    let json = r#"{
        "app_id": "app-uuid-1",
        "version": "2.0.0",
        "build_number": 1,
        "commit": "abc1234",
        "platforms": ["web"],
        "artifact_ids": []
    }"#;

    let req: ReleaseCreateRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.app_id, "app-uuid-1");
    assert_eq!(req.version, "2.0.0");
    assert_eq!(req.build_number, 1);
    assert_eq!(req.commit, "abc1234");
    assert_eq!(req.changelog, None);
    assert_eq!(req.environment_id, None);
    assert_eq!(req.platforms, vec!["web"]);
    assert!(req.artifact_ids.is_empty());
}

#[test]
fn test_release_approve_request_deserialization() {
    let approve_json = r#"{ "approved": true, "reason": "QA passed" }"#;
    let approve_req: ReleaseApproveRequest = serde_json::from_str(approve_json).unwrap();
    assert!(approve_req.approved);
    assert_eq!(approve_req.reason, Some("QA passed".to_string()));

    let reject_json = r#"{ "approved": false, "reason": "Smoke test failed" }"#;
    let reject_req: ReleaseApproveRequest = serde_json::from_str(reject_json).unwrap();
    assert!(!reject_req.approved);
    assert_eq!(reject_req.reason, Some("Smoke test failed".to_string()));

    let minimal_json = r#"{ "approved": true }"#;
    let minimal_req: ReleaseApproveRequest = serde_json::from_str(minimal_json).unwrap();
    assert!(minimal_req.approved);
    assert_eq!(minimal_req.reason, None);
}

#[test]
fn test_release_rollback_and_update_requests_deserialization() {
    let rollback_json = r#"{ "reason": "Crash loop on startup" }"#;
    let rollback_req: ReleaseRollbackRequest = serde_json::from_str(rollback_json).unwrap();
    assert_eq!(
        rollback_req.reason,
        Some("Crash loop on startup".to_string())
    );

    let update_json = r#"{
        "changelog": "Updated changelog text.",
        "rollout_status": { "ios": "staged_10_percent" },
        "status": "rolling_out"
    }"#;
    let update_req: ReleaseUpdateRequest = serde_json::from_str(update_json).unwrap();
    assert_eq!(
        update_req.changelog,
        Some("Updated changelog text.".to_string())
    );
    assert_eq!(update_req.status, Some("rolling_out".to_string()));
    assert_eq!(
        update_req.rollout_status,
        Some(serde_json::json!({ "ios": "staged_10_percent" }))
    );
}

#[test]
fn test_json_in_text_field_parsers() {
    // Platforms parsing
    assert_eq!(
        parse_platforms("[\"ios\", \"android\"]"),
        vec!["ios", "android"]
    );
    assert_eq!(parse_platforms("invalid_json"), Vec::<String>::new());
    assert_eq!(parse_platforms("[]"), Vec::<String>::new());

    // Artifact IDs parsing
    assert_eq!(
        parse_artifact_ids("[\"art-1\", \"art-2\"]"),
        vec!["art-1", "art-2"]
    );
    assert_eq!(parse_artifact_ids("malformed"), Vec::<String>::new());

    // Rollout status parsing
    assert_eq!(
        parse_rollout_status("{\"ios\": \"live\"}"),
        serde_json::json!({ "ios": "live" })
    );
    assert_eq!(
        parse_rollout_status("unparseable_json"),
        serde_json::json!({})
    );
}

#[test]
fn test_release_response_serialization_and_roundtrip() {
    let artifact = ArtifactResponse {
        id: "art-550e8400-e29b-41d4-a716-446655440000".to_string(),
        build_id: "build-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        platform: "ios".to_string(),
        kind: "ipa".to_string(),
        file_name: "Runner.ipa".to_string(),
        file_size: 25_000_000,
        checksum: "abcdef0123456789".to_string(),
        version: "1.0.0".to_string(),
        build_number: 42,
        metadata: serde_json::json!({ "bundle_id": "com.example.app" }),
        download_url: None,
        created_at: "2026-08-15T10:00:00Z".to_string(),
    };

    let response = ReleaseResponse {
        id: "rel-550e8400-e29b-41d4-a716-446655440000".to_string(),
        app_id: "app-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        version: "1.0.0".to_string(),
        build_number: 42,
        commit: "0123456789abcdef0123456789abcdef01234567".to_string(),
        changelog: "# What's New\n- Bug fixes and improvements".to_string(),
        environment_id: Some("env-550e8400-e29b-41d4-a716-446655440000".to_string()),
        status: "approved".to_string(),
        platforms: vec!["ios".to_string(), "android".to_string()],
        artifacts: vec![artifact],
        rollout_status: serde_json::json!({ "ios": "staged", "android": "ready" }),
        created_by_id: "user-550e8400-e29b-41d4-a716-446655440000".to_string(),
        created_at: "2026-08-15T10:00:00Z".to_string(),
        updated_at: "2026-08-15T10:05:00Z".to_string(),
    };

    let serialized = serde_json::to_string(&response).unwrap();

    // Verify key fields
    assert!(serialized.contains("\"id\":\"rel-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"app_id\":\"app-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"organization_id\":\"org-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"version\":\"1.0.0\""));
    assert!(serialized.contains("\"status\":\"approved\""));
    assert!(serialized.contains("\"platforms\":[\"ios\",\"android\"]"));
    assert!(serialized.contains("\"rollout_status\":{\"android\":\"ready\",\"ios\":\"staged\"}"));
    assert!(serialized.contains("\"created_by_id\":\"user-550e8400-e29b-41d4-a716-446655440000\""));

    // Verify wire contract: internal primary keys never leaked
    assert!(!serialized.contains("public_id"));

    // Round-trip deserialization
    let deserialized: ReleaseResponse = serde_json::from_str(&serialized).unwrap();
    assert_eq!(deserialized, response);
}

#[test]
fn test_release_error_mappings() {
    let err = ReleaseError::ReleaseNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = ReleaseError::AppNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = ReleaseError::EnvironmentNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = ReleaseError::ArtifactNotFound("art-123".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = ReleaseError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = ReleaseError::UserNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = ReleaseError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = ReleaseError::InvalidStatus;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::CONFLICT);
    assert_eq!(dj_err.code(), "invalid_status");

    let err = ReleaseError::ValidationError("Invalid version".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");

    let err = ReleaseError::Database("db failed".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "database_error");
}
