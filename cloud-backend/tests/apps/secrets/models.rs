use bloom_cloud_backend::apps::secrets::models::{Secret, SecretVersion};
use djangors_orm::meta::{OnDelete, RelationKind};

#[test]
fn test_secret_model_metadata() {
    let meta = Secret::meta();
    assert_eq!(meta.app_label, "secrets");
    assert_eq!(meta.table_name, "secrets_secret");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on Secret");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Secret");
    assert_eq!(public_id_field.max_length, Some(36));

    let key_field = meta
        .fields
        .iter()
        .find(|f| f.name == "key")
        .expect("key field must exist on Secret");
    assert_eq!(key_field.max_length, Some(255));

    let is_json_field = meta
        .fields
        .iter()
        .find(|f| f.name == "is_json")
        .expect("is_json field must exist on Secret");
    assert!(!is_json_field.primary_key);

    let version_field = meta
        .fields
        .iter()
        .find(|f| f.name == "version")
        .expect("version field must exist on Secret");
    assert!(!version_field.primary_key);

    let env_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "environment_id")
        .expect("environment_id relation must exist on Secret");
    assert_eq!(env_rel.kind, RelationKind::ForeignKey);
    assert_eq!(env_rel.on_delete, OnDelete::Cascade);

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on Secret");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
}

#[test]
fn test_secret_version_model_metadata() {
    let meta = SecretVersion::meta();
    assert_eq!(meta.app_label, "secrets");
    assert_eq!(meta.table_name, "secrets_secretversion");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on SecretVersion");
    assert!(id_field.primary_key, "id must be primary key");

    let secret_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "secret_id")
        .expect("secret_id relation must exist on SecretVersion");
    assert_eq!(secret_rel.kind, RelationKind::ForeignKey);
    assert_eq!(secret_rel.on_delete, OnDelete::Cascade);
}
