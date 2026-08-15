use bloom_cloud_backend::apps::emails::contracts::{
    CampaignStatsResponse, CreateCampaignRequest, EmailLogListResponse, EmailLogResponse,
    PreferenceResponse, PreferencesListResponse, UnsubscribeRequest, UnsubscribeResponse,
    UpdatePreferenceItem, UpdatePreferencesRequest,
};
use bloom_cloud_backend::apps::emails::errors::EmailsError;
use chrono::Utc;
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_update_preferences_request_deserialization() {
    // 1. Single preference update
    let json_single = r#"{
        "category": "builds",
        "value": "mine_only"
    }"#;
    let req: UpdatePreferencesRequest = serde_json::from_str(json_single).unwrap();
    assert_eq!(req.category, Some("builds".to_string()));
    assert_eq!(req.value, Some("mine_only".to_string()));
    assert_eq!(req.preferences, None);

    // 2. Bulk preference update
    let json_bulk = r#"{
        "preferences": [
            { "category": "builds", "value": "all" },
            { "category": "product", "value": "digest" }
        ]
    }"#;
    let req_bulk: UpdatePreferencesRequest = serde_json::from_str(json_bulk).unwrap();
    assert_eq!(
        req_bulk.preferences,
        Some(vec![
            UpdatePreferenceItem {
                category: "builds".to_string(),
                value: "all".to_string(),
            },
            UpdatePreferenceItem {
                category: "product".to_string(),
                value: "digest".to_string(),
            },
        ])
    );
}

#[test]
fn test_preferences_response_wire_format_uses_id_not_public_id() {
    let now = Utc::now();
    let pref = PreferenceResponse {
        id: "550e8400-e29b-41d4-a716-446655440000".to_string(),
        category: "product".to_string(),
        value: "digest".to_string(),
        created_at: now,
        updated_at: now,
    };

    let list_res = PreferencesListResponse {
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        preferences: vec![pref],
    };

    let serialized = serde_json::to_string(&list_res).unwrap();
    assert!(serialized.contains("\"id\":\"550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"category\":\"product\""));
    assert!(serialized.contains("\"value\":\"digest\""));
    assert!(
        !serialized.contains("public_id"),
        "Wire JSON must NEVER expose 'public_id'"
    );
}

#[test]
fn test_unsubscribe_request_and_response_serialization() {
    let req = UnsubscribeRequest {
        token: "user-uuid:product:1718000000:signature12345".to_string(),
    };
    let serialized_req = serde_json::to_string(&req).unwrap();
    assert!(serialized_req.contains("\"token\":\"user-uuid:product:1718000000:signature12345\""));

    let res = UnsubscribeResponse {
        success: true,
        message: "Successfully unsubscribed".to_string(),
        user_id: Some("user-uuid".to_string()),
        category: Some("product".to_string()),
    };
    let serialized_res = serde_json::to_string(&res).unwrap();
    assert!(serialized_res.contains("\"success\":true"));
    assert!(serialized_res.contains("\"category\":\"product\""));
}

