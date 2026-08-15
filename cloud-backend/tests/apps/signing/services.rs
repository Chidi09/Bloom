use bloom_cloud_backend::apps::signing::contracts::{
    SigningIdentityCreateRequest, SigningIdentityMetadata,
};
use bloom_cloud_backend::apps::signing::models::SigningIdentity;
use bloom_cloud_backend::apps::signing::serializers::{
    is_identity_expiring, serialize_signing_identity,
};
use bloom_cloud_backend::apps::signing::services::{
    redact_signing_snapshot, validate_signing_request,
};
use bloom_cloud_backend::infra::crypto::Crypto;
use chrono::{Duration, Utc};
use djangors_orm::ForeignKey;

#[test]
fn test_validate_signing_request_valid() {
    let req = SigningIdentityCreateRequest {
        platform: "android".to_string(),
        name: "Release Keystore".to_string(),
        kind: "keystore".to_string(),
        material: "dGVzdC1rZXlzdG9yZS1jb250ZW50".to_string(),
        metadata: SigningIdentityMetadata::Keystore {
            alias: "upload".to_string(),
        },
        expires_at: Some("2030-01-01T00:00:00Z".to_string()),
    };

    let result = validate_signing_request(&req);
    assert!(result.is_ok());
    let validated = result.unwrap();
    assert_eq!(validated.platform, "android");
    assert_eq!(validated.name, "Release Keystore");
    assert_eq!(validated.kind, "keystore");
    assert!(validated.metadata.contains("\"alias\":\"upload\""));
    assert!(validated.expires_at.is_some());
}

#[test]
fn test_validate_signing_request_mismatch_and_invalid() {
    // Platform invalid
    let mut req = SigningIdentityCreateRequest {
        platform: "windows".to_string(),
        name: "Windows Cert".to_string(),
        kind: "certificate".to_string(),
        material: "dGVzdA==".to_string(),
        metadata: SigningIdentityMetadata::Certificate {
            fingerprint: "AA:BB:CC".to_string(),
        },
        expires_at: None,
    };
    assert!(validate_signing_request(&req).is_err());

    // Kind mismatch with metadata variant
    req.platform = "ios".to_string();
    req.kind = "keystore".to_string(); // metadata is Certificate
    assert!(validate_signing_request(&req).is_err());

    // Empty material
    req.kind = "certificate".to_string();
    req.material = "   ".to_string();
    assert!(validate_signing_request(&req).is_err());
}

#[test]
fn test_crypto_signing_material_encryption_and_decryption() {
    let hex_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    let _ = Crypto::init(hex_key);

    let raw_keystore_base64 =
        "MIIJfgIBAzCCCX8GCSqGSIb3DQEHAaCCCXAEgglsMIIJaDCCBfcGCSqGSIb3DQEHBqCCBe";
    let encrypted = Crypto::encrypt(raw_keystore_base64).expect("Encryption must succeed");

    assert!(encrypted.starts_with("v1:"));
    assert_ne!(encrypted, raw_keystore_base64);
    assert!(!encrypted.contains(raw_keystore_base64));

    let decrypted = Crypto::decrypt(&encrypted).expect("Decryption must succeed");
    assert_eq!(decrypted, raw_keystore_base64);
}

#[test]
fn test_audit_snapshot_redacts_signing_material() {
    let now = Utc::now();
    let identity = SigningIdentity {
        id: 10,
        public_id: "sign-uuid-1111".to_string(),
        organization_id: ForeignKey::new(5),
        platform: "ios".to_string(),
        name: "Distribution Cert".to_string(),
        kind: "certificate".to_string(),
        encrypted_material: "v1:supersecretencryptedmaterial==".to_string(),
        metadata: r#"{"kind":"certificate","fingerprint":"12:34:56:78"}"#.to_string(),
        expires_at: Some(now + Duration::days(60)),
        created_at: now,
        updated_at: now,
    };

    let snapshot = redact_signing_snapshot(&identity, "org-uuid-5555");
    let json_str = snapshot.to_string();

    assert!(json_str.contains("\"id\":\"sign-uuid-1111\""));
    assert!(json_str.contains("\"organization_id\":\"org-uuid-5555\""));
    assert!(json_str.contains("\"platform\":\"ios\""));
    assert!(json_str.contains("\"material\":\"[REDACTED]\""));
    assert!(!json_str.contains("supersecretencryptedmaterial"));
}

#[test]
fn test_expiry_warning_threshold() {
    let now = Utc::now();

    // Expired
    assert!(is_identity_expiring(Some(now - Duration::days(1))));

    // Expiring in 10 days (< 30 days) -> warning true
    assert!(is_identity_expiring(Some(now + Duration::days(10))));

    // Expiring in 29 days (< 30 days) -> warning true
    assert!(is_identity_expiring(Some(now + Duration::days(29))));

    // Expiring in 90 days (> 30 days) -> warning false
    assert!(!is_identity_expiring(Some(now + Duration::days(90))));

    // No expiry -> warning false
    assert!(!is_identity_expiring(None));
}

#[test]
fn test_no_raw_secret_in_serialized_response() {
    let now = Utc::now();
    let raw_secret_material = "PRIVATE_KEY_BYTES_OR_BASE64_MATERIAL_ABC123";
    let encrypted =
        Crypto::encrypt(raw_secret_material).unwrap_or_else(|_| "v1:dummyciphertext".to_string());

    let identity = SigningIdentity {
        id: 77,
        public_id: "sign-pub-uuid-8888".to_string(),
        organization_id: ForeignKey::new(12),
        platform: "ios".to_string(),
        name: "App Store Connect API Key".to_string(),
        kind: "api_key".to_string(),
        encrypted_material: encrypted,
        metadata:
            r#"{"kind":"api_key","key_id":"KEY123","issuer_id":"ISS456","team_id":"TEAM789"}"#
                .to_string(),
        expires_at: Some(now + Duration::days(15)),
        created_at: now,
        updated_at: now,
    };

    let response = serialize_signing_identity(&identity, "org-uuid-9999");
    let json_bytes = serde_json::to_vec(&response).unwrap();
    let json_str = String::from_utf8(json_bytes).unwrap();

    // Verify metadata is included
    assert!(json_str.contains("\"id\":\"sign-pub-uuid-8888\""));
    assert!(json_str.contains("\"organization_id\":\"org-uuid-9999\""));
    assert!(json_str.contains("\"key_id\":\"KEY123\""));
    assert!(json_str.contains("\"is_expiring\":true"));

    // Verify secret / ciphertext never appears in serialized JSON
    assert!(!json_str.contains(raw_secret_material));
    assert!(!json_str.contains("encrypted_material"));
    assert!(!json_str.contains("v1:"));
    assert!(!json_str.contains("public_id"));
}
