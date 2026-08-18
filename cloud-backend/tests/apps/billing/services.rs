use bloom_cloud_backend::apps::billing::contracts::{
    EnforcementDecision, Entitlements, FeatureEntitlements, OveragePricing,
};
use bloom_cloud_backend::apps::billing::errors::BillingError;
use bloom_cloud_backend::apps::billing::models::{Plan, Subscription};
use bloom_cloud_backend::apps::billing::serializers::parse_entitlements_json;
use bloom_cloud_backend::apps::billing::services::{
    apply_charge_initiation, apply_free_downgrade, apply_payment_success, calculate_build_minutes,
    calculate_prorated_amount, can_transition_subscription, check_bandwidth_entitlement,
    check_build_minutes_entitlement, check_storage_entitlement, check_web_hosting_entitlement,
    evaluate_feature_enforcement, evaluate_numeric_enforcement, validate_subscription_upgrade,
    EnforcementContext, VALID_INVOICE_STATUSES, VALID_METRICS, VALID_SUBSCRIPTION_STATUSES,
};
use bloom_cloud_backend::infra::crypto::Crypto;
use chrono::{Duration, Utc};
use djangors_contrib_payments::PaymentProvider;
use djangors_contrib_payments::{BachsProvider, PaystackProvider};
use djangors_core::{DjangorsError, StatusCode};
use djangors_orm::ForeignKey;
use hmac::{Hmac, Mac};
use sha2::Sha512;
use uuid::Uuid;

#[test]
fn test_entitlements_parsing_and_restrictive_defaults() {
    // 1. Valid full JSON
    let json = r#"{
        "max_projects": 3,
        "max_apps": 5,
        "max_seats": 10,
        "build_minutes_monthly": 500,
        "artifact_storage_gb": 50,
        "web_bandwidth_gb": 100,
        "features": {
            "testflight_deployments": true,
            "google_play_deployments": true,
            "web_hosting": true,
            "shorebird": false,
            "workflows": false,
            "priority_support": false
        }
    }"#;
    let parsed = parse_entitlements_json(json);
    assert_eq!(parsed.max_projects, 3);
    assert_eq!(parsed.max_apps, 5);
    assert_eq!(parsed.max_seats, 10);
    assert_eq!(parsed.build_minutes_monthly, 500);
    assert_eq!(parsed.artifact_storage_gb, 50);
    assert_eq!(parsed.web_bandwidth_gb, 100);
    assert!(parsed.features.testflight_deployments);
    assert!(parsed.features.google_play_deployments);
    assert!(parsed.features.web_hosting);
    assert!(!parsed.features.shorebird);
    assert!(!parsed.features.workflows);
    assert!(!parsed.features.priority_support);

    // 2. Empty JSON string
    let empty_parsed = parse_entitlements_json("{}");
    assert_eq!(empty_parsed.max_projects, 0);
    assert_eq!(empty_parsed.build_minutes_monthly, 0);
    assert_eq!(empty_parsed.artifact_storage_gb, 0);
    assert!(!empty_parsed.features.testflight_deployments);

    // 3. Malformed JSON must NEVER panic and must yield most restrictive defaults (0 quotas, no paid features)
    let malformed = "{ this is completely invalid json ### }";
    let fallback = parse_entitlements_json(malformed);
    assert_eq!(fallback.max_projects, 0);
    assert_eq!(fallback.max_apps, 0);
    assert_eq!(fallback.max_seats, 0);
    assert_eq!(fallback.build_minutes_monthly, 0);
    assert_eq!(fallback.artifact_storage_gb, 0);
    assert_eq!(fallback.web_bandwidth_gb, 0);
    assert_eq!(fallback.features, FeatureEntitlements::default());
}

