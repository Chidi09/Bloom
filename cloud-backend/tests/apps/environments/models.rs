use bloom_cloud_backend::apps::environments::models::Environment;

#[test]
fn test_environment_model_metadata() {
    let meta = Environment::meta();
    assert_eq!(meta.app_label, "environments");
    assert_eq!(meta.table_name, "environments_environment");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Environment");
    assert_eq!(public_id_field.max_length, Some(36));

    let app_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "app_id")
        .expect("app_id field must exist on Environment");
    assert!(app_id_field.db_index, "app_id must be indexed");

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on Environment");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Environment");
    assert_eq!(name_field.max_length, Some(255));

    let slug_field = meta
        .fields
        .iter()
        .find(|f| f.name == "slug")
        .expect("slug field must exist on Environment");
    assert_eq!(slug_field.max_length, Some(64));

    let build_profile_field = meta
        .fields
        .iter()
        .find(|f| f.name == "build_profile")
        .expect("build_profile field must exist on Environment");
    assert_eq!(build_profile_field.max_length, Some(32));

    // Verify unique_together constraint contains (app_id, slug)
    assert!(
        meta.unique_together
            .iter()
            .any(|ut| ut.contains(&"app_id") && ut.contains(&"slug")),
        "unique_together must include app_id and slug"
    );
}
