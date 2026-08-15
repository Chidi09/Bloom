use bloom_cloud_backend::apps::credentials::contracts::CredentialMetadata;
use bloom_cloud_backend::apps::credentials::services::{
    validate_provider_and_metadata, ALLOWED_PROVIDERS,
};
use bloom_cloud_backend::infra::crypto::Crypto;

#[test]
fn test_allowed_providers_list() {
    assert!(ALLOWED_PROVIDERS.contains(&"apple"));
    assert!(ALLOWED_PROVIDERS.contains(&"google_play"));
    assert!(ALLOWED_PROVIDERS.contains(&"shorebird"));
    assert!(ALLOWED_PROVIDERS.contains(&"github"));
    assert!(ALLOWED_PROVIDERS.contains(&"gitlab"));
    assert!(ALLOWED_PROVIDERS.contains(&"bitbucket"));
}

#[test]
fn test_validate_provider_and_metadata_apple() {
    let meta = CredentialMetadata::Apple {
        key_id: "KEY123".to_string(),
        issuer_id: "ISSUER123".to_string(),
        team_id: "TEAM123".to_string(),
    };
    let json_str = validate_provider_and_metadata("apple", &meta).unwrap();
    assert!(json_str.contains("KEY123"));
    assert!(json_str.contains("ISSUER123"));
    assert!(json_str.contains("TEAM123"));

    // Invalid Apple metadata
    let invalid_meta = CredentialMetadata::Apple {
        key_id: "".to_string(),
        issuer_id: "ISSUER".to_string(),
        team_id: "TEAM".to_string(),
    };
    assert!(validate_provider_and_metadata("apple", &invalid_meta).is_err());
}

#[test]
fn test_validate_provider_and_metadata_google_play() {
    let meta = CredentialMetadata::GooglePlay {
        client_email: "service-account@bloom.iam.gserviceaccount.com".to_string(),
    };
    let json_str = validate_provider_and_metadata("google_play", &meta).unwrap();
    assert!(json_str.contains("service-account@bloom.iam.gserviceaccount.com"));

    // Invalid email
    let invalid_meta = CredentialMetadata::GooglePlay {
        client_email: "not-an-email".to_string(),
    };
    assert!(validate_provider_and_metadata("google_play", &invalid_meta).is_err());
}

#[test]
fn test_validate_provider_and_metadata_mismatch() {
    let meta = CredentialMetadata::Shorebird {
        app_id: "app-uuid".to_string(),
    };
    assert!(validate_provider_and_metadata("apple", &meta).is_err());
}

#[test]
fn test_encryption_and_decryption_roundtrip() {
    let hex_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    let _ = Crypto::init(hex_key);

    let raw_secret = "AuthKey_ABC12345XYZ-----BEGIN PRIVATE KEY-----";
    let ciphertext = Crypto::encrypt(raw_secret).unwrap();
    assert!(ciphertext.starts_with("v1:"));
    assert!(!ciphertext.contains("AuthKey_ABC12345XYZ"));

    let decrypted = Crypto::decrypt(&ciphertext).unwrap();
    assert_eq!(decrypted, raw_secret);
}
