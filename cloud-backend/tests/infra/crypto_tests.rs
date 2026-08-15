//! Unit tests for cryptographic envelope encryption, key rotation, and token hashing.

use bloom_cloud_backend::infra::crypto::{Crypto, CryptoEngine, CryptoError, CryptoKeyRing};

const TEST_HEX_KEY_1: &str = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
const TEST_HEX_KEY_2: &str = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";

#[test]
fn test_crypto_engine_roundtrip_string() {
    let engine = CryptoEngine::from_hex_key(TEST_HEX_KEY_1).expect("valid hex key");
    let secret = "apple_app_store_connect_private_key_p8_content_12345";

    let ciphertext = engine.encrypt(secret).expect("encryption succeeds");
    assert!(ciphertext.starts_with("v1:"));

    let decrypted = engine.decrypt(&ciphertext).expect("decryption succeeds");
    assert_eq!(decrypted, secret);
}

#[test]
fn test_crypto_engine_roundtrip_binary_and_empty() {
    let engine = CryptoEngine::from_hex_key(TEST_HEX_KEY_1).expect("valid hex key");

    // Empty plaintext
    let empty_bytes = b"";
    let ciphertext_empty = engine.encrypt_bytes(empty_bytes).expect("encrypts empty");
    assert!(ciphertext_empty.starts_with("v1:"));
    let decrypted_empty = engine
        .decrypt_bytes(&ciphertext_empty)
        .expect("decrypts empty");
    assert_eq!(decrypted_empty, empty_bytes);

    // Arbitrary binary bytes (including nulls and non-UTF8 sequences)
    let binary_data = vec![0x00, 0xFF, 0xFE, 0xBA, 0xBE, 0x12, 0x34, 0x56, 0x78];
    let ciphertext_bin = engine.encrypt_bytes(&binary_data).expect("encrypts binary");
    let decrypted_bin = engine
        .decrypt_bytes(&ciphertext_bin)
        .expect("decrypts binary");
    assert_eq!(decrypted_bin, binary_data);
}

#[test]
fn test_random_nonce_uniqueness() {
    let engine = CryptoEngine::from_hex_key(TEST_HEX_KEY_1).expect("valid hex key");
    let plaintext = "identical_plaintext_payload";

    let cipher1 = engine.encrypt(plaintext).expect("encrypt 1");
    let cipher2 = engine.encrypt(plaintext).expect("encrypt 2");

    // Even with identical plaintext and key, ciphertexts must differ due to random nonce
    assert_ne!(cipher1, cipher2);

    // Both must decrypt to the original plaintext
    assert_eq!(engine.decrypt(&cipher1).unwrap(), plaintext);
    assert_eq!(engine.decrypt(&cipher2).unwrap(), plaintext);
}

#[test]
fn test_tampered_ciphertext_rejection() {
    let engine = CryptoEngine::from_hex_key(TEST_HEX_KEY_1).expect("valid hex key");
    let plaintext = "super_sensitive_api_secret_credential";

    let ciphertext = engine.encrypt(plaintext).expect("encryption succeeds");
    let parts: Vec<&str> = ciphertext.splitn(2, ':').collect();
    let version = parts[0];
    let b64 = parts[1];

    let mut raw_bytes = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, b64)
        .expect("valid base64");

    // Flip the last byte of ciphertext/tag
    let len = raw_bytes.len();
    raw_bytes[len - 1] ^= 0x01;

    let tampered_b64 =
        base64::Engine::encode(&base64::engine::general_purpose::STANDARD, &raw_bytes);
    let tampered_ciphertext = format!("{version}:{tampered_b64}");

    let result = engine.decrypt(&tampered_ciphertext);
    assert!(result.is_err());
    match result {
        Err(CryptoError::DecryptionFailed(_)) => {}
        other => panic!("Expected DecryptionFailed, got {:?}", other),
    }
}