#[test]
fn test_numeric_enforcement_boundary_conditions() {
    let limit = 100_i64;

    let free_within_grace = EnforcementContext {
        plan_name: "free".to_string(),
        subscription_status: "active".to_string(),
        grace_days_elapsed: 5,
        max_grace_days: 14,
    };

    let free_expired_grace = EnforcementContext {
        plan_name: "free".to_string(),
        subscription_status: "active".to_string(),
        grace_days_elapsed: 14,
        max_grace_days: 14,
    };

    let pro_active = EnforcementContext {
        plan_name: "pro".to_string(),
        subscription_status: "active".to_string(),
        grace_days_elapsed: 0,
        max_grace_days: 0,
    };

    let locked_ctx = EnforcementContext {
        plan_name: "pro".to_string(),
        subscription_status: "locked".to_string(),
        grace_days_elapsed: 0,
        max_grace_days: 14,
    };

    // 1. Well under limit (< 80%) -> Allow
    assert_eq!(
        evaluate_numeric_enforcement(50, 0, limit, &free_within_grace),
        EnforcementDecision::Allow
    );
    assert_eq!(
        evaluate_numeric_enforcement(79, 0, limit, &free_within_grace),
        EnforcementDecision::Allow
    );

    // 2. Warning threshold (>= 80% and <= 100%) -> Warn
    assert_eq!(
        evaluate_numeric_enforcement(80, 0, limit, &free_within_grace),
        EnforcementDecision::Warn
    );
    assert_eq!(
        evaluate_numeric_enforcement(99, 0, limit, &free_within_grace),
        EnforcementDecision::Warn
    );
    // Exactly at boundary
    assert_eq!(
        evaluate_numeric_enforcement(100, 0, limit, &free_within_grace),
        EnforcementDecision::Warn
    );
    assert_eq!(
        evaluate_numeric_enforcement(90, 10, limit, &free_within_grace),
        EnforcementDecision::Warn
    );

    // 3. Just over limit (101 / 100)
    // Free tier during grace -> SoftBlock
    assert_eq!(
        evaluate_numeric_enforcement(101, 0, limit, &free_within_grace),
        EnforcementDecision::SoftBlock
    );
    assert_eq!(
        evaluate_numeric_enforcement(100, 1, limit, &free_within_grace),
        EnforcementDecision::SoftBlock
    );

    // Free tier after grace period expired -> HardLock
    assert_eq!(
        evaluate_numeric_enforcement(101, 0, limit, &free_expired_grace),
        EnforcementDecision::HardLock
    );

    // Pro tier over limit -> HardLock
    assert_eq!(
        evaluate_numeric_enforcement(101, 0, limit, &pro_active),
        EnforcementDecision::HardLock
    );

    // 4. Locked subscription -> HardLock unconditionally
    assert_eq!(
        evaluate_numeric_enforcement(10, 0, limit, &locked_ctx),
        EnforcementDecision::HardLock
    );
}

#[test]
fn test_feature_enforcement_decisions() {
    let free_in_grace = EnforcementContext {
        plan_name: "free".to_string(),
        subscription_status: "active".to_string(),
        grace_days_elapsed: 2,
        max_grace_days: 14,
    };

    let free_after_grace = EnforcementContext {
        plan_name: "free".to_string(),
        subscription_status: "active".to_string(),
        grace_days_elapsed: 15,
        max_grace_days: 14,
    };

    let pro_active = EnforcementContext {
        plan_name: "pro".to_string(),
        subscription_status: "active".to_string(),
        grace_days_elapsed: 0,
        max_grace_days: 0,
    };

    // Enabled feature -> Allow
    assert_eq!(
        evaluate_feature_enforcement(true, &free_in_grace),
        EnforcementDecision::Allow
    );
    assert_eq!(
        evaluate_feature_enforcement(true, &pro_active),
        EnforcementDecision::Allow
    );

    // Disabled feature in free tier with grace -> SoftBlock
    assert_eq!(
        evaluate_feature_enforcement(false, &free_in_grace),
        EnforcementDecision::SoftBlock
    );

    // Disabled feature in free tier after grace -> HardLock
    assert_eq!(
        evaluate_feature_enforcement(false, &free_after_grace),
        EnforcementDecision::HardLock
    );

    // Disabled feature on paid plan -> HardLock
    assert_eq!(
        evaluate_feature_enforcement(false, &pro_active),
        EnforcementDecision::HardLock
    );
}

