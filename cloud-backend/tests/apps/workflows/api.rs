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

#[test]
fn test_workflows_list_pagination_envelope_and_slicing() {
    use bytes::Bytes;
    use djangors_core::Request;
    use djangors_rest::pagination::{PageNumberPagination, Pagination, REST_PER_PAGE};
    use hyper::http::{HeaderMap, Method, Uri};

    let pagination = PageNumberPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    // 1. Default page 1 request with no query params
    let req = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/workflows"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 250_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1_results: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("wf-{i}"), "name": format!("Workflow {i}") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1_results.clone());
    assert_eq!(env1["count"], 250);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 3);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    // 2. Page 2 request
    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/workflows?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2_results: Vec<serde_json::Value> = (100..200)
        .map(|i| serde_json::json!({ "id": format!("wf-{i}"), "name": format!("Workflow {i}") }))
        .collect();

    let env2 = pagination.envelope(&req_p2, total, dummy_page2_results.clone());
    assert_eq!(env2["page"], 2);
    assert_eq!(env2["total_pages"], 3);
    assert_eq!(env2["results"].as_array().unwrap().len(), 100);

    // Page 2 differs from Page 1 and shares no rows
    let page1_ids: std::collections::HashSet<_> = dummy_page1_results
        .iter()
        .map(|v| v["id"].as_str().unwrap())
        .collect();
    let page2_ids: std::collections::HashSet<_> = dummy_page2_results
        .iter()
        .map(|v| v["id"].as_str().unwrap())
        .collect();
    assert!(page1_ids.is_disjoint(&page2_ids));

    // 3. Oversized ?page_size= is clamped to max_page_size (100)
    let req_oversized = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/workflows?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
    let slice_clamped = pagination.slice(&req_oversized, total);
    assert_eq!(slice_clamped.limit, 100);

    // Custom valid page_size
    let req_custom_size = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/workflows?page_size=25"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_custom_size), 25);
    let slice_custom = pagination.slice(&req_custom_size, total);
    assert_eq!(slice_custom.limit, 25);
    assert_eq!(slice_custom.offset, 0);
}
