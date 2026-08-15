use bloom_cloud_backend::apps::artifacts::models::Artifact;

#[test]
fn test_artifact_model_metadata() {
    let meta = Artifact::meta();
    assert_eq!(meta.app_label, "artifacts");
    assert_eq!(meta.table_name, "artifacts_artifact");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Artifact");
    assert_eq!(public_id_field.max_length, Some(36));

    let build_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "build_id")
        .expect("build_id field must exist on Artifact");
    assert!(build_id_field.db_index, "build_id must be indexed");

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on Artifact");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let platform_field = meta
        .fields
        .iter()
        .find(|f| f.name == "platform")
        .expect("platform field must exist on Artifact");
    assert_eq!(platform_field.max_length, Some(32));

    let kind_field = meta
        .fields
        .iter()
        .find(|f| f.name == "kind")
        .expect("kind field must exist on Artifact");
    assert_eq!(kind_field.max_length, Some(32));

    let storage_key_field = meta
        .fields
        .iter()
        .find(|f| f.name == "storage_key")
        .expect("storage_key field must exist on Artifact");
    assert_eq!(storage_key_field.max_length, Some(500));

    let storage_bucket_field = meta
        .fields
        .iter()
        .find(|f| f.name == "storage_bucket")
        .expect("storage_bucket field must exist on Artifact");
    assert_eq!(storage_bucket_field.max_length, Some(255));

    let file_name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "file_name")
        .expect("file_name field must exist on Artifact");
    assert_eq!(file_name_field.max_length, Some(255));

    let checksum_field = meta
        .fields
        .iter()
        .find(|f| f.name == "checksum")
        .expect("checksum field must exist on Artifact");
    assert_eq!(checksum_field.max_length, Some(64));

    let version_field = meta
        .fields
        .iter()
        .find(|f| f.name == "version")
        .expect("version field must exist on Artifact");
    assert_eq!(version_field.max_length, Some(64));
}