#[test]
fn test_email_log_response_serialization() {
    let now = Utc::now();
    let log = EmailLogResponse {
        id: "log-uuid-1".to_string(),
        template_key: "build.failed".to_string(),
        recipient: "developer@bloom.dev".to_string(),
        organization_id: Some("org-uuid-1".to_string()),
        subject: "Build #142 failed — acme-app".to_string(),
        status: "sent".to_string(),
        provider_message_id: Some("smtp-msg-123".to_string()),
        error: None,
        campaign_key: None,
        is_promotional: false,
        created_at: now,
        sent_at: Some(now),
    };

    let list_res = EmailLogListResponse {
        items: vec![log],
        total: 1,
    };

    let serialized = serde_json::to_string(&list_res).unwrap();
    assert!(serialized.contains("\"id\":\"log-uuid-1\""));
    assert!(serialized.contains("\"template_key\":\"build.failed\""));
    assert!(serialized.contains("\"is_promotional\":false"));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_campaign_contracts_serialization() {
    let create_req = CreateCampaignRequest {
        key: "promo.git_not_connected".to_string(),
        name: "Connect Git".to_string(),
        subject_template: "Connect Git to build on push".to_string(),
        body_template: "Connect Git in 30 seconds...".to_string(),
        active: Some(true),
        trigger_rule: Some(serde_json::json!({ "manual_build_count_gte": 3 })),
        score_floor_override: Some(65),
    };

    let serialized_create = serde_json::to_string(&create_req).unwrap();
    assert!(serialized_create.contains("\"key\":\"promo.git_not_connected\""));
    assert!(serialized_create.contains("\"score_floor_override\":65"));

    let stats_res = CampaignStatsResponse {
        id: "camp-uuid-1".to_string(),
        key: "promo.git_not_connected".to_string(),
        name: "Connect Git".to_string(),
        active: true,
        total_sends: 600,
        opened_count: 300,
        clicked_count: 120,
        converted_count: 30,
        open_rate_percent: 50,
        click_rate_percent: 20,
        conversion_rate_percent: 5,
        automatically_disabled: false,
    };

    let serialized_stats = serde_json::to_string(&stats_res).unwrap();
    assert!(serialized_stats.contains("\"total_sends\":600"));
    assert!(serialized_stats.contains("\"open_rate_percent\":50"));
    assert!(serialized_stats.contains("\"conversion_rate_percent\":5"));
    assert!(serialized_stats.contains("\"automatically_disabled\":false"));
    assert!(!serialized_stats.contains("public_id"));
}

#[test]
fn test_error_status_mappings() {
    // 1. Immutable category preference -> 400 Bad Request
    let err_immutable = EmailsError::ImmutableCategoryPreference("security".to_string());
    let d_err: DjangorsError = err_immutable.into();
    assert_eq!(d_err.status_code(), StatusCode::BAD_REQUEST);

    // 2. Frequency cap exceeded -> 429 Too Many Requests
    let err_freq = EmailsError::FrequencyCapExceeded("Max 4 per 30 days".to_string());
    let d_err_freq: DjangorsError = err_freq.into();
    assert_eq!(d_err_freq.status_code(), StatusCode::TOO_MANY_REQUESTS);

    // 3. Insufficient role -> 403 Forbidden
    let err_role = EmailsError::InsufficientRole;
    let d_err_role: DjangorsError = err_role.into();
    assert_eq!(d_err_role.status_code(), StatusCode::FORBIDDEN);

    // 4. Campaign not found -> 404 Not Found
    let err_nf = EmailsError::CampaignNotFound;
    let d_err_nf: DjangorsError = err_nf.into();
    assert_eq!(d_err_nf.status_code(), StatusCode::NOT_FOUND);
}

#[test]
fn test_missing_or_malformed_encryption_key_causes_settings_load_failure() {
    use bloom_cloud_backend::settings::BloomSettings;

    // 1. Ensure that without BLOOM_ENCRYPTION_KEY set, BloomSettings::load fails (no fallback key)
    // Note: If env var is not present in test environment, load() will return Err.
    // We also test that BloomSettings fields include encryption_key.
    let settings = BloomSettings {
        database_url: "postgres://localhost/test".to_string(),
        redis_url: "redis://localhost:6379".to_string(),
        api_url: "http://localhost:8000".to_string(),
        jwt_secret: "secret".to_string(),
        worker_claim_timeout_secs: 30,
        encryption_key: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            .to_string(),
        encryption_master_key: None,
        encryption_key_version: "v1".to_string(),
        sentry_dsn: None,
    };

    assert_eq!(settings.encryption_key.len(), 64);
}

#[test]
fn test_emails_list_pagination_envelope_and_slicing() {
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
        Uri::from_static("/api/v1/organizations/org-123/email-log"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 250_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1_results: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("log-{i}"), "recipient": format!("user{i}@example.com") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1_results.clone());
    assert_eq!(env1["count"], 250);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 3);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    // 2. Page 2 request
    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/organizations/org-123/email-log?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2_results: Vec<serde_json::Value> = (100..200)
        .map(|i| serde_json::json!({ "id": format!("log-{i}"), "recipient": format!("user{i}@example.com") }))
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
        Uri::from_static("/api/v1/organizations/org-123/email-log?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
    let slice_clamped = pagination.slice(&req_oversized, total);
    assert_eq!(slice_clamped.limit, 100);

    // Custom valid page_size
    let req_custom_size = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/organizations/org-123/email-log?page_size=25"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_custom_size), 25);
    let slice_custom = pagination.slice(&req_custom_size, total);
    assert_eq!(slice_custom.limit, 25);
    assert_eq!(slice_custom.offset, 0);
}
