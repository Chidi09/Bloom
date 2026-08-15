//! AES-256-GCM envelope encryption and token hashing infrastructure.
//!
//! # Security Architecture
//!
//! Every customer secret, platform credential, and signing material in Bloom Cloud
//! is encrypted at rest using AES-256-GCM envelope encryption.
//!
//! ## Ciphertext Wire/Storage Format
//!
//! All ciphertexts adhere to the versioned format:
//!
//! ```text
//! {version_prefix}:{base64_payload}
//! ```
//!
//! Specifically for version 1 (`v1`):
//!
//! ```text
//! v1:{base64(12_byte_nonce || 16_byte_auth_tag || ciphertext)}
//! ```
//!
//! ### Components:
//! 1. **Version Prefix** (`v1:`):
//!    Identifies the encryption key generation used to produce the ciphertext.
//!    Enables seamless zero-downtime key rotation: a future key (`v2:`, `v3:`) can decrypt
//!    older ciphertexts while ensuring new writes use the latest active key generation.
//!
//! 2. **Base64 Payload**:
//!    Standard RFC 4648 Base64 encoded string containing:
//!    - **Nonce** (12 bytes / 96 bits): A cryptographically secure random value generated per encryption
//!      via OS randomness (`rand::rngs::OsRng`). A nonce is NEVER reused or hardcoded.
//!    - **Authentication Tag** (16 bytes / 128 bits): Poly1305 authentication tag computed over the ciphertext.
//!    - **Ciphertext**: AES-256 encrypted plaintext bytes.
//!
//! ## Key Management and Rotation
//!
//! - Master keys are loaded strictly from the environment or typed settings (`ENCRYPTION_KEY` / `BLOOM_ENCRYPTION_KEY`).
//! - Keys are never hardcoded, never logged, and redacted in all `Debug` representations.
//! - A 256-bit key consists of 32 raw bytes (64 hexadecimal characters).
//! - When rotating keys:
//!   - Add the new key as the primary key (e.g. `v2`).
//!   - Keep the old key in the `CryptoKeyRing` (e.g. `v1`).
//!   - Read paths decrypt older `v1:` ciphertexts seamlessly using the `v1` key.
//!   - Write paths immediately produce `v2:` ciphertexts.
//!   - `Crypto::needs_rotation(ciphertext)` indicates if a ciphertext should be re-encrypted on read.
//!
//! ## Log Hygiene
//!
//! Plaintext, raw keys, nonces, and unencrypted credentials MUST NEVER appear in log lines.

use std::collections::HashMap;
use std::fmt;
use std::sync::{Arc, RwLock};

use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine as _;
use rand::rngs::OsRng;
use rand::RngCore;
use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;

/// Length of the AES-256 key in bytes (256 bits = 32 bytes).
pub const KEY_SIZE_BYTES: usize = 32;

/// Length of the AES-GCM nonce in bytes (96 bits = 12 bytes).
pub const NONCE_SIZE_BYTES: usize = 12;

/// Length of the GCM authentication tag in bytes (128 bits = 16 bytes).
pub const TAG_SIZE_BYTES: usize = 16;

/// Default active key version prefix.
pub const CURRENT_VERSION: &str = "v1";

/// Errors originating from the cryptographic infrastructure layer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CryptoError {
    /// The provided key is invalid (e.g., incorrect length, invalid hex string).
    InvalidKey(String),
    /// Encryption failed (e.g., AEAD primitive failure).
    EncryptionFailed(String),
    /// Decryption failed (e.g., authentication tag mismatch, tampered ciphertext).
    DecryptionFailed(String),
    /// The ciphertext string does not match the expected versioned format.
    InvalidFormat(String),
    /// The key version prefix is not recognized or not available in the keyring.
    UnknownKeyVersion(String),
    /// Master encryption key is missing from environment/configuration.
    MissingKey(String),
    /// Decrypted payload is not valid UTF-8 when string decoding was requested.
    Utf8Error(String),
}

