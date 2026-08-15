use bloom_cloud_backend::apps::credentials::models::Credential;
use djangors_orm::meta::{OnDelete, RelationKind};

#[test]
fn test_credential_model_metadata() {
    let meta = Credential::meta();
    assert_eq!(meta.app_label, "credentials");
    assert_eq!(meta.table_name, "credentials_credential");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on Credential");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Credential");
    assert_eq!(public_id_field.max_length, Some(36));

    let provider_field = meta
        .fields
        .iter()
        .find(|f| f.name == "provider")
        .expect("provider field must exist on Credential");
    assert_eq!(provider_field.max_length, Some(32));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Credential");
    assert_eq!(name_field.max_length, Some(255));

    let token_field = meta
        .fields
        .iter()
        .find(|f| f.name == "encrypted_token")
        .expect("encrypted_token field must exist on Credential");
    assert!(
        !token_field.nullable,
        "encrypted_token must not be nullable"
    );

    let meta_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metadata")
        .expect("metadata field must exist on Credential");
    assert!(!meta_field.nullable, "metadata must not be nullable");

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on Credential");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
}
