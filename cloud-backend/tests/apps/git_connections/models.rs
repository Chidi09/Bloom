use bloom_cloud_backend::apps::git_connections::models::{GitConnection, WebhookDelivery};
use djangors_orm::meta::{OnDelete, RelationKind};

#[test]
fn test_git_connection_model_metadata() {
    let meta = GitConnection::meta();
    assert_eq!(meta.app_label, "git_connections");
    assert_eq!(meta.table_name, "git_connections_gitconnection");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on GitConnection");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on GitConnection");
    assert_eq!(public_id_field.max_length, Some(36));

    let provider_field = meta
        .fields
        .iter()
        .find(|f| f.name == "provider")
        .expect("provider field must exist on GitConnection");
    assert_eq!(provider_field.max_length, Some(32));

    let installation_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "installation_id")
        .expect("installation_id field must exist on GitConnection");
    assert_eq!(installation_id_field.max_length, Some(255));

    let token_field = meta
        .fields
        .iter()
        .find(|f| f.name == "encrypted_access_token")
        .expect("encrypted_access_token field must exist on GitConnection");
    assert!(
        !token_field.nullable,
        "encrypted_access_token must not be nullable"
    );

    let meta_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metadata")
        .expect("metadata field must exist on GitConnection");
    assert!(!meta_field.nullable, "metadata must not be nullable");

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on GitConnection");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
}

#[test]
fn test_webhook_delivery_model_metadata() {
    let meta = WebhookDelivery::meta();
    assert_eq!(meta.app_label, "git_connections");
    assert_eq!(meta.table_name, "git_connections_webhookdelivery");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on WebhookDelivery");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on WebhookDelivery");
    assert_eq!(public_id_field.max_length, Some(36));

    let provider_field = meta
        .fields
        .iter()
        .find(|f| f.name == "provider")
        .expect("provider field must exist on WebhookDelivery");
    assert_eq!(provider_field.max_length, Some(32));

    let delivery_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "delivery_id")
        .expect("delivery_id field must exist on WebhookDelivery");
    assert_eq!(delivery_id_field.max_length, Some(255));

    let event_type_field = meta
        .fields
        .iter()
        .find(|f| f.name == "event_type")
        .expect("event_type field must exist on WebhookDelivery");
    assert_eq!(event_type_field.max_length, Some(64));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on WebhookDelivery");
    assert_eq!(status_field.max_length, Some(32));
}
