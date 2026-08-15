//! Unit tests for object storage abstraction and InMemoryStorage backend.

use std::time::Duration;
use bytes::Bytes;

use bloom_cloud_backend::infra::storage::{
    artifact_storage_key, build_log_storage_key, web_bundle_storage_key,
    InMemoryStorage, ObjectStorage, StorageConfig, StorageError,
};

#[tokio::test]
async fn test_in_memory_storage_crud_roundtrip() {
    let storage = InMemoryStorage::new();
    let key = "orgs/org-123/projects/proj-456/apps/app-789/builds/b-101/artifacts/art-202/app.ipa";
    let data = Bytes::from_static(b"PK\x03\x04fake_ipa_binary_payload");
    let content_type = "application/octet-stream";

    // 1. Check exists is false initially
    assert!(!storage.exists(key).await.expect("exists check"));

    // 2. Put object
    storage.put(key, data.clone(), content_type).await.expect("put succeeds");

    // 3. Exists is true
    assert!(storage.exists(key).await.expect("exists check"));
    assert_eq!(storage.count().await, 1);

    // 4. Get object
    let fetched = storage.get(key).await.expect("get succeeds");
    assert_eq!(fetched, data);

    // 5. Delete object
    storage.delete(key).await.expect("delete succeeds");
    assert!(!storage.exists(key).await.expect("exists check"));
    assert_eq!(storage.count().await, 0);

    // 6. Get after delete returns NotFound
    let get_res = storage.get(key).await;
    assert!(matches!(get_res, Err(StorageError::NotFound(_))));
}

#[tokio::test]
async fn test_in_memory_storage_presigned_url() {
    let storage = InMemoryStorage::with_bucket("bloom-test-bucket");
    let key = "builds/123/logs/build.log";
    let data = Bytes::from_static(b"Step 1: Flutter build running...");

    // Presign on non-existent key fails
    let presign_err = storage.presigned_url(key, Duration::from_secs(900)).await;
    assert!(matches!(presign_err, Err(StorageError::NotFound(_))));

    // Put data
    storage.put(key, data, "text/plain").await.expect("put succeeds");

    // Presign on existing key succeeds and contains bucket and key
    let url = storage
        .presigned_url(key, Duration::from_secs(900))
        .await
        .expect("presign succeeds");

    assert!(url.contains("bloom-test-bucket"));
    assert!(url.contains("builds/123/logs/build.log"));
    assert!(url.contains("expires="));
}

#[test]
fn test_canonical_storage_key_builders() {
    let org_id = "org_a1b2c3d4";
    let proj_id = "proj_e5f6g7h8";
    let app_id = "app_i9j0k1l2";
    let build_id = "build_m3n4o5p6";
    let artifact_id = "art_q7r8s9t0";

    // 1. Artifact key
    let art_key = artifact_storage_key(
        org_id,
        proj_id,
        app_id,
        build_id,
        artifact_id,
        "release.aab",
    );
    assert_eq!(
        art_key,
        "orgs/org_a1b2c3d4/projects/proj_e5f6g7h8/apps/app_i9j0k1l2/builds/build_m3n4o5p6/artifacts/art_q7r8s9t0/release.aab"
    );

    // 2. Build log key
    let log_key = build_log_storage_key(org_id, proj_id, app_id, build_id);
    assert_eq!(
        log_key,
        "orgs/org_a1b2c3d4/projects/proj_e5f6g7h8/apps/app_i9j0k1l2/builds/build_m3n4o5p6/logs/build.log"
    );

    // 3. Web bundle key
    let deployment_id = "dep_u1v2w3x4";
    let web_key = web_bundle_storage_key(org_id, proj_id, app_id, deployment_id, "main.dart.js");
    assert_eq!(
        web_key,
        "orgs/org_a1b2c3d4/projects/proj_e5f6g7h8/apps/app_i9j0k1l2/web/dep_u1v2w3x4/main.dart.js"
    );
}

#[test]
fn test_storage_config_debug_redaction() {
    let config = StorageConfig {
        endpoint: Some("https://r2.cloudflarestorage.com".to_string()),
        bucket: "my-bucket".to_string(),
        access_key_id: "AKIAIOSFODNN7EXAMPLE".to_string(),
        secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY".to_string(),
        region: "auto".to_string(),
    };

    let debug_str = format!("{:?}", config);
    assert!(!debug_str.contains("wJalrXUtnFEMI"));
    assert!(debug_str.contains("[REDACTED]"));
}
