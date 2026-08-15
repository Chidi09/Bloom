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
