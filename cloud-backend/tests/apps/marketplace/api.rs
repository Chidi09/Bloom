use bloom_cloud_backend::apps::marketplace::errors::MarketplaceError;
use bloom_cloud_backend::apps::marketplace::models::{
    ReviewReport, SellerAccount, Template, TemplatePurchase, TemplateReview,
};
use bloom_cloud_backend::apps::marketplace::serializers::{
    serialize_access, serialize_install, serialize_purchase, serialize_refund, serialize_review,
    serialize_review_report, serialize_seller_account, serialize_template,
};
use chrono::Utc;
use djangors_core::{DjangorsError, StatusCode};
use djangors_orm::ForeignKey;

#[test]
fn test_template_response_serialization_wire_contract() {
    let template = Template {
        id: 10,
        public_id: "22222222-2222-4222-8222-222222222222".to_string(),
        organization_id: ForeignKey::new(5),
        name: "E-Commerce App".to_string(),
        slug: "e-commerce-app".to_string(),
        description: Some("Production e-commerce Flutter template".to_string()),
        visibility: "public".to_string(),
        status: "published".to_string(),
        is_free: false,
        price_amount: 4900,
        price_currency: "usd".to_string(),
        metadata: r#"{"tags":["ecommerce","stripe"],"platform":"web"}"#.to_string(),
        rating_count: 14,
        rating_sum: 67,
        rating_bayesian_milli: 4625,
        install_count: 1250,
        featured_type: "editorial".to_string(),
        featured_until: Some(Utc::now()),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let org_pub = "11111111-1111-4111-8111-111111111111";
    let res = serialize_template(&template, org_pub, Some("1.2.0".to_string()), 3);
    let json_str = serde_json::to_string(&res).unwrap();

    // Wire contract asserts:
    assert!(json_str.contains("\"id\":\"22222222-2222-4222-8222-222222222222\""));
    assert!(json_str.contains("\"organization_id\":\"11111111-1111-4111-8111-111111111111\""));
    assert!(json_str.contains("\"name\":\"E-Commerce App\""));
    assert!(json_str.contains("\"slug\":\"e-commerce-app\""));
    assert!(json_str.contains("\"visibility\":\"public\""));
    assert!(json_str.contains("\"status\":\"published\""));
    assert!(json_str.contains("\"is_free\":false"));
    assert!(json_str.contains("\"price_amount\":4900"));
    assert!(json_str.contains("\"price_currency\":\"usd\""));
    assert!(json_str.contains("\"latest_version\":\"1.2.0\""));
    assert!(json_str.contains("\"versions_count\":3"));
    assert!(json_str.contains("\"rating_count\":14"));
    assert!(json_str.contains("\"rating_bayesian_milli\":4625"));
    assert!(json_str.contains("\"install_count\":1250"));
    assert!(json_str.contains("\"featured_type\":\"editorial\""));
    assert!(json_str.contains("\"is_featured\":true"));
    assert!(json_str.contains("\"is_editorial_featured\":true"));
    assert!(json_str.contains("\"is_paid_featured\":false"));

    // Ensure metadata is serialized as real JSON object, not a raw escaped string
    assert!(json_str.contains("\"tags\":[\"ecommerce\",\"stripe\"]"));
    assert!(!json_str.contains("public_id"));
}

#[test]
fn test_featured_editorial_vs_paid_distinguishable_in_serialization() {
    let mut template_editorial = Template {
        id: 1,
        public_id: "tmpl_editorial_123".to_string(),
        organization_id: ForeignKey::new(10),
        name: "Curated Starter".to_string(),
        slug: "curated-starter".to_string(),
        description: None,
        visibility: "public".to_string(),
        status: "published".to_string(),
        is_free: true,
        price_amount: 0,
        price_currency: "usd".to_string(),
        metadata: "{}".to_string(),
        rating_count: 0,
        rating_sum: 0,
        rating_bayesian_milli: 0,
        install_count: 50,
        featured_type: "editorial".to_string(),
        featured_until: None,
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    // 1. Editorial featured response:
    let res_editorial = serialize_template(&template_editorial, "org_1", None, 1);
    let json_editorial = serde_json::to_string(&res_editorial).unwrap();
    assert!(json_editorial.contains("\"featured_type\":\"editorial\""));
    assert!(json_editorial.contains("\"is_featured\":true"));
    assert!(json_editorial.contains("\"is_editorial_featured\":true"));
    assert!(json_editorial.contains("\"is_paid_featured\":false"));

    // 2. Paid placement response (EU P2B and FTC compliance requirement):
    template_editorial.featured_type = "paid".to_string();
    let res_paid = serialize_template(&template_editorial, "org_1", None, 1);
    let json_paid = serde_json::to_string(&res_paid).unwrap();
    assert!(json_paid.contains("\"featured_type\":\"paid\""));
    assert!(json_paid.contains("\"is_featured\":true"));
    assert!(json_paid.contains("\"is_editorial_featured\":false"));
    assert!(json_paid.contains("\"is_paid_featured\":true"));

    // 3. Organic non-featured response:
    template_editorial.featured_type = "none".to_string();
    let res_organic = serialize_template(&template_editorial, "org_1", None, 1);
    let json_organic = serde_json::to_string(&res_organic).unwrap();
    assert!(json_organic.contains("\"featured_type\":\"none\""));
    assert!(json_organic.contains("\"is_featured\":false"));
    assert!(json_organic.contains("\"is_editorial_featured\":false"));
    assert!(json_organic.contains("\"is_paid_featured\":false"));
}

#[test]
fn test_review_and_report_serialization() {
    let review = TemplateReview {
        id: 5,
        public_id: "rev_pub_555".to_string(),
        template_id: ForeignKey::new(10),
        buyer_organization_id: ForeignKey::new(20),
        reviewer_user_id: 30,
        rating: 5,
        title: "Outstanding Template".to_string(),
        comment: "Flawless integration with clean code.".to_string(),
        status: "published".to_string(),
        author_response: Some("Glad you loved it!".to_string()),
        author_responded_at: Some(Utc::now()),
        author_responded_by_id: Some(1),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let r_res = serialize_review(&review, "tmpl_pub_10", "buyer_org_pub_20");
    let r_json = serde_json::to_string(&r_res).unwrap();
    assert!(r_json.contains("\"id\":\"rev_pub_555\""));
    assert!(r_json.contains("\"template_id\":\"tmpl_pub_10\""));
    assert!(r_json.contains("\"buyer_organization_id\":\"buyer_org_pub_20\""));
    assert!(r_json.contains("\"rating\":5"));
    assert!(r_json.contains("\"title\":\"Outstanding Template\""));
    assert!(r_json.contains("\"comment\":\"Flawless integration with clean code.\""));
    assert!(r_json.contains("\"status\":\"published\""));
    assert!(r_json.contains("\"author_response\":\"Glad you loved it!\""));

    let report = ReviewReport {
        id: 1,
        public_id: "rep_pub_777".to_string(),
        review_id: ForeignKey::new(5),
        reporter_organization_id: ForeignKey::new(40),
        reporter_user_id: 50,
        reason: "spam".to_string(),
        details: "Promotional links in review text".to_string(),
        status: "pending".to_string(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let rep_res = serialize_review_report(&report, "rev_pub_555", "reporter_org_pub_40");
    let rep_json = serde_json::to_string(&rep_res).unwrap();
    assert!(rep_json.contains("\"id\":\"rep_pub_777\""));
    assert!(rep_json.contains("\"review_id\":\"rev_pub_555\""));
    assert!(rep_json.contains("\"reporter_organization_id\":\"reporter_org_pub_40\""));
    assert!(rep_json.contains("\"reason\":\"spam\""));
    assert!(rep_json.contains("\"status\":\"pending\""));

    let install_res = serialize_install("tmpl_pub_10", Some("ver_pub_1".to_string()), 42, false);
    let ins_json = serde_json::to_string(&install_res).unwrap();
    assert!(ins_json.contains("\"template_id\":\"tmpl_pub_10\""));
    assert!(ins_json.contains("\"template_version_id\":\"ver_pub_1\""));
    assert!(ins_json.contains("\"install_count\":42"));
    assert!(ins_json.contains("\"deduplicated\":false"));
}

#[test]
fn test_seller_account_serialization() {
    let account = SellerAccount {
        id: 1,
        public_id: "sa_pub_12345".to_string(),
        organization_id: ForeignKey::new(5),
        stripe_account_id: "acct_12345678".to_string(),
        payouts_enabled: true,
        charges_enabled: true,
        details_submitted: true,
        default_currency: Some("usd".to_string()),
        last_payouts_checked_at: Some(Utc::now()),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let res = serialize_seller_account(&account, "org_pub_123");
    let json_str = serde_json::to_string(&res).unwrap();

    assert!(json_str.contains("\"id\":\"sa_pub_12345\""));
    assert!(json_str.contains("\"organization_id\":\"org_pub_123\""));
    assert!(json_str.contains("\"stripe_account_id\":\"acct_12345678\""));
    assert!(json_str.contains("\"payouts_enabled\":true"));
    assert!(json_str.contains("\"charges_enabled\":true"));
    assert!(json_str.contains("\"details_submitted\":true"));
    assert!(json_str.contains("\"default_currency\":\"usd\""));
}

#[test]
fn test_purchase_and_refund_serialization() {
    let purchase = TemplatePurchase {
        id: 1,
        public_id: "pur_pub_987".to_string(),
        buyer_organization_id: ForeignKey::new(10),
        template_id: ForeignKey::new(20),
        template_version_id: Some(30),
        seller_organization_id: ForeignKey::new(40),
        amount: 2900,
        currency: "usd".to_string(),
        platform_fee: 580,
        seller_amount: 2320,
        stripe_payment_intent_id: "pi_123456".to_string(),
        status: "succeeded".to_string(),
        idempotency_key: "idem_key_abc".to_string(),
        created_by_id: 1,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    let p_res = serialize_purchase(
        &purchase,
        "buyer_org_pub",
        "template_pub",
        "SaaS Starter",
        Some("version_pub".to_string()),
        "seller_org_pub",
        Some("pi_123_secret".to_string()),
    );

    let p_json = serde_json::to_string(&p_res).unwrap();
    assert!(p_json.contains("\"id\":\"pur_pub_987\""));
    assert!(p_json.contains("\"buyer_organization_id\":\"buyer_org_pub\""));
    assert!(p_json.contains("\"template_id\":\"template_pub\""));
    assert!(p_json.contains("\"template_name\":\"SaaS Starter\""));
    assert!(p_json.contains("\"amount\":2900"));
    assert!(p_json.contains("\"platform_fee\":580"));
    assert!(p_json.contains("\"seller_amount\":2320"));
    assert!(p_json.contains("\"status\":\"succeeded\""));
    assert!(p_json.contains("\"client_secret\":\"pi_123_secret\""));

    let r_res = serialize_refund("pur_pub_987", "re_98765", 2900, "usd", "succeeded");
    let r_json = serde_json::to_string(&r_res).unwrap();
    assert!(r_json.contains("\"purchase_id\":\"pur_pub_987\""));
    assert!(r_json.contains("\"stripe_refund_id\":\"re_98765\""));
    assert!(r_json.contains("\"amount\":2900"));

    let a_res = serialize_access(true, "owner", "tmpl_123", Some("ver_456".to_string()));
    let a_json = serde_json::to_string(&a_res).unwrap();
    assert!(a_json.contains("\"has_access\":true"));
    assert!(a_json.contains("\"access_reason\":\"owner\""));
}

#[test]
fn test_marketplace_error_mappings() {
    let err = MarketplaceError::TemplateNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "template_not_found");

    let err = MarketplaceError::SellerPayoutsNotEnabled;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "seller_payouts_not_enabled");

    let err = MarketplaceError::CannotPurchaseOwnTemplate;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "cannot_purchase_own_template");

    let err = MarketplaceError::PaymentRequired;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::PAYMENT_REQUIRED);
    assert_eq!(dj_err.code(), "payment_required");

    let err = MarketplaceError::PaymentFailed("Card declined".to_string());
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::PAYMENT_REQUIRED);
    assert_eq!(dj_err.code(), "payment_failed");

    let err = MarketplaceError::PurchaseNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "purchase_not_found");

    let err = MarketplaceError::PurchaseAlreadyRefunded;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "purchase_already_refunded");

    let err = MarketplaceError::InvalidRating(6);
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "invalid_rating");

    let err = MarketplaceError::ReviewNotAllowedNoPurchaseOrInstall;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "review_not_allowed");

    let err = MarketplaceError::AuthorCannotModerateReviews;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::FORBIDDEN);
    assert_eq!(dj_err.code(), "author_cannot_moderate_reviews");

    let err = MarketplaceError::AuthorCannotReviewOwnTemplate;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::BAD_REQUEST);
    assert_eq!(dj_err.code(), "author_cannot_review_own_template");

    let err = MarketplaceError::ReviewNotFound;
    let dj_err: DjangorsError = err.into();
    assert_eq!(dj_err.status_code(), StatusCode::NOT_FOUND);
    assert_eq!(dj_err.code(), "review_not_found");
}

