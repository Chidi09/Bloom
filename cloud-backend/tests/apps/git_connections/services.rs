use bloom_cloud_backend::apps::git_connections::errors::GitConnectionError;
use bloom_cloud_backend::apps::git_connections::services::{
    compute_hmac_sha256, verify_github_signature, ALLOWED_PROVIDERS,
};
use bloom_cloud_backend::infra::crypto::Crypto;

#[test]
fn test_allowed_providers_list() {
    assert!(ALLOWED_PROVIDERS.contains(&"github"));
    assert!(ALLOWED_PROVIDERS.contains(&"gitlab"));
    assert!(ALLOWED_PROVIDERS.contains(&"bitbucket"));
}

#[test]
fn test_hmac_sha256_rfc_standard_test_vectors() {
    // RFC 4231 Test Case 1
    let key1 = [0x0bu8; 20];
    let data1 = b"Hi There";
    let digest1 = compute_hmac_sha256(&key1, data1);
    assert_eq!(
        digest1,
        "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
    );

    // RFC 4231 Test Case 2
    let key2 = b"Jefe";
    let data2 = b"what do ya want for nothing?";
    let digest2 = compute_hmac_sha256(key2, data2);
    assert_eq!(
        digest2,
        "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
    );

    // RFC 4231 Test Case 3
    let key3 = [0xaau8; 20];
    let data3 = [0xddu8; 50];
    let digest3 = compute_hmac_sha256(&key3, &data3);
    assert_eq!(
        digest3,
        // Verified against openssl:
        //   printf '\xdd'*50 | openssl dgst -sha256 -mac HMAC -macopt hexkey:aa*20
        "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"
    );
}

#[test]
fn test_github_signature_verification_known_good() {
    let secret = "bloom_super_secret_webhook_key_2026";
    let body = br#"{"ref":"refs/heads/main","after":"0000000000000000000000000000000000000000"}"#;

    let computed_hex = compute_hmac_sha256(secret.as_bytes(), body);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_github_signature(secret, Some(&signature_header), body);
    assert!(result.is_ok(), "Known-good signature must verify");
}

#[test]
fn test_github_signature_verification_tampered_body() {
    let secret = "bloom_super_secret_webhook_key_2026";
    let body = br#"{"ref":"refs/heads/main","after":"0000000000000000000000000000000000000000"}"#;
    let tampered_body =
        br#"{"ref":"refs/heads/main","after":"1111111111111111111111111111111111111111"}"#;

    let computed_hex = compute_hmac_sha256(secret.as_bytes(), body);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_github_signature(secret, Some(&signature_header), tampered_body);
    assert_eq!(result, Err(GitConnectionError::InvalidSignature));
}

#[test]
fn test_github_signature_verification_wrong_secret() {
    let actual_secret = "bloom_actual_secret";
    let wrong_secret = "bloom_wrong_secret";
    let body = br#"{"action":"opened","number":42}"#;

    let computed_hex = compute_hmac_sha256(actual_secret.as_bytes(), body);
    let signature_header = format!("sha256={computed_hex}");

    let result = verify_github_signature(wrong_secret, Some(&signature_header), body);
    assert_eq!(result, Err(GitConnectionError::InvalidSignature));
}

#[test]
fn test_github_signature_verification_missing_and_empty_signature() {
    let secret = "bloom_secret";
    let body = b"test payload";

    assert_eq!(
        verify_github_signature(secret, None, body),
        Err(GitConnectionError::MissingSignature)
    );
    assert_eq!(
        verify_github_signature(secret, Some(""), body),
        Err(GitConnectionError::MissingSignature)
    );
    assert_eq!(
        verify_github_signature(secret, Some("   "), body),
        Err(GitConnectionError::MissingSignature)
    );
}

#[test]
fn test_github_signature_verification_missing_secret() {
    let body = b"test payload";
    let sig = "sha256=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";

    assert_eq!(
        verify_github_signature("", Some(sig), body),
        Err(GitConnectionError::MissingSecret)
    );
    assert_eq!(
        verify_github_signature("   ", Some(sig), body),
        Err(GitConnectionError::MissingSecret)
    );
}

#[test]
fn test_github_signature_verification_prefix_required() {
    let secret = "bloom_secret";
    let body = b"test payload";
    let raw_hex = compute_hmac_sha256(secret.as_bytes(), body);

    // Missing "sha256=" prefix
    let result = verify_github_signature(secret, Some(&raw_hex), body);
    assert_eq!(result, Err(GitConnectionError::InvalidSignatureFormat));

    // Wrong prefix
    let wrong_prefix = format!("sha1={raw_hex}");
    let result = verify_github_signature(secret, Some(&wrong_prefix), body);
    assert_eq!(result, Err(GitConnectionError::InvalidSignatureFormat));
}

#[test]
fn test_encryption_and_decryption_token_roundtrip() {
    let hex_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    let _ = Crypto::init(hex_key);

    let raw_token = "ghp_1234567890abcdefghijklmnopqrstuvwxyzABCD";
    let ciphertext = Crypto::encrypt(raw_token).unwrap();
    assert!(ciphertext.starts_with("v1:"));
    assert!(!ciphertext.contains("ghp_1234567890"));

    let decrypted = Crypto::decrypt(&ciphertext).unwrap();
    assert_eq!(decrypted, raw_token);
}

