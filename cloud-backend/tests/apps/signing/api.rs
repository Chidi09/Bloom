use bloom_cloud_backend::apps::signing::contracts::{
    SigningIdentityCreateRequest, SigningIdentityMetadata, SigningIdentityResponse,
    WorkerSigningIdentity, WorkerSigningResponse,
};
use bloom_cloud_backend::apps::signing::errors::SigningError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_signing_contracts_serialization_and_deserialization() {
    let req_json = r#"{
        "platform": "ios",
        "name": "Production Provisioning Profile",
        "kind": "provisioning_profile",
        "material": "YmFzZTY0LWNvbnRlbnQ=",
        "metadata": {
            "kind": "provisioning_profile",
            "bundle_id": "dev.bloomcloud.app",
            "uuid": "e86d4b24-180b-4890-a7d9-c0c169229871"
        },
        "expires_at": "2027-06-01T00:00:00Z"
    }"#;

    let create_req: SigningIdentityCreateRequest = serde_json::from_str(req_json).unwrap();
    assert_eq!(create_req.platform, "ios");
    assert_eq!(create_req.name, "Production Provisioning Profile");
    assert_eq!(create_req.kind, "provisioning_profile");
    assert_eq!(create_req.material, "YmFzZTY0LWNvbnRlbnQ=");
    assert_eq!(
        create_req.expires_at,
        Some("2027-06-01T00:00:00Z".to_string())
    );

    match create_req.metadata {
        SigningIdentityMetadata::ProvisioningProfile { bundle_id, uuid } => {
            assert_eq!(bundle_id, "dev.bloomcloud.app");
            assert_eq!(uuid, "e86d4b24-180b-4890-a7d9-c0c169229871");
        }
        _ => panic!("Expected ProvisioningProfile metadata variant"),
    }

    let response = SigningIdentityResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "660e8400-e29b-41d4-a716-446655440000".to_string(),
        platform: "android".to_string(),
        name: "Upload Key".to_string(),
        kind: "keystore".to_string(),
        metadata: serde_json::json!({ "kind": "keystore", "alias": "upload" }),
        expires_at: Some("2030-01-01T00:00:00Z".to_string()),
        is_expiring: false,
        created_at: "2026-08-15T00:00:00Z".to_string(),
    };

    let res_json = serde_json::to_string(&response).unwrap();
    assert!(res_json.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(res_json.contains("\"organization_id\":\"660e8400-e29b-41d4-a716-446655440000\""));
    assert!(res_json.contains("\"platform\":\"android\""));
    assert!(res_json.contains("\"alias\":\"upload\""));
    assert!(res_json.contains("\"is_expiring\":false"));
    assert!(!res_json.contains("public_id"));
    assert!(!res_json.contains("encrypted_material"));

    let worker_signing = WorkerSigningIdentity {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        platform: "android".to_string(),
        name: "Upload Key".to_string(),
        kind: "keystore".to_string(),
        material: "decrypted_base64_material".to_string(),
        metadata: serde_json::json!({ "alias": "upload" }),
        expires_at: None,
    };
    let worker_res = WorkerSigningResponse {
        identities: vec![worker_signing],
    };
    let worker_json = serde_json::to_string(&worker_res).unwrap();
    assert!(worker_json.contains("\"material\":\"decrypted_base64_material\""));
}

#[test]
fn test_signing_error_mappings() {
    let err = SigningError::SigningIdentityNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "signing_identity_not_found");

    let err = SigningError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = SigningError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = SigningError::InsufficientRole;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "insufficient_role");

    let err = SigningError::Unauthorized;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");

    let err = SigningError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = SigningError::InvalidPlatform("windows".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_platform");

    let err = SigningError::InvalidKind("ssh_key".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_kind");

    let err = SigningError::MetadataMismatch("Kind mismatch".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "metadata_mismatch");

    let err = SigningError::InvalidMaterial("empty".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_material");

    let err = SigningError::InvalidExpiryDate("bad date".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_expiry_date");

    let err = SigningError::ValidationError("Name too long".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");

    let err = SigningError::Crypto("Decryption failed".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "cryptographic_error");

    let err = SigningError::Database("connection timeout".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "database_error");
}

#[test]
fn test_signing_list_pagination_envelope_and_slicing() {
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
        Uri::from_static("/api/v1/signing"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 101_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("sign-{i}"), "name": format!("Sign {i}") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1.clone());
    assert_eq!(env1["count"], 101);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 2);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/signing?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2: Vec<serde_json::Value> = (100..101)
        .map(|i| serde_json::json!({ "id": format!("sign-{i}"), "name": format!("Sign {i}") }))
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
        Uri::from_static("/api/v1/signing?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
}
