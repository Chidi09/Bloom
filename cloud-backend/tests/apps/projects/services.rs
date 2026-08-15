use bloom_cloud_backend::apps::projects::contracts::{ProjectCreateRequest, ProjectUpdateRequest};
use bloom_cloud_backend::apps::projects::services::slugify;

#[test]
fn test_slugify_logic() {
    assert_eq!(slugify("My Awesome Project"), "my-awesome-project");
    assert_eq!(slugify("Bloom Engine v2.0!"), "bloom-engine-v2-0");
    assert_eq!(slugify("  --spaces-and-dashes--  "), "spaces-and-dashes");
    assert_eq!(slugify("123-numbers"), "123-numbers");
    assert_eq!(slugify(""), "project");
}

#[test]
fn test_slugify_max_length() {
    let long_name = "a".repeat(100);
    let slug = slugify(&long_name);
    assert!(slug.len() <= 60);
}

#[test]
fn test_project_create_request_validation_contracts() {
    let req = ProjectCreateRequest {
        name: "Web Portal".to_string(),
        description: Some("Customer web dashboard".to_string()),
    };
    assert_eq!(req.name, "Web Portal");
    assert_eq!(req.description, Some("Customer web dashboard".to_string()));
}

#[test]
fn test_project_update_request_partial_contracts() {
    let req: ProjectUpdateRequest = serde_json::from_str(r#"{"name":"New Name"}"#).unwrap();
    assert_eq!(req.name, Some("New Name".to_string()));
    assert_eq!(req.description, None);

    let empty_update: ProjectUpdateRequest = serde_json::from_str(r#"{}"#).unwrap();
    assert_eq!(empty_update.name, None);
    assert_eq!(empty_update.description, None);
}
