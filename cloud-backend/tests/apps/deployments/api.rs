use bloom_cloud_backend::apps::deployments::contracts::{
    DeploymentCreateRequest, DeploymentResponse,
};
use bloom_cloud_backend::apps::deployments::errors::DeploymentError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_deployment_create_request_deserialization() {
    let json_with_release = r#"{
        "release_id": "rel-550e8400-e29b-41d4-a716-446655440000",
        "environment_id": "env-550e8400-e29b-41d4-a716-446655440000",
        "platform": "ios",
        "target": "testflight"
    }"#;

    let req: DeploymentCreateRequest = serde_json::from_str(json_with_release).unwrap();
    assert_eq!(
        req.release_id,
        Some("rel-550e8400-e29b-41d4-a716-446655440000".to_string())
    );
    assert_eq!(req.artifact_id, None);
    assert_eq!(
        req.environment_id,
        "env-550e8400-e29b-41d4-a716-446655440000"
    );
    assert_eq!(req.platform, "ios");
    assert_eq!(req.target, "testflight");

    let json_with_artifact = r#"{
        "artifact_id": "art-550e8400-e29b-41d4-a716-446655440000",
        "environment_id": "env-550e8400-e29b-41d4-a716-446655440000",
        "platform": "android",
        "target": "internal"
    }"#;

    let req2: DeploymentCreateRequest = serde_json::from_str(json_with_artifact).unwrap();
    assert_eq!(req2.release_id, None);
    assert_eq!(
        req2.artifact_id,
        Some("art-550e8400-e29b-41d4-a716-446655440000".to_string())
    );
    assert_eq!(req2.platform, "android");
    assert_eq!(req2.target, "internal");
}

#[test]
fn test_deployment_response_serialization() {
    let res = DeploymentResponse {
        id: "dep-550e8400-e29b-41d4-a716-446655440000".to_string(),
        release_id: Some("rel-123".to_string()),
        artifact_id: Some("art-456".to_string()),
        environment_id: "env-789".to_string(),
        organization_id: "org-001".to_string(),
        platform: "ios".to_string(),
        target: "testflight".to_string(),
        status: "ready".to_string(),
        external_id: Some("build-999".to_string()),
        external_url: Some("https://appstoreconnect.apple.com/apps/123/testflight".to_string()),
        error_message: None,
        started_at: Some("2026-08-15T12:00:00Z".to_string()),
        finished_at: Some("2026-08-15T12:05:00Z".to_string()),
        created_by_id: "user-42".to_string(),
        created_at: "2026-08-15T11:59:00Z".to_string(),
        updated_at: "2026-08-15T12:05:00Z".to_string(),
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"dep-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"release_id\":\"rel-123\""));
    assert!(serialized.contains("\"artifact_id\":\"art-456\""));
    assert!(serialized.contains("\"environment_id\":\"env-789\""));
    assert!(serialized.contains("\"organization_id\":\"org-001\""));
    assert!(serialized.contains("\"platform\":\"ios\""));
    assert!(serialized.contains("\"target\":\"testflight\""));
    assert!(serialized.contains("\"status\":\"ready\""));
    assert!(serialized.contains("\"external_id\":\"build-999\""));
    assert!(serialized.contains("\"created_by_id\":\"user-42\""));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_deployment_error_mappings() {
    let err = DeploymentError::DeploymentNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "deployment_not_found");

    let err = DeploymentError::ReleaseNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "release_not_found");

    let err = DeploymentError::ArtifactNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "artifact_not_found");

    let err = DeploymentError::EnvironmentNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "environment_not_found");

    let err = DeploymentError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = DeploymentError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = DeploymentError::InvalidPlatform("unknown".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_platform");

    let err = DeploymentError::InvalidTarget("unknown".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_target");

    let err = DeploymentError::IncompatiblePlatformAndTarget {
        platform: "ios".to_string(),
        target: "internal".to_string(),
    };
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "incompatible_platform_target");

    let err = DeploymentError::UnapprovedRelease;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "unapproved_release");

    let err = DeploymentError::MissingReleaseOrArtifact;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "missing_release_or_artifact");
}