#[test]
fn test_specific_entitlement_helpers() {
    let entitlements = Entitlements {
        max_projects: 3,
        max_apps: 5,
        max_seats: 10,
        build_minutes_monthly: 500,
        artifact_storage_gb: 50,
        web_bandwidth_gb: 100,
        features: FeatureEntitlements {
            testflight_deployments: true,
            google_play_deployments: true,
            web_hosting: true,
            shorebird: false,
            workflows: false,
            priority_support: false,
        },
        overage: OveragePricing::default(),
    };

    let ctx = EnforcementContext {
        plan_name: "free".to_string(),
        subscription_status: "active".to_string(),
        grace_days_elapsed: 0,
        max_grace_days: 14,
    };

    // Build minutes: 400/500 = 80% -> Warn
    assert_eq!(
        check_build_minutes_entitlement(&entitlements, 400, 0, &ctx),
        EnforcementDecision::Warn
    );
    // Build minutes: 200/500 = 40% -> Allow
    assert_eq!(
        check_build_minutes_entitlement(&entitlements, 200, 0, &ctx),
        EnforcementDecision::Allow
    );

    // Web hosting: enabled -> Allow
    assert_eq!(
        check_web_hosting_entitlement(&entitlements, &ctx),
        EnforcementDecision::Allow
    );

    // Storage: 45/50 = 90% -> Warn
    assert_eq!(
        check_storage_entitlement(&entitlements, 45, 0, &ctx),
        EnforcementDecision::Warn
    );

    // Bandwidth: 10/100 = 10% -> Allow
    assert_eq!(
        check_bandwidth_entitlement(&entitlements, 10, 0, &ctx),
        EnforcementDecision::Allow
    );
}

#[test]
fn test_integer_money_proration_arithmetic() {
    // 1. $29/mo (2900 cents) used for 15 days out of 30 days
    let half_month = calculate_prorated_amount(2900, 15 * 86400, 30 * 86400);
    assert_eq!(half_month, 1450);

    // 2. Exact division with documented integer truncation:
    // 1000 cents used for 1 third of duration (1 / 3) -> 333 cents
    let third = calculate_prorated_amount(1000, 1, 3);
    assert_eq!(third, 333);

    // 3. Full period usage
    let full = calculate_prorated_amount(2900, 30 * 86400, 30 * 86400);
    assert_eq!(full, 2900);

    // 4. Over period clamped to total
    let over = calculate_prorated_amount(2900, 35 * 86400, 30 * 86400);
    assert_eq!(over, 2900);

    // 5. Zero or negative edge cases
    assert_eq!(calculate_prorated_amount(0, 15, 30), 0);
    assert_eq!(calculate_prorated_amount(2900, 0, 30), 0);
    assert_eq!(calculate_prorated_amount(2900, -5, 30), 0);
    assert_eq!(calculate_prorated_amount(2900, 15, 0), 0);
}

#[test]
fn test_build_minutes_calculation() {
    let now = Utc::now();

    // 1. Missing start or finish -> 0
    assert_eq!(calculate_build_minutes(None, None), 0);
    assert_eq!(calculate_build_minutes(Some(now), None), 0);
    assert_eq!(calculate_build_minutes(None, Some(now)), 0);

    // 2. Inverted interval (finished before started) -> clamped at 0
    let earlier = now - Duration::seconds(120);
    assert_eq!(calculate_build_minutes(Some(now), Some(earlier)), 0);

    // 3. 45 seconds -> 1 minute (ceiling integer division)
    let end_45s = now + Duration::seconds(45);
    assert_eq!(calculate_build_minutes(Some(now), Some(end_45s)), 1);

    // 4. Exactly 60 seconds -> 1 minute
    let end_60s = now + Duration::seconds(60);
    assert_eq!(calculate_build_minutes(Some(now), Some(end_60s)), 1);

    // 5. 61 seconds -> 2 minutes
    let end_61s = now + Duration::seconds(61);
    assert_eq!(calculate_build_minutes(Some(now), Some(end_61s)), 2);

    // 6. 120 seconds -> 2 minutes
    let end_120s = now + Duration::seconds(120);
    assert_eq!(calculate_build_minutes(Some(now), Some(end_120s)), 2);
}

#[test]
fn test_subscription_status_transitions_exhaustive() {
    let statuses = ["trialing", "active", "past_due", "locked", "cancelled"];

    for from in &statuses {
        for to in &statuses {
            let allowed = can_transition_subscription(from, to);
            match (*from, *to) {
                ("trialing", "active") => assert!(allowed),
                ("trialing", "past_due") => assert!(allowed),
                ("trialing", "cancelled") => assert!(allowed),
                ("active", "past_due") => assert!(allowed),
                ("active", "locked") => assert!(allowed),
                ("active", "cancelled") => assert!(allowed),
                ("past_due", "active") => assert!(allowed),
                ("past_due", "locked") => assert!(allowed),
                ("past_due", "cancelled") => assert!(allowed),
                ("locked", "active") => assert!(allowed),
                ("locked", "cancelled") => assert!(allowed),
                ("cancelled", "active") => assert!(allowed),
                ("cancelled", "trialing") => assert!(allowed),
                _ => assert!(!allowed, "Transition '{from}' -> '{to}' must be rejected"),
            }
        }
    }
}

