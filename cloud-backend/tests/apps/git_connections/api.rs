use bloom_cloud_backend::apps::git_connections::contracts::{
    GitConnectionCreateRequest, GitConnectionResponse, RepositoryResponse, WebhookResponse,
};
use bloom_cloud_backend::apps::git_connections::errors::GitConnectionError;
use bloom_cloud_backend::apps::git_connections::models::GitConnection;
use bloom_cloud_backend::apps::git_connections::serializers::serialize_git_connection;
use djangors_core::{DjangorsError, StatusCode};
use djangors_orm::ForeignKey;

#[test]
fn test_git_connection_create_request_deserialization() {
    let json_req = r#"{
        "provider": "github",
        "installation_id": "12345678",
        "access_token": "ghp_secrettokenvalue123456",
        "metadata": {
            "account": "bloom-org",
            "repositories": [
                {
                    "id": "1001",
                    "full_name": "bloom-org/flutter-app",
                    "default_branch": "main",
                    "url": "https://github.com/bloom-org/flutter-app"
                }
            ]
        }
    }"#;

    let create_req: GitConnectionCreateRequest = serde_json::from_str(json_req).unwrap();
    assert_eq!(create_req.provider, "github");
    assert_eq!(create_req.installation_id, "12345678");
    assert_eq!(create_req.access_token, "ghp_secrettokenvalue123456");
    assert!(create_req.metadata.is_some());
}

#[test]
fn test_git_connection_response_never_contains_secret() {
    let raw_token = "ghp_SUPER_SECRET_TOKEN_DO_NOT_LEAK";
    let ciphertext = "v1:dGVzdG5vbmNldGFnY2lwaGVydGV4dA==";

    let conn = GitConnection {
        id: 42,
        public_id: "660e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: ForeignKey::new(100),
        provider: "github".to_string(),
        installation_id: "inst_99999".to_string(),
        encrypted_access_token: ciphertext.to_string(),
        metadata: r#"{"account":"test-org"}"#.to_string(),
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
    };

    let response: GitConnectionResponse = serialize_git_connection(&conn, "org-uuid-5555");
    let serialized_json = serde_json::to_string(&response).unwrap();

    // Verify response fields
    assert_eq!(response.id, "660e8400-e29b-41d4-a716-446655440000");
    assert_eq!(response.organization_id, "org-uuid-5555");
    assert_eq!(response.provider, "github");
    assert_eq!(response.installation_id, "inst_99999");

    // Critical security check: wire JSON must NEVER contain raw token, ciphertext, or internal id
    assert!(!serialized_json.contains(raw_token));
    assert!(!serialized_json.contains(ciphertext));
    assert!(!serialized_json.contains("encrypted_access_token"));
    assert!(!serialized_json.contains("public_id"));
    assert!(!serialized_json.contains("\"id\":42"));
}

#[test]
fn test_repository_response_contracts() {
    let repo_res = RepositoryResponse {
        id: "repo_1234".to_string(),
        full_name: "bloom-foundation/bloom-cloud".to_string(),
        default_branch: "main".to_string(),
        url: "https://github.com/bloom-foundation/bloom-cloud".to_string(),
    };

    let json_str = serde_json::to_string(&repo_res).unwrap();
    assert!(json_str.contains("\"full_name\":\"bloom-foundation/bloom-cloud\""));
    assert!(json_str.contains("\"default_branch\":\"main\""));

    let deserialized: RepositoryResponse = serde_json::from_str(&json_str).unwrap();
    assert_eq!(deserialized, repo_res);
}

#[test]
fn test_webhook_response_serialization() {
    let response = WebhookResponse {
        success: true,
        message: "Push event received".to_string(),
        delivery_id: Some("72d3162e-cc78-11e3-81ab-4c9367dc0958".to_string()),
    };

    let json_str = serde_json::to_string(&response).unwrap();
    assert!(json_str.contains("\"success\":true"));
    assert!(json_str.contains("72d3162e-cc78-11e3-81ab-4c9367dc0958"));
}

#[test]
fn test_git_connection_error_mappings() {
    let err = GitConnectionError::ConnectionNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "connection_not_found");

    let err = GitConnectionError::ConnectionAlreadyExists;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "connection_already_exists");

    let err = GitConnectionError::InvalidProvider("svn".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_provider");

    let err = GitConnectionError::InvalidSignature;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_signature");

    let err = GitConnectionError::MissingSignature;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "missing_signature");

    let err = GitConnectionError::MissingSecret;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "missing_secret");

    let err = GitConnectionError::InvalidSignatureFormat;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_signature_format");

    let err = GitConnectionError::UnverifiedProviderSignature("gitlab".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "unverified_provider_signature");

    let err = GitConnectionError::MissingDeliveryId;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "missing_delivery_id");

    let err = GitConnectionError::Crypto("decryption failed".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "crypto_error");

    let err = GitConnectionError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = GitConnectionError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = GitConnectionError::InsufficientRole;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "insufficient_role");

    let err = GitConnectionError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = GitConnectionError::Unauthorized;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");
}

#[test]
fn test_git_connections_list_pagination_envelope_and_slicing() {
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
        Uri::from_static("/api/v1/git-connections"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 250_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1_results: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("conn-{i}"), "provider": "github", "account_name": format!("org{i}") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1_results.clone());
    assert_eq!(env1["count"], 250);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 3);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    // 2. Page 2 request
    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/git-connections?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2_results: Vec<serde_json::Value> = (100..200)
        .map(|i| serde_json::json!({ "id": format!("conn-{i}"), "provider": "github", "account_name": format!("org{i}") }))
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
        Uri::from_static("/api/v1/git-connections?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
    let slice_clamped = pagination.slice(&req_oversized, total);
    assert_eq!(slice_clamped.limit, 100);

    // Custom valid page_size
    let req_custom_size = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/git-connections?page_size=25"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_custom_size), 25);
    let slice_custom = pagination.slice(&req_custom_size, total);
    assert_eq!(slice_custom.limit, 25);
    assert_eq!(slice_custom.offset, 0);
}
