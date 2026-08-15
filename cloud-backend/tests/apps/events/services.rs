use serde_json::json;

use djangors_orm::Model;

use bloom_cloud_backend::apps::events::models::EventLog;
use bloom_cloud_backend::apps::events::repositories;
use bloom_cloud_backend::apps::events::serializers::serialize_event;
use bloom_cloud_backend::apps::events::services::{emit, record_event};

/// Builds a minimal `EventLog` fixture for serializer tests.
fn test_event_log(payload: &str) -> EventLog {
    EventLog {
        id: 1,
        public_id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        event_id: "550e8400-e29b-41d4-a716-446655440001".to_string(),
        event_type: "build.completed".to_string(),
        organization_id: Some(100),
        project_id: Some(7),
        app_id: Some(3),
        actor_id: None,
        payload: payload.to_string(),
        created_at: chrono::Utc::now(),
    }
}

#[test]
fn test_payload_json_round_trips_through_serializer() {
    let payload = json!({
        "build_id": "550e8400-e29b-41d4-a716-446655440002",
        "status": "success",
    });
    let event = test_event_log(&payload.to_string());

    let response = serialize_event(
        &event,
        Some("org-100"),
        Some("prj-7"),
        Some("app-3"),
        Some("system"),
    );

    // The stored payload string round-trips back to the same JSON value.
    assert_eq!(response.payload, payload);
    assert_eq!(response.id, event.public_id);
    assert_eq!(response.event_id, event.event_id);
    assert_eq!(response.event_type, "build.completed");
    assert_eq!(response.organization_id.as_deref(), Some("org-100"));
    assert_eq!(response.project_id.as_deref(), Some("prj-7"));
    assert_eq!(response.app_id.as_deref(), Some("app-3"));
    assert_eq!(response.actor_id.as_deref(), Some("system"));
    assert!(!response.created_at.is_empty());
}

#[test]
fn test_unparseable_payload_does_not_panic_serializer() {
    let event = test_event_log("this is not valid json");
    let response = serialize_event(&event, Some("org-100"), None, None, None);

    assert_eq!(response.payload, serde_json::Value::Null);
}

#[tokio::test]
async fn test_emit_does_not_propagate_error() {
    let config = djangors_db::DatabaseConfig::new("sqlite::memory:").max_connections(1);
    let db = djangors_db::Database::connect(&config)
        .await
        .expect("sqlite in-memory database connects");

    // The events_eventlog table does not exist in this fresh database, so the
    // insert fails; emit must swallow that failure and return ().
    emit(
        &db,
        "build.completed",
        Some(100),
        Some(7),
        Some(3),
        None,
        json!({ "build_id": "b-1", "status": "success" }),
    )
    .await;
}

#[tokio::test]
async fn test_event_type_filtering() {
    let config = djangors_db::DatabaseConfig::new("sqlite::memory:").max_connections(1);
    let db = djangors_db::Database::connect(&config)
        .await
        .expect("sqlite in-memory database connects");

    // Single shared connection (max_connections = 1) keeps the in-memory
    // database visible to every query in this test.
    db.conn()
        .execute(
            "CREATE TABLE events_eventlog (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                public_id VARCHAR(36) NOT NULL UNIQUE,
                event_id VARCHAR(36) NOT NULL UNIQUE,
                event_type VARCHAR(128) NOT NULL,
                organization_id BIGINT,
                project_id BIGINT,
                app_id BIGINT,
                actor_id BIGINT,
                payload TEXT NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )",
            &[],
        )
        .await
        .expect("create events_eventlog table");

    record_event(
        &db,
        "build.started",
        Some(100),
        Some(7),
        Some(3),
        Some(1),
        json!({ "build_id": "b-1" }),
    )
    .await
    .expect("record build.started");

    record_event(
        &db,
        "build.completed",
        Some(100),
        Some(7),
        Some(3),
        Some(1),
        json!({ "build_id": "b-1", "status": "success" }),
    )
    .await
    .expect("record build.completed");

    record_event(
        &db,
        "secret.created",
        Some(100),
        None,
        None,
        Some(1),
        json!({ "key": "API_KEY" }),
    )
    .await
    .expect("record secret.created");

    // A generous limit here so these filter assertions still see every matching row; the
    // paging behaviour itself is covered separately.
    const ALL: i64 = 1000;

    let (started, _) = repositories::list_events_cursor(
        &db,
        EventLog::objects(),
        Some("build.started"),
        None,
        None,
        None,
        ALL,
    )
    .await
    .expect("filter by event_type");
    assert_eq!(started.len(), 1);
    assert_eq!(started[0].event_type, "build.started");

    let (completed, _) = repositories::list_events_cursor(
        &db,
        EventLog::objects(),
        Some("build.completed"),
        None,
        None,
        None,
        ALL,
    )
    .await
    .expect("filter by event_type");
    assert_eq!(completed.len(), 1);
    assert_eq!(completed[0].event_type, "build.completed");

    let (all_builds, _) = repositories::list_events_cursor(
        &db,
        EventLog::objects(),
        None,
        Some(7),
        Some(3),
        None,
        ALL,
    )
    .await
    .expect("filter by project and app");
    assert_eq!(all_builds.len(), 2);

    let (org_events, _) = repositories::list_events_cursor(
        &db,
        EventLog::objects()
            .filter(djangors_orm::q!(organization_id = 100))
            .unwrap(),
        None,
        None,
        None,
        None,
        ALL,
    )
    .await
    .expect("list all org events");
    assert_eq!(org_events.len(), 3);
}