#[test]
fn test_bachs_and_paystack_signature_verification() {
    // 1. Bachs signature test with real HMAC-SHA256 computation
    let bachs_secret = "bachs_sec_test_key_12345";
    let bachs_provider = BachsProvider::new(bachs_secret);
    let raw_body = br#"{"type":"collection.succeeded","data":{"reference":"sub_ref_123","amount":"29.00","currency":"USD"}}"#;
    let timestamp = "1723723800";

    // Bachs signs HMAC-SHA256 over `timestamp + "." + raw_body`, hex-encoded — confirmed
    // against verify_webhook_signature_with_timestamp in djangors-contrib-payments' bachs.rs.
    // Built with the crate's own HMAC helper rather than pulling in `hmac` and `hex` for a test.
    let mut msg = timestamp.as_bytes().to_vec();
    msg.push(b'.');
    msg.extend_from_slice(raw_body);
    let valid_bachs_sig = Crypto::hmac_sha256_hex(bachs_secret.as_bytes(), &msg);

    // Valid signature + timestamp succeeds
    assert!(bachs_provider.verify_webhook_signature_with_timestamp(
        raw_body,
        Some(timestamp),
        &valid_bachs_sig
    ));

    // Bad signature fails
    assert!(!bachs_provider.verify_webhook_signature_with_timestamp(
        raw_body,
        Some(timestamp),
        "deadbeefdeadbeef"
    ));

    // Missing timestamp fails
    assert!(!bachs_provider.verify_webhook_signature_with_timestamp(
        raw_body,
        None,
        &valid_bachs_sig
    ));

    // Modified body fails
    let tampered_body = br#"{"type":"collection.succeeded","data":{"amount":"0.01"}}"#;
    assert!(!bachs_provider.verify_webhook_signature_with_timestamp(
        tampered_body,
        Some(timestamp),
        &valid_bachs_sig
    ));

    // 2. Paystack signature test with real HMAC-SHA512 computation
    let paystack_secret = "paystack_sec_key_67890";
    let paystack_provider = PaystackProvider::new(paystack_secret);

    type HmacSha512 = Hmac<Sha512>;
    let mut p_mac = HmacSha512::new_from_slice(paystack_secret.as_bytes()).unwrap();
    p_mac.update(raw_body);
    let valid_paystack_sig = hex::encode(p_mac.finalize().into_bytes());

    assert!(paystack_provider.verify_webhook_signature(raw_body, &valid_paystack_sig));
    assert!(!paystack_provider.verify_webhook_signature(raw_body, "bad_signature_value"));
    assert!(!paystack_provider.verify_webhook_signature(tampered_body, &valid_paystack_sig));
}

#[test]
fn test_constants_completeness() {
    assert_eq!(
        VALID_METRICS,
        &[
            "build_minutes",
            "artifact_storage_gb",
            "web_bandwidth_gb",
            "deploy_count"
        ]
    );
    assert_eq!(
        VALID_SUBSCRIPTION_STATUSES,
        &["trialing", "active", "past_due", "locked", "cancelled"]
    );
    assert_eq!(
        VALID_INVOICE_STATUSES,
        &["draft", "sent", "paid", "overdue", "void"]
    );
}

fn sample_plan(id: i64, name: &str, price_minor: i64, currency: &str) -> Plan {
    Plan {
        id,
        public_id: Uuid::new_v4().to_string(),
        name: name.to_string(),
        description: Some(format!("{name} plan")),
        price_minor,
        currency: currency.to_string(),
        entitlements: "{}".to_string(),
        active: true,
        created_at: Utc::now(),
    }
}

fn sample_subscription(id: i64, plan_id: i64, status: &str) -> Subscription {
    let now = Utc::now();
    Subscription {
        id,
        public_id: Uuid::new_v4().to_string(),
        organization_id: ForeignKey::new(100),
        plan_id: ForeignKey::new(plan_id),
        pending_plan_id: None,
        status: status.to_string(),
        trial_ends_at: None,
        activated_at: Some(now),
        current_period_start: now,
        current_period_end: now + Duration::days(30),
        stripe_customer_id: None,
        stripe_subscription_id: None,
        created_at: now,
        updated_at: now,
    }
}