impl fmt::Display for CryptoError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CryptoError::InvalidKey(msg) => write!(f, "Invalid encryption key: {msg}"),
            CryptoError::EncryptionFailed(msg) => write!(f, "Encryption failed: {msg}"),
            CryptoError::DecryptionFailed(msg) => {
                write!(
                    f,
                    "Decryption failed (ciphertext may be corrupted or tampered): {msg}"
                )
            }
            CryptoError::InvalidFormat(msg) => write!(f, "Invalid ciphertext format: {msg}"),
            CryptoError::UnknownKeyVersion(ver) => {
                write!(f, "Unknown or unconfigured encryption key version: {ver}")
            }
            CryptoError::MissingKey(msg) => write!(f, "Missing encryption key: {msg}"),
            CryptoError::Utf8Error(msg) => write!(f, "Decrypted data is not valid UTF-8: {msg}"),
        }
    }
}

impl std::error::Error for CryptoError {}

/// In-memory key ring supporting multiple versioned keys for key rotation.
#[derive(Clone)]
pub struct CryptoKeyRing {
    primary_version: String,
    keys: HashMap<String, [u8; KEY_SIZE_BYTES]>,
}

impl CryptoKeyRing {
    /// Creates a new key ring with a primary key version.
    pub fn new(primary_version: impl Into<String>, primary_key: [u8; KEY_SIZE_BYTES]) -> Self {
        let version = primary_version.into();
        let mut keys = HashMap::new();
        keys.insert(version.clone(), primary_key);
        Self {
            primary_version: version,
            keys,
        }
    }

    /// Creates a key ring from a 64-character hex-encoded string for version "v1".
    pub fn from_hex(hex_key: &str) -> Result<Self, CryptoError> {
        let raw_key = decode_hex_key(hex_key)?;
        Ok(Self::new(CURRENT_VERSION, raw_key))
    }

    /// Adds a secondary/historical key version for decryption during key rotation.
    pub fn add_key(&mut self, version: impl Into<String>, key: [u8; KEY_SIZE_BYTES]) -> &mut Self {
        self.keys.insert(version.into(), key);
        self
    }

    /// Adds a secondary/historical key version from a hex string.
    pub fn add_hex_key(
        &mut self,
        version: impl Into<String>,
        hex_key: &str,
    ) -> Result<&mut Self, CryptoError> {
        let raw_key = decode_hex_key(hex_key)?;
        self.keys.insert(version.into(), raw_key);
        Ok(self)
    }

    /// Sets the primary key version used for new encryptions.
    pub fn set_primary_version(&mut self, version: impl Into<String>) -> Result<(), CryptoError> {
        let ver = version.into();
        if !self.keys.contains_key(&ver) {
            return Err(CryptoError::UnknownKeyVersion(format!(
                "Cannot set primary version '{ver}': key not in keyring"
            )));
        }
        self.primary_version = ver;
        Ok(())
    }

    /// Returns the active primary version name.
    pub fn primary_version(&self) -> &str {
        &self.primary_version
    }

    /// Retrieves the key for a given version.
    pub fn get_key(&self, version: &str) -> Option<&[u8; KEY_SIZE_BYTES]> {
        self.keys.get(version)
    }

    /// Retrieves the active primary key.
    pub fn primary_key(&self) -> Option<&[u8; KEY_SIZE_BYTES]> {
        self.keys.get(&self.primary_version)
    }
}

// Ensure keys are NEVER leaked via Debug.
impl fmt::Debug for CryptoKeyRing {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("CryptoKeyRing")
            .field("primary_version", &self.primary_version)
            .field("available_versions", &self.keys.keys().collect::<Vec<_>>())
            .field("keys", &"[REDACTED]")
            .finish()
    }
}

/// Standalone cryptographic engine.
#[derive(Clone, Debug)]
pub struct CryptoEngine {
    keyring: CryptoKeyRing,
}

impl CryptoEngine {
    /// Creates a new crypto engine with the provided keyring.
    pub fn new(keyring: CryptoKeyRing) -> Self {
        Self { keyring }
    }

    /// Creates a new crypto engine from a 64-character hex master key string.
    pub fn from_hex_key(hex_key: &str) -> Result<Self, CryptoError> {
        let keyring = CryptoKeyRing::from_hex(hex_key)?;
        Ok(Self::new(keyring))
    }