#[test]
fn test_key_rotation_multi_version() {
    // Initial Keyring with v1
    let mut keyring = CryptoKeyRing::from_hex(TEST_HEX_KEY_1).expect("valid key 1");
    let engine_v1 = CryptoEngine::new(keyring.clone());

    // Encrypt under v1
    let secret = "rotate_this_secret_value";
    let ciphertext_v1 = engine_v1.encrypt(secret).expect("encrypt v1");
    assert!(ciphertext_v1.starts_with("v1:"));

    // Rotate keys: add v2 and set v2 as primary
    keyring
        .add_hex_key("v2", TEST_HEX_KEY_2)
        .expect("valid key 2");
    keyring.set_primary_version("v2").expect("set primary v2");
    let engine_v2 = CryptoEngine::new(keyring);

    // New encryptions produce v2 prefix
    let ciphertext_v2 = engine_v2.encrypt(secret).expect("encrypt v2");
    assert!(ciphertext_v2.starts_with("v2:"));

    // Engine with rotated keyring can decrypt BOTH v1 and v2 ciphertexts
    let decrypted_old = engine_v2.decrypt(&ciphertext_v1).expect("decrypt old v1");
    let decrypted_new = engine_v2.decrypt(&ciphertext_v2).expect("decrypt new v2");
    assert_eq!(decrypted_old, secret);
    assert_eq!(decrypted_new, secret);

    // Check needs_rotation helper
    assert!(engine_v2.needs_rotation(&ciphertext_v1));
    assert!(!engine_v2.needs_rotation(&ciphertext_v2));
}

#[test]
fn test_unknown_key_version_rejection() {
    let engine = CryptoEngine::from_hex_key(TEST_HEX_KEY_1).expect("valid key");
    let fake_ciphertext = "v99:SGVsbG8gV29ybGQgTm9uY2UgQXV0aCBUYWcgQ2lwaGVy";

    let result = engine.decrypt(fake_ciphertext);
    assert!(matches!(result, Err(CryptoError::UnknownKeyVersion(_))));
}

#[test]
fn test_invalid_format_rejection() {
    let engine = CryptoEngine::from_hex_key(TEST_HEX_KEY_1).expect("valid key");

    // Missing colon prefix
    assert!(matches!(
        engine.decrypt("invalid_no_colon_payload"),
        Err(CryptoError::InvalidFormat(_))
    ));

    // Invalid base64
    assert!(matches!(
        engine.decrypt("v1:not_valid_base64!@#$"),
        Err(CryptoError::InvalidFormat(_))
    ));

    // Truncated payload (shorter than nonce + tag)
    let short_b64 = base64::Engine::encode(&base64::engine::general_purpose::STANDARD, b"short");
    assert!(matches!(
        engine.decrypt(&format!("v1:{short_b64}")),
        Err(CryptoError::InvalidFormat(_))
    ));
}

#[test]
fn test_hash_token_sha256() {
    let token = "bloom_pat_abcdef1234567890";
    let hash = Crypto::hash_token(token);

    // SHA-256 produces 64 hex characters
    assert_eq!(hash.len(), 64);
    // Verified independently: `printf 'bloom_pat_abcdef1234567890' | sha256sum`.
    // The previous constant here was fabricated and had never been executed, because
    // tests/infra/ was not registered in any test target until now.
    assert_eq!(
        hash,
        "d21a6fba5d20b3388cf3eda66f6093d6b819d81e3178d63de99f0635c54f5453"
    );
}

#[test]
fn test_constant_time_equality() {
    let a = b"super_secret_token_1234";
    let b = b"super_secret_token_1234";
    let c = b"super_secret_token_5678";
    let d = b"short";

    assert!(Crypto::constant_time_eq(a, b));
    assert!(!Crypto::constant_time_eq(a, c));
    assert!(!Crypto::constant_time_eq(a, d));

    assert!(Crypto::constant_time_eq_str("secret_abc", "secret_abc"));
    assert!(!Crypto::constant_time_eq_str("secret_abc", "secret_xyz"));
}

#[test]
fn test_invalid_hex_key_handling() {
    // Too short (62 chars instead of 64)
    let short_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd";
    assert!(matches!(
        CryptoKeyRing::from_hex(short_key),
        Err(CryptoError::InvalidKey(_))
    ));

    // Non-hex character
    let bad_char_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdeg";
    assert!(matches!(
        CryptoKeyRing::from_hex(bad_char_key),
        Err(CryptoError::InvalidKey(_))
    ));
}