#[test]
fn test_unknown_provider_string_rejected_with_validation_error() {
    let pro_plan = sample_plan(2, "pro", 2900, "USD");

    // Invalid providers rejected with validation error
    let err_stripe = validate_subscription_upgrade(&pro_plan, Some("stripe")).unwrap_err();
    assert!(matches!(err_stripe, BillingError::ValidationError(_)));

    let err_paypal = validate_subscription_upgrade(&pro_plan, Some("paypal")).unwrap_err();
    assert!(matches!(err_paypal, BillingError::ValidationError(_)));

    let err_random = validate_subscription_upgrade(&pro_plan, Some("unknown_prov")).unwrap_err();
    assert!(matches!(err_random, BillingError::ValidationError(_)));

    // Valid providers accepted
    let (prov_bachs, amt, curr) = validate_subscription_upgrade(&pro_plan, Some("bachs")).unwrap();
    assert_eq!(prov_bachs, "bachs");
    assert_eq!(amt, 2900);
    assert_eq!(curr, "USD");

    let (prov_paystack, amt, curr) =
        validate_subscription_upgrade(&pro_plan, Some("paystack")).unwrap();
    assert_eq!(prov_paystack, "paystack");
    assert_eq!(amt, 2900);
    assert_eq!(curr, "USD");

    // Default provider when None is bachs
    let (prov_default, amt, curr) = validate_subscription_upgrade(&pro_plan, None).unwrap();
    assert_eq!(prov_default, "bachs");
    assert_eq!(amt, 2900);
    assert_eq!(curr, "USD");
}

#[test]
fn test_plan_price_minor_drives_charge_and_zero_price_on_paid_plan_rejected() {
    // 1. Paid plan with price 0 is rejected as an invalid amount
    let zero_price_pro = sample_plan(2, "pro", 0, "USD");
    let err_zero = validate_subscription_upgrade(&zero_price_pro, None).unwrap_err();
    assert!(matches!(err_zero, BillingError::InvalidAmount(_)));

    // Negative price is also rejected
    let neg_price_plan = sample_plan(2, "pro", -100, "USD");
    let err_neg = validate_subscription_upgrade(&neg_price_plan, None).unwrap_err();
    assert!(matches!(err_neg, BillingError::InvalidAmount(_)));

    // 2. Enterprise plan with price 19900 cents correctly returns 19900
    let ent_plan = sample_plan(3, "enterprise", 19900, "USD");
    let (_, charged_cents, currency) = validate_subscription_upgrade(&ent_plan, None).unwrap();
    assert_eq!(charged_cents, 19900);
    assert_eq!(currency, "USD");

    // Custom paid plan price drives the charged amount
    let custom_plan = sample_plan(4, "custom", 4900, "USD");
    let (_, charged_cents, currency) = validate_subscription_upgrade(&custom_plan, None).unwrap();
    assert_eq!(charged_cents, 4900);
    assert_eq!(currency, "USD");
}

#[test]
fn test_free_downgrade_immediate_no_charge_attempted() {
    let free_plan = sample_plan(1, "free", 0, "USD");

    // Free plan validation bypasses provider charge
    let (provider, amount, _) = validate_subscription_upgrade(&free_plan, None).unwrap();
    assert_eq!(provider, "none");
    assert_eq!(amount, 0);

    // Free downgrade directly updates plan_id and sets active without pending_plan_id
    let mut sub = sample_subscription(10, 2, "active"); // currently on Pro (plan_id = 2)
    let now = Utc::now();
    let period_end = now + Duration::days(30);

    apply_free_downgrade(&mut sub, free_plan.id, now, period_end);

    assert_eq!(sub.plan_id.id, 1);
    assert_eq!(sub.pending_plan_id, None);
    assert_eq!(sub.status, "active");
}

#[test]
fn test_successful_initiation_sets_past_due_preserves_plan_id_and_sets_pending_plan() {
    let mut sub = sample_subscription(10, 1, "active"); // on Free (plan_id = 1)
    let now = Utc::now();
    let original_period_start = sub.current_period_start;
    let original_period_end = sub.current_period_end;
    let target_plan_id = 2_i64; // Pro
    let reference = "sub_100_test_ref_123";

    apply_charge_initiation(&mut sub, target_plan_id, reference, now)
        .expect("charge initiation succeeds");

    // Status becomes past_due
    assert_eq!(sub.status, "past_due");
    // PREVIOUS plan_id is UNCHANGED until payment confirms
    assert_eq!(sub.plan_id.id, 1);
    // Pending target plan is persisted
    assert_eq!(sub.pending_plan_id, Some(2));
    // Reference is recorded
    assert_eq!(sub.stripe_subscription_id, Some(reference.to_string()));
    // The billing period must NOT advance on mere initiation. Metered usage is counted since
    // current_period_start, so advancing it here would let a caller reset their own quota by
    // starting an upgrade and abandoning the payment page.
    assert_eq!(sub.current_period_start, original_period_start);
    assert_eq!(sub.current_period_end, original_period_end);
}