// -----------------------------------------------------------------------------
// Bitbucket Cloud Signature Verification Tests
// -----------------------------------------------------------------------------

#[test]
fn test_bitbucket_signature_verification_success() {
    let secret = "bitbucket_webhook_secret_key_98765";
    let body =
        br#"{"push":{"changes":[{"new":{"name":"main","target":{"hash":"abcd1234ef56"}}}]}}"#;

    let computed_hex = compute_hmac_sha256(secret.as_bytes(), body);
    let signature_header = format!("sha256={computed_hex}");

    let result = bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
        secret,
        Some(&signature_header),
        body,
    );
    assert!(result.is_ok(), "Known-good Bitbucket signature must verify");
}

#[test]
fn test_bitbucket_signature_verification_tampered_body() {
    let secret = "bitbucket_webhook_secret_key_98765";
    let body =
        br#"{"push":{"changes":[{"new":{"name":"main","target":{"hash":"abcd1234ef56"}}}]}}"#;
    let tampered_body =
        br#"{"push":{"changes":[{"new":{"name":"main","target":{"hash":"abcd1234ef57"}}}]}}"#;

    let computed_hex = compute_hmac_sha256(secret.as_bytes(), body);
    let signature_header = format!("sha256={computed_hex}");

    let result = bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
        secret,
        Some(&signature_header),
        tampered_body,
    );
    assert_eq!(result, Err(GitConnectionError::InvalidSignature));
}

#[test]
fn test_bitbucket_signature_verification_wrong_secret() {
    let secret = "bitbucket_correct_secret";
    let wrong_secret = "bitbucket_wrong_secret";
    let body = br#"{"event":"repo:push"}"#;

    let computed_hex = compute_hmac_sha256(secret.as_bytes(), body);
    let signature_header = format!("sha256={computed_hex}");

    let result = bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
        wrong_secret,
        Some(&signature_header),
        body,
    );
    assert_eq!(result, Err(GitConnectionError::InvalidSignature));
}

#[test]
fn test_bitbucket_signature_missing_header_strictly_rejected() {
    // *** Critical Security Detail: Bitbucket Cloud does NOT sign by default and omits X-Hub-Signature
    // when no secret is configured. Missing signature headers MUST be treated as REJECT. ***
    let secret = "bitbucket_secret";
    let body = b"test payload";

    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
            secret, None, body,
        ),
        Err(GitConnectionError::MissingSignature)
    );
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
            secret,
            Some(""),
            body,
        ),
        Err(GitConnectionError::MissingSignature)
    );
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
            secret,
            Some("   "),
            body,
        ),
        Err(GitConnectionError::MissingSignature)
    );
}

#[test]
fn test_bitbucket_signature_malformed_format_rejected() {
    let secret = "bitbucket_secret";
    let body = b"test payload";
    let raw_hex = compute_hmac_sha256(secret.as_bytes(), body);

    // Missing "sha256=" prefix
    let result = bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
        secret,
        Some(&raw_hex),
        body,
    );
    assert_eq!(result, Err(GitConnectionError::InvalidSignatureFormat));

    // Wrong prefix
    let wrong_prefix = format!("sha1={raw_hex}");
    let result = bloom_cloud_backend::apps::git_connections::services::verify_bitbucket_signature(
        secret,
        Some(&wrong_prefix),
        body,
    );
    assert_eq!(result, Err(GitConnectionError::InvalidSignatureFormat));
}

// -----------------------------------------------------------------------------
// GitLab Signature Verification Tests
// -----------------------------------------------------------------------------

#[test]
fn test_gitlab_legacy_token_verification() {
    let secret = "gitlab_legacy_secret_token_abc123";
    let wrong_token = "wrong_token";

    // Match accepted
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_legacy_token(
            secret,
            Some(secret),
        ),
        Ok(())
    );

    // Mismatch rejected in constant time
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_legacy_token(
            secret,
            Some(wrong_token),
        ),
        Err(GitConnectionError::InvalidSignature)
    );

    // Missing token rejected
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_legacy_token(
            secret, None,
        ),
        Err(GitConnectionError::MissingSignature)
    );

    // Missing secret rejected
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_legacy_token(
            "",
            Some(secret),
        ),
        Err(GitConnectionError::MissingSecret)
    );
}

