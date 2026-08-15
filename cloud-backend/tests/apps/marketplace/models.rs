use bloom_cloud_backend::apps::marketplace::models::{Template, TemplateVersion};
use djangors_orm::meta::{DefaultValue, OnDelete, RelationKind};

#[test]
fn test_template_model_metadata() {
    let meta = Template::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_template");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on Template");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Template");
    assert_eq!(public_id_field.max_length, Some(36));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Template");
    assert_eq!(name_field.max_length, Some(255));

    let slug_field = meta
        .fields
        .iter()
        .find(|f| f.name == "slug")
        .expect("slug field must exist on Template");
    assert_eq!(slug_field.max_length, Some(64));

    let desc_field = meta
        .fields
        .iter()
        .find(|f| f.name == "description")
        .expect("description field must exist on Template");
    assert!(desc_field.nullable, "description must be nullable");
    assert_eq!(desc_field.max_length, Some(2000));

    let vis_field = meta
        .fields
        .iter()
        .find(|f| f.name == "visibility")
        .expect("visibility field must exist on Template");
    assert_eq!(vis_field.max_length, Some(32));
    assert!(vis_field.db_index, "visibility must be indexed");

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on Template");
    assert_eq!(status_field.max_length, Some(32));
    assert!(status_field.db_index, "status must be indexed");

    let meta_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metadata")
        .expect("metadata field must exist on Template");
    assert_eq!(meta_field.default, DefaultValue::Text("{}"));

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on Template");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
}

#[test]
fn test_template_version_model_metadata() {
    let meta = TemplateVersion::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_templateversion");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on TemplateVersion");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on TemplateVersion");
    assert_eq!(public_id_field.max_length, Some(36));

    let version_field = meta
        .fields
        .iter()
        .find(|f| f.name == "version")
        .expect("version field must exist on TemplateVersion");
    assert_eq!(version_field.max_length, Some(64));
    assert!(version_field.db_index, "version must be indexed");

    let manifest_field = meta
        .fields
        .iter()
        .find(|f| f.name == "manifest")
        .expect("manifest field must exist on TemplateVersion");
    assert_eq!(manifest_field.default, DefaultValue::Text("{}"));

    let tmpl_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "template_id")
        .expect("template_id relation must exist on TemplateVersion");
    assert_eq!(tmpl_rel.kind, RelationKind::ForeignKey);
    assert_eq!(tmpl_rel.on_delete, OnDelete::Cascade);
}