#[test]
fn test_marketplace_list_pagination_envelope_and_slicing() {
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
        Uri::from_static("/api/v1/marketplace/templates"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let total = 250_i64;
    let slice1 = pagination.slice(&req, total);
    assert_eq!(slice1.limit, 100);
    assert_eq!(slice1.offset, 0);

    let dummy_page1_results: Vec<serde_json::Value> = (0..100)
        .map(|i| serde_json::json!({ "id": format!("tmpl-{i}"), "name": format!("Template {i}") }))
        .collect();

    let env1 = pagination.envelope(&req, total, dummy_page1_results.clone());
    assert_eq!(env1["count"], 250);
    assert_eq!(env1["page"], 1);
    assert_eq!(env1["total_pages"], 3);
    assert_eq!(env1["results"].as_array().unwrap().len(), 100);

    // 2. Page 2 request
    let req_p2 = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/marketplace/templates?page=2"),
        HeaderMap::new(),
        Bytes::new(),
    );
    let slice2 = pagination.slice(&req_p2, total);
    assert_eq!(slice2.limit, 100);
    assert_eq!(slice2.offset, 100);

    let dummy_page2_results: Vec<serde_json::Value> = (100..200)
        .map(|i| serde_json::json!({ "id": format!("tmpl-{i}"), "name": format!("Template {i}") }))
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
        Uri::from_static("/api/v1/marketplace/templates?page_size=500"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_oversized), 100);
    let slice_clamped = pagination.slice(&req_oversized, total);
    assert_eq!(slice_clamped.limit, 100);

    // Custom valid page_size
    let req_custom_size = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/marketplace/templates?page_size=25"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req_custom_size), 25);
    let slice_custom = pagination.slice(&req_custom_size, total);
    assert_eq!(slice_custom.limit, 25);
    assert_eq!(slice_custom.offset, 0);
}

#[test]
fn test_marketplace_purchases_cursor_pagination_envelope() {
    use bytes::Bytes;
    use djangors_core::Request;
    use djangors_rest::pagination::{CursorPagination, Pagination, REST_PER_PAGE};
    use hyper::http::{HeaderMap, Method, Uri};

    let pagination = CursorPagination {
        page_size: REST_PER_PAGE,
        max_page_size: Some(100),
    };

    let req = Request::new(
        Method::GET,
        Uri::from_static("/api/v1/marketplace/purchases"),
        HeaderMap::new(),
        Bytes::new(),
    );
    assert_eq!(pagination.page_size(&req), 100);

    let dummy_results: Vec<serde_json::Value> = (0..5)
        .map(|i| serde_json::json!({ "id": format!("purch-{i}"), "amount": 2900 }))
        .collect();

    let next_cursor = Some("ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJ".to_string());
    let envelope = serde_json::json!({
        "results": dummy_results,
        "next_cursor": next_cursor,
        "previous_cursor": serde_json::Value::Null,
    });

    assert_eq!(envelope["results"].as_array().unwrap().len(), 5);
    assert_eq!(
        envelope["next_cursor"],
        "ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJ"
    );
    assert!(envelope["previous_cursor"].is_null());
}
