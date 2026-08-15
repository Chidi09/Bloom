use bloom_cloud_backend::apps::webhosting::contracts::{
    CreateCustomDomainRequest, CustomDomainResponse, DeployWebRequest, WebDeploymentResponse,
};
use bloom_cloud_backend::apps::webhosting::errors::WebHostingError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_deploy_web_request_deserialization() {
    let deploy_json = r#"{
        "app_id": "app-550e8400-e29b-41d4-a716-446655440000",
        "environment_id": "env-550e8400-e29b-41d4-a716-446655440000",
        "artifact_id": "art-550e8400-e29b-41d4-a716-446655440000",
        "release_id": "rel-550e8400-e29b-41d4-a716-446655440000",
        "target": "preview",
        "git_branch": "feature/login-screen",
        "metadata": {
            "headers": {"X-Custom-Header": "value"},
            "cacheControl": "max-age=3600"
        }
    }"#;

    let req: DeployWebRequest = serde_json::from_str(deploy_json).unwrap();
    assert_eq!(req.app_id, "app-550e8400-e29b-41d4-a716-446655440000");
    assert_eq!(
        req.environment_id,
        "env-550e8400-e29b-41d4-a716-446655440000"
    );
    assert_eq!(req.artifact_id, "art-550e8400-e29b-41d4-a716-446655440000");
    assert_eq!(
        req.release_id,
        Some("rel-550e8400-e29b-41d4-a716-446655440000".to_string())
    );
    assert_eq!(req.target, "preview");
    assert_eq!(req.git_branch, Some("feature/login-screen".to_string()));
    assert!(req.metadata.is_some());
    let meta = req.metadata.unwrap();
    assert_eq!(meta["headers"]["X-Custom-Header"], "value");
}

#[test]
fn test_create_custom_domain_request_deserialization() {
    let domain_json = r#"{
        "app_id": "app-550e8400-e29b-41d4-a716-446655440000",
        "domain": "app.mycompany.com"
    }"#;

    let req: CreateCustomDomainRequest = serde_json::from_str(domain_json).unwrap();
    assert_eq!(req.app_id, "app-550e8400-e29b-41d4-a716-446655440000");
    assert_eq!(req.domain, "app.mycompany.com");
}

#[test]
fn test_web_deployment_response_serialization() {
    let res = WebDeploymentResponse {
        id: "dep-550e8400-e29b-41d4-a716-446655440000".to_string(),
        app_id: "app-123".to_string(),
        environment_id: "env-456".to_string(),
        release_id: Some("rel-789".to_string()),
        target: "production".to_string(),
        url: "https://shop-acme.bloomcloud.dev".to_string(),
        status: "live".to_string(),
        deployed_by_id: "user-10".to_string(),
        created_at: "2026-08-15T12:00:00Z".to_string(),
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"dep-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"app_id\":\"app-123\""));
    assert!(serialized.contains("\"environment_id\":\"env-456\""));
    assert!(serialized.contains("\"release_id\":\"rel-789\""));
    assert!(serialized.contains("\"target\":\"production\""));
    assert!(serialized.contains("\"url\":\"https://shop-acme.bloomcloud.dev\""));
    assert!(serialized.contains("\"status\":\"live\""));
    assert!(serialized.contains("\"deployed_by_id\":\"user-10\""));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_custom_domain_response_serialization() {
    let res = CustomDomainResponse {
        id: "dom-550e8400-e29b-41d4-a716-446655440000".to_string(),
        app_id: "app-123".to_string(),
        domain: "store.example.com".to_string(),
        certificate_status: "issued".to_string(),
        certificate_expires_at: Some("2027-01-01T00:00:00Z".to_string()),
        verified_at: Some("2026-08-15T12:00:00Z".to_string()),
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"dom-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"app_id\":\"app-123\""));
    assert!(serialized.contains("\"domain\":\"store.example.com\""));
    assert!(serialized.contains("\"certificate_status\":\"issued\""));
    assert!(serialized.contains("\"certificate_expires_at\":\"2027-01-01T00:00:00Z\""));
    assert!(serialized.contains("\"verified_at\":\"2026-08-15T12:00:00Z\""));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_webhosting_error_mappings() {
    let err = WebHostingError::DeploymentNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "deployment_not_found");

    let err = WebHostingError::DomainNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "domain_not_found");

    let err = WebHostingError::AppNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "app_not_found");

    let err = WebHostingError::ProjectNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "project_not_found");

    let err = WebHostingError::EnvironmentNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "environment_not_found");

    let err = WebHostingError::ArtifactNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "artifact_not_found");

    let err = WebHostingError::InvalidArtifactKind;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_artifact_kind");

    let err = WebHostingError::ReleaseNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "release_not_found");

    let err = WebHostingError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = WebHostingError::InvalidTarget;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_target");

    let err = WebHostingError::InvalidStatus;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_status");

    let err = WebHostingError::InvalidDomain;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_domain");

    let err = WebHostingError::DomainAlreadyExists;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::CONFLICT);
    assert_eq!(dj_err.code(), "domain_already_exists");

    let err = WebHostingError::NoPreviousDeployment;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "no_previous_deployment");

    let err = WebHostingError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = WebHostingError::ValidationError("Missing field".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");
}
