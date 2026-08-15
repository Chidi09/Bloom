use bloom_cloud_backend::apps::marketplace::contracts::{
    CreateSellerOnboardingLinkRequest, FeatureTemplateRequest, PurchaseTemplateRequest,
    RefundPurchaseRequest, ReviewAuthorReplyRequest, ReviewCreateRequest, TemplateCreateRequest,
};
use bloom_cloud_backend::apps::marketplace::services::{
    calculate_bayesian_rating, calculate_hn_ranking_score, calculate_split,
    calculate_wilson_score_lower_bound, can_transition, compute_install_actor_hash, slugify,
    validate_featured_type, validate_pricing, validate_rating, validate_review_status,
    validate_status, validate_version, validate_visibility, BAYESIAN_PRIOR_WEIGHT_M,
    DEFAULT_GLOBAL_MEAN_MILLI, VALID_FEATURED_TYPES, VALID_PURCHASE_STATUSES,
    VALID_REPORT_STATUSES, VALID_REVIEW_STATUSES, VALID_STATUSES, VALID_VISIBILITIES,
};

#[test]
fn test_calculate_split_fee_plus_seller_equals_total_invariant() {
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
    assert!(calculate_split(-1, 2000).is_err());
    assert!(calculate_split(-500, 2000).is_err());
    assert!(calculate_split(1000, -1).is_err());
    assert!(calculate_split(1000, 10001).is_err());
}

#[test]
fn test_pricing_validation() {
    assert!(validate_pricing(true, 0, "usd").is_ok());
    assert!(validate_pricing(true, 500, "usd").is_err());

    assert!(validate_pricing(false, 2900, "usd").is_ok());
    assert!(validate_pricing(false, 1000, "eur").is_ok());
    assert!(validate_pricing(false, 500, "gbp").is_ok());

    assert!(validate_pricing(false, 0, "usd").is_err());
    assert!(validate_pricing(false, -100, "usd").is_err());
    assert!(validate_pricing(false, 1000, "us").is_err());
    assert!(validate_pricing(false, 1000, "usdt").is_err());
    assert!(validate_pricing(false, 1000, "123").is_err());
}

