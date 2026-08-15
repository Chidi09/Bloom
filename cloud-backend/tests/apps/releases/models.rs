use bloom_cloud_backend::apps::releases::models::Release;

#[test]
fn test_release_model_metadata() {
    let meta = Release::meta();
    assert_eq!(meta.app_label, "releases");
    assert_eq!(meta.table_name, "releases_release");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Release");
    assert_eq!(public_id_field.max_length, Some(36));

    let version_field = meta
        .fields
        .iter()
        .find(|f| f.name == "version")
        .expect("version field must exist on Release");
    assert_eq!(version_field.max_length, Some(64));

    let commit_field = meta
        .fields
        .iter()
        .find(|f| f.name == "commit")
        .expect("commit field must exist on Release");
    assert_eq!(commit_field.max_length, Some(40));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on Release");
    assert_eq!(status_field.max_length, Some(32));
    assert!(status_field.db_index, "status must be indexed");

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on Release");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let platforms_field = meta
        .fields
        .iter()
        .find(|f| f.name == "platforms")
        .expect("platforms field must exist on Release");
    assert!(!platforms_field.db_index);

    let artifacts_field = meta
        .fields
        .iter()
        .find(|f| f.name == "artifacts")
        .expect("artifacts field must exist on Release");
    assert!(!artifacts_field.db_index);

    let rollout_field = meta
        .fields
        .iter()
        .find(|f| f.name == "rollout_status")
        .expect("rollout_status field must exist on Release");
    assert!(!rollout_field.db_index);

    // app_id is a required relation and carries relation metadata.
    let fk_fields: Vec<&str> = meta.relations.iter().map(|r| r.field_name).collect();
    assert!(
        fk_fields.contains(&"app_id"),
        "app_id must be a foreign key relation"
    );

    // environment_id is a NULLABLE foreign key. Djangors 0.7.0 cannot express one as a
    // relation: the Model derive matches relations on the outer type, so
    // `Option<ForeignKey<Environment>>` is rejected outright and the field must be declared
    // `Option<i64>`. It therefore carries no relation metadata, and the referential
    // integrity is enforced by the migration's
    // `REFERENCES environments_environment(id) ON DELETE SET NULL` instead. Assert the
    // nullable column exists rather than a relation that cannot exist.
    assert!(
        !fk_fields.contains(&"environment_id"),
        "environment_id cannot be a relation: nullable foreign keys are not expressible"
    );
    let env_field = meta
        .fields
        .iter()
        .find(|f| f.name == "environment_id")
        .expect("environment_id field must exist on Release");
    assert!(env_field.nullable, "environment_id must be nullable");
}
