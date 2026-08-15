use bloom_cloud_backend::apps::credentials::contracts::{
    CredentialCreateRequest, CredentialMetadata, CredentialResponse, CredentialTestResponse,
};
use bloom_cloud_backend::apps::credentials::errors::CredentialError;
use bloom_cloud_backend::apps::credentials::models::Credential;
use bloom_cloud_backend::apps::credentials::serializers::serialize_credential;
use djangors_core::{DjangorsError, StatusCode};
use djangors_orm::ForeignKey;

#[test]
fn test_credential_contracts_serialization_and_deserialization() {
    let json_req = r#"{
        "provider": "apple",
        "name": "Production App Store Key",
        "token": "-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...\n-----END PRIVATE KEY-----",
        "metadata": {
            "provider": "apple",
            "key_id": "ABC1234XYZ",
            "issuer_id": "11111111-2222-3333-4444-555555555555",
            "team_id": "TEAM12345"
        },
        "expires_at": "2027-01-01T00:00:00Z"
    }"#;

    let create_req: CredentialCreateRequest = serde_json::from_str(json_req).unwrap();
    assert_eq!(create_req.provider, "apple");
    assert_eq!(create_req.name, "Production App Store Key");
    assert!(create_req.token.contains("BEGIN PRIVATE KEY"));
    assert_eq!(
        create_req.expires_at,
        Some("2027-01-01T00:00:00Z".to_string())
    );

    match create_req.metadata {
        CredentialMetadata::Apple {
            key_id,
            issuer_id,
            team_id,
        } => {
            assert_eq!(key_id, "ABC1234XYZ");
            assert_eq!(issuer_id, "11111111-2222-3333-4444-555555555555");
            assert_eq!(team_id, "TEAM12345");
        }
        _ => panic!("Expected Apple metadata variant"),
    }
}

#[test]
fn test_credential_response_never_contains_secret() {
    let raw_secret = "SUPER_SECRET_PLATFORM_KEY_DO_NOT_LEAK";
    let ciphertext = "v1:dGVzdG5vbmNldGFnY2lwaGVydGV4dA==";

    let cred = Credential {
        id: 1,
        public_id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: ForeignKey::new(10),
        provider: "apple".to_string(),
        name: "Apple Store".to_string(),
        encrypted_token: ciphertext.to_string(),
        metadata: r#"{"provider":"apple","key_id":"KEY1","issuer_id":"ISS1","team_id":"TM1"}"#
            .to_string(),
        expires_at: None,
        last_used_at: None,
        created_by_id: 2,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
    };

    let response: CredentialResponse = serialize_credential(&cred, "org-uuid-1234");
    let serialized_json = serde_json::to_string(&response).unwrap();

    // Verify response fields
    assert_eq!(response.id, "550e8400-e29b-41d4-a716-446655440000");
    assert_eq!(response.organization_id, "org-uuid-1234");
    assert_eq!(response.provider, "apple");
    assert_eq!(response.name, "Apple Store");

    // Critical security check: wire JSON must NEVER contain raw secret, ciphertext, or internal id
    assert!(!serialized_json.contains(raw_secret));
    assert!(!serialized_json.contains(ciphertext));
    assert!(!serialized_json.contains("encrypted_token"));
    assert!(!serialized_json.contains("public_id"));
    assert!(!serialized_json.contains("\"id\":1"));
}

#[test]
fn test_credential_test_response_serialization() {
    let test_res = CredentialTestResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        provider: "google_play".to_string(),
        success: true,
        message: "Successfully validated google_play credentials".to_string(),
    };
    let json_str = serde_json::to_string(&test_res).unwrap();
    assert!(json_str.contains("\"success\":true"));
    assert!(json_str.contains("\"provider\":\"google_play\""));
}

#[test]
fn test_credential_error_mappings() {
    let err = CredentialError::CredentialNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "credential_not_found");

    let err = CredentialError::NameTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "name_taken");

    let err = CredentialError::InvalidProvider("unknown".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_provider");

    let err = CredentialError::InvalidMetadata("bad metadata".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_metadata");

    let err = CredentialError::InvalidToken("empty".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_token");

    let err = CredentialError::Crypto("key failed".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "crypto_error");

    let err = CredentialError::ValidationFailed("API returned 401".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_failed");

    let err = CredentialError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = CredentialError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = CredentialError::InsufficientRole;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "insufficient_role");

    let err = CredentialError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = CredentialError::Unauthorized;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");
}

#[test]
fn test_credentials_list_pagination_envelope_and_slicing() {
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
        Uri::from_static("/api/v1/credentials"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 101_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1: Vec<serde_json::Value> = (0..100)
        .map(
            |i| serde_json::json!({ "id": format!("cred-{i}"), "name": format!("Credential {i}") }),
        )
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1.clone());
    assert_eq!(env1["count"], 101);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 2);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/credentials?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2: Vec<serde_json::Value> = (100..101)
        .map(
            |i| serde_json::json!({ "id": format!("cred-{i}"), "name": format!("Credential {i}") }),
        )
        .collect();

    let env2 = pagination.envelope(&req_p2, total, dummy_page2.clone());
    assert_eq!(env2["page"], 2);
    assert_eq!(env2["total_pages"], 2);
    assert_eq!(env2["results"].as_array().unwrap().len(), 1);

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
        Uri::from_static("/api/v1/credentials?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
}
