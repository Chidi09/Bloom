//! Object storage abstraction for Cloudflare R2 and AWS S3-compatible backends.
//!
//! # Storage Hierarchy
//!
//! Storage keys use stable public UUIDs rather than internal schema IDs to prevent
//! leaking database primary keys:
//!
//! ```text
//! orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/builds/{build_public_id}/artifacts/{artifact_public_id}/{filename}
//! ```
//!
//! # Security & Access Model
//!
//! - All artifacts, logs, and signing materials in storage are **private by default**.
//! - Raw bucket URLs are never returned across API boundaries.
//! - Downloads and uploads are authorized exclusively via time-bounded **presigned URLs**
//!   (default expiry: 15 minutes).

use std::collections::HashMap;
use std::fmt;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use bytes::Bytes;
use tokio::sync::RwLock;

/// Default expiration duration for presigned artifact and log URLs (15 minutes).
pub const DEFAULT_PRESIGNED_EXPIRY: Duration = Duration::from_secs(15 * 60);

/// Errors arising from storage operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StorageError {
    /// Object with the given key was not found.
    NotFound(String),
    /// Missing or invalid storage credentials/configuration.
    ConfigError(String),
    /// Upload/put operation failed.
    UploadFailed(String),
    /// Download/get operation failed.
    DownloadFailed(String),
    /// Deletion failed.
    DeleteFailed(String),
    /// Failed to generate a presigned URL.
    PresignFailed(String),
    /// General storage backend error.
    Backend(String),
}

impl fmt::Display for StorageError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StorageError::NotFound(key) => write!(f, "Storage object not found: {key}"),
            StorageError::ConfigError(msg) => write!(f, "Storage configuration error: {msg}"),
            StorageError::UploadFailed(msg) => write!(f, "Storage upload failed: {msg}"),
            StorageError::DownloadFailed(msg) => write!(f, "Storage download failed: {msg}"),
            StorageError::DeleteFailed(msg) => write!(f, "Storage deletion failed: {msg}"),
            StorageError::PresignFailed(msg) => write!(f, "Presigned URL generation failed: {msg}"),
            StorageError::Backend(msg) => write!(f, "Storage backend error: {msg}"),
        }
    }
}

impl std::error::Error for StorageError {}

/// Configuration for S3 / Cloudflare R2 object storage.
#[derive(Clone, PartialEq, Eq)]
pub struct StorageConfig {
    /// S3/R2 custom endpoint (e.g. `https://<account_id>.r2.cloudflarestorage.com`).
    pub endpoint: Option<String>,
    /// Target bucket name.
    pub bucket: String,
    /// Storage Access Key ID.
    pub access_key_id: String,
    /// Storage Secret Access Key.
    pub secret_access_key: String,
    /// Region (default `auto` for Cloudflare R2, or `us-east-1` etc.).
    pub region: String,
}

impl StorageConfig {
    /// Loads storage configuration from environment variables.
    pub fn from_env() -> Result<Self, StorageError> {
        let bucket = std::env::var("STORAGE_BUCKET")
            .or_else(|_| std::env::var("BLOOM_STORAGE_BUCKET"))
            .map_err(|_| StorageError::ConfigError("STORAGE_BUCKET must be set".to_string()))?;

        let access_key_id = std::env::var("STORAGE_ACCESS_KEY_ID")
            .or_else(|_| std::env::var("BLOOM_STORAGE_ACCESS_KEY_ID"))
            .map_err(|_| {
                StorageError::ConfigError("STORAGE_ACCESS_KEY_ID must be set".to_string())
            })?;

        let secret_access_key = std::env::var("STORAGE_SECRET_ACCESS_KEY")
            .or_else(|_| std::env::var("BLOOM_STORAGE_SECRET_ACCESS_KEY"))
            .map_err(|_| {
                StorageError::ConfigError("STORAGE_SECRET_ACCESS_KEY must be set".to_string())
            })?;

        let endpoint = std::env::var("STORAGE_ENDPOINT")
            .or_else(|_| std::env::var("BLOOM_STORAGE_ENDPOINT"))
            .ok()
            .filter(|s| !s.is_empty());

        let region = std::env::var("STORAGE_REGION")
            .or_else(|_| std::env::var("BLOOM_STORAGE_REGION"))
            .unwrap_or_else(|_| "auto".to_string());

        Ok(Self {
            endpoint,
            bucket,
            access_key_id,
            secret_access_key,
            region,
        })
    }
}

