use bloom_cloud_backend::apps::organizations::contracts::{
    AcceptInviteRequest, ChangeRoleRequest, InviteRequest, InviteResponse, MembershipResponse,
    OrganizationCreateRequest, OrganizationResponse, OrganizationUpdateRequest,
};
use bloom_cloud_backend::apps::organizations::errors::OrganizationError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_organizations_contracts_serialization() {
    let create_req: OrganizationCreateRequest =
        serde_json::from_str(r#"{"name":"Bloom Technologies"}"#).unwrap();
    assert_eq!(create_req.name, "Bloom Technologies");

    let update_req: OrganizationUpdateRequest =
        serde_json::from_str(r#"{"name":"Bloom Inc","billing_email":"billing@bloom.dev"}"#)
            .unwrap();
    assert_eq!(update_req.name, Some("Bloom Inc".to_string()));
    assert_eq!(
        update_req.billing_email,
        Some("billing@bloom.dev".to_string())
    );

    // Test partial update with omitted fields
    let partial_req: OrganizationUpdateRequest =
        serde_json::from_str(r#"{"billing_email":"finance@bloom.dev"}"#).unwrap();
    assert_eq!(partial_req.name, None);
    assert_eq!(
        partial_req.billing_email,
        Some("finance@bloom.dev".to_string())
    );

    let org_res = OrganizationResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        name: "Bloom Dev".to_string(),
        slug: "bloom-dev".to_string(),
        plan: "pro".to_string(),
        role: "owner".to_string(),
        created_at: "2026-08-15T00:00:00Z".to_string(),
    };
    let org_json = serde_json::to_string(&org_res).unwrap();
    assert!(org_json.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(org_json.contains("\"role\":\"owner\""));
    assert!(!org_json.contains("public_id"));

    let membership_res = MembershipResponse {
        id: "770e8400-e29b-41d4-a716-446655440000".to_string(),
        user_id: "990e8400-e29b-41d4-a716-446655440000".to_string(),
        email: "alice@bloom.dev".to_string(),
        username: "alice".to_string(),
        role: "developer".to_string(),
        created_at: "2026-08-15T00:00:00Z".to_string(),
    };
    let member_json = serde_json::to_string(&membership_res).unwrap();
    assert!(member_json.contains("\"email\":\"alice@bloom.dev\""));
    assert!(member_json.contains("\"role\":\"developer\""));

    let invite_req: InviteRequest =
        serde_json::from_str(r#"{"email":"bob@bloom.dev","role":"developer"}"#).unwrap();
    assert_eq!(invite_req.email, "bob@bloom.dev");
    assert_eq!(invite_req.role, "developer");

    let invite_res = InviteResponse {
        id: "110e8400-e29b-41d4-a716-446655440000".to_string(),
        email: "bob@bloom.dev".to_string(),
        role: "developer".to_string(),
        token: "tok_secret_12345".to_string(),
        expires_at: "2026-08-22T00:00:00Z".to_string(),
        created_at: "2026-08-15T00:00:00Z".to_string(),
    };
    let invite_json = serde_json::to_string(&invite_res).unwrap();
    assert!(invite_json.contains("\"token\":\"tok_secret_12345\""));

    let accept_req: AcceptInviteRequest =
        serde_json::from_str(r#"{"token":"tok_secret_12345"}"#).unwrap();
    assert_eq!(accept_req.token, "tok_secret_12345");

    let change_role_req: ChangeRoleRequest = serde_json::from_str(r#"{"role":"admin"}"#).unwrap();
    assert_eq!(change_role_req.role, "admin");
}

#[test]
fn test_organizations_error_mappings() {
    let err = OrganizationError::NameTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "name_taken");

    let err = OrganizationError::SlugTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "slug_taken");

    let err = OrganizationError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = OrganizationError::MembershipNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "membership_not_found");

    let err = OrganizationError::AlreadyMember;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "already_member");

    let err = OrganizationError::InviteNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "invite_not_found");

    let err = OrganizationError::InviteExpired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invite_expired");

    let err = OrganizationError::CannotRemoveLastOwner;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "cannot_remove_last_owner");

    let err = OrganizationError::OrganizationNotEmpty;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "organization_not_empty");

    let err = OrganizationError::InsufficientRole;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "insufficient_role");
}

#[test]
fn test_organizations_list_pagination_envelope_and_slicing() {
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
        Uri::from_static("/api/v1/organizations"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 150_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("org-{i}"), "name": format!("Org {i}") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1.clone());
    assert_eq!(env1["count"], 150);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 2);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/organizations?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2: Vec<serde_json::Value> = (100..150)
        .map(|i| serde_json::json!({ "id": format!("org-{i}"), "name": format!("Org {i}") }))
        .collect();

    let env2 = pagination.envelope(&req_p2, total, dummy_page2.clone());
    assert_eq!(env2["page"], 2);
    assert_eq!(env2["total_pages"], 2);
    assert_eq!(env2["results"].as_array().unwrap().len(), 50);

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
        Uri::from_static("/api/v1/organizations?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
}
