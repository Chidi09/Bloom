use bloom_cloud_backend::apps::events::models::EventLog;

#[test]
fn test_events_model_metadata() {
    let meta = EventLog::meta();
    assert_eq!(meta.app_label, "events");
    assert_eq!(meta.table_name, "events_eventlog");

    let event_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "event_id")
        .expect("event_id field must exist on EventLog");
    assert!(event_id_field.unique, "event_id must be unique on EventLog");
    assert_eq!(event_id_field.max_length, Some(36));

    let event_type_field = meta
        .fields
        .iter()
        .find(|f| f.name == "event_type")
        .expect("event_type field must exist on EventLog");
    assert!(event_type_field.db_index, "event_type must be indexed");
    assert_eq!(event_type_field.max_length, Some(128));

    let org_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on EventLog");
    assert!(
        org_field.nullable,
        "organization_id must be nullable on EventLog"
    );
    assert!(org_field.db_index, "organization_id must be indexed");

    let created_at_field = meta
        .fields
        .iter()
        .find(|f| f.name == "created_at")
        .expect("created_at field must exist on EventLog");
    assert!(created_at_field.db_index, "created_at must be indexed");
}
