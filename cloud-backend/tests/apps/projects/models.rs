use bloom_cloud_backend::apps::projects::models::Project;
use djangors_orm::meta::{OnDelete, RelationKind};

#[test]
fn test_project_model_metadata() {
    let meta = Project::meta();
    assert_eq!(meta.app_label, "projects");
    assert_eq!(meta.table_name, "projects_project");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on Project");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Project");
    assert_eq!(public_id_field.max_length, Some(36));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Project");
    assert_eq!(name_field.max_length, Some(255));

    let slug_field = meta
        .fields
        .iter()
        .find(|f| f.name == "slug")
        .expect("slug field must exist on Project");
    assert_eq!(slug_field.max_length, Some(64));

    let desc_field = meta
        .fields
        .iter()
        .find(|f| f.name == "description")
        .expect("description field must exist on Project");
    assert!(desc_field.nullable, "description must be nullable");
    assert_eq!(desc_field.max_length, Some(1000));

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on Project");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
}
