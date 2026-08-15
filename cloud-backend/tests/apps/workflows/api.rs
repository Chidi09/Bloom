use bloom_cloud_backend::apps::workflows::contracts::{
    WorkflowApproveRequest, WorkflowCreateRequest, WorkflowResponse, WorkflowRunCreateRequest,
    WorkflowRunResponse, WorkflowRunStepResponse,
};
use bloom_cloud_backend::apps::workflows::errors::WorkflowError;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_workflow_create_request_deserialization() {
    let json = r#"{
        "app_id": "app-uuid-123",
        "name": "Main CI/CD",
        "slug": "main-ci",
        "description": "Builds and deploys main branch",
        "definition": "workflow:\n  on:\n    push:\n      branches: [main]",
        "is_active": true
    }"#;

    let req: WorkflowCreateRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.app_id, "app-uuid-123");
    assert_eq!(req.name, "Main CI/CD");
    assert_eq!(req.slug, "main-ci");
    assert_eq!(
        req.description,
        Some("Builds and deploys main branch".to_string())
    );
    assert!(req.is_active);
}

#[test]
fn test_workflow_run_create_request_defaults() {
    let json = r#"{}"#;
    let req: WorkflowRunCreateRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.git_commit, None);
    assert_eq!(req.git_branch, None);
    assert_eq!(req.git_ref, None);
    assert_eq!(req.trigger_event, "manual");
}

#[test]
fn test_workflow_approve_request_deserialization() {
    let json = r#"{
        "approved": true,
        "reason": "QA passed and verified"
    }"#;
    let req: WorkflowApproveRequest = serde_json::from_str(json).unwrap();
    assert!(req.approved);
    assert_eq!(req.reason, Some("QA passed and verified".to_string()));
}

#[test]
fn test_workflow_response_serialization() {
    let response = WorkflowResponse {
        id: "wf-550e8400-e29b-41d4-a716-446655440000".to_string(),
        app_id: "app-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        name: "Release Pipeline".to_string(),
        slug: "release-pipeline".to_string(),
        description: Some("Production release workflow".to_string()),
        definition: "workflow:\n  on:\n    push".to_string(),
        is_active: true,
        created_by: "user-uuid-1".to_string(),
        created_at: "2026-08-15T10:00:00Z".to_string(),
        updated_at: "2026-08-15T10:00:00Z".to_string(),
    };

    let serialized = serde_json::to_string(&response).unwrap();
    assert!(serialized.contains("\"id\":\"wf-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"app_id\":\"app-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"organization_id\":\"org-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"name\":\"Release Pipeline\""));
    assert!(serialized.contains("\"slug\":\"release-pipeline\""));
    assert!(serialized.contains("\"is_active\":true"));
    assert!(!serialized.contains("public_id"));
    assert!(!serialized.contains("created_by_id"));

    // Round-trip
    let deserialized: WorkflowResponse = serde_json::from_str(&serialized).unwrap();
    assert_eq!(deserialized, response);
}

#[test]
fn test_workflow_run_response_serialization() {
    let response = WorkflowRunResponse {
        id: "run-550e8400-e29b-41d4-a716-446655440000".to_string(),
        workflow_id: "wf-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        git_commit: "abc123456789".to_string(),
        git_branch: "main".to_string(),
        git_ref: "refs/heads/main".to_string(),
        status: "blocked".to_string(),
        trigger_event: "push".to_string(),
        started_at: Some("2026-08-15T10:00:00Z".to_string()),
        finished_at: None,
        approved_by: None,
        approved_at: None,
        metadata: serde_json::json!({"runner": "cloud-worker-1"}),
        steps: vec![
            WorkflowRunStepResponse {
                id: "step-1".to_string(),
                step_order: 1,
                name: "test".to_string(),
                step_kind: "test".to_string(),
                status: "completed".to_string(),
                requires_approval: false,
                started_at: Some("2026-08-15T10:00:01Z".to_string()),
                finished_at: Some("2026-08-15T10:00:15Z".to_string()),
                log_snippet: Some("All tests passed.".to_string()),
                metadata: serde_json::json!({}),
                created_at: "2026-08-15T10:00:00Z".to_string(),
            },
            WorkflowRunStepResponse {
                id: "step-2".to_string(),
                step_order: 2,
                name: "approval_gate".to_string(),
                step_kind: "approval_gate".to_string(),
                status: "blocked".to_string(),
                requires_approval: true,
                started_at: Some("2026-08-15T10:00:16Z".to_string()),
                finished_at: None,
                log_snippet: None,
                metadata: serde_json::json!({}),
                created_at: "2026-08-15T10:00:00Z".to_string(),
            },
        ],
        created_by: "user-uuid-1".to_string(),
        created_at: "2026-08-15T10:00:00Z".to_string(),
        updated_at: "2026-08-15T10:00:16Z".to_string(),
    };

    let serialized = serde_json::to_string(&response).unwrap();
    assert!(serialized.contains("\"id\":\"run-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"status\":\"blocked\""));
    assert!(serialized.contains("\"steps\""));
    assert!(serialized.contains("\"requires_approval\":true"));
    assert!(!serialized.contains("public_id"));

    let deserialized: WorkflowRunResponse = serde_json::from_str(&serialized).unwrap();
    assert_eq!(deserialized, response);
}

#[test]
fn test_workflow_error_mappings() {
    let err = WorkflowError::WorkflowNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = WorkflowError::WorkflowRunNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = WorkflowError::AppNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "not_found");

    let err = WorkflowError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = WorkflowError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = WorkflowError::InvalidStatus("cannot transition".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::CONFLICT);
    assert_eq!(dj_err.code(), "invalid_status");

    let err = WorkflowError::DuplicateSlug("main-ci".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::CONFLICT);
    assert_eq!(dj_err.code(), "duplicate_slug");

    let err = WorkflowError::GateAlreadyDecided;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::CONFLICT);
    assert_eq!(dj_err.code(), "gate_already_decided");

    let err = WorkflowError::ValidationError("empty name".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "validation_error");
}