// Redact secret access key in debug prints
impl fmt::Debug for StorageConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("StorageConfig")
            .field("endpoint", &self.endpoint)
            .field("bucket", &self.bucket)
            .field("access_key_id", &self.access_key_id)
            .field("secret_access_key", &"[REDACTED]")
            .field("region", &self.region)
            .finish()
    }
}

/// Abstract asynchronous object storage contract.
#[async_trait]
pub trait ObjectStorage: Send + Sync + 'static {
    /// Uploads an object to the specified key.
    async fn put(&self, key: &str, body: Bytes, content_type: &str) -> Result<(), StorageError>;

    /// Downloads the raw bytes for the specified key.
    async fn get(&self, key: &str) -> Result<Bytes, StorageError>;

    /// Deletes the object at the specified key if it exists.
    async fn delete(&self, key: &str) -> Result<(), StorageError>;

    /// Generates a time-limited presigned GET URL for downloading private artifacts.
    async fn presigned_url(&self, key: &str, expires_in: Duration) -> Result<String, StorageError>;

    /// Checks whether an object exists at the specified key.
    async fn exists(&self, key: &str) -> Result<bool, StorageError>;
}

/// Production AWS S3 / Cloudflare R2 object storage implementation.
pub struct S3Storage {
    client: aws_sdk_s3::Client,
    bucket: String,
}

impl S3Storage {
    /// Creates a new `S3Storage` instance from configuration.
    pub async fn from_config(config: StorageConfig) -> Result<Self, StorageError> {
        let credentials = aws_sdk_s3::config::Credentials::new(
            config.access_key_id,
            config.secret_access_key,
            None,
            None,
            "bloom_cloud_storage",
        );

        let region = aws_sdk_s3::config::Region::new(config.region);

        let mut config_builder = aws_sdk_s3::config::Builder::new()
            .region(region)
            .credentials_provider(credentials)
            .force_path_style(true);

        if let Some(endpoint) = config.endpoint {
            config_builder = config_builder.endpoint_url(endpoint);
        }

        let s3_config = config_builder.build();
        let client = aws_sdk_s3::Client::from_conf(s3_config);

        Ok(Self {
            client,
            bucket: config.bucket,
        })
    }

    /// Creates an `S3Storage` instance by reading configuration from environment variables.
    pub async fn from_env() -> Result<Self, StorageError> {
        let config = StorageConfig::from_env()?;
        Self::from_config(config).await
    }
}

#[async_trait]
impl ObjectStorage for S3Storage {
    async fn put(&self, key: &str, body: Bytes, content_type: &str) -> Result<(), StorageError> {
        let byte_stream = aws_sdk_s3::primitives::ByteStream::from(body);

        self.client
            .put_object()
            .bucket(&self.bucket)
            .key(key)
            .content_type(content_type)
            .body(byte_stream)
            .send()
            .await
            .map_err(|e| StorageError::UploadFailed(e.to_string()))?;

        Ok(())
    }

    async fn get(&self, key: &str) -> Result<Bytes, StorageError> {
        let output = self
            .client
            .get_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| match e.into_service_error() {
                aws_sdk_s3::operation::get_object::GetObjectError::NoSuchKey(_) => {
                    StorageError::NotFound(key.to_string())
                }
                other => StorageError::DownloadFailed(other.to_string()),
            })?;

        let data =
            output.body.collect().await.map_err(|e| {
                StorageError::DownloadFailed(format!("Failed reading body bytes: {e}"))
            })?;

        Ok(data.into_bytes())
    }

    async fn delete(&self, key: &str) -> Result<(), StorageError> {
        self.client
            .delete_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| StorageError::DeleteFailed(e.to_string()))?;

        Ok(())
    }

    async fn presigned_url(&self, key: &str, expires_in: Duration) -> Result<String, StorageError> {
        let presigning_config = aws_sdk_s3::presigning::PresigningConfig::expires_in(expires_in)
            .map_err(|e| {
                StorageError::PresignFailed(format!("Invalid expiration duration: {e}"))
            })?;

        let presigned_req = self
            .client
            .get_object()
            .bucket(&self.bucket)
            .key(key)
            .presigned(presigning_config)
            .await
            .map_err(|e| StorageError::PresignFailed(e.to_string()))?;

        Ok(presigned_req.uri().to_string())
    }

    async fn exists(&self, key: &str) -> Result<bool, StorageError> {
        match self
            .client
            .head_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
        {
            Ok(_) => Ok(true),
            Err(e) => match e.into_service_error() {
                aws_sdk_s3::operation::head_object::HeadObjectError::NotFound(_) => Ok(false),
                other => Err(StorageError::Backend(other.to_string())),
            },
        }
    }
}

