//! Unit tests for webhook HMAC-SHA256 signature verification, deduplication, and worker logic.

use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine as _;
use chrono::Utc;

use bloom_cloud_backend::workers::webhook::{
    compute_hmac_sha256_base64, compute_hmac_sha256_hex, parse_bitbucket_pr_payload,
    parse_bitbucket_push_payload, parse_github_pr_payload, parse_github_push_payload,
    parse_gitlab_mr_payload, parse_gitlab_push_payload, parse_provider_push_payload,
    verify_bitbucket_signature, verify_github_signature, verify_gitlab_delivery_full,
    verify_gitlab_legacy_token, verify_gitlab_standard_signature, verify_webhook_delivery,
    WebhookBranchPolicy, WebhookDeduplicator, WebhookError, WebhookProvider,
    GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS, HEADER_BITBUCKET_EVENT, HEADER_BITBUCKET_SIGNATURE,
    HEADER_BITBUCKET_UUID, HEADER_GITHUB_DELIVERY, HEADER_GITHUB_EVENT, HEADER_GITHUB_HOOK_ID,
    HEADER_GITLAB_EVENT, HEADER_GITLAB_TOKEN, HEADER_GITLAB_WEBHOOK_ID,
    HEADER_GITLAB_WEBHOOK_SIGNATURE, HEADER_GITLAB_WEBHOOK_TIMESTAMP, HEADER_HUB_SIGNATURE_256,
};

// -----------------------------------------------------------------------------
// 1. RFC 4231 HMAC-SHA256 Test Vectors
// -----------------------------------------------------------------------------

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
    let expected3 = "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe";
    assert_eq!(compute_hmac_sha256_hex(&key3, &data3), expected3);
}

// -----------------------------------------------------------------------------
// 2. GitHub Signature Verification Tests
// -----------------------------------------------------------------------------

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
    let tampered_payload = br#"{"ref":"refs/heads/main","after":"abc123commit457"}"#;

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

// -----------------------------------------------------------------------------
// 3. Bitbucket Cloud Signature Verification Tests
// -----------------------------------------------------------------------------

#[test]
fn test_bitbucket_signature_verification_success() {
    let secret = b"bitbucket_test_webhook_secret_key_2026";
    let payload = br#"{"push":{"changes":[{"new":{"name":"main","target":{"hash":"11223344"}}}]}}"#;

    let computed_hex = compute_hmac_sha256_hex(secret, payload);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_bitbucket_signature(secret, payload, &signature_header);
    assert_eq!(result, Ok(true));
}

#[test]
fn test_bitbucket_signature_tampered_body_fails() {
    let secret = b"bitbucket_test_webhook_secret_key_2026";
    let original_payload =
        br#"{"push":{"changes":[{"new":{"name":"main","target":{"hash":"11223344"}}}]}}"#;
    let tampered_payload =
        br#"{"push":{"changes":[{"new":{"name":"main","target":{"hash":"11223345"}}}]}}"#;

    let computed_hex = compute_hmac_sha256_hex(secret, original_payload);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_bitbucket_signature(secret, tampered_payload, &signature_header);
    assert_eq!(result, Ok(false));
}

#[test]
fn test_bitbucket_signature_wrong_secret_fails() {
    let correct_secret = b"bitbucket_correct_secret";
    let wrong_secret = b"bitbucket_wrong_secret";
    let payload = br#"{"event":"repo:push"}"#;

    let computed_hex = compute_hmac_sha256_hex(correct_secret, payload);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_bitbucket_signature(wrong_secret, payload, &signature_header);
    assert_eq!(result, Ok(false));
}

#[test]
fn test_bitbucket_signature_missing_header_fails_in_verify_webhook_delivery() {
    // Critical security detail: Bitbucket Cloud omits X-Hub-Signature when no secret is configured.
    // An absent signature header MUST be rejected, never accepted as unverified.
    let secret = "bitbucket_configured_secret";
    let payload = br#"{"event":"repo:push"}"#;

    let result = verify_webhook_delivery(
        WebhookProvider::BitBucket,
        Some(secret),
        payload,
        None, // Missing header
    );

    assert!(matches!(result, Err(WebhookError::MissingSignature(_))));
}

