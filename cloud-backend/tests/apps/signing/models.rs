use bloom_cloud_backend::apps::signing::models::SigningIdentity;
use djangors_orm::meta::{OnDelete, RelationKind};

#[test]
fn test_signing_identity_model_metadata() {
    let meta = SigningIdentity::meta();
    assert_eq!(meta.app_label, "signing");
    assert_eq!(meta.table_name, "signing_signingidentity");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on SigningIdentity");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on SigningIdentity");
    assert_eq!(public_id_field.max_length, Some(36));

    let platform_field = meta
        .fields
        .iter()
        .find(|f| f.name == "platform")
        .expect("platform field must exist on SigningIdentity");
    assert_eq!(platform_field.max_length, Some(32));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on SigningIdentity");
    assert_eq!(name_field.max_length, Some(255));

    let kind_field = meta
        .fields
        .iter()
        .find(|f| f.name == "kind")
        .expect("kind field must exist on SigningIdentity");
    assert_eq!(kind_field.max_length, Some(32));

    let encrypted_material_field = meta
        .fields
        .iter()
        .find(|f| f.name == "encrypted_material")
        .expect("encrypted_material field must exist on SigningIdentity");
    assert!(!encrypted_material_field.primary_key);

    let metadata_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metadata")
        .expect("metadata field must exist on SigningIdentity");
    assert!(!metadata_field.primary_key);

    let expires_at_field = meta
        .fields
        .iter()
        .find(|f| f.name == "expires_at")
        .expect("expires_at field must exist on SigningIdentity");
    assert!(expires_at_field.nullable, "expires_at must be nullable");

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on SigningIdentity");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
}
