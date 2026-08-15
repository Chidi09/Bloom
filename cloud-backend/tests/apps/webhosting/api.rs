use bloom_cloud_backend::apps::webhosting::contracts::{
    CreateCustomDomainRequest, CustomDomainResponse, DeployWebRequest, RequiredDnsRecord,
    WebDeploymentResponse,
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
        verification_token: "bloom_verify_xyz123".to_string(),
        certificate_status: "active".to_string(),
        certificate_expires_at: Some("2027-01-01T00:00:00Z".to_string()),
        verified_at: Some("2026-08-15T12:00:00Z".to_string()),
        failure_reason: None,
        required_records: vec![
            RequiredDnsRecord {
                record_type: "TXT".to_string(),
                host: "_bloom-challenge.store.example.com".to_string(),
                value: "bloom_verify_xyz123".to_string(),
                purpose: "Domain ownership verification".to_string(),
            },
            RequiredDnsRecord {
                record_type: "CNAME".to_string(),
                host: "store.example.com".to_string(),
                value: "store-app.bloomcloud.dev".to_string(),
                purpose: "Traffic routing (CNAME)".to_string(),
            },
        ],
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"dom-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"app_id\":\"app-123\""));
    assert!(serialized.contains("\"domain\":\"store.example.com\""));
    assert!(serialized.contains("\"verification_token\":\"bloom_verify_xyz123\""));
    assert!(serialized.contains("\"certificate_status\":\"active\""));
    assert!(serialized.contains("\"certificate_expires_at\":\"2027-01-01T00:00:00Z\""));
    assert!(serialized.contains("\"verified_at\":\"2026-08-15T12:00:00Z\""));
    assert!(serialized.contains("\"required_records\":["));
    assert!(serialized.contains("\"record_type\":\"TXT\""));
    assert!(serialized.contains("\"record_type\":\"CNAME\""));
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

    let err = WebHostingError::VerificationFailed("Missing TXT".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "verification_failed");

    let err = WebHostingError::DomainNotVerified("Domain unverified".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "domain_not_verified");

    let err = WebHostingError::NoPreviousDeployment;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "no_previous_deployment");

    let err = WebHostingError::InvalidMetadata("Bad JSON".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_metadata");

    let err = WebHostingError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = WebHostingError::ValidationError("Missing field".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");

    let err = WebHostingError::DnsError("Resolver timeout".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_GATEWAY);
    assert_eq!(dj_err.code(), "dns_error");

    let err = WebHostingError::CaddyError("Proxy unreachable".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "caddy_error");
}

#[test]
fn test_webhosting_list_pagination_envelope_and_slicing() {
    use bytes::Bytes;
    use djangors_core::Request;
    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    use hyper::http::{HeaderMap, Method, Uri};

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    // 1. Default page 1 request with no query params
    let req = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/webhosting/deployments"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 250_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1_results: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("dep-{i}"), "url": format!("https://app{i}.bloomcloud.dev") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1_results.clone());
    assert_eq!(env1["count"], 250);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 3);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    // 2. Page 2 request
    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/webhosting/deployments?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2_results: Vec<serde_json::Value> = (100..200)
        .map(|i| serde_json::json!({ "id": format!("dep-{i}"), "url": format!("https://app{i}.bloomcloud.dev") }))
        .collect();

    let env2 = pagination.envelope(&req_p2, total, dummy_page2_results.clone());
    assert_eq!(env2["page"], 2);
    assert_eq!(env2["total_pages"], 3);
    assert_eq!(env2["results"].as_array().unwrap().len(), 100);

    // Page 2 differs from Page 1 and shares no rows
    let page1_ids: std::collections::HashSet<_> = dummy_page1_results
        .iter()
        .map(|v| v["id"].as_str().unwrap())
        .collect();
    let page2_ids: std::collections::HashSet<_> = dummy_page2_results
        .iter()
        .map(|v| v["id"].as_str().unwrap())
        .collect();
    assert!(page1_ids.is_disjoint(&page2_ids));

    // 3. Oversized ?page_size= is clamped to max_page_size (100)
    let req_oversized = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/webhosting/deployments?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
    let slice_clamped = pagination.slice(&req_oversized, total);
    assert_eq!(slice_clamped.limit, 100);

    // Custom valid page_size
    let req_custom_size = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/webhosting/deployments?page_size=25"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_custom_size), 25);
    let slice_custom = pagination.slice(&req_custom_size, total);
    assert_eq!(slice_custom.limit, 25);
    assert_eq!(slice_custom.offset, 0);
}
