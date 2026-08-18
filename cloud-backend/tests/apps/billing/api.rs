use bloom_cloud_backend::apps::billing::contracts::{
    CancelSubscriptionRequest, EnforcementDecision, Entitlements, FeatureEntitlements,
    InvoiceResponse, OveragePricing, PlanResponse, RecordUsageRequest, SubscribeRequest,
    SubscriptionResponse, UsageEnforcementSummary, UsageOverageSummary, UsageSummaryResponse,
};
use bloom_cloud_backend::apps::billing::errors::BillingError;
use chrono::{NaiveDate, Utc};
use djangors_core::{DjangorsError, StatusCode};

#[test]
fn test_subscribe_request_deserialization() {
    let json_minimal = r#"{
        "plan_id": "plan-uuid-1234"
    }"#;
    let req: SubscribeRequest = serde_json::from_str(json_minimal).unwrap();
    assert_eq!(req.plan_id, "plan-uuid-1234");
    assert_eq!(req.provider, None);
    assert_eq!(req.callback_url, None);

    let json_full = r#"{
        "plan_id": "pro",
        "provider": "bachs",
        "callback_url": "https://dashboard.bloomcloud.dev/billing/callback"
    }"#;
    let req2: SubscribeRequest = serde_json::from_str(json_full).unwrap();
    assert_eq!(req2.plan_id, "pro");
    assert_eq!(req2.provider, Some("bachs".to_string()));
    assert_eq!(
        req2.callback_url,
        Some("https://dashboard.bloomcloud.dev/billing/callback".to_string())
    );
}

#[test]
fn test_cancel_subscription_request_deserialization() {
    let json = r#"{
        "reason": "Moving to another cloud platform",
        "immediately": true
    }"#;
    let req: CancelSubscriptionRequest = serde_json::from_str(json).unwrap();
    assert_eq!(
        req.reason,
        Some("Moving to another cloud platform".to_string())
    );
    assert_eq!(req.immediately, Some(true));
}

#[test]
fn test_record_usage_request_deserialization() {
    let json = r#"{
        "metric": "build_minutes",
        "value": 15,
        "metadata": {
            "build_id": "bld-uuid-999"
        }
    }"#;
    let req: RecordUsageRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.metric, "build_minutes");
    assert_eq!(req.value, 15);
    assert!(req.metadata.is_some());
}

#[test]
fn test_plan_response_serialization() {
    let now = Utc::now();
    let res = PlanResponse {
        id: "plan-550e8400-e29b-41d4-a716-446655440000".to_string(),
        name: "pro".to_string(),
        description: Some("Professional Plan".to_string()),
        price_minor: 2900,
        currency: "USD".to_string(),
        entitlements: Entitlements {
            max_projects: 10,
            max_apps: 25,
            max_seats: 50,
            build_minutes_monthly: 2000,
            artifact_storage_gb: 250,
            web_bandwidth_gb: 500,
            features: FeatureEntitlements {
                testflight_deployments: true,
                google_play_deployments: true,
                web_hosting: true,
                shorebird: true,
                workflows: true,
                priority_support: true,
            },
            overage: OveragePricing::default(),
        },
        active: true,
        created_at: now,
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"plan-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"name\":\"pro\""));
    assert!(serialized.contains("\"price_minor\":2900"));
    assert!(serialized.contains("\"currency\":\"USD\""));
    assert!(serialized.contains("\"max_projects\":10"));
    assert!(serialized.contains("\"build_minutes_monthly\":2000"));
    assert!(serialized.contains("\"shorebird\":true"));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_subscription_response_serialization() {
    let now = Utc::now();
    let res = SubscriptionResponse {
        id: "sub-550e8400-e29b-41d4-a716-446655440000".to_string(),
        organization_id: "org-550e8400-e29b-41d4-a716-446655440000".to_string(),
        plan_id: "plan-550e8400-e29b-41d4-a716-446655440000".to_string(),
        plan_name: "pro".to_string(),
        status: "active".to_string(),
        trial_ends_at: None,
        activated_at: Some(now),
        current_period_start: now,
        current_period_end: now,
        provider_customer_id: Some("cus_bachs_123".to_string()),
        provider_subscription_id: Some("sub_bachs_456".to_string()),
        created_at: now,
        updated_at: now,
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"sub-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"organization_id\":\"org-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"plan_name\":\"pro\""));
    assert!(serialized.contains("\"status\":\"active\""));
    assert!(serialized.contains("\"provider_customer_id\":\"cus_bachs_123\""));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_invoice_response_serialization() {
    let now = Utc::now();
    let res = InvoiceResponse {
        id: "inv-550e8400-e29b-41d4-a716-446655440000".to_string(),
        subscription_id: "sub-123".to_string(),
        organization_id: "org-456".to_string(),
        amount_cents: 2900,
        status: "paid".to_string(),
        due_date: NaiveDate::from_ymd_opt(2026, 8, 15).unwrap(),
        paid_at: Some(now),
        provider_invoice_id: Some("tx_bachs_789".to_string()),
        created_at: now,
        line_items: Vec::new(),
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"id\":\"inv-550e8400-e29b-41d4-a716-446655440000\""));
    assert!(serialized.contains("\"amount_cents\":2900"));
    assert!(serialized.contains("\"status\":\"paid\""));
    assert!(serialized.contains("\"due_date\":\"2026-08-15\""));
    assert!(!serialized.contains("public_id"));
}

