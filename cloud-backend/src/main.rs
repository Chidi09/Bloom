use std::sync::Arc;

use djangors_core::{Djangors, DjangorsError, DjangorsSettings, Router};

use bloom_cloud_backend::infra::storage::{ObjectStorage, S3Storage, StorageConfig};
use bloom_cloud_backend::settings::ObjectStorageSettings;

/// Builds a `StorageConfig` from the typed settings, or `None` when a required
/// credential is absent (object storage is then left unconfigured).
fn storage_config(settings: &ObjectStorageSettings) -> Option<StorageConfig> {
    Some(StorageConfig {
        endpoint: settings.endpoint.clone(),
        bucket: settings.bucket.clone()?,
        access_key_id: settings.access_key_id.clone()?,
        secret_access_key: settings.secret_access_key.clone()?,
        region: settings.region.clone(),
    })
}

// The module tree lives in the library crate (src/lib.rs). The binary consumes it
// rather than re-declaring `mod apps;` etc., which would compile a second, private
// copy of every module and make each app's public API look like dead code.
use bloom_cloud_backend::{migrations, settings, urls};

#[tokio::main]
async fn main() -> Result<(), DjangorsError> {
    djangors_core::introspect_models_if_requested();
    djangors_core::run_management_command_if_requested().await;
    djangors_core::logging::init_dev_logging();

    let (settings, warnings) = DjangorsSettings::load()?;
    for w in warnings {
        eprintln!("settings warning: {w}");
    }

    let bloom_settings = settings::BloomSettings::load()
        .map_err(|e| DjangorsError::Internal(format!("Failed to load Bloom settings: {e}")))?;

    let db_config = djangors_db::DatabaseConfig::new(&bloom_settings.database_url);
    let db = djangors_db::Database::connect(&db_config)
        .await
        .map_err(|e| DjangorsError::Internal(format!("Failed to connect to database: {e}")))?;

    migrations::run_migrations(&db)
        .await
        .map_err(|e| DjangorsError::Internal(format!("Migration failed: {e}")))?;

    // The build/deploy job queue is attached to router state so handlers (and the
    // /readyz probe) can reach Redis without opening a fresh connection each time.
    let queue = bloom_cloud_backend::infra::queue::JobQueue::from_url(&bloom_settings.redis_url)
        .map_err(|e| DjangorsError::Internal(format!("Failed to open Redis job queue: {e}")))?
        .with_claim_timeout_secs(bloom_settings.worker_claim_timeout_secs);

    // Object storage backs artifact/log downloads. It is configured through the typed
    // `BLOOM_S3_*` settings rather than storage.rs's own `from_env`, so there is one
    // source of truth. When it is not configured the server still boots: handlers that
    // need it answer `storage_unavailable` rather than the whole control plane refusing
    // to start over a feature many deployments do not use yet.
    let storage_settings = settings::ObjectStorageSettings::load()
        .map_err(|e| DjangorsError::Internal(format!("Failed to load storage settings: {e}")))?;

    let storage: Option<Arc<dyn ObjectStorage>> = match storage_config(&storage_settings) {
        Some(config) => match S3Storage::from_config(config).await {
            Ok(s3) => Some(Arc::new(s3)),
            Err(e) => {
                eprintln!("object storage disabled: {e}");
                None
            }
        },
        None => {
            eprintln!(
                "object storage disabled: set BLOOM_S3_BUCKET, BLOOM_S3_ACCESS_KEY_ID and \
                 BLOOM_S3_SECRET_ACCESS_KEY to enable artifact and log downloads"
            );
            None
        }
    };

    // Rate-limit counters for djangors-rest's `Throttle`. Backed by Redis rather than an
    // in-process cache because the control plane runs multiple instances: an in-memory
    // counter is per-process, so an attacker would get the configured limit multiplied by
    // the number of instances. A throttle that silently scales with the deployment is not
    // a throttle. This is a get/set/delete KV use and does not revisit the decision to
    // drive the build/deploy queue through raw Redis Streams.
    let throttle_cache: Arc<dyn djangors_cache::Cache> = Arc::new(
        djangors_cache::RedisCache::new(&bloom_settings.redis_url).map_err(|e| {
            DjangorsError::Internal(format!("Failed to open Redis throttle cache: {e}"))
        })?,
    );

    let mut router = urls::root()
        .with_state(db)
        .with_state(queue)
        .with_state(throttle_cache)
        .with_state(bloom_settings);

    if let Some(storage) = storage {
        router = router.with_state(storage);
    }
    let router_service = djangors_core::router::RouterService::new(router, settings.debug);

    let service = tower::ServiceBuilder::new()
        .layer(djangors_core::middleware::security_headers_layer())
        .service(router_service);

    Djangors::new(settings, Router::new())
        .run_service(service)
        .await
}
