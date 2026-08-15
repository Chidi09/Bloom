//! Unit tests for webhook HMAC-SHA256 signature verification, deduplication, and worker logic.

use bloom_cloud_backend::workers::webhook::{
    compute_hmac_sha256_hex, parse_github_pr_payload, parse_github_push_payload,
    verify_github_signature, verify_webhook_delivery, WebhookBranchPolicy, WebhookDeduplicator,
    WebhookError, WebhookProvider, HEADER_GITHUB_DELIVERY, HEADER_HUB_SIGNATURE_256,
};

#[test]
fn test_hmac_sha256_rfc4231_standard_vectors() {
    // RFC 4231 Test Case 1
    let key1 = [0x0b; 20];
    let data1 = b"Hi There";
    let expected1 = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7";
    assert_eq!(compute_hmac_sha256_hex(&key1, data1), expected1);

    // RFC 4231 Test Case 2 ("Jefe")
    let key2 = b"Jefe";
    let data2 = b"what do ya want for nothing?";
    let expected2 = "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843";
    assert_eq!(compute_hmac_sha256_hex(key2, data2), expected2);

    // RFC 4231 Test Case 3
    let key3 = [0xaa; 20];
    let data3 = [0xdd; 50];
    // Verified against openssl:
    //   printf '\xdd'*50 | openssl dgst -sha256 -mac HMAC -macopt hexkey:aa*20
    let expected3 = "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe";
    assert_eq!(compute_hmac_sha256_hex(&key3, &data3), expected3);
}

#[test]
fn test_github_signature_verification_success() {
    let secret = b"bloom_test_webhook_secret_key_12345";
    let payload = br#"{"ref":"refs/heads/main","after":"abc123commit456"}"#;

    // Real computed HMAC over the exact payload bytes
    let computed_hex = compute_hmac_sha256_hex(secret, payload);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_github_signature(secret, payload, &signature_header);
    assert_eq!(result, Ok(true));
}

#[test]
fn test_github_signature_tampered_body_fails() {
    let secret = b"bloom_test_webhook_secret_key_12345";
    let original_payload = br#"{"ref":"refs/heads/main","after":"abc123commit456"}"#;
    let tampered_payload = br#"{"ref":"refs/heads/main","after":"hacked_commit"}"#;

    let computed_hex = compute_hmac_sha256_hex(secret, original_payload);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_github_signature(secret, tampered_payload, &signature_header);
    assert_eq!(result, Ok(false));
}

#[test]
fn test_github_signature_wrong_secret_fails() {
    let correct_secret = b"correct_secret_value";
    let wrong_secret = b"wrong_secret_value";
    let payload = br#"{"action":"opened","number":10}"#;

    let computed_hex = compute_hmac_sha256_hex(correct_secret, payload);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_github_signature(wrong_secret, payload, &signature_header);
    assert_eq!(result, Ok(false));
}

#[test]
fn test_github_signature_missing_prefix_fails() {
    let secret = b"secret_key";
    let payload = b"payload_bytes";
    let computed_hex = compute_hmac_sha256_hex(secret, payload);

    // Missing "sha256=" prefix
    let result = verify_github_signature(secret, payload, &computed_hex);
    assert!(matches!(
        result,
        Err(WebhookError::InvalidSignatureFormat(_))
    ));
}

#[test]
fn test_github_signature_empty_secret_fails() {
    let empty_secret = b"";
    let payload = b"payload_bytes";
    let result = verify_github_signature(empty_secret, payload, "sha256=abcdef");
    assert!(matches!(result, Err(WebhookError::MissingSecret(_))));
}

#[test]
fn test_verify_webhook_delivery_unverified_providers_rejected() {
    let secret = "some_secret";
    let payload = b"{}";
    let sig = "sha256=1234";

    // GitLab is unverified -> rejected with UnverifiedProvider error
    let gitlab_res =
        verify_webhook_delivery(WebhookProvider::GitLab, Some(secret), payload, Some(sig));
    match gitlab_res {
        Err(WebhookError::UnverifiedProvider(msg)) => {
            assert!(msg.contains("GitLab webhook signature scheme is unverified"));
        }
        other => panic!("Expected Err(UnverifiedProvider), got: {:?}", other),
    }

    // GitLab with None signature header is also rejected with UnverifiedProvider
    let gitlab_no_sig =
        verify_webhook_delivery(WebhookProvider::GitLab, Some(secret), payload, None);
    assert!(matches!(
        gitlab_no_sig,
        Err(WebhookError::UnverifiedProvider(_))
    ));

    // Bitbucket is unverified -> rejected with UnverifiedProvider error
    let bitbucket_res =
        verify_webhook_delivery(WebhookProvider::BitBucket, Some(secret), payload, Some(sig));
    match bitbucket_res {
        Err(WebhookError::UnverifiedProvider(msg)) => {
            assert!(msg.contains("Bitbucket webhook signature scheme is unverified"));
        }
        other => panic!("Expected Err(UnverifiedProvider), got: {:?}", other),
    }

    // Bitbucket with invalid/missing signature is also rejected with UnverifiedProvider
    let bitbucket_no_sig =
        verify_webhook_delivery(WebhookProvider::BitBucket, Some(secret), payload, None);
    assert!(matches!(
        bitbucket_no_sig,
        Err(WebhookError::UnverifiedProvider(_))
    ));
}

