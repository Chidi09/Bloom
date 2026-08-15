use bloom_cloud_backend::apps::secrets::contracts::{
    SecretCreateRequest, SecretRollbackRequest, SecretUpdateRequest,
};
use bloom_cloud_backend::apps::secrets::models::Secret;
use bloom_cloud_backend::apps::secrets::services::{redact_secret_snapshot, validate_key_format};
use bloom_cloud_backend::infra::crypto::Crypto;
use chrono::Utc;
use djangors_orm::ForeignKey;

#[test]
fn test_validate_key_format_valid_keys() {
    assert!(validate_key_format("DATABASE_URL").is_ok());
    assert!(validate_key_format("API_KEY_123").is_ok());
    assert!(validate_key_format("_PRIVATE_KEY").is_ok());
    assert!(validate_key_format("STRIPE_SECRET_KEY").is_ok());
    assert!(validate_key_format("a").is_ok());
    assert!(validate_key_format("_").is_ok());
}

#[test]
fn test_validate_key_format_invalid_keys() {
    // Leading digit rejected
    assert!(validate_key_format("123_KEY").is_err());
    // Empty key rejected
    assert!(validate_key_format("").is_err());
    // Special symbols rejected
    assert!(validate_key_format("KEY-WITH-HYPHEN").is_err());
    assert!(validate_key_format("KEY.WITH.DOT").is_err());
    assert!(validate_key_format("KEY WITH SPACES").is_err());
    assert!(validate_key_format("KEY$SPECIAL").is_err());
    // Key longer than 255 chars rejected
    let long_key = "A".repeat(256);
    assert!(validate_key_format(&long_key).is_err());
}

#[test]
fn test_crypto_encryption_and_decryption_roundtrip() {
    // Initialize crypto engine for unit test with 32-byte hex key
    let hex_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    let _ = Crypto::init(hex_key);

    let raw_secret = "postgres://user:super_secret_password@db.example.com:5432/bloom";
    let encrypted = Crypto::encrypt(raw_secret).expect("Encryption must succeed");

    assert!(encrypted.starts_with("v1:"));
    assert_ne!(encrypted, raw_secret);
    assert!(!encrypted.contains("super_secret_password"));

    let decrypted = Crypto::decrypt(&encrypted).expect("Decryption must succeed");
    assert_eq!(decrypted, raw_secret);
}

#[test]
fn test_audit_snapshot_redacts_values_and_ciphertexts() {
    let secret = Secret {
        id: 42,
        public_id: "sec-uuid-1234".to_string(),
        environment_id: ForeignKey::new(10),
        organization_id: ForeignKey::new(5),
        key: "SENTRY_AUTH_TOKEN".to_string(),
        encrypted_value: "v1:supersecretciphertextbytes==".to_string(),
        is_json: false,
        version: 3,
        created_by_id: 1,
        created_at: Utc::now(),
    };

    let snapshot = redact_secret_snapshot(&secret, "env-uuid-5678");
    let json_str = snapshot.to_string();

    assert!(json_str.contains("\"key\":\"SENTRY_AUTH_TOKEN\""));
    assert!(json_str.contains("\"value\":\"[REDACTED]\""));
    assert!(!json_str.contains("supersecretciphertextbytes"));
}

#[test]
fn test_contract_deserialization_defaults() {
    let create_json = r#"{"environment_id":"env-123","key":"API_KEY","value":"secret-token"}"#;
    let req: SecretCreateRequest = serde_json::from_str(create_json).unwrap();
    assert_eq!(req.key, "API_KEY");
    assert_eq!(req.value, "secret-token");
    assert!(!req.is_json); // defaults to false

    let update_json = r#"{"value":"new-secret-token"}"#;
    let update_req: SecretUpdateRequest = serde_json::from_str(update_json).unwrap();
    assert_eq!(update_req.value, Some("new-secret-token".to_string()));
    assert_eq!(update_req.is_json, None);

    let rollback_json = r#"{"version":2}"#;
    let rollback_req: SecretRollbackRequest = serde_json::from_str(rollback_json).unwrap();
    assert_eq!(rollback_req.version, 2);
}