#[test]
fn test_bitbucket_signature_malformed_header_fails() {
    let secret = b"bitbucket_secret";
    let payload = b"some_payload";
    let computed_hex = compute_hmac_sha256_hex(secret, payload);

    // Missing "sha256=" prefix
    let result = verify_bitbucket_signature(secret, payload, &computed_hex);
    assert!(matches!(
        result,
        Err(WebhookError::InvalidSignatureFormat(_))
    ));

    // Wrong prefix
    let wrong_prefix = format!("sha1={computed_hex}");
    let result = verify_bitbucket_signature(secret, payload, &wrong_prefix);
    assert!(matches!(
        result,
        Err(WebhookError::InvalidSignatureFormat(_))
    ));
}

// -----------------------------------------------------------------------------
// 4. GitLab Signature Verification Tests (Legacy & Standard Webhooks)
// -----------------------------------------------------------------------------

#[test]
fn test_gitlab_legacy_token_verification() {
    let secret = "gitlab_legacy_shared_secret_token_123";
    let wrong_token = "wrong_token_value";

    // Matching token accepted
    let res_ok = verify_gitlab_legacy_token(secret, secret);
    assert_eq!(res_ok, Ok(true));

    // Mismatched token rejected in constant time
    let res_fail = verify_gitlab_legacy_token(secret, wrong_token);
    assert_eq!(res_fail, Ok(false));

    // Empty token header rejected
    let res_empty = verify_gitlab_legacy_token(secret, "");
    assert!(matches!(res_empty, Err(WebhookError::MissingSignature(_))));

    // Empty secret rejected
    let res_no_sec = verify_gitlab_legacy_token("", secret);
    assert!(matches!(res_no_sec, Err(WebhookError::MissingSecret(_))));
}