#[test]
fn test_usage_summary_response_serialization() {
    let now = Utc::now();
    let res = UsageSummaryResponse {
        organization_id: "org-123".to_string(),
        plan_name: "pro".to_string(),
        current_period_start: now,
        current_period_end: now,
        build_minutes_used: 1600,
        build_minutes_limit: 2000,
        artifact_storage_gb_used: 40,
        artifact_storage_gb_limit: 250,
        web_bandwidth_gb_used: 50,
        web_bandwidth_gb_limit: 500,
        deploy_count: 12,
        enforcement: UsageEnforcementSummary {
            overall_decision: EnforcementDecision::Warn,
            build_minutes_decision: EnforcementDecision::Warn,
            storage_decision: EnforcementDecision::Allow,
            bandwidth_decision: EnforcementDecision::Allow,
        },
        overage: UsageOverageSummary {
            enabled: false,
            build_minutes_over: 0,
            storage_gb_over: 0,
            bandwidth_gb_over: 0,
            build_minutes_cost_cents: 0,
            storage_cost_cents: 0,
            bandwidth_cost_cents: 0,
            total_cost_cents: 0,
        },
    };

    let serialized = serde_json::to_string(&res).unwrap();
    assert!(serialized.contains("\"build_minutes_used\":1600"));
    assert!(serialized.contains("\"overall_decision\":\"warn\""));
    assert!(serialized.contains("\"storage_decision\":\"allow\""));
}

#[test]
fn test_billing_error_mappings() {
    let err = BillingError::PlanNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "plan_not_found");

    let err = BillingError::SubscriptionNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "subscription_not_found");

    let err = BillingError::InvoiceNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "invoice_not_found");

    let err = BillingError::OrganizationNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "organization_not_found");

    let err = BillingError::OrganizationRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "organization_required");

    let err = BillingError::Forbidden;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "permission_denied");

    let err = BillingError::InsufficientRole;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "insufficient_role");

    let err = BillingError::InvalidStatusTransition {
        from: "locked".to_string(),
        to: "past_due".to_string(),
    };
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_status_transition");

    let err = BillingError::InvalidMetric("unknown_metric".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_metric");

    let err = BillingError::InvalidWebhookSignature;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_webhook_signature");

    let err = BillingError::MissingWebhookSecret;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "missing_webhook_secret");

    let err = BillingError::PaymentProviderNotConfigured;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(dj_err.code(), "payment_provider_not_configured");

    let err = BillingError::QuotaExceeded {
        metric: "build_minutes".to_string(),
        limit: 500,
        current: 501,
    };
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::PAYMENT_REQUIRED);
    assert_eq!(dj_err.code(), "quota_exceeded");

    let err = BillingError::FeatureNotEntitled("shorebird".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::PAYMENT_REQUIRED);
    assert_eq!(dj_err.code(), "feature_not_entitled");

    let err = BillingError::AccountLocked;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::PAYMENT_REQUIRED);
    assert_eq!(dj_err.code(), "account_locked");
}

#[test]
fn test_billing_list_pagination_envelope_and_slicing() {
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
        Uri::from_static("/billing/plans"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 250_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1_results: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("plan-{i}"), "name": format!("Plan {i}") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1_results.clone());
    assert_eq!(env1["count"], 250);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 3);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    // 2. Page 2 request
    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/billing/plans?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2_results: Vec<serde_json::Value> = (100..200)
        .map(|i| serde_json::json!({ "id": format!("plan-{i}"), "name": format!("Plan {i}") }))
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
        Uri::from_static("/billing/plans?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
    let slice_clamped = pagination.slice(&req_oversized, total);
    assert_eq!(slice_clamped.limit, 100);

    // Custom valid page_size
    let req_custom_size = Request::new(
        Method::GET,
        Uri::from_static("/billing/plans?page_size=25"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_custom_size), 25);
    let slice_custom = pagination.slice(&req_custom_size, total);
    assert_eq!(slice_custom.limit, 25);
    assert_eq!(slice_custom.offset, 0);
}
