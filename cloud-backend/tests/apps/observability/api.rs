use bloom_cloud_backend::apps::observability::contracts::{
    AppStatusResponse, EnvironmentStatus, PlatformHealth, ReleaseHealthResponse,
};
use bloom_cloud_backend::apps::observability::errors::ObservabilityError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_release_health_contract_serialization() {
    let response = ReleaseHealthResponse {
        release_id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        overall_crash_free_rate: Some(0.995),
        platforms: vec![
            PlatformHealth {
                platform: "ios".to_string(),
                target: "testflight".to_string(),
                crash_free_rate: Some(0.998),
                sessions: Some(1000),
                crashes: Some(2),
                status: "healthy".to_string(),
            },
            PlatformHealth {
                platform: "android".to_string(),
                target: "google_play".to_string(),
                crash_free_rate: Some(0.992),
                sessions: Some(1000),
                crashes: Some(8),
                status: "healthy".to_string(),
            },
        ],
    };

    let body = serde_json::to_string(&response).expect("serialization succeeds");
    assert!(body.contains("\"release_id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(body.contains("\"overall_crash_free_rate\":0.995"));
    assert!(body.contains("\"platform\":\"ios\""));
    assert!(body.contains("\"target\":\"testflight\""));
    assert!(body.contains("\"crash_free_rate\":0.998"));
    assert!(body.contains("\"sessions\":1000"));
    assert!(body.contains("\"crashes\":2"));
    assert!(body.contains("\"status\":\"healthy\""));

    let deserialized: ReleaseHealthResponse =
        serde_json::from_str(&body).expect("deserialization succeeds");
    assert_eq!(response, deserialized);
}

#[test]
fn test_app_status_contract_serialization() {
    let response = AppStatusResponse {
        app_id: "660e8400-e29b-41d4-a716-446655440000".to_string(),
        environments: vec![
            EnvironmentStatus {
                environment: "production".to_string(),
                platform: "ios".to_string(),
                release_id: Some("770e8400-e29b-41d4-a716-446655440000".to_string()),
                version: Some("1.2.0".to_string()),
                build_number: Some(42),
                status: "released".to_string(),
                crash_free_rate: Some(0.999),
            },
            EnvironmentStatus {
                environment: "staging".to_string(),
                platform: "all".to_string(),
                release_id: None,
                version: None,
                build_number: None,
                status: "no_release".to_string(),
                crash_free_rate: None,
            },
        ],
    };

    let body = serde_json::to_string(&response).expect("serialization succeeds");
    assert!(body.contains("\"app_id\":\"660e8400-e29b-41d4-a716-446655440000\""));
    assert!(body.contains("\"environment\":\"production\""));
    assert!(body.contains("\"status\":\"released\""));
    assert!(body.contains("\"status\":\"no_release\""));

    let deserialized: AppStatusResponse =
        serde_json::from_str(&body).expect("deserialization succeeds");
    assert_eq!(response, deserialized);
}

#[test]
fn test_observability_error_status_codes() {
    let err = ObservabilityError::ReleaseNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "release_not_found");

    let err = ObservabilityError::AppNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "app_not_found");

    let err = ObservabilityError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = ObservabilityError::Unauthorized;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");

    let err = ObservabilityError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = ObservabilityError::ValidationError("bad input".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");

    let err = ObservabilityError::Database("db fail".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "database_error");
}
