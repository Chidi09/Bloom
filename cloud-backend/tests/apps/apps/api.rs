use bloom_cloud_backend::apps::apps::contracts::{
    AppCreateRequest, AppLinkRequest, AppResponse, AppUpdateRequest,
};
use bloom_cloud_backend::apps::apps::errors::AppError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_apps_contracts_serialization() {
    let create_json = r#"{
        "project_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
        "name": "Bloom Mobile App",
        "repository_url": "https://github.com/bloom/mobile",
        "default_branch": "develop"
    }"#;
    let create_req: AppCreateRequest = serde_json::from_str(create_json).unwrap();
    assert_eq!(
        create_req.project_id,
        "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    );
    assert_eq!(create_req.name, "Bloom Mobile App");
    assert_eq!(
        create_req.repository_url,
        Some("https://github.com/bloom/mobile".to_string())
    );
    assert_eq!(create_req.default_branch, Some("develop".to_string()));

    let update_json = r#"{"name":"Updated App Name"}"#;
    let update_req: AppUpdateRequest = serde_json::from_str(update_json).unwrap();
    assert_eq!(update_req.name, Some("Updated App Name".to_string()));
    assert_eq!(update_req.repository_url, None);
    assert_eq!(update_req.default_branch, None);

    let link_json = r#"{
        "project_slug": "bloom-core",
        "app_slug": "bloom-mobile"
    }"#;
    let link_req: AppLinkRequest = serde_json::from_str(link_json).unwrap();
    assert_eq!(link_req.project_slug, "bloom-core");
    assert_eq!(link_req.app_slug, "bloom-mobile");

    let app_res = AppResponse {
        id: "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d".to_string(),
        project_id: "6ba7b810-9dad-11d1-80b4-00c04fd430c8".to_string(),
        organization_id: "123e4567-e89b-12d3-a456-426614174000".to_string(),
        name: "Bloom Mobile".to_string(),
        slug: "bloom-mobile".to_string(),
        repository_url: Some("https://github.com/bloom/mobile".to_string()),
        default_branch: "main".to_string(),
        created_at: "2026-08-15T00:00:00Z".to_string(),
        updated_at: "2026-08-15T00:00:00Z".to_string(),
    };
    let app_res_json = serde_json::to_string(&app_res).unwrap();
    assert!(app_res_json.contains("\"id\":\"a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d\""));
    assert!(app_res_json.contains("\"project_id\":\"6ba7b810-9dad-11d1-80b4-00c04fd430c8\""));
    assert!(app_res_json.contains("\"organization_id\":\"123e4567-e89b-12d3-a456-426614174000\""));
    assert!(!app_res_json.contains("public_id"));
}

#[test]
fn test_apps_error_mappings() {
    let err = AppError::SlugTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "slug_taken");

    let err = AppError::AppNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = AppError::ProjectNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = AppError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = AppError::AppNotEmpty;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "app_not_empty");

    let err = AppError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");
}