/// A stored item in the in-memory mock storage.
#[derive(Clone, Debug)]
pub struct StoredObject {
    /// Raw byte contents.
    pub body: Bytes,
    /// MIME content type.
    pub content_type: String,
    /// Creation timestamp.
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Thread-safe in-memory object storage implementation for testing and local development.
#[derive(Clone, Default)]
pub struct InMemoryStorage {
    bucket: String,
    objects: Arc<RwLock<HashMap<String, StoredObject>>>,
}

impl InMemoryStorage {
    /// Creates a new in-memory object storage with default bucket `bloomcloud-local`.
    pub fn new() -> Self {
        Self {
            bucket: "bloomcloud-local".to_string(),
            objects: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Creates an in-memory object storage with a named bucket.
    pub fn with_bucket(bucket: impl Into<String>) -> Self {
        Self {
            bucket: bucket.into(),
            objects: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Returns the total number of objects currently stored.
    pub async fn count(&self) -> usize {
        self.objects.read().await.len()
    }

    /// Clears all stored objects.
    pub async fn clear(&self) {
        self.objects.write().await.clear();
    }
}

#[async_trait]
impl ObjectStorage for InMemoryStorage {
    async fn put(&self, key: &str, body: Bytes, content_type: &str) -> Result<(), StorageError> {
        let object = StoredObject {
            body,
            content_type: content_type.to_string(),
            created_at: chrono::Utc::now(),
        };
        self.objects.write().await.insert(key.to_string(), object);
        Ok(())
    }

    async fn get(&self, key: &str) -> Result<Bytes, StorageError> {
        let guard = self.objects.read().await;
        let object = guard
            .get(key)
            .ok_or_else(|| StorageError::NotFound(key.to_string()))?;
        Ok(object.body.clone())
    }

    async fn delete(&self, key: &str) -> Result<(), StorageError> {
        self.objects.write().await.remove(key);
        Ok(())
    }

    async fn presigned_url(&self, key: &str, expires_in: Duration) -> Result<String, StorageError> {
        if !self.exists(key).await? {
            return Err(StorageError::NotFound(key.to_string()));
        }
        let expiry_secs = chrono::Utc::now().timestamp() + expires_in.as_secs() as i64;
        Ok(format!(
            "https://storage.local/{}/{}?expires={}&mock_token=presigned",
            self.bucket, key, expiry_secs
        ))
    }

    async fn exists(&self, key: &str) -> Result<bool, StorageError> {
        Ok(self.objects.read().await.contains_key(key))
    }
}

// -----------------------------------------------------------------------------
// Canonical Storage Key Path Builders
// -----------------------------------------------------------------------------

/// Constructs the canonical storage key for a build artifact.
///
/// Hierarchy:
/// `orgs/{org_id}/projects/{project_id}/apps/{app_id}/builds/{build_id}/artifacts/{artifact_id}/{filename}`
pub fn artifact_storage_key(
    org_public_id: &str,
    project_public_id: &str,
    app_public_id: &str,
    build_public_id: &str,
    artifact_public_id: &str,
    filename: &str,
) -> String {
    format!(
        "orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/builds/{build_public_id}/artifacts/{artifact_public_id}/{filename}"
    )
}

/// Constructs the canonical storage key for a build log file.
///
/// Hierarchy:
/// `orgs/{org_id}/projects/{project_id}/apps/{app_id}/builds/{build_id}/logs/build.log`
pub fn build_log_storage_key(
    org_public_id: &str,
    project_public_id: &str,
    app_public_id: &str,
    build_public_id: &str,
) -> String {
    format!(
        "orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/builds/{build_public_id}/logs/build.log"
    )
}

/// Constructs the canonical storage key for a web bundle asset.
///
/// Hierarchy:
/// `orgs/{org_id}/projects/{project_id}/apps/{app_id}/web/{deployment_id}/{filename}`
pub fn web_bundle_storage_key(
    org_public_id: &str,
    project_public_id: &str,
    app_public_id: &str,
    deployment_public_id: &str,
    filename: &str,
) -> String {
    format!(
        "orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/web/{deployment_public_id}/{filename}"
    )
}
