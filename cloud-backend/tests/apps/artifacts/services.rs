use std::time::Duration;

use bytes::Bytes;

use bloom_cloud_backend::apps::artifacts::models::Artifact;
use bloom_cloud_backend::apps::artifacts::services::{
    artifact_belongs_to_org, artifact_download_url, build_artifact_storage_key,
    presigned_download_url, validate_kind, validate_platform, VALID_ARTIFACT_KINDS,
    VALID_PLATFORMS,
};
use bloom_cloud_backend::infra::storage::{artifact_storage_key, InMemoryStorage, ObjectStorage};

/// Builds a minimal `Artifact` fixture whose storage key matches the canonical hierarchy.
fn test_artifact() -> Artifact {
    Artifact {
        id: 1,
        public_id: "art-550e8400-e29b-41d4-a716-446655440000".to_string(),
        build_id: 7,
        organization_id: 100,
        platform: "ios".to_string(),
        kind: "ipa".to_string(),
        storage_key: artifact_storage_key(
            "org-100",
            "proj-1",
            "app-1",
            "build-7",
            "art-550e8400-e29b-41d4-a716-446655440000",
            "app.ipa",
        ),
        storage_bucket: "bloom-artifact-test".to_string(),
        file_name: "app.ipa".to_string(),
        file_size: 2048,
        checksum: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef".to_string(),
        version: "1.0.0".to_string(),
        build_number: 42,
        metadata: "{}".to_string(),
        created_at: chrono::Utc::now(),
    }
}

#[test]
fn test_storage_key_construction_matches_canonical() {
    let key = build_artifact_storage_key("org-a", "proj-b", "app-c", "build-d", "art-e", "app.ipa");

    // Must match the canonical builder exactly (the contract the workers rely on).
    assert_eq!(
        key,
        artifact_storage_key("org-a", "proj-b", "app-c", "build-d", "art-e", "app.ipa")
    );
    assert_eq!(
        key,
        "orgs/org-a/projects/proj-b/apps/app-c/builds/build-d/artifacts/art-e/app.ipa"
    );
}

#[tokio::test]
async fn test_presigned_url_produced_with_specified_ttl() {
    let storage = InMemoryStorage::with_bucket("bloom-artifact-test");
    let artifact = test_artifact();

    storage
        .put(
            &artifact.storage_key,
            Bytes::from_static(b"fake-ipa-binary"),
            "application/octet-stream",
        )
        .await
        .expect("put succeeds");

    let ttl = Duration::from_secs(15 * 60);
    let url = presigned_download_url(&storage, &artifact, ttl)
        .await
        .expect("presigned url succeeds");

    // The presigned URL names the bucket and object and carries an expiration timestamp.
    assert!(url.contains("bloom-artifact-test"));
    assert!(url.contains(&artifact.storage_key));
    assert!(url.contains("expires="));
    assert!(url.starts_with("https://storage.local/"));
}

#[tokio::test]
async fn test_download_for_another_organization_is_refused() {
    let storage = InMemoryStorage::new();
    let artifact = test_artifact(); // organization_id = 100

    storage
        .put(
            &artifact.storage_key,
            Bytes::from_static(b"fake-ipa-binary"),
            "application/octet-stream",
        )
        .await
        .expect("put succeeds");

    // Same organization: allowed.
    let allowed = artifact_download_url(&storage, &artifact, 100, Duration::from_secs(900)).await;
    assert!(allowed.is_ok(), "same-organization download must succeed");

    // Another organization: refused.
    let denied = artifact_download_url(&storage, &artifact, 999, Duration::from_secs(900)).await;
    assert!(
        denied.is_err(),
        "cross-organization download must be refused"
    );

    // Pure ownership check agrees.
    assert!(artifact_belongs_to_org(&artifact, 100));
    assert!(!artifact_belongs_to_org(&artifact, 999));
}

#[test]
fn test_platform_and_kind_validation() {
    assert_eq!(VALID_PLATFORMS, &["android", "ios", "web"]);

    assert!(validate_platform("android").is_ok());
    assert!(validate_platform("ios").is_ok());
    assert!(validate_platform("web").is_ok());
    assert!(validate_platform("windows").is_err());
    assert!(validate_platform("").is_err());

    assert_eq!(
        VALID_ARTIFACT_KINDS,
        &[
            "ipa",
            "aab",
            "apk",
            "web_bundle",
            "dsym",
            "source_map",
            "mapping",
            "log"
        ]
    );

    for kind in VALID_ARTIFACT_KINDS {
        assert!(validate_kind(kind).is_ok(), "kind {kind} must be valid");
    }
    assert!(validate_kind("unknown").is_err());
    assert!(validate_kind("").is_err());
}
