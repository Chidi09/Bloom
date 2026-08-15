use bloom_cloud_backend::apps::apps::models::App;

#[test]
fn test_apps_model_metadata() {
    let app_meta = App::meta();
    assert_eq!(app_meta.app_label, "apps");
    assert_eq!(app_meta.table_name, "apps_app");

    let slug_field = app_meta
        .fields
        .iter()
        .find(|f| f.name == "slug")
        .expect("slug field must exist on App");
    assert_eq!(slug_field.max_length, Some(64));

    let public_id_field = app_meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on App");
    assert_eq!(public_id_field.max_length, Some(36));

    let project_id_field = app_meta
        .fields
        .iter()
        .find(|f| f.name == "project_id")
        .expect("project_id field must exist on App");
    assert!(project_id_field.db_index, "project_id must be indexed");

    let org_id_field = app_meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on App");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let repo_url_field = app_meta
        .fields
        .iter()
        .find(|f| f.name == "repository_url")
        .expect("repository_url field must exist on App");
    assert_eq!(repo_url_field.max_length, Some(500));
    assert!(repo_url_field.nullable);

    let branch_field = app_meta
        .fields
        .iter()
        .find(|f| f.name == "default_branch")
        .expect("default_branch field must exist on App");
    assert_eq!(branch_field.max_length, Some(255));
}
