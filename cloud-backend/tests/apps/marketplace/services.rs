use bloom_cloud_backend::apps::marketplace::contracts::{
    CreateSellerOnboardingLinkRequest, PurchaseTemplateRequest, RefundPurchaseRequest,
    TemplateCreateRequest,
};
use bloom_cloud_backend::apps::marketplace::services::{
    calculate_split, can_transition, slugify, validate_pricing, validate_status, validate_version,
    validate_visibility, VALID_PURCHASE_STATUSES, VALID_STATUSES, VALID_VISIBILITIES,
};

#[test]
fn test_calculate_split_fee_plus_seller_equals_total_invariant() {
    // Test across a comprehensive spectrum of amounts including 0, 1, and odd/fractional amounts
    let test_amounts = [
        0, 1, 2, 3, 5, 7, 9, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 50, 99, 100, 101, 199,
        299, 500, 999, 1000, 1499, 1500, 2900, 4999, 9999, 19900, 99999, 1234567, 10000000,
    ];

    let commission_rates = [0, 500, 1000, 1500, 2000, 2500, 3000, 5000, 7500, 10000];

    for &amt in &test_amounts {
        for &bps in &commission_rates {
            let split = calculate_split(amt, bps).expect("split calculation succeeds");

            // Non-negotiable invariant 1: platform_fee + seller_amount MUST equal total amount
            assert_eq!(
                split.platform_fee + split.seller_amount,
                amt,
                "Invariant violated for amount={amt} and commission_bps={bps}: fee={} + seller={}",
                split.platform_fee,
                split.seller_amount
            );

            // Invariant 2: platform fee can never exceed total amount
            assert!(
                split.platform_fee <= amt,
                "Platform fee {} exceeded total amount {}",
                split.platform_fee,
                amt
            );

            // Invariant 3: seller amount is non-negative
            assert!(
                split.seller_amount >= 0,
                "Seller amount {} is negative for amount {}",
                split.seller_amount,
                amt
            );
        }
    }
}

#[test]
fn test_calculate_split_invalid_inputs() {
    // Negative amounts must be rejected
    assert!(calculate_split(-1, 2000).is_err());
    assert!(calculate_split(-500, 2000).is_err());

    // Commission bps outside 0..=10000 must be rejected
    assert!(calculate_split(1000, -1).is_err());
    assert!(calculate_split(1000, 10001).is_err());
}

#[test]
fn test_pricing_validation() {
    // 1. Free templates must have price 0
    assert!(validate_pricing(true, 0, "usd").is_ok());
    assert!(validate_pricing(true, 500, "usd").is_err());

    // 2. Paid templates must have price > 0 and valid 3-letter currency
    assert!(validate_pricing(false, 2900, "usd").is_ok());
    assert!(validate_pricing(false, 1000, "eur").is_ok());
    assert!(validate_pricing(false, 500, "gbp").is_ok());

    assert!(validate_pricing(false, 0, "usd").is_err());
    assert!(validate_pricing(false, -100, "usd").is_err());
    assert!(validate_pricing(false, 1000, "us").is_err()); // Too short
    assert!(validate_pricing(false, 1000, "usdt").is_err()); // Too long
    assert!(validate_pricing(false, 1000, "123").is_err()); // Non-alphabetic
}

#[test]
fn test_template_status_transition_matrix() {
    // 1. Legal transitions from draft
    assert!(
        can_transition("draft", "published"),
        "draft can be published"
    );
    assert!(can_transition("draft", "archived"), "draft can be archived");
    assert!(!can_transition("draft", "draft"));

    // 2. Legal transitions from published
    assert!(
        can_transition("published", "draft"),
        "published can return to draft"
    );
    assert!(
        can_transition("published", "archived"),
        "published can be archived"
    );
    assert!(!can_transition("published", "published"));

    // 3. Archived is strictly absorbing terminal state
    assert!(
        !can_transition("archived", "draft"),
        "archived cannot transition to draft"
    );
    assert!(
        !can_transition("archived", "published"),
        "archived cannot transition to published"
    );
    assert!(!can_transition("archived", "archived"));

    // 4. Unknown statuses
    assert!(!can_transition("unknown", "published"));
    assert!(!can_transition("draft", "unknown"));
}

#[test]
fn test_slugify_logic() {
    assert_eq!(slugify("Flutter SaaS Starter"), "flutter-saas-starter");
    assert_eq!(slugify("Bloom E-Commerce v2.0!"), "bloom-e-commerce-v2-0");
    assert_eq!(slugify("  --spaces-and-dashes--  "), "spaces-and-dashes");
    assert_eq!(slugify("123-numbers"), "123-numbers");
    assert_eq!(slugify(""), "template");
}

#[test]
fn test_slugify_max_length() {
    let long_name = "x".repeat(120);
    let slug = slugify(&long_name);
    assert!(slug.len() <= 60);
}

#[test]
fn test_validate_version_semver() {
    assert!(validate_version("1.0.0").is_ok());
    assert!(validate_version("0.1.0-alpha.1").is_ok());
    assert!(validate_version("v2.3.4").is_ok());

    assert!(validate_version("").is_err());
    assert!(validate_version("   ").is_err());
    assert!(validate_version("not-a-semver").is_err());
    assert!(validate_version(&"1".repeat(70)).is_err());
}

#[test]
fn test_validate_visibility_and_status() {
    for vis in VALID_VISIBILITIES {
        assert!(validate_visibility(vis).is_ok());
    }
    assert!(validate_visibility("secret").is_err());

    for st in VALID_STATUSES {
        assert!(validate_status(st).is_ok());
    }
    assert!(validate_status("in_review").is_err());

    assert_eq!(VALID_PURCHASE_STATUSES.len(), 4);
    assert!(VALID_PURCHASE_STATUSES.contains(&"succeeded"));
    assert!(VALID_PURCHASE_STATUSES.contains(&"refunded"));
}

#[test]
fn test_contracts_deserialization() {
    let create_req: TemplateCreateRequest = serde_json::from_str(
        r#"{"name":"Mobile Starter","description":"Starter kit","visibility":"public","is_free":false,"price_amount":2900,"price_currency":"usd","metadata":{"category":"mobile"}}"#,
    )
    .unwrap();
    assert_eq!(create_req.name, "Mobile Starter");
    assert_eq!(create_req.is_free, Some(false));
    assert_eq!(create_req.price_amount, Some(2900));
    assert_eq!(create_req.price_currency, Some("usd".to_string()));

    let buy_req: PurchaseTemplateRequest =
        serde_json::from_str(r#"{"template_version_id":"ver-123","idempotency_key":"key-456"}"#)
            .unwrap();
    assert_eq!(buy_req.template_version_id, Some("ver-123".to_string()));
    assert_eq!(buy_req.idempotency_key, Some("key-456".to_string()));

    let onboarding_req: CreateSellerOnboardingLinkRequest = serde_json::from_str(
        r#"{"refresh_url":"https://example.com/refresh","return_url":"https://example.com/return"}"#,
    )
    .unwrap();
    assert_eq!(onboarding_req.refresh_url, "https://example.com/refresh");

    let refund_req: RefundPurchaseRequest =
        serde_json::from_str(r#"{"reason":"Customer requested"}"#).unwrap();
    assert_eq!(refund_req.reason, Some("Customer requested".to_string()));
}
