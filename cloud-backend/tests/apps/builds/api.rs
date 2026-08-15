use bloom_cloud_backend::apps::builds::contracts::{
    BuildCreateRequest, BuildLogsResponse, BuildResponse, BuildStageResponse, CompleteBuildRequest,
    StageUpdateRequest,
};
use bloom_cloud_backend::apps::builds::errors::BuildError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_build_create_request_deserialization() {
    let json = r#"{
        "app_id": "app-uuid-123",
        "environment_id": "env-uuid-456",
        "platform": "android",
        "git_commit": "abc123",
        "git_branch": "feature/x",
        "git_ref": "refs/heads/feature/x",
        "build_profile": "profile",
        "flutter_version": "3.24.0",
        "dart_version": "3.5.0",
        "bloom_version": "0.8.0",
        "flavor": "internal"
    }"#;

    let req: BuildCreateRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.app_id, "app-uuid-123");
    assert_eq!(req.environment_id, "env-uuid-456");
    assert_eq!(req.platform, "android");
    assert_eq!(req.git_commit, Some("abc123".to_string()));
    assert_eq!(req.git_branch, Some("feature/x".to_string()));
    assert_eq!(req.git_ref, Some("refs/heads/feature/x".to_string()));
    assert_eq!(req.build_profile, Some("profile".to_string()));
    assert_eq!(req.flutter_version, Some("3.24.0".to_string()));
    assert_eq!(req.dart_version, Some("3.5.0".to_string()));
    assert_eq!(req.bloom_version, Some("0.8.0".to_string()));
    assert_eq!(req.flavor, Some("internal".to_string()));
}

#[test]
fn test_build_create_request_defaults_to_none() {
    let json = r#"{
        "app_id": "app-uuid-123",
        "environment_id": "env-uuid-456",
        "platform": "ios"
    }"#;

    let req: BuildCreateRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.app_id, "app-uuid-123");
    assert_eq!(req.environment_id, "env-uuid-456");
    assert_eq!(req.platform, "ios");
    assert_eq!(req.git_commit, None);
    assert_eq!(req.git_branch, None);
    assert_eq!(req.git_ref, None);
    assert_eq!(req.build_profile, None);
    assert_eq!(req.flutter_version, None);
    assert_eq!(req.dart_version, None);
    assert_eq!(req.bloom_version, None);
    assert_eq!(req.flavor, None);
}

#[test]
fn test_build_response_serialization() {
    let response = BuildResponse {
        id: "build-550e8400-e29b-41d4-a716-446655440000".to_string(),
        app_id: "app-550e8400-e29b-41d4-a716-446655440000".to_string(),
        environment_id: "env-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        git_commit: "abc123".to_string(),
        git_branch: "main".to_string(),
        git_ref: "main".to_string(),
        status: "running".to_string(),
        platform: "android".to_string(),
        build_profile: "release".to_string(),
        flutter_version: "3.24.0".to_string(),
        dart_version: "3.5.0".to_string(),
        bloom_version: "0.8.0".to_string(),
        flavor: None,
        started_at: Some("2026-08-15T10:00:00Z".to_string()),
        finished_at: None,
        logs_url: None,
        stages: vec![BuildStageResponse {
            stage: "checkout".to_string(),
            status: "completed".to_string(),
            started_at: Some("2026-08-15T10:00:00Z".to_string()),
            finished_at: Some("2026-08-15T10:00:05Z".to_string()),
            log_snippet: Some("Cloning repository...".to_string()),
        }],
        created_at: "2026-08-15T09:59:00Z".to_string(),
        updated_at: "2026-08-15T10:00:05Z".to_string(),
    };

    let serialized = serde_json::to_string(&response).unwrap();
    assert!(serialized.contains("\"id\":\"build-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"app_id\":\"app-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"organization_id\":\"org-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"status\":\"running\""));
    assert!(serialized.contains("\"platform\":\"android\""));
    assert!(serialized.contains("\"stages\""));
    assert!(serialized.contains("\"stage\":\"checkout\""));
    // The response must never leak internal keys.
    assert!(!serialized.contains("public_id"));
    assert!(!serialized.contains("worker_id"));

    // Round-trip: BuildResponse is Deserialize as well, so a round trip must hold.
    let deserialized: BuildResponse = serde_json::from_str(&serialized).unwrap();
    assert_eq!(deserialized, response);
}

#[test]
fn test_worker_contracts_deserialization() {
    let stage_json = r#"{
        "stage": "build",
        "status": "running",
        "log_snippet": "Running flutter build...",
        "worker_id": "worker-1"
    }"#;
    let stage: StageUpdateRequest = serde_json::from_str(stage_json).unwrap();
    assert_eq!(stage.stage, "build");
    assert_eq!(stage.status, "running");
    assert_eq!(
        stage.log_snippet,
        Some("Running flutter build...".to_string())
    );
    assert_eq!(stage.worker_id, Some("worker-1".to_string()));

    let complete_json = r#"{
        "status": "success",
        "metadata": "{\"duration_ms\": 42000}",
        "logs_url": "orgs/.../logs/build.log",
        "reason": null
    }"#;
    let complete: CompleteBuildRequest = serde_json::from_str(complete_json).unwrap();
    assert_eq!(complete.status, "success");
    assert_eq!(
        complete.metadata,
        Some("{\"duration_ms\": 42000}".to_string())
    );
    assert_eq!(
        complete.logs_url,
        Some("orgs/.../logs/build.log".to_string())
    );
    assert_eq!(complete.reason, None);

    let logs_resp = BuildLogsResponse {
        url: "https://presigned.example/build.log?X-Amz-Signature=...".to_string(),
        expires_in_secs: 900,
    };
    let serialized = serde_json::to_string(&logs_resp).unwrap();
    assert!(serialized.contains("\"url\":\"https://presigned.example/build.log"));
    assert!(serialized.contains("\"expires_in_secs\":900"));
}

#[test]
fn test_build_error_mappings() {
    let err = BuildError::BuildNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = BuildError::AppNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = BuildError::EnvironmentNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = BuildError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = BuildError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = BuildError::InvalidStatus;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::CONFLICT);
    assert_eq!(dj_err.code(), "invalid_status");

    let err = BuildError::ValidationError("Missing build id".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");

    let err = BuildError::QueueError("redis down".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_GATEWAY);
    assert_eq!(dj_err.code(), "queue_error");

    let err = BuildError::Storage("presign failed".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "storage_error");

    let err = BuildError::InvalidJobToken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_job_token");

    let err = BuildError::Database("boom".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "database_error");
}