#[test]
fn test_github_invalid_signature_is_rejected() {
    let _secret = b"bloom_test_webhook_secret_key_12345";
    let payload = br#"{"ref":"refs/heads/main","after":"abc123commit456"}"#;

    // Bad signature string
    let bad_sig = "sha256=0000000000000000000000000000000000000000000000000000000000000000";
    let res = verify_webhook_delivery(
        WebhookProvider::GitHub,
        Some("bloom_test_webhook_secret_key_12345"),
        payload,
        Some(bad_sig),
    );
    assert!(matches!(res, Err(WebhookError::SignatureMismatch(_))));

    // Missing signature header on GitHub
    let res_missing_sig = verify_webhook_delivery(
        WebhookProvider::GitHub,
        Some("bloom_test_webhook_secret_key_12345"),
        payload,
        None,
    );
    assert!(matches!(
        res_missing_sig,
        Err(WebhookError::MissingSignature(_))
    ));
}

#[tokio::test]
async fn test_webhook_deduplicator_idempotency() {
    let deduplicator = WebhookDeduplicator::new();
    let delivery_guid = "7d8f4c2e-1111-4444-8888-abcdef012345";

    // First arrival: recorded successfully (new)
    let is_new = deduplicator.record_if_new(delivery_guid).await;
    assert!(is_new);
    assert!(deduplicator.is_recorded(delivery_guid).await);

    // Replay arrival: detected as duplicate (not new)
    let is_replay_new = deduplicator.record_if_new(delivery_guid).await;
    assert!(!is_replay_new);

    // Different delivery ID: recorded successfully
    let other_guid = "99999999-2222-3333-4444-555555555555";
    assert!(deduplicator.record_if_new(other_guid).await);
}

#[test]
fn test_branch_policy_matching() {
    let exact_policy = WebhookBranchPolicy {
        pattern: "main".to_string(),
        environment: "env-prod".to_string(),
        auto_deploy: true,
        preview: false,
    };
    assert!(exact_policy.matches_branch("main"));
    assert!(!exact_policy.matches_branch("staging"));
    assert!(!exact_policy.matches_branch("main-fix"));

    let wildcard_policy = WebhookBranchPolicy {
        pattern: "feature/*".to_string(),
        environment: "env-dev".to_string(),
        auto_deploy: false,
        preview: true,
    };
    assert!(wildcard_policy.matches_branch("feature/login"));
    assert!(wildcard_policy.matches_branch("feature/dark-mode"));
    assert!(!wildcard_policy.matches_branch("bugfix/login"));

    let catch_all_policy = WebhookBranchPolicy {
        pattern: "*".to_string(),
        environment: "env-preview".to_string(),
        auto_deploy: false,
        preview: true,
    };
    assert!(catch_all_policy.matches_branch("anything"));
    assert!(catch_all_policy.matches_branch("release-1.0"));
}

#[test]
fn test_parse_github_push_payload() {
    let payload = serde_json::json!({
        "ref": "refs/heads/release/v1.0",
        "after": "11223344556677889900aabbccddeeff11223344",
        "repository": {
            "full_name": "bloom-org/flutter-app"
        }
    });

    let (repo, branch, commit) =
        parse_github_push_payload(&payload).expect("parse valid push payload");
    assert_eq!(repo, "bloom-org/flutter-app");
    assert_eq!(branch, "release/v1.0");
    assert_eq!(commit, "11223344556677889900aabbccddeeff11223344");
}

#[test]
fn test_parse_github_pr_payload() {
    let payload = serde_json::json!({
        "action": "opened",
        "pull_request": {
            "number": 42,
            "head": {
                "sha": "deadbeefcafebabe1234567890abcdef12345678"
            }
        },
        "repository": {
            "full_name": "bloom-org/mobile-client"
        }
    });

    let (repo, pr_num, action, commit) =
        parse_github_pr_payload(&payload).expect("parse valid PR payload");
    assert_eq!(repo, "bloom-org/mobile-client");
    assert_eq!(pr_num, 42);
    assert_eq!(action, "opened");
    assert_eq!(commit, "deadbeefcafebabe1234567890abcdef12345678");
}

#[test]
fn test_webhook_header_constants() {
    assert_eq!(HEADER_GITHUB_DELIVERY, "X-GitHub-Delivery");
    assert_eq!(HEADER_HUB_SIGNATURE_256, "X-Hub-Signature-256");
}
