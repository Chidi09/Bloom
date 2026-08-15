use bloom_cloud_backend::apps::workflows::models::{Workflow, WorkflowRun, WorkflowRunStep};
use djangors_orm::meta::DefaultValue;

#[test]
fn test_workflow_model_metadata() {
    let meta = Workflow::meta();
    assert_eq!(meta.app_label, "workflows");
    assert_eq!(meta.table_name, "workflows_workflow");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Workflow");
    assert_eq!(public_id_field.max_length, Some(36));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Workflow");
    assert_eq!(name_field.max_length, Some(255));

    let slug_field = meta
        .fields
        .iter()
        .find(|f| f.name == "slug")
        .expect("slug field must exist on Workflow");
    assert_eq!(slug_field.max_length, Some(64));

    let is_active_field = meta
        .fields
        .iter()
        .find(|f| f.name == "is_active")
        .expect("is_active field must exist on Workflow");
    assert_eq!(is_active_field.default, DefaultValue::Bool(true));

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on Workflow");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    // app_id is declared as a ForeignKey relation
    let fk_fields: Vec<&str> = meta.relations.iter().map(|r| r.field_name).collect();
    assert!(
        fk_fields.contains(&"app_id"),
        "app_id must be a foreign key relation"
    );

    // unique_together contains (app_id, slug)
    assert!(
        meta.unique_together
            .iter()
            .any(|ut| ut.contains(&"app_id") && ut.contains(&"slug")),
        "unique_together must include app_id and slug"
    );
}

#[test]
fn test_workflowrun_model_metadata() {
    let meta = WorkflowRun::meta();
    assert_eq!(meta.app_label, "workflows");
    assert_eq!(meta.table_name, "workflows_workflowrun");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on WorkflowRun");
    assert_eq!(public_id_field.max_length, Some(36));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on WorkflowRun");
    assert_eq!(status_field.max_length, Some(32));
    assert!(status_field.db_index, "status must be indexed");

    let git_commit_field = meta
        .fields
        .iter()
        .find(|f| f.name == "git_commit")
        .expect("git_commit field must exist on WorkflowRun");
    assert_eq!(git_commit_field.max_length, Some(40));

    let org_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on WorkflowRun");
    assert!(org_id_field.db_index, "organization_id must be indexed");

    let fk_fields: Vec<&str> = meta.relations.iter().map(|r| r.field_name).collect();
    assert!(
        fk_fields.contains(&"workflow_id"),
        "workflow_id must be a foreign key relation"
    );
}

#[test]
fn test_workflowrunstep_model_metadata() {
    let meta = WorkflowRunStep::meta();
    assert_eq!(meta.app_label, "workflows");
    assert_eq!(meta.table_name, "workflows_workflowrunstep");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on WorkflowRunStep");
    assert_eq!(public_id_field.max_length, Some(36));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on WorkflowRunStep");
    assert_eq!(name_field.max_length, Some(128));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on WorkflowRunStep");
    assert_eq!(status_field.max_length, Some(32));

    let step_kind_field = meta
        .fields
        .iter()
        .find(|f| f.name == "step_kind")
        .expect("step_kind field must exist on WorkflowRunStep");
    assert_eq!(step_kind_field.max_length, Some(64));

    let requires_approval_field = meta
        .fields
        .iter()
        .find(|f| f.name == "requires_approval")
        .expect("requires_approval field must exist on WorkflowRunStep");
    assert_eq!(requires_approval_field.default, DefaultValue::Bool(false));

    let fk_fields: Vec<&str> = meta.relations.iter().map(|r| r.field_name).collect();
    assert!(
        fk_fields.contains(&"run_id"),
        "run_id must be a foreign key relation"
    );

    // unique_together contains (run_id, step_order)
    assert!(
        meta.unique_together
            .iter()
            .any(|ut| ut.contains(&"run_id") && ut.contains(&"step_order")),
        "unique_together must include run_id and step_order"
    );
}
