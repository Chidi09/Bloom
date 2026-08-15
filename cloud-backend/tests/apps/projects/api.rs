use bloom_cloud_backend::apps::projects::contracts::{
    ProjectCreateRequest, ProjectResponse, ProjectUpdateRequest,
};
use bloom_cloud_backend::apps::projects::errors::ProjectError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_project_contracts_serialization_and_deserialization() {
    let create_req: ProjectCreateRequest =
        serde_json::from_str(r#"{"name":"Mobile App","description":"Cross-platform flutter app"}"#)
            .unwrap();
    assert_eq!(create_req.name, "Mobile App");
    assert_eq!(
        create_req.description,
        Some("Cross-platform flutter app".to_string())
    );

    let update_req: ProjectUpdateRequest =
        serde_json::from_str(r#"{"name":"Mobile App Port"}"#).unwrap();
    assert_eq!(update_req.name, Some("Mobile App Port".to_string()));
    assert_eq!(update_req.description, None);

    let project_res = ProjectResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "660e8400-e29b-41d4-a716-446655440000".to_string(),
        name: "Mobile App".to_string(),
        slug: "mobile-app".to_string(),
        description: Some("Cross-platform flutter app".to_string()),
        created_at: "2026-08-15T00:00:00Z".to_string(),
        updated_at: "2026-08-15T00:00:00Z".to_string(),
    };
    let res_json = serde_json::to_string(&project_res).unwrap();
    assert!(res_json.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(res_json.contains("\"organization_id\":\"660e8400-e29b-41d4-a716-446655440000\""));
    assert!(res_json.contains("\"name\":\"Mobile App\""));
    assert!(res_json.contains("\"slug\":\"mobile-app\""));
    assert!(!res_json.contains("public_id"));
}

#[test]
fn test_project_error_mappings() {
    let err = ProjectError::ProjectNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "project_not_found");

    let err = ProjectError::NameTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "name_taken");

    let err = ProjectError::SlugTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "slug_taken");

    let err = ProjectError::ProjectNotEmpty;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "project_not_empty");

    let err = ProjectError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = ProjectError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = ProjectError::InsufficientRole;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "insufficient_role");

    let err = ProjectError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = ProjectError::Unauthorized;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");

    let err = ProjectError::ValidationError("Name too long".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");
}
