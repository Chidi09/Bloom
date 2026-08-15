use bloom_cloud_backend::apps::marketplace::contracts::{
    TemplateCreateRequest, TemplatePublishRequest, TemplateUpdateRequest,
    TemplateVersionCreateRequest,
};
use bloom_cloud_backend::apps::marketplace::serializers::parse_json_safely;
use bloom_cloud_backend::apps::marketplace::services::{
    can_transition, slugify, validate_status, validate_version, validate_visibility,
    VALID_STATUSES, VALID_VISIBILITIES,
};

#[test]
fn test_template_status_transition_matrix() {
    // 1. Legal transitions from draft
    assert!(
        can_transition("draft", "published"),
        "draft can be published"
    );
    assert!(can_transition("draft", "archived"), "draft can be archived");
    assert!(!can_transition("draft", "draft"));

    // 2. Legal transitions from published
    assert!(
        can_transition("published", "draft"),
        "published can return to draft"
    );
    assert!(
        can_transition("published", "archived"),
        "published can be archived"
    );
    assert!(!can_transition("published", "published"));

    // 3. Archived is strictly absorbing terminal state
    assert!(
        !can_transition("archived", "draft"),
        "archived cannot transition to draft"
    );
    assert!(
        !can_transition("archived", "published"),
        "archived cannot transition to published"
    );
    assert!(!can_transition("archived", "archived"));

    // 4. Unknown statuses
    assert!(!can_transition("unknown", "published"));
    assert!(!can_transition("draft", "unknown"));
}

#[test]
fn test_slugify_logic() {
    assert_eq!(slugify("Flutter SaaS Starter"), "flutter-saas-starter");
    assert_eq!(slugify("Bloom E-Commerce v2.0!"), "bloom-e-commerce-v2-0");
    assert_eq!(slugify("  --spaces-and-dashes--  "), "spaces-and-dashes");
    assert_eq!(slugify("123-numbers"), "123-numbers");
    assert_eq!(slugify(""), "template");
}

#[test]
fn test_slugify_max_length() {
    let long_name = "x".repeat(120);
    let slug = slugify(&long_name);
    assert!(slug.len() <= 60);
}

#[test]
fn test_validate_version_semver() {
    assert!(validate_version("1.0.0").is_ok());
    assert!(validate_version("0.1.0-alpha.1").is_ok());
    assert!(validate_version("v2.3.4").is_ok());

    assert!(validate_version("").is_err());
    assert!(validate_version("   ").is_err());
    assert!(validate_version("not-a-semver").is_err());
    assert!(validate_version(&"1".repeat(70)).is_err());
}

#[test]
fn test_validate_visibility_and_status() {
    for vis in VALID_VISIBILITIES {
        assert!(validate_visibility(vis).is_ok());
    }
    assert!(validate_visibility("secret").is_err());

    for st in VALID_STATUSES {
        assert!(validate_status(st).is_ok());
    }
    assert!(validate_status("in_review").is_err());
}

#[test]
fn test_json_in_text_roundtripping() {
    let empty = parse_json_safely("");
    assert_eq!(empty, serde_json::json!({}));

    let invalid = parse_json_safely("not-json{");
    assert_eq!(invalid, serde_json::json!({}));

    let raw = r#"{"tags":["flutter","mobile"],"platforms":["ios","android"],"framework_version":"3.24.0"}"#;
    let parsed = parse_json_safely(raw);
    assert_eq!(parsed["framework_version"], "3.24.0");
    assert_eq!(parsed["tags"][0], "flutter");
    assert_eq!(parsed["tags"][1], "mobile");
    assert_eq!(parsed["platforms"][0], "ios");
}

#[test]
fn test_contracts_deserialization() {
    let create_req: TemplateCreateRequest = serde_json::from_str(
        r#"{"name":"Mobile Starter","description":"Starter kit","visibility":"public","metadata":{"category":"mobile"}}"#,
    )
    .unwrap();
    assert_eq!(create_req.name, "Mobile Starter");
    assert_eq!(create_req.visibility, Some("public".to_string()));

    let update_req: TemplateUpdateRequest =
        serde_json::from_str(r#"{"status":"published"}"#).unwrap();
    assert_eq!(update_req.status, Some("published".to_string()));
    assert_eq!(update_req.name, None);

    let publish_req: TemplatePublishRequest =
        serde_json::from_str(r#"{"visibility":"public"}"#).unwrap();
    assert_eq!(publish_req.visibility, Some("public".to_string()));

    let version_req: TemplateVersionCreateRequest = serde_json::from_str(
        r#"{"version":"1.0.0","changelog":"Initial release","manifest":{"dependencies":{"bloom":"^0.1.0"}}}"#,
    )
    .unwrap();
    assert_eq!(version_req.version, "1.0.0");
    assert_eq!(version_req.changelog, Some("Initial release".to_string()));
}