    /// Encrypts binary plaintext using the active primary key.
    ///
    /// Returns ciphertext formatted as `{version}:{base64(nonce || tag || ciphertext)}`.
    pub fn encrypt_bytes(&self, plaintext: &[u8]) -> Result<String, CryptoError> {
        let version = self.keyring.primary_version();
        let key_bytes = self.keyring.primary_key().ok_or_else(|| {
            CryptoError::MissingKey(format!(
                "Primary encryption key for version '{version}' not found"
            ))
        })?;

        // 1. Generate fresh 96-bit random nonce from OS randomness
        let mut nonce_bytes = [0u8; NONCE_SIZE_BYTES];
        OsRng.fill_bytes(&mut nonce_bytes);

        // 2. Initialize AES-256-GCM cipher
        let key = Key::<Aes256Gcm>::from_slice(key_bytes);
        let cipher = Aes256Gcm::new(key);
        let nonce = Nonce::from_slice(&nonce_bytes);

        // 3. Encrypt plaintext (produces ciphertext || 16-byte authentication tag)
        let encrypted_data = cipher
            .encrypt(nonce, plaintext)
            .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;

        // 4. Construct payload: [12-byte nonce] || [ciphertext with tag]
        let mut payload = Vec::with_capacity(NONCE_SIZE_BYTES + encrypted_data.len());
        payload.extend_from_slice(&nonce_bytes);
        payload.extend_from_slice(&encrypted_data);

        // 5. Encode to Base64 and attach version prefix
        let base64_payload = BASE64_STANDARD.encode(&payload);
        Ok(format!("{version}:{base64_payload}"))
    }

    /// Encrypts a UTF-8 string plaintext using the active primary key.
    pub fn encrypt(&self, plaintext: &str) -> Result<String, CryptoError> {
        self.encrypt_bytes(plaintext.as_bytes())
    }

    /// Decrypts a versioned ciphertext string into raw bytes.
    ///
    /// Validates the authentication tag in constant time; any tampering or
    /// bit-flips will produce a `CryptoError::DecryptionFailed`.
    pub fn decrypt_bytes(&self, ciphertext: &str) -> Result<Vec<u8>, CryptoError> {
        // 1. Parse version prefix: "{version}:{base64_payload}"
        let (version, base64_payload) = parse_versioned_ciphertext(ciphertext)?;

        // 2. Look up key for the specified version
        let key_bytes = self.keyring.get_key(version).ok_or_else(|| {
            CryptoError::UnknownKeyVersion(format!(
                "No key configured for version prefix '{version}'"
            ))
        })?;

        // 3. Decode Base64 payload
        let payload = BASE64_STANDARD
            .decode(base64_payload)
            .map_err(|e| CryptoError::InvalidFormat(format!("Invalid base64 payload: {e}")))?;

        // Minimum length check: 12 bytes nonce + 16 bytes tag = 28 bytes
        if payload.len() < NONCE_SIZE_BYTES + TAG_SIZE_BYTES {
            return Err(CryptoError::InvalidFormat(
                "Ciphertext payload is shorter than minimum nonce + tag length".to_string(),
            ));
        }

        // 4. Extract nonce and encrypted bytes
        let (nonce_slice, encrypted_data) = payload.split_at(NONCE_SIZE_BYTES);

        // 5. Decrypt using AES-256-GCM
        let key = Key::<Aes256Gcm>::from_slice(key_bytes);
        let cipher = Aes256Gcm::new(key);
        let nonce = Nonce::from_slice(nonce_slice);

        cipher
            .decrypt(nonce, encrypted_data)
            .map_err(|e| CryptoError::DecryptionFailed(e.to_string()))
    }

    /// Decrypts a versioned ciphertext string into a UTF-8 string.
    pub fn decrypt(&self, ciphertext: &str) -> Result<String, CryptoError> {
        let bytes = self.decrypt_bytes(ciphertext)?;
        String::from_utf8(bytes).map_err(|e| CryptoError::Utf8Error(e.to_string()))
    }

