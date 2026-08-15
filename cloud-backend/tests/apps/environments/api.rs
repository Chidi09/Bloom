use bloom_cloud_backend::apps::environments::contracts::{
    ApiConfig, EnvVar, EnvironmentCreateRequest, EnvironmentResponse, EnvironmentUpdateRequest,
    FeatureFlag,
};
use bloom_cloud_backend::apps::environments::errors::EnvironmentError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_environment_contracts_serialization_and_deserialization() {
    let create_json = r#"{
        "app_id": "app-uuid-123",
        "name": "Production",
        "slug": "production",
        "api_config": {
            "env_vars": [
                {"key": "API_URL", "value": "https://api.example.com"}
            ],
            "feature_flags": [
                {"key": "new_ui", "enabled": true}
            ]
        },
        "build_profile": "release",
        "flutter_version": "3.22.0",
        "dart_version": "3.4.0",
        "bloom_version": "0.7.0",
        "flavor": "prod"
    }"#;

    let create_req: EnvironmentCreateRequest = serde_json::from_str(create_json).unwrap();
    assert_eq!(create_req.app_id, "app-uuid-123");
    assert_eq!(create_req.name, "Production");
    assert_eq!(create_req.slug, "production");
    assert_eq!(create_req.build_profile, Some("release".to_string()));
    assert_eq!(create_req.flutter_version, Some("3.22.0".to_string()));
    assert_eq!(create_req.api_config.env_vars.len(), 1);
    assert_eq!(create_req.api_config.env_vars[0].key, "API_URL");
    assert_eq!(create_req.api_config.feature_flags.len(), 1);
    assert_eq!(create_req.api_config.feature_flags[0].key, "new_ui");
    assert!(create_req.api_config.feature_flags[0].enabled);

    // Partial update contract
    let update_json = r#"{
        "name": "Production Updated",
        "flutter_version": "3.24.0"
    }"#;
    let update_req: EnvironmentUpdateRequest = serde_json::from_str(update_json).unwrap();
    assert_eq!(update_req.name, Some("Production Updated".to_string()));
    assert_eq!(update_req.flutter_version, Some("3.24.0".to_string()));
    assert_eq!(update_req.api_config, None);
    assert_eq!(update_req.build_profile, None);
    assert_eq!(update_req.dart_version, None);
    assert_eq!(update_req.bloom_version, None);
    assert_eq!(update_req.flavor, None);

    // Wire response serialization
    let env_res = EnvironmentResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        app_id: "app-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        name: "Staging".to_string(),
        slug: "staging".to_string(),
        api_config: ApiConfig {
            env_vars: vec![EnvVar {
                key: "BASE".to_string(),
                value: "staging.example.com".to_string(),
            }],
            feature_flags: vec![FeatureFlag {
                key: "test_flag".to_string(),
                enabled: false,
            }],
        },
        build_profile: "debug".to_string(),
        flutter_version: Some("3.22.0".to_string()),
        dart_version: None,
        bloom_version: Some("0.7.0".to_string()),
        flavor: None,
        created_at: "2026-08-15T00:00:00Z".to_string(),
        updated_at: "2026-08-15T00:00:00Z".to_string(),
    };

    let serialized_res = serde_json::to_string(&env_res).unwrap();
    assert!(serialized_res.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized_res.contains("\"app_id\":\"app-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(
        serialized_res.contains("\"organization_id\":\"org-550e8400-e29b-41d4-a716-446655440000\"")
    );
    assert!(serialized_res.contains("\"slug\":\"staging\""));
    assert!(serialized_res.contains("\"build_profile\":\"debug\""));
    assert!(!serialized_res.contains("public_id"));
}

#[test]
fn test_environment_error_mappings() {
    let err = EnvironmentError::SlugTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "slug_taken");

    let err = EnvironmentError::EnvironmentNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = EnvironmentError::AppNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = EnvironmentError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = EnvironmentError::InvalidBuildProfile;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_build_profile");

    let err = EnvironmentError::InvalidApiConfig("bad json".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_api_config");

    let err = EnvironmentError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = EnvironmentError::ValidationError("Missing field".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");
}

#[test]
fn test_environments_list_pagination_envelope_and_slicing() {
    use bytes::Bytes;
    use djangors_core::Request;
    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    use hyper::http::{HeaderMap, Method, Uri};

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let req = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/environments"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 205_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("env-{i}"), "name": format!("Env {i}") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1.clone());
    assert_eq!(env1["count"], 205);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 3);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/environments?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2: Vec<serde_json::Value> = (100..200)
        .map(|i| serde_json::json!({ "id": format!("env-{i}"), "name": format!("Env {i}") }))
        .collect();

    let env2 = pagination.envelope(&req_p2, total, dummy_page2.clone());
    assert_eq!(env2["page"], 2);
    assert_eq!(env2["total_pages"], 3);
    assert_eq!(env2["results"].as_array().unwrap().len(), 100);

    let p1_ids: std::collections::HashSet<_> = dummy_page1
        .iter()
        .map(|v| v["id"].as_str().unwrap())
        .collect();
    let p2_ids: std::collections::HashSet<_> = dummy_page2
        .iter()
        .map(|v| v["id"].as_str().unwrap())
        .collect();
    assert!(p1_ids.is_disjoint(&p2_ids));

    let req_oversized = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/environments?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
}