#[test]
fn test_gitlab_standard_signature_verification_success() {
    // 32-byte raw HMAC key encoded in Base64 with "whsec_" prefix
    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_2026_gitlab_uuid_0001";
    let now_ts = Utc::now().timestamp();
    let timestamp_str = now_ts.to_string();
    let payload = br#"{"event_name":"push","project":{"path_with_namespace":"bloom/frontend"}}"#;

    // String to sign: "{webhook-id}.{webhook-timestamp}.{raw_body}"
    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(timestamp_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(payload);

    let expected_b64 = compute_hmac_sha256_base64(raw_key, &to_sign).unwrap();
    let signature_header = format!("v1,{expected_b64}");

    let result = verify_gitlab_standard_signature(
        &secret,
        webhook_id,
        &timestamp_str,
        &signature_header,
        payload,
    );
    assert_eq!(result, Ok(true));
}

#[test]
fn test_gitlab_standard_signature_tampered_body_fails() {
    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_2026_gitlab_uuid_0001";
    let timestamp_str = Utc::now().timestamp().to_string();
    let original_payload = br#"{"event_name":"push","ref":"refs/heads/main"}"#;
    let tampered_payload = br#"{"event_name":"push","ref":"refs/heads/hack"}"#;

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(timestamp_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(original_payload);

    let expected_b64 = compute_hmac_sha256_base64(raw_key, &to_sign).unwrap();
    let signature_header = format!("v1,{expected_b64}");

    let result = verify_gitlab_standard_signature(
        &secret,
        webhook_id,
        &timestamp_str,
        &signature_header,
        tampered_payload,
    );
    assert_eq!(result, Ok(false));
}

#[test]
fn test_gitlab_standard_signature_rotation_multi_signature_accepted() {
    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_rot_123";
    let timestamp_str = Utc::now().timestamp().to_string();
    let payload = br#"{"event_name":"push"}"#;

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(timestamp_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(payload);

    let valid_b64 = compute_hmac_sha256_base64(raw_key, &to_sign).unwrap();
    let valid_sig = format!("v1,{valid_b64}");
    let stale_sig = "v1,dGhpcyBpcyBhbiBvbGQgb3Igb3RoZXIga2V5IHNpZ25hdHVyZQ==";

    // Multi-signature header: stale key signature first, followed by active key signature
    let multi_sig_header = format!("{stale_sig} {valid_sig}");

    let result = verify_gitlab_standard_signature(
        &secret,
        webhook_id,
        &timestamp_str,
        &multi_sig_header,
        payload,
    );
    assert_eq!(
        result,
        Ok(true),
        "Multi-signature header must accept if any candidate matches"
    );
}

#[test]
fn test_gitlab_standard_signature_stale_timestamp_rejected() {
    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_stale_123";
    // 10 minutes ago (> 5 minutes tolerance)
    let stale_ts = (Utc::now().timestamp() - 600).to_string();
    let payload = br#"{"event_name":"push"}"#;

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(stale_ts.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(payload);

    let valid_b64 = compute_hmac_sha256_base64(raw_key, &to_sign).unwrap();
    let signature_header = format!("v1,{valid_b64}");

    let result = verify_gitlab_standard_signature(
        &secret,
        webhook_id,
        &stale_ts,
        &signature_header,
        payload,
    );
    assert!(
        matches!(result, Err(WebhookError::SignatureMismatch(_))),
        "Stale timestamp outside tolerance window must be rejected for replay protection"
    );
}

#[test]
fn test_gitlab_standard_signature_missing_whsec_prefix_fails() {
    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    // Missing "whsec_" prefix
    let secret = key_b64;

    let result = verify_gitlab_standard_signature(
        &secret,
        "id",
        &Utc::now().timestamp().to_string(),
        "v1,sig",
        b"{}",
    );
    assert!(matches!(
        result,
        Err(WebhookError::InvalidSignatureFormat(_))
    ));
}

#[test]
fn test_gitlab_delivery_full_dispatch() {
    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let standard_secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_full_1";
    let ts_str = Utc::now().timestamp().to_string();
    let payload = b"{}";

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(ts_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(payload);

    let sig_b64 = compute_hmac_sha256_base64(raw_key, &to_sign).unwrap();
    let sig_header = format!("v1,{sig_b64}");

    // Standard headers present
    let res_standard = verify_gitlab_delivery_full(
        Some(&standard_secret),
        payload,
        None,
        Some(webhook_id),
        Some(&ts_str),
        Some(&sig_header),
    );
    assert_eq!(res_standard, Ok(()));

    // Legacy token present
    let legacy_secret = "my_legacy_secret";
    let res_legacy = verify_gitlab_delivery_full(
        Some(legacy_secret),
        payload,
        Some(legacy_secret),
        None,
        None,
        None,
    );
    assert_eq!(res_legacy, Ok(()));
}

// -----------------------------------------------------------------------------
// 5. Provider Dispatch via verify_webhook_delivery
// -----------------------------------------------------------------------------

#[test]
fn test_verify_webhook_delivery_all_providers_accepted() {
    let payload = br#"{"ref":"refs/heads/main"}"#;

    // 1. GitHub
    let gh_secret = "gh_secret_12345";
    let gh_hex = compute_hmac_sha256_hex(gh_secret.as_bytes(), payload);
    let gh_sig = format!("sha256={gh_hex}");
    assert_eq!(
        verify_webhook_delivery(
            WebhookProvider::GitHub,
            Some(gh_secret),
            payload,
            Some(&gh_sig)
        ),
        Ok(())
    );

    // 2. Bitbucket
    let bb_secret = "bb_secret_12345";
    let bb_hex = compute_hmac_sha256_hex(bb_secret.as_bytes(), payload);
    let bb_sig = format!("sha256={bb_hex}");
    assert_eq!(
        verify_webhook_delivery(
            WebhookProvider::BitBucket,
            Some(bb_secret),
            payload,
            Some(&bb_sig)
        ),
        Ok(())
    );

    // 3. GitLab Legacy Token
    let gl_secret = "gl_secret_token_12345";
    assert_eq!(
        verify_webhook_delivery(
            WebhookProvider::GitLab,
            Some(gl_secret),
            payload,
            Some(gl_secret)
        ),
        Ok(())
    );
}

// -----------------------------------------------------------------------------
// 6. Deduplication & Idempotency Store Tests
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// 7. Branch Policy Matching Tests
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// 8. Payload Parsing Tests Across Providers
// -----------------------------------------------------------------------------

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
fn test_parse_gitlab_push_payload() {
    let payload = serde_json::json!({
        "ref": "refs/heads/main",
        "after": "9876543210abcdef9876543210abcdef98765432",
        "project": {
            "path_with_namespace": "gitlab-org/bloom-project"
        }
    });

    let (repo, branch, commit) =
        parse_gitlab_push_payload(&payload).expect("parse valid gitlab push payload");
    assert_eq!(repo, "gitlab-org/bloom-project");
    assert_eq!(branch, "main");
    assert_eq!(commit, "9876543210abcdef9876543210abcdef98765432");
}

#[test]
fn test_parse_gitlab_mr_payload() {
    let payload = serde_json::json!({
        "project": {
            "path_with_namespace": "gitlab-org/bloom-project"
        },
        "object_attributes": {
            "id": 99,
            "iid": 12,
            "action": "open",
            "last_commit": {
                "id": "commit1234567890abcdef"
            }
        }
    });

    let (repo, pr_num, action, commit) =
        parse_gitlab_mr_payload(&payload).expect("parse valid gitlab mr payload");
    assert_eq!(repo, "gitlab-org/bloom-project");
    assert_eq!(pr_num, 12);
    assert_eq!(action, "open");
    assert_eq!(commit, "commit1234567890abcdef");
}

#[test]
fn test_parse_bitbucket_push_payload() {
    let payload = serde_json::json!({
        "repository": {
            "full_name": "bitbucket-team/mobile-app"
        },
        "push": {
            "changes": [
                {
                    "new": {
                        "name": "staging",
                        "target": {
                            "hash": "bbcommitsha1234567890"
                        }
                    }
                }
            ]
        }
    });

    let (repo, branch, commit) =
        parse_bitbucket_push_payload(&payload).expect("parse valid bitbucket push payload");
    assert_eq!(repo, "bitbucket-team/mobile-app");
    assert_eq!(branch, "staging");
    assert_eq!(commit, "bbcommitsha1234567890");
}

#[test]
fn test_parse_bitbucket_pr_payload() {
    let payload = serde_json::json!({
        "repository": {
            "full_name": "bitbucket-team/mobile-app"
        },
        "pullrequest": {
            "id": 77,
            "source": {
                "commit": {
                    "hash": "bbheadsha0987654321"
                }
            }
        },
        "action": "created"
    });

    let (repo, pr_num, action, commit) =
        parse_bitbucket_pr_payload(&payload).expect("parse valid bitbucket pr payload");
    assert_eq!(repo, "bitbucket-team/mobile-app");
    assert_eq!(pr_num, 77);
    assert_eq!(action, "created");
    assert_eq!(commit, "bbheadsha0987654321");
}

#[test]
fn test_parse_provider_generic_dispatch() {
    let gh_payload = serde_json::json!({
        "ref": "refs/heads/dev",
        "after": "ghsha123",
        "repository": { "full_name": "org/app" }
    });
    let (repo, branch, commit) =
        parse_provider_push_payload(WebhookProvider::GitHub, &gh_payload).unwrap();
    assert_eq!(repo, "org/app");
    assert_eq!(branch, "dev");
    assert_eq!(commit, "ghsha123");
}

// -----------------------------------------------------------------------------
// 9. Constants Verification Tests
// -----------------------------------------------------------------------------

#[test]
fn test_webhook_header_constants() {
    assert_eq!(HEADER_GITHUB_HOOK_ID, "X-GitHub-Hook-ID");
    assert_eq!(HEADER_GITHUB_EVENT, "X-GitHub-Event");
    assert_eq!(HEADER_GITHUB_DELIVERY, "X-GitHub-Delivery");
    assert_eq!(HEADER_HUB_SIGNATURE_256, "X-Hub-Signature-256");

    assert_eq!(HEADER_GITLAB_TOKEN, "X-Gitlab-Token");
    assert_eq!(HEADER_GITLAB_WEBHOOK_ID, "webhook-id");
    assert_eq!(HEADER_GITLAB_WEBHOOK_TIMESTAMP, "webhook-timestamp");
    assert_eq!(HEADER_GITLAB_WEBHOOK_SIGNATURE, "webhook-signature");
    assert_eq!(HEADER_GITLAB_EVENT, "X-Gitlab-Event");

    assert_eq!(HEADER_BITBUCKET_SIGNATURE, "X-Hub-Signature");
    assert_eq!(HEADER_BITBUCKET_UUID, "X-Request-UUID");
    assert_eq!(HEADER_BITBUCKET_EVENT, "X-Event-Key");

    assert_eq!(GITLAB_WEBHOOK_TIMESTAMP_TOLERANCE_SECONDS, 300);
}
