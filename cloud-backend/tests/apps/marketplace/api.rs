use bloom_cloud_backend::apps::marketplace::errors::MarketplaceError;
use bloom_cloud_backend::apps::marketplace::models::{Template, TemplateVersion};
use bloom_cloud_backend::apps::marketplace::serializers::{
    serialize_template, serialize_template_detail, serialize_template_version,
};
use chrono::Utc;
use djangors_core::{DjangorsError, StatusCode};
use djangors_orm::ForeignKey;

#[test]
fn test_template_response_serialization_wire_contract() {
    let template = Template {
        id: 10,
        public_id: "22222222-2222-4222-8222-222222222222".to_string(),
        organization_id: ForeignKey::new(5),
        name: "E-Commerce App".to_string(),
        slug: "e-commerce-app".to_string(),
        description: Some("Production e-commerce Flutter template".to_string()),
        visibility: "public".to_string(),
        status: "published".to_string(),
        metadata: r#"{"tags":["ecommerce","stripe"],"platform":"web"}"#.to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let org_pub = "11111111-1111-4111-8111-111111111111";
    let res = serialize_template(&template, org_pub, Some("1.2.0".to_string()), 3);
    let json_str = serde_json::to_string(&res).unwrap();

    // Wire contract asserts:
    assert!(json_str.contains("\"id\":\"22222222-2222-4222-8222-222222222222\""));
    assert!(json_str.contains("\"organization_id\":\"11111111-1111-4111-8111-111111111111\""));
    assert!(json_str.contains("\"name\":\"E-Commerce App\""));
    assert!(json_str.contains("\"slug\":\"e-commerce-app\""));
    assert!(json_str.contains("\"visibility\":\"public\""));
    assert!(json_str.contains("\"status\":\"published\""));
    assert!(json_str.contains("\"latest_version\":\"1.2.0\""));
    assert!(json_str.contains("\"versions_count\":3"));

    // Ensure metadata is serialized as real JSON object, not a raw escaped string
    assert!(json_str.contains("\"tags\":[\"ecommerce\",\"stripe\"]"));
    assert!(!json_str.contains("public_id"));
}

#[test]
fn test_template_detail_and_version_serialization() {
    let template = Template {
        id: 10,
        public_id: "22222222-2222-4222-8222-222222222222".to_string(),
        organization_id: ForeignKey::new(5),
        name: "E-Commerce App".to_string(),
        slug: "e-commerce-app".to_string(),
        description: Some("Template description".to_string()),
        visibility: "public".to_string(),
        status: "published".to_string(),
        metadata: "{}".to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let version = TemplateVersion {
        id: 101,
        public_id: "33333333-3333-4333-8333-333333333333".to_string(),
        template_id: ForeignKey::new(template.id),
        version: "1.0.0".to_string(),
        changelog: "Initial release".to_string(),
        manifest: r#"{"entrypoint":"lib/main.dart"}"#.to_string(),
        readme: "# E-Commerce Starter\nWelcome!".to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let detail = serialize_template_detail(
        &template,
        "11111111-1111-4111-8111-111111111111",
        std::slice::from_ref(&version),
    );
    assert_eq!(detail.versions.len(), 1);
    assert_eq!(
        detail.versions[0].id,
        "33333333-3333-4333-8333-333333333333"
    );
    assert_eq!(detail.versions[0].version, "1.0.0");

    let version_res = serialize_template_version(&version, &template.public_id);
    let v_json = serde_json::to_string(&version_res).unwrap();
    assert!(v_json.contains("\"id\":\"33333333-3333-4333-8333-333333333333\""));
    assert!(v_json.contains("\"template_id\":\"22222222-2222-4222-8222-222222222222\""));
    assert!(v_json.contains("\"version\":\"1.0.0\""));
    assert!(v_json.contains("\"entrypoint\":\"lib/main.dart\""));
}

#[test]
fn test_public_filtering_invariants() {
    let public_published = Template {
        id: 1,
        public_id: "pub-pub".to_string(),
        organization_id: ForeignKey::new(1),
        name: "Public Published".to_string(),
        slug: "pub-pub".to_string(),
        description: None,
        visibility: "public".to_string(),
        status: "published".to_string(),
        metadata: "{}".to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let private_published = Template {
        id: 2,
        public_id: "priv-pub".to_string(),
        organization_id: ForeignKey::new(1),
        name: "Private Published".to_string(),
        slug: "priv-pub".to_string(),
        description: None,
        visibility: "private".to_string(),
        status: "published".to_string(),
        metadata: "{}".to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let public_draft = Template {
        id: 3,
        public_id: "pub-draft".to_string(),
        organization_id: ForeignKey::new(1),
        name: "Public Draft".to_string(),
        slug: "pub-draft".to_string(),
        description: None,
        visibility: "public".to_string(),
        status: "draft".to_string(),
        metadata: "{}".to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let public_archived = Template {
        id: 4,
        public_id: "pub-arch".to_string(),
        organization_id: ForeignKey::new(1),
        name: "Public Archived".to_string(),
        slug: "pub-arch".to_string(),
        description: None,
        visibility: "public".to_string(),
        status: "archived".to_string(),
        metadata: "{}".to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let all = vec![
        public_published,
        private_published,
        public_draft,
        public_archived,
    ];

    let public_marketplace_visible: Vec<_> = all
        .into_iter()
        .filter(|t| t.visibility == "public" && t.status == "published")
        .collect();

    assert_eq!(public_marketplace_visible.len(), 1);
    assert_eq!(public_marketplace_visible[0].public_id, "pub-pub");
}

#[test]
fn test_marketplace_error_mappings() {
    let err = MarketplaceError::TemplateNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "template_not_found");

    let err = MarketplaceError::TemplateVersionNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "template_version_not_found");

    let err = MarketplaceError::SlugTaken;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "slug_taken");

    let err = MarketplaceError::VersionAlreadyExists;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "version_already_exists");

    let err = MarketplaceError::InvalidStateTransition {
        from: "archived".to_string(),
        to: "published".to_string(),
    };
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_state_transition");

    let err = MarketplaceError::TemplateNotPublished;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "template_not_found");

    let err = MarketplaceError::TemplatePrivate;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "template_not_found");

    let err = MarketplaceError::ValidationError("Bad name".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");

    let err = MarketplaceError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = MarketplaceError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = MarketplaceError::InsufficientRole;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "insufficient_role");

    let err = MarketplaceError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = MarketplaceError::Unauthorized;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");
}
