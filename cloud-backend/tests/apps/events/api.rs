use serde_json::json;

use bloom_cloud_backend::apps::events::contracts::EventResponse;
use bloom_cloud_backend::apps::events::errors::EventError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_events_contract_serialization_uses_public_ids() {
    let response = EventResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        event_id: "550e8400-e29b-41d4-a716-446655440001".to_string(),
        event_type: "build.completed".to_string(),
        organization_id: Some("org-100".to_string()),
        project_id: Some("prj-7".to_string()),
        app_id: Some("app-3".to_string()),
        actor_id: Some("system".to_string()),
        payload: json!({ "status": "success" }),
        created_at: "2026-08-14T12:00:00Z".to_string(),
    };

    let body = serde_json::to_string(&response).unwrap();
    assert!(body.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(body.contains("\"event_id\":\"550e8400-e29b-41d4-a716-446655440001\""));
    assert!(body.contains("\"event_type\":\"build.completed\""));
    assert!(body.contains("\"organization_id\":\"org-100\""));
    assert!(body.contains("\"actor_id\":\"system\""));
    assert!(
        !body.contains("public_id"),
        "internal field names must not leak"
    );

    // The payload is emitted as a JSON object, never as a raw string.
    assert!(body.contains("\"payload\":{\"status\":\"success\"}"));
}

#[test]
fn test_events_error_mapping_status_codes() {
    let err = EventError::EventNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "event_not_found");

    let err = EventError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = EventError::Unauthorized;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::UNAUTHORIZED);
    assert_eq!(dj_err.code(), "invalid_credentials");
}

#[test]
fn test_events_cursor_pagination_envelope() {
    use djangors_rest::pagination::CursorPagination;
    let pagination = CursorPagination {
        page_size: 100,
        max_page_size: Some(100),
    };

    let sample_event = serde_json::json!({
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "event_id": "550e8400-e29b-41d4-a716-446655440001",
        "event_type": "build.completed",
        "organization_id": "org-100",
        "project_id": null,
        "app_id": null,
        "actor_id": "system",
        "payload": { "status": "success" },
        "created_at": "2026-08-14T12:00:00Z"
    });

    let envelope = pagination.envelope_with_cursor(
        42,
        vec![sample_event],
        Some("bmV4dF9jdXJzb3JfdG9rZW4=".to_string()),
    );

    assert_eq!(envelope["count"], 42);
    assert_eq!(envelope["results"].as_array().unwrap().len(), 1);
    assert_eq!(envelope["next_cursor"], "bmV4dF9jdXJzb3JfdG9rZW4=");
    assert_eq!(envelope["previous_cursor"], serde_json::Value::Null);
}
