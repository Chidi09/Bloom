use bloom_cloud_backend::apps::accounts::permissions::CurrentOrganizationId;
use bloom_cloud_backend::apps::common::scoping::{
    organization_scope, OrganizationResolutionFailed,
};
use bloom_cloud_backend::apps::organizations::models::UserOrganizationMembership;
use bytes::Bytes;
use djangors_core::request::Request;
use djangors_core::StatusCode;
use djangors_orm::Model;
use hyper::http::{Extensions, HeaderMap, Method, Uri};

fn dummy_request_with_extensions(ext: Extensions) -> Request {
    Request::new(
        Method::GET,
        Uri::from_static("/test"),
        HeaderMap::new(),
        Bytes::new(),
    )
    .with_extensions(ext)
}

#[test]
fn test_organization_scope_rejects_missing_organization() {
    let req = dummy_request_with_extensions(Extensions::new());
    let qs = UserOrganizationMembership::objects();

    let res = organization_scope(&req, qs, "organization_id");
    assert!(res.is_err());

    let err = res.unwrap_err();
    assert_eq!(err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(err.code(), "organization_required");
}

#[test]
fn test_organization_scope_rejects_resolution_failed() {
    let mut ext = Extensions::new();
    ext.insert(OrganizationResolutionFailed);

    let req = dummy_request_with_extensions(ext);
    let qs = UserOrganizationMembership::objects();

    let res = organization_scope(&req, qs, "organization_id");
    assert!(res.is_err());

    let err = res.unwrap_err();
    assert_eq!(err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
}

#[test]
fn test_organization_scope_applies_filter_when_present() {
    let mut ext = Extensions::new();
    ext.insert(CurrentOrganizationId(123));

    let req = dummy_request_with_extensions(ext);
    let qs = UserOrganizationMembership::objects();

    let res = organization_scope(&req, qs, "organization_id");
    assert!(res.is_ok());
}