#[test]
fn test_abandoned_checkout_does_not_reset_metered_usage_window() {
    let mut sub = sample_subscription(10, 1, "active");
    let original_period_start = sub.current_period_start;

    // Caller repeatedly starts an upgrade and never pays.
    for i in 0..3 {
        let now = Utc::now() + Duration::minutes(i);
        apply_charge_initiation(&mut sub, 2, &format!("ref_{i}"), now)
            .expect("re-initiation from past_due is allowed");
        assert_eq!(
            sub.current_period_start, original_period_start,
            "quota window must never move without a confirmed payment"
        );
    }

    // Still on the free plan the whole time.
    assert_eq!(sub.plan_id.id, 1);
}

#[test]
fn test_webhook_success_applies_pending_plan_and_activates() {
    let mut sub = sample_subscription(10, 1, "past_due");
    sub.pending_plan_id = Some(2); // Pro upgrade pending
    sub.activated_at = None;

    let now = Utc::now();
    let period_end = now + Duration::days(30);
    let changed = apply_payment_success(&mut sub, now, period_end);

    assert!(changed, "apply_payment_success must report state changed");
    // The billing period advances here, against a confirmed payment.
    assert_eq!(sub.current_period_start, now);
    assert_eq!(sub.current_period_end, period_end);
    // Plan is updated to pending target plan
    assert_eq!(sub.plan_id.id, 2);
    // Pending target plan is cleared
    assert_eq!(sub.pending_plan_id, None);
    // Status transitions to active
    assert_eq!(sub.status, "active");
    // Activated timestamp is set
    assert_eq!(sub.activated_at, Some(now));
}

#[test]
fn test_webhook_redelivered_twice_is_idempotent() {
    let mut sub = sample_subscription(10, 1, "past_due");
    sub.pending_plan_id = Some(2);
    sub.activated_at = None;

    let first_time = Utc::now();
    let first_applied =
        apply_payment_success(&mut sub, first_time, first_time + Duration::days(30));
    assert!(first_applied);
    assert_eq!(sub.plan_id.id, 2);
    assert_eq!(sub.pending_plan_id, None);
    assert_eq!(sub.status, "active");
    assert_eq!(sub.activated_at, Some(first_time));

    // Second webhook delivery for same event later
    let second_time = first_time + Duration::minutes(10);
    let period_after_first = sub.current_period_start;
    let second_applied =
        apply_payment_success(&mut sub, second_time, second_time + Duration::days(30));

    // A redelivered webhook must not slide the quota window forward either.
    assert_eq!(sub.current_period_start, period_after_first);

    // Must NOT re-apply or mutate
    assert!(
        !second_applied,
        "Second delivery must be a no-op (idempotent)"
    );
    assert_eq!(sub.plan_id.id, 2);
    assert_eq!(sub.pending_plan_id, None);
    assert_eq!(sub.status, "active");
    // Original activated_at preserved
    assert_eq!(sub.activated_at, Some(first_time));
}

#[test]
fn test_provider_failure_maps_to_bad_gateway_and_never_grants_the_plan() {
    // A provider failure must surface as 502 rather than being swallowed. `subscribe_to_plan`
    // propagates it with `?` BEFORE calling apply_charge_initiation, so the only way a plan
    // change is ever persisted is through the success path exercised above.
    let err: DjangorsError =
        BillingError::PaymentProviderError("bachs: 502 Bad Gateway".to_string()).into();
    assert_eq!(err.status_code(), StatusCode::BAD_GATEWAY);

    // An unconfigured provider is likewise an error, not a silent free upgrade.
    let unconfigured: DjangorsError = BillingError::PaymentProviderNotConfigured.into();
    assert_eq!(
        unconfigured.status_code(),
        StatusCode::INTERNAL_SERVER_ERROR
    );
}
