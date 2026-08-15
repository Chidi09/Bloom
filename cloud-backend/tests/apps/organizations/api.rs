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
