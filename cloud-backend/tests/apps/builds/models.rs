use bloom_cloud_backend::apps::builds::models::{Build, BuildStage};

#[test]
fn test_build_model_metadata() {
    let meta = Build::meta();
    assert_eq!(meta.app_label, "builds");
    assert_eq!(meta.table_name, "builds_build");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Build");
    assert_eq!(public_id_field.max_length, Some(36));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on Build");
    assert_eq!(status_field.max_length, Some(32));
    assert!(status_field.db_index, "status must be indexed");

    let platform_field = meta
        .fields
        .iter()
        .find(|f| f.name == "platform")
        .expect("platform field must exist on Build");
    assert_eq!(platform_field.max_length, Some(32));

    let build_profile_field = meta
        .fields
        .iter()
        .find(|f| f.name == "build_profile")
        .expect("build_profile field must exist on Build");
    assert_eq!(build_profile_field.max_length, Some(32));

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on Build");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    // app_id and environment_id must be declared as foreign keys.
    let fk_fields: Vec<&str> = meta.relations.iter().map(|r| r.field_name).collect();
    assert!(
        fk_fields.contains(&"app_id"),
        "app_id must be a foreign key relation"
    );
    assert!(
        fk_fields.contains(&"environment_id"),
        "environment_id must be a foreign key relation"
    );
}

#[test]
fn test_buildstage_model_metadata() {
    let meta = BuildStage::meta();
    assert_eq!(meta.app_label, "builds");
    assert_eq!(meta.table_name, "builds_buildstage");

    let fk_fields: Vec<&str> = meta.relations.iter().map(|r| r.field_name).collect();
    assert!(
        fk_fields.contains(&"build_id"),
        "build_id must be a foreign key relation"
    );

    let stage_field = meta
        .fields
        .iter()
        .find(|f| f.name == "stage")
        .expect("stage field must exist on BuildStage");
    assert_eq!(stage_field.max_length, Some(32));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on BuildStage");
    assert_eq!(status_field.max_length, Some(32));

    // Verify unique_together constraint contains (build_id, stage)
    assert!(
        meta.unique_together
            .iter()
            .any(|ut| ut.contains(&"build_id") && ut.contains(&"stage")),
        "unique_together must include build_id and stage"
    );
}
