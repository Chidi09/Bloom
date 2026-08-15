use bloom_cloud_backend::apps::observability::models::{PlatformMetric, ReleaseHealthSnapshot};
use djangors_orm::meta::DefaultValue;

#[test]
fn test_release_health_snapshot_model_metadata() {
    let meta = ReleaseHealthSnapshot::meta();
    assert_eq!(meta.app_label, "observability");
    assert_eq!(meta.table_name, "observability_releasehealthsnapshot");

    let platform_field = meta
        .fields
        .iter()
        .find(|f| f.name == "platform")
        .expect("platform field must exist on ReleaseHealthSnapshot");
    assert_eq!(platform_field.max_length, Some(32));

    let target_field = meta
        .fields
        .iter()
        .find(|f| f.name == "target")
        .expect("target field must exist on ReleaseHealthSnapshot");
    assert_eq!(target_field.max_length, Some(32));

    let crash_free_field = meta
        .fields
        .iter()
        .find(|f| f.name == "crash_free_rate")
        .expect("crash_free_rate field must exist on ReleaseHealthSnapshot");
    assert!(
        crash_free_field.nullable,
        "crash_free_rate must be nullable on ReleaseHealthSnapshot"
    );

    let sessions_field = meta
        .fields
        .iter()
        .find(|f| f.name == "sessions")
        .expect("sessions field must exist on ReleaseHealthSnapshot");
    assert!(
        sessions_field.nullable,
        "sessions must be nullable on ReleaseHealthSnapshot"
    );

    let crashes_field = meta
        .fields
        .iter()
        .find(|f| f.name == "crashes")
        .expect("crashes field must exist on ReleaseHealthSnapshot");
    assert!(
        crashes_field.nullable,
        "crashes must be nullable on ReleaseHealthSnapshot"
    );

    let active_users_field = meta
        .fields
        .iter()
        .find(|f| f.name == "active_users")
        .expect("active_users field must exist on ReleaseHealthSnapshot");
    assert!(
        active_users_field.nullable,
        "active_users must be nullable on ReleaseHealthSnapshot"
    );

    let metric_data_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metric_data")
        .expect("metric_data field must exist on ReleaseHealthSnapshot");
    // `default` is a `DefaultValue` enum, and a literal string default is `Text`.
    assert_eq!(metric_data_field.default, DefaultValue::Text("{}"));

    let relation = meta
        .relations
        .iter()
        .find(|r| r.field_name == "release_id")
        .expect("release_id foreign key relation must exist");
    // `target` is a late-bound `fn() -> &'static ModelMeta` (it resolves ordering circularity),
    // not a name string; call it and compare the app label and table it points at.
    let target = (relation.target)();
    assert_eq!(target.app_label, "releases");
    assert_eq!(target.table_name, "releases_release");
}

#[test]
fn test_platform_metric_model_metadata() {
    let meta = PlatformMetric::meta();
    assert_eq!(meta.app_label, "observability");
    assert_eq!(meta.table_name, "observability_platformmetric");

    let deployment_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "deployment_id")
        .expect("deployment_id field must exist on PlatformMetric");
    assert!(
        deployment_id_field.db_index,
        "deployment_id must be indexed on PlatformMetric"
    );

    let metric_type_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metric_type")
        .expect("metric_type field must exist on PlatformMetric");
    assert_eq!(metric_type_field.max_length, Some(32));

    let value_field = meta
        .fields
        .iter()
        .find(|f| f.name == "value")
        .expect("value field must exist on PlatformMetric");
    assert!(!value_field.nullable, "value must not be nullable");
}