    /// Checks if a ciphertext was encrypted with an older key and should be rotated.
    pub fn needs_rotation(&self, ciphertext: &str) -> bool {
        match parse_versioned_ciphertext(ciphertext) {
            Ok((version, _)) => version != self.keyring.primary_version(),
            Err(_) => false,
        }
    }
}

// Global default instance state for singleton-style access matching `Crypto::encrypt`.
static GLOBAL_ENGINE: RwLock<Option<Arc<CryptoEngine>>> = RwLock::new(None);

/// Public cryptographic interface for Bloom Cloud backend.
pub struct Crypto;

impl Crypto {
    /// Initializes the global crypto engine with a 64-character hex master key.
    pub fn init(hex_key: &str) -> Result<(), CryptoError> {
        let engine = CryptoEngine::from_hex_key(hex_key)?;
        let mut guard = GLOBAL_ENGINE.write().map_err(|_| {
            CryptoError::EncryptionFailed("Failed to acquire global crypto lock".to_string())
        })?;
        *guard = Some(Arc::new(engine));
        Ok(())
    }

    /// Initializes the global crypto engine with a multi-version keyring.
    pub fn init_with_keyring(keyring: CryptoKeyRing) -> Result<(), CryptoError> {
        let engine = CryptoEngine::new(keyring);
        let mut guard = GLOBAL_ENGINE.write().map_err(|_| {
            CryptoError::EncryptionFailed("Failed to acquire global crypto lock".to_string())
        })?;
        *guard = Some(Arc::new(engine));
        Ok(())
    }

    /// Loads the master key from the environment variable `BLOOM_ENCRYPTION_KEY` or `ENCRYPTION_KEY`.
    pub fn init_from_env() -> Result<(), CryptoError> {
        let key_str = std::env::var("BLOOM_ENCRYPTION_KEY")
            .or_else(|_| std::env::var("ENCRYPTION_KEY"))
            .map_err(|_| {
                CryptoError::MissingKey(
                    "Neither BLOOM_ENCRYPTION_KEY nor ENCRYPTION_KEY is set in environment"
                        .to_string(),
                )
            })?;
        Self::init(&key_str)
    }

    /// Gets a reference to the global engine or lazily initializes from environment.
    fn get_engine() -> Result<Arc<CryptoEngine>, CryptoError> {
        {
            let guard = GLOBAL_ENGINE.read().map_err(|_| {
                CryptoError::EncryptionFailed("Failed to acquire global crypto lock".to_string())
            })?;
            if let Some(engine) = &*guard {
                return Ok(engine.clone());
            }
        }

        // Attempt lazy initialization from environment
        Self::init_from_env()?;

        let guard = GLOBAL_ENGINE.read().map_err(|_| {
            CryptoError::EncryptionFailed("Failed to acquire global crypto lock".to_string())
        })?;
        guard
            .as_ref()
            .cloned()
            .ok_or_else(|| CryptoError::MissingKey("Crypto engine was not initialized".to_string()))
    }

    /// Encrypts plaintext string using AES-256-GCM envelope encryption.
    ///
    /// Produces `v1:{base64(nonce || tag || ciphertext)}`.
    pub fn encrypt(plaintext: &str) -> Result<String, CryptoError> {
        Self::get_engine()?.encrypt(plaintext)
    }

    /// Encrypts raw bytes using AES-256-GCM envelope encryption.
    pub fn encrypt_bytes(plaintext: &[u8]) -> Result<String, CryptoError> {
        Self::get_engine()?.encrypt_bytes(plaintext)
    }

    /// Decrypts versioned ciphertext string into a UTF-8 string.
    pub fn decrypt(ciphertext: &str) -> Result<String, CryptoError> {
        Self::get_engine()?.decrypt(ciphertext)
    }

    /// Decrypts versioned ciphertext string into raw bytes.
    pub fn decrypt_bytes(ciphertext: &str) -> Result<Vec<u8>, CryptoError> {
        Self::get_engine()?.decrypt_bytes(ciphertext)
    }

    /// Checks if a ciphertext was encrypted with an older key version and needs re-encryption.
    pub fn needs_rotation(ciphertext: &str) -> bool {
        Self::get_engine()
            .map(|engine| engine.needs_rotation(ciphertext))
            .unwrap_or(false)
    }