#[test]
fn test_gitlab_standard_signature_verification_success() {
    use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
    use base64::Engine as _;
    use chrono::Utc;

    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_gitlab_123456";
    let now_ts = Utc::now().timestamp();
    let ts_str = now_ts.to_string();
    let body = br#"{"event_name":"push","ref":"refs/heads/main"}"#;

    // String to sign: "{webhook-id}.{webhook-timestamp}.{raw_body}"
    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(ts_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(body);

    let digest_b64 =
        bloom_cloud_backend::apps::git_connections::services::compute_hmac_sha256_base64(
            raw_key, &to_sign,
        )
        .unwrap();
    let signature_header = format!("v1,{digest_b64}");

    let result =
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_standard_signature(
            &secret,
            Some(webhook_id),
            Some(&ts_str),
            Some(&signature_header),
            body,
        );
    assert_eq!(result, Ok(()));
}

#[test]
fn test_gitlab_standard_signature_tampered_body() {
    use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
    use base64::Engine as _;
    use chrono::Utc;

    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_gitlab_123456";
    let ts_str = Utc::now().timestamp().to_string();
    let body = br#"{"event_name":"push","ref":"refs/heads/main"}"#;
    let tampered_body = br#"{"event_name":"push","ref":"refs/heads/hack"}"#;

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(ts_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(body);

    let digest_b64 =
        bloom_cloud_backend::apps::git_connections::services::compute_hmac_sha256_base64(
            raw_key, &to_sign,
        )
        .unwrap();
    let signature_header = format!("v1,{digest_b64}");

    let result =
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_standard_signature(
            &secret,
            Some(webhook_id),
            Some(&ts_str),
            Some(&signature_header),
            tampered_body,
        );
    assert_eq!(result, Err(GitConnectionError::InvalidSignature));
}

#[test]
fn test_gitlab_standard_signature_rotation_multi_signature() {
    use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
    use base64::Engine as _;
    use chrono::Utc;

    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_rot_999";
    let ts_str = Utc::now().timestamp().to_string();
    let body = br#"{"event_name":"push"}"#;

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(ts_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(body);

    let valid_b64 =
        bloom_cloud_backend::apps::git_connections::services::compute_hmac_sha256_base64(
            raw_key, &to_sign,
        )
        .unwrap();
    let valid_sig = format!("v1,{valid_b64}");
    let stale_sig = "v1,c3RhbGVfc2lnbmF0dXJlX2Zvcl9yb3RhdGlvbl90ZXN0";

    // Multi-signature header: stale key first, valid key second
    let multi_sig_header = format!("{stale_sig} {valid_sig}");

    let result =
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_standard_signature(
            &secret,
            Some(webhook_id),
            Some(&ts_str),
            Some(&multi_sig_header),
            body,
        );
    assert_eq!(result, Ok(()));
}

#[test]
fn test_gitlab_standard_signature_stale_timestamp_rejected() {
    use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
    use base64::Engine as _;
    use chrono::Utc;

    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_stale_999";
    // 10 minutes ago (> 5 minutes tolerance)
    let stale_ts = (Utc::now().timestamp() - 600).to_string();
    let body = br#"{"event_name":"push"}"#;

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(stale_ts.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(body);

    let valid_b64 =
        bloom_cloud_backend::apps::git_connections::services::compute_hmac_sha256_base64(
            raw_key, &to_sign,
        )
        .unwrap();
    let valid_sig = format!("v1,{valid_b64}");

    let result =
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_standard_signature(
            &secret,
            Some(webhook_id),
            Some(&stale_ts),
            Some(&valid_sig),
            body,
        );
    assert_eq!(
        result,
        Err(GitConnectionError::InvalidSignature),
        "Stale timestamp must be rejected for replay protection"
    );
}

#[test]
fn test_gitlab_webhook_headers_dispatch() {
    use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
    use base64::Engine as _;
    use chrono::Utc;

    let raw_key = b"01234567890123456789012345678901";
    let key_b64 = BASE64_STANDARD.encode(raw_key);
    let standard_secret = format!("whsec_{key_b64}");

    let webhook_id = "msg_dispatch_1";
    let ts_str = Utc::now().timestamp().to_string();
    let body = br#"{"event_name":"push"}"#;

    let mut to_sign = Vec::new();
    to_sign.extend_from_slice(webhook_id.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(ts_str.as_bytes());
    to_sign.push(b'.');
    to_sign.extend_from_slice(body);

    let valid_b64 =
        bloom_cloud_backend::apps::git_connections::services::compute_hmac_sha256_base64(
            raw_key, &to_sign,
        )
        .unwrap();
    let valid_sig = format!("v1,{valid_b64}");

    // Standard headers
    let standard_headers =
        bloom_cloud_backend::apps::git_connections::services::GitLabWebhookHeaders {
            token: None,
            webhook_id: Some(webhook_id),
            webhook_timestamp: Some(&ts_str),
            webhook_signature: Some(&valid_sig),
            event_type: Some("push"),
            delivery_id: Some(webhook_id),
        };
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_webhook(
            &standard_secret,
            &standard_headers,
            body,
        ),
        Ok(())
    );

    // Legacy headers
    let legacy_secret = "legacy_secret_value";
    let legacy_headers =
        bloom_cloud_backend::apps::git_connections::services::GitLabWebhookHeaders {
            token: Some(legacy_secret),
            webhook_id: None,
            webhook_timestamp: None,
            webhook_signature: None,
            event_type: Some("push"),
            delivery_id: None,
        };
    assert_eq!(
        bloom_cloud_backend::apps::git_connections::services::verify_gitlab_webhook(
            legacy_secret,
            &legacy_headers,
            body,
        ),
        Ok(())
    );
}
