//! Integration and unit tests for Stripe Connect infrastructure client and MockStripeClient.

use std::collections::HashMap;

use bloom_cloud_backend::infra::stripe::{
    CreateAccountLinkParams, CreateAccountParams, CreatePaymentIntentParams, CreateRefundParams,
    MockStripeClient, StripeClient, StripeConfig, StripeError,
};

#[test]
fn test_stripe_config_secret_redaction_in_debug() {
    let secret = "sk_test_51MzFakeKey9876543210ABCDEFabcdef";
    let config = StripeConfig::new(secret);

    let debug_str = format!("{config:?}");
    assert!(
        !debug_str.contains(secret),
        "Secret API key must not appear in Debug output"
    );
    assert!(
        debug_str.contains("[REDACTED]"),
        "Secret API key must be replaced with [REDACTED]"
    );
}

#[tokio::test]
async fn test_mock_stripe_account_onboarding_and_payouts() {
    let client = MockStripeClient::new();

    // 1. Create Express connected account
    let mut meta = HashMap::new();
    meta.insert("org_id".to_string(), "org_123".to_string());

    let params = CreateAccountParams {
        email: Some("seller@example.com".to_string()),
        country: Some("US".to_string()),
        business_type: Some("company".to_string()),
        metadata: meta,
    };

    let acct = client
        .create_express_account(&params)
        .await
        .expect("create express account succeeds");

    assert!(acct.id.starts_with("acct_mock_"));
    assert!(
        !acct.payouts_enabled,
        "New account has payouts_enabled = false"
    );
    assert!(!acct.charges_enabled);

    // 2. Create AccountLink
    let link_params = CreateAccountLinkParams {
        account_id: acct.id.clone(),
        refresh_url: "https://bloom.dev/seller/reauth".to_string(),
        return_url: "https://bloom.dev/seller/return".to_string(),
        link_type: Some("account_onboarding".to_string()),
    };

    let link = client
        .create_account_link(&link_params)
        .await
        .expect("create account link succeeds");

    assert!(link.url.contains("connect.stripe.com/setup/s/"));
    assert!(link.expires_at > 0);

    // 3. Retrieve account before enabling payouts
    let fetched = client
        .retrieve_account(&acct.id)
        .await
        .expect("retrieve account succeeds");
    assert!(!fetched.payouts_enabled);

    // 4. Simulate seller onboarding completion
    client.set_payouts_enabled(&acct.id, true).await;

    let updated = client
        .retrieve_account(&acct.id)
        .await
        .expect("retrieve account succeeds");
    assert!(updated.payouts_enabled);
    assert!(updated.details_submitted);
}

#[tokio::test]
async fn test_mock_stripe_payment_intent_destination_charge() {
    let client = MockStripeClient::new();
    let dest_acct = "acct_mock_seller_001";

    let params = CreatePaymentIntentParams {
        amount: 5000,
        currency: "usd".to_string(),
        application_fee_amount: 1000,
        destination_account_id: dest_acct.to_string(),
        description: Some("Template Purchase: SaaS Kit".to_string()),
        metadata: HashMap::new(),
    };

    let pi = client
        .create_payment_intent(&params, Some("idem_key_001"))
        .await
        .expect("payment intent creation succeeds");

    assert_eq!(pi.amount, 5000);
    assert_eq!(pi.currency, "usd");
    assert_eq!(pi.application_fee_amount, Some(1000));
    assert_eq!(pi.destination_account_id, Some(dest_acct.to_string()));
    assert_eq!(pi.status, "succeeded");
    assert!(pi.client_secret.is_some());

    // Idempotency: repeated call with same idempotency key returns same payment intent
    let pi_retry = client
        .create_payment_intent(&params, Some("idem_key_001"))
        .await
        .expect("idempotent retry succeeds");

    assert_eq!(pi.id, pi_retry.id);
    assert_eq!(client.payment_intents_count().await, 1);
}

#[tokio::test]
async fn test_mock_stripe_fee_exceeding_amount_rejected() {
    let client = MockStripeClient::new();

    // Constraint: application_fee_amount cannot exceed amount
    let params = CreatePaymentIntentParams {
        amount: 2000,
        currency: "usd".to_string(),
        application_fee_amount: 2500, // Exceeds 2000
        destination_account_id: "acct_mock_seller_001".to_string(),
        description: None,
        metadata: HashMap::new(),
    };

    let result = client.create_payment_intent(&params, None).await;
    assert!(
        matches!(result, Err(StripeError::InvalidRequest(_))),
        "Fee exceeding total payment amount must be rejected as InvalidRequest"
    );
}

#[tokio::test]
async fn test_mock_stripe_card_declined_simulation() {
    let client = MockStripeClient::new();
    client.set_should_decline_next_card(true).await;

    let params = CreatePaymentIntentParams {
        amount: 3000,
        currency: "usd".to_string(),
        application_fee_amount: 600,
        destination_account_id: "acct_mock_seller_001".to_string(),
        description: None,
        metadata: HashMap::new(),
    };

    let result = client.create_payment_intent(&params, None).await;
    assert!(
        matches!(result, Err(StripeError::CardDeclined(_))),
        "Simulated card decline must produce StripeError::CardDeclined"
    );

    // Subsequent call succeeds once flag is consumed
    let retry = client.create_payment_intent(&params, None).await;
    assert!(retry.is_ok());
}

#[tokio::test]
async fn test_mock_stripe_refund_with_reverse_transfer() {
    let client = MockStripeClient::new();

    let pi_params = CreatePaymentIntentParams {
        amount: 4000,
        currency: "usd".to_string(),
        application_fee_amount: 800,
        destination_account_id: "acct_mock_seller_001".to_string(),
        description: None,
        metadata: HashMap::new(),
    };

    let pi = client
        .create_payment_intent(&pi_params, None)
        .await
        .expect("payment intent created");

    let refund_params = CreateRefundParams {
        payment_intent_id: pi.id.clone(),
        amount: Some(4000),
        reverse_transfer: true,
        refund_application_fee: Some(true),
    };

    let refund = client
        .create_refund(&refund_params, Some("refund_idem_001"))
        .await
        .expect("refund succeeds");

    assert_eq!(refund.amount, 4000);
    assert_eq!(refund.currency, "usd");
    assert_eq!(refund.status, "succeeded");
    assert_eq!(refund.payment_intent_id, Some(pi.id));

    // Idempotent refund retry
    let refund_retry = client
        .create_refund(&refund_params, Some("refund_idem_001"))
        .await
        .expect("idempotent refund succeeds");
    assert_eq!(refund.id, refund_retry.id);
    assert_eq!(client.refunds_count().await, 1);
}

#[test]
fn test_stripe_error_display_formatting() {
    let err = StripeError::AuthenticationFailed("Invalid API Key".to_string());
    assert!(err.to_string().contains("Stripe authentication failed"));

    let err = StripeError::CardDeclined("Card expired".to_string());
    assert!(err.to_string().contains("Payment declined"));

    let err = StripeError::RateLimited("429 Too Many Requests".to_string());
    assert!(err.to_string().contains("rate limit"));
}
