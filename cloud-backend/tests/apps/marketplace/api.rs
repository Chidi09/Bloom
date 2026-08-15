use bloom_cloud_backend::apps::marketplace::errors::MarketplaceError;
use bloom_cloud_backend::apps::marketplace::models::{SellerAccount, Template, TemplatePurchase};
use bloom_cloud_backend::apps::marketplace::serializers::{
    serialize_access, serialize_purchase, serialize_refund, serialize_seller_account,
    serialize_template,
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

    // Ensure metadata is serialized as real JSON object, not a raw escaped string
    assert!(json_str.contains("\"tags\":[\"ecommerce\",\"stripe\"]"));
    assert!(!json_str.contains("public_id"));
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
}