#[test]
fn test_template_status_transition_matrix() {
    assert!(can_transition("draft", "published"));
    assert!(can_transition("draft", "archived"));
    assert!(!can_transition("draft", "draft"));

    assert!(can_transition("published", "draft"));
    assert!(can_transition("published", "archived"));
    assert!(!can_transition("published", "published"));

    assert!(!can_transition("archived", "draft"));
    assert!(!can_transition("archived", "published"));
    assert!(!can_transition("archived", "archived"));

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
fn test_rating_scale_validation() {
    // Valid ratings: 1..=5 integer stars
    for r in 1..=5 {
        assert!(validate_rating(r).is_ok(), "Rating {r} must be valid");
    }

    // Invalid ratings: outside 1..=5 rejected
    assert!(validate_rating(0).is_err(), "Rating 0 must be rejected");
    assert!(
        validate_rating(-1).is_err(),
        "Negative rating must be rejected"
    );
    assert!(validate_rating(6).is_err(), "Rating 6 must be rejected");
    assert!(validate_rating(100).is_err(), "Rating 100 must be rejected");
}

#[test]
fn test_review_and_featured_statuses_validation() {
    for st in VALID_REVIEW_STATUSES {
        assert!(validate_review_status(st).is_ok());
    }
    assert!(validate_review_status("deleted").is_err());

    for ft in VALID_FEATURED_TYPES {
        assert!(validate_featured_type(ft).is_ok());
    }
    assert!(validate_featured_type("sponsored_banner").is_err());

    assert_eq!(VALID_REPORT_STATUSES.len(), 4);
    assert!(VALID_REPORT_STATUSES.contains(&"pending"));
    assert!(VALID_REPORT_STATUSES.contains(&"actioned"));
}

#[test]
fn test_bayesian_rating_few_ratings_pulled_to_global_mean() {
    let global_mean_milli = DEFAULT_GLOBAL_MEAN_MILLI; // 3500 (3.5 stars)
    let prior_m = BAYESIAN_PRIOR_WEIGHT_M; // 2

    // Single 5-star rating (n = 1, sum = 5)
    // Formula: (1000 * 5 + 2 * 3500 + 3 / 2) / (1 + 2) = (5000 + 7000 + 1) / 3 = 12001 / 3 = 4000
    let bayesian_score = calculate_bayesian_rating(5, 1, global_mean_milli, prior_m)
        .expect("Bayesian calculation succeeds");
    assert_eq!(
        bayesian_score, 4000,
        "A single 5-star rating must be pulled down toward global mean (3.5 stars) to 4.0 stars (4000 milli-stars)"
    );

    // Single 1-star rating (n = 1, sum = 1)
    // Formula: (1000 * 1 + 2 * 3500 + 3 / 2) / (1 + 2) = (1000 + 7000 + 1) / 3 = 8001 / 3 = 2667
    let bayesian_low = calculate_bayesian_rating(1, 1, global_mean_milli, prior_m)
        .expect("Bayesian calculation succeeds");
    assert_eq!(
        bayesian_low, 2667,
        "A single 1-star rating must be pulled up toward global mean (3.5 stars) to 2.667 stars"
    );
}

#[test]
fn test_bayesian_rating_many_ratings_dominated_by_own_ratings() {
    let global_mean_milli = DEFAULT_GLOBAL_MEAN_MILLI; // 3500 (3.5 stars)
    let prior_m = BAYESIAN_PRIOR_WEIGHT_M; // 2

    // 100 ratings of 5 stars (n = 100, sum = 500)
    // Formula: (1000 * 500 + 2 * 3500 + 102 / 2) / (100 + 2) = (500000 + 7000 + 51) / 102 = 507051 / 102 = 4971
    let bayesian_high_volume = calculate_bayesian_rating(500, 100, global_mean_milli, prior_m)
        .expect("Bayesian calculation succeeds");
    assert_eq!(
        bayesian_high_volume, 4971,
        "High volume 5-star ratings must be dominated by its own ratings (4.971 stars)"
    );

    // 500 ratings of 4 stars (n = 500, sum = 2000)
    // Formula: (1000 * 2000 + 2 * 3500 + 502 / 2) / (500 + 2) = (2000000 + 7000 + 251) / 502 = 2007251 / 502 = 3998
    let bayesian_4star_volume = calculate_bayesian_rating(2000, 500, global_mean_milli, prior_m)
        .expect("Bayesian calculation succeeds");
    assert_eq!(bayesian_4star_volume, 3998);
}

#[test]
fn test_bayesian_rating_rounding_term_half_up_boundaries() {
    let global_mean_milli = 3500;
    let prior_m = 2;

    // Zero ratings: score should equal global mean
    let zero_score = calculate_bayesian_rating(0, 0, global_mean_milli, prior_m)
        .expect("Bayesian calculation succeeds");
    assert_eq!(zero_score, 3500);

    // Test exact round-half-up behavior:
    // With n = 2, m = 2 -> denominator = 4, half_term = (4 / 2) = 2.
    // For 2 ratings of 4 stars (sum = 8):
    // 1000 * 8 + 2 * 3500 = 8000 + 7000 = 15000.
    // (15000 + 2) / 4 = 15002 / 4 = 3750.
    let score_exact = calculate_bayesian_rating(8, 2, global_mean_milli, prior_m).unwrap();
    assert_eq!(score_exact, 3750);
}

#[test]
fn test_wilson_score_5star_from_2_ranks_below_4_7_from_400() {
    // Template A: Two 5-star reviews (sum = 10, count = 2) -> Average 5.0
    let wilson_a = calculate_wilson_score_lower_bound(10, 2);

    // Template B: Four hundred reviews with average 4.7 stars (sum = 1880, count = 400)
    let wilson_b = calculate_wilson_score_lower_bound(1880, 400);

    // Verification: 5.0 from 2 reviews has high statistical uncertainty and must rank BELOW 4.7 from 400 reviews
    assert!(
        wilson_a < wilson_b,
        "Wilson lower bound failed: 5.0 from 2 reviews ({wilson_a}) should rank BELOW 4.7 from 400 reviews ({wilson_b})"
    );

    // Exact mathematical checks:
    // For (10, 2): p = 1.0, z = 1.96 -> Wilson lower bound ≈ 0.4387
    // For (1880, 400): p = 0.925, z = 1.96 -> Wilson lower bound ≈ 0.8954
    assert!((0.43..=0.45).contains(&wilson_a));
    assert!((0.89..=0.91).contains(&wilson_b));
}

#[test]
fn test_hn_ranking_popularity_vs_recency() {
    // Fresh popular template: 50 installs published 2 hours ago
    let score_fresh = calculate_hn_ranking_score(50, 2.0);

    // Older template: 500 installs published 100 hours ago
    let score_old = calculate_hn_ranking_score(500, 100.0);

    // Verified HN property: Fresh popular item outranks older item despite older having 10x more installs
    assert!(
        score_fresh > score_old,
        "Fresh template score ({score_fresh}) should exceed older template score ({score_old})"
    );

    // Monotonic decay over time: As hours T increase for fixed P, score strictly decreases
    let score_t1 = calculate_hn_ranking_score(100, 5.0);
    let score_t2 = calculate_hn_ranking_score(100, 24.0);
    let score_t3 = calculate_hn_ranking_score(100, 72.0);

    assert!(score_t1 > score_t2);
    assert!(score_t2 > score_t3);

    // Base boundary: 1 install or 0 installs produces score 0.0
    assert_eq!(calculate_hn_ranking_score(1, 10.0), 0.0);
    assert_eq!(calculate_hn_ranking_score(0, 10.0), 0.0);
}

#[test]
fn test_privacy_preserving_install_hash_deduplication() {
    let day1_salt = "bloom_install_salt_2026-08-15";
    let day2_salt = "bloom_install_salt_2026-08-16";
    let client_ip = "198.51.100.42";

    // 1. Same actor within same daily window produces identical hash (deduplication)
    let hash_day1_a = compute_install_actor_hash(day1_salt, client_ip);
    let hash_day1_b = compute_install_actor_hash(day1_salt, client_ip);
    assert_eq!(hash_day1_a, hash_day1_b);

    // 2. Different day (different rotating salt) produces completely unlinked hash
    let hash_day2 = compute_install_actor_hash(day2_salt, client_ip);
    assert_ne!(hash_day1_a, hash_day2);

    // 3. Privacy assurance: raw IP is not in hash and hash is fixed 64-char SHA-256 hex digest
    assert_eq!(hash_day1_a.len(), 64);
    assert!(!hash_day1_a.contains(client_ip));
    assert!(hash_day1_a.chars().all(|c| c.is_ascii_hexdigit()));
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

    let review_req: ReviewCreateRequest = serde_json::from_str(
        r#"{"rating":5,"title":"Superb starter!","comment":"Clean architecture."}"#,
    )
    .unwrap();
    assert_eq!(review_req.rating, 5);
    assert_eq!(review_req.title, Some("Superb starter!".to_string()));

    let reply_req: ReviewAuthorReplyRequest =
        serde_json::from_str(r#"{"response":"Thank you for the kind review!"}"#).unwrap();
    assert_eq!(reply_req.response, "Thank you for the kind review!");

    let feature_req: FeatureTemplateRequest =
        serde_json::from_str(r#"{"featured_type":"editorial","duration_days":14}"#).unwrap();
    assert_eq!(feature_req.featured_type, "editorial");
    assert_eq!(feature_req.duration_days, Some(14));
}
