use bloom_cloud_backend::apps::deployments::models::Deployment;

#[test]
fn test_deployment_model_metadata() {
    let meta = Deployment::meta();
    assert_eq!(meta.app_label, "deployments");
    assert_eq!(meta.table_name, "deployments_deployment");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Deployment");
    assert_eq!(public_id_field.max_length, Some(36));

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on Deployment");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let platform_field = meta
        .fields
        .iter()
        .find(|f| f.name == "platform")
        .expect("platform field must exist on Deployment");
    assert_eq!(platform_field.max_length, Some(32));

    let target_field = meta
        .fields
        .iter()
        .find(|f| f.name == "target")
        .expect("target field must exist on Deployment");
    assert_eq!(target_field.max_length, Some(32));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on Deployment");
    assert_eq!(status_field.max_length, Some(32));
    assert!(status_field.db_index, "status must be indexed");

    let ext_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "external_id")
        .expect("external_id field must exist on Deployment");
    assert_eq!(ext_id_field.max_length, Some(255));

    let ext_url_field = meta
        .fields
        .iter()
        .find(|f| f.name == "external_url")
        .expect("external_url field must exist on Deployment");
    assert_eq!(ext_url_field.max_length, Some(500));

    // Assert that release_id and artifact_id are nullable fields
    let release_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "release_id")
        .expect("release_id field must exist");
    assert!(release_id_field.nullable);
    assert!(release_id_field.db_index);

    let artifact_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "artifact_id")
        .expect("artifact_id field must exist");
    assert!(artifact_id_field.nullable);
}