    /// Computes an HMAC-SHA256 of `message` under `key`, as a lowercase hex digest.
    ///
    /// This is the single implementation of HMAC in the codebase. Webhook signature
    /// verification depends on it, so it lives here beside [`Crypto::constant_time_eq`]
    /// rather than being reimplemented per caller — two copies of a security primitive is
    /// two places for a subtle bug to hide.
    ///
    /// Implements RFC 2104 over SHA-256 and is verified in `tests/infra/crypto_tests.rs`
    /// against the RFC 4231 test vectors.
    pub fn hmac_sha256_hex(key: &[u8], message: &[u8]) -> String {
        /// SHA-256 block size in bytes.
        const BLOCK_SIZE: usize = 64;

        // Keys longer than the block size are replaced by their own digest; shorter keys are
        // zero-padded to the block size.
        let mut key_block = [0u8; BLOCK_SIZE];
        if key.len() > BLOCK_SIZE {
            let mut hasher = Sha256::new();
            hasher.update(key);
            let hash = hasher.finalize();
            key_block[..hash.len()].copy_from_slice(&hash);
        } else {
            key_block[..key.len()].copy_from_slice(key);
        }

        let mut k_ipad = [0u8; BLOCK_SIZE];
        let mut k_opad = [0u8; BLOCK_SIZE];
        for i in 0..BLOCK_SIZE {
            k_ipad[i] = key_block[i] ^ 0x36;
            k_opad[i] = key_block[i] ^ 0x5c;
        }

        let mut inner_hasher = Sha256::new();
        inner_hasher.update(k_ipad);
        inner_hasher.update(message);
        let inner_hash = inner_hasher.finalize();

        let mut outer_hasher = Sha256::new();
        outer_hasher.update(k_opad);
        outer_hasher.update(inner_hash);
        format!("{:x}", outer_hasher.finalize())
    }

    /// Computes a SHA-256 hex digest of a token for secure database lookup.
    ///
    /// API tokens and worker tokens store only this hash in the database.
    pub fn hash_token(token: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(token.as_bytes());
        format!("{:x}", hasher.finalize())
    }

    /// Constant-time byte slice comparison to mitigate timing attacks on secrets and signatures.
    pub fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
        if a.len() != b.len() {
            return false;
        }
        a.ct_eq(b).into()
    }

    /// Constant-time string comparison for secret tokens.
    pub fn constant_time_eq_str(a: &str, b: &str) -> bool {
        Self::constant_time_eq(a.as_bytes(), b.as_bytes())
    }
}

/// Helper to split a versioned ciphertext into `(version, base64_payload)`.
fn parse_versioned_ciphertext(ciphertext: &str) -> Result<(&str, &str), CryptoError> {
    let parts: Vec<&str> = ciphertext.splitn(2, ':').collect();
    if parts.len() != 2 || parts[0].is_empty() || parts[1].is_empty() {
        return Err(CryptoError::InvalidFormat(
            "Ciphertext must follow format '{version}:{base64_payload}'".to_string(),
        ));
    }
    Ok((parts[0], parts[1]))
}

/// Helper to decode a 64-hex-character string into a 32-byte key array.
fn decode_hex_key(hex_key: &str) -> Result<[u8; KEY_SIZE_BYTES], CryptoError> {
    let trimmed = hex_key.trim();
    if trimmed.len() != KEY_SIZE_BYTES * 2 {
        return Err(CryptoError::InvalidKey(format!(
            "Hex key must be exactly {} hex characters (got {})",
            KEY_SIZE_BYTES * 2,
            trimmed.len()
        )));
    }

    let mut key = [0u8; KEY_SIZE_BYTES];
    for i in 0..KEY_SIZE_BYTES {
        let byte_str = &trimmed[i * 2..i * 2 + 2];
        key[i] = u8::from_str_radix(byte_str, 16).map_err(|e| {
            CryptoError::InvalidKey(format!("Invalid hex character at index {}: {e}", i * 2))
        })?;
    }

    Ok(key)
}
