//! Unit tests for the build worker skeleton and queue claim/ack/fail semantics.

use bloom_cloud_backend::infra::queue::{InMemoryJobQueue, Job};
use bloom_cloud_backend::infra::storage::{
    artifact_storage_key, build_log_storage_key, InMemoryStorage, ObjectStorage,
};
use bloom_cloud_backend::workers::build::BUILD_STAGES;
use bytes::Bytes;

#[tokio::test]
async fn test_build_worker_storage_keys_match_canonical_helpers() {
    let org_id = "org_11111111-1111-1111-1111-111111111111";
    let prj_id = "prj_22222222-2222-2222-2222-222222222222";
    let app_id = "app_33333333-3333-3333-3333-333333333333";
    let build_id = "bld_44444444-4444-4444-4444-444444444444";
    let artifact_id = "art_55555555-5555-5555-5555-555555555555";
    let filename = "Runner.ipa";

    let expected_log_key =
        format!("orgs/{org_id}/projects/{prj_id}/apps/{app_id}/builds/{build_id}/logs/build.log");
    let actual_log_key = build_log_storage_key(org_id, prj_id, app_id, build_id);
    assert_eq!(actual_log_key, expected_log_key);

    let expected_art_key = format!(
        "orgs/{org_id}/projects/{prj_id}/apps/{app_id}/builds/{build_id}/artifacts/{artifact_id}/{filename}"
    );
    let actual_art_key =
        artifact_storage_key(org_id, prj_id, app_id, build_id, artifact_id, filename);
    assert_eq!(actual_art_key, expected_art_key);
}

#[tokio::test]
async fn test_build_worker_claim_ack_on_success() {
    let queue = InMemoryJobQueue::new();
    let storage = InMemoryStorage::new();

    let build_job = Job::Build {
        build_id: "bld_101".to_string(),
        organization_id: "org_101".to_string(),
        project_id: "prj_101".to_string(),
        app_id: "app_101".to_string(),
        environment_id: "env_101".to_string(),
        git_commit: "commit123".to_string(),
        platform: "android".to_string(),
        build_profile: "release".to_string(),
    };

    let stream_id = queue.push(build_job.clone()).await.expect("push build job");
    assert_eq!(queue.pending_count().await, 1);

    let claimed_opt = queue.claim("worker-builder-01").await.expect("claim job");
    assert!(claimed_opt.is_some());
    let claimed = claimed_opt.unwrap();
    assert_eq!(claimed.stream_id, stream_id);
    assert_eq!(claimed.job, build_job);

    // Simulate successful log and artifact upload
    let log_key = build_log_storage_key("org_101", "prj_101", "app_101", "bld_101");
    storage
        .put(&log_key, Bytes::from("Build succeeded"), "text/plain")
        .await
        .expect("put log");

    let art_key = artifact_storage_key(
        "org_101",
        "prj_101",
        "app_101",
        "bld_101",
        "art_101",
        "app-release.aab",
    );
    storage
        .put(
            &art_key,
            Bytes::from("AAB bytes"),
            "application/octet-stream",
        )
        .await
        .expect("put artifact");

    assert!(storage.exists(&log_key).await.unwrap());
    assert!(storage.exists(&art_key).await.unwrap());

    // Worker acks on success
    queue.ack(&claimed.stream_id).await.expect("ack job");

    // Queue is empty, dead letter count is 0
    assert_eq!(queue.pending_count().await, 0);
    assert_eq!(queue.dead_letter_count().await, 0);
    assert!(queue.claim("worker-builder-01").await.unwrap().is_none());
}

#[tokio::test]
async fn test_build_worker_fail_records_reason_and_requeues() {
    let queue = InMemoryJobQueue::new().with_max_retries(3);

    let build_job = Job::Build {
        build_id: "bld_fail_test".to_string(),
        organization_id: "org_1".to_string(),
        project_id: "prj_1".to_string(),
        app_id: "app_1".to_string(),
        environment_id: "env_1".to_string(),
        git_commit: "deadbeef".to_string(),
        platform: "ios".to_string(),
        build_profile: "release".to_string(),
    };

    queue.push(build_job.clone()).await.expect("push build job");

    // Claim 1
    let claim1 = queue
        .claim("worker-builder-02")
        .await
        .unwrap()
        .expect("claimed");
    assert_eq!(claim1.retry_count, 0);

    // Fail stage
    let failure_reason = "Gradle build failure: ExitCode 1";
    queue
        .fail(&claim1.stream_id, failure_reason)
        .await
        .expect("fail job");

    // Job was requeued with retry_count incremented
    assert_eq!(queue.pending_count().await, 1);
    assert_eq!(queue.dead_letter_count().await, 0);

    // Claim 2
    let claim2 = queue
        .claim("worker-builder-03")
        .await
        .unwrap()
        .expect("re-claimed");
    assert_eq!(claim2.retry_count, 1);
    assert_eq!(claim2.last_error, Some(failure_reason.to_string()));
}

#[test]
fn test_build_stages_canonical_list() {
    assert_eq!(BUILD_STAGES.len(), 9);
    assert_eq!(BUILD_STAGES[0], "checkout");
    assert_eq!(BUILD_STAGES[1], "install");
    assert_eq!(BUILD_STAGES[2], "resolve");
    assert_eq!(BUILD_STAGES[3], "generate");
    assert_eq!(BUILD_STAGES[4], "prebuild");
    assert_eq!(BUILD_STAGES[5], "test");
    assert_eq!(BUILD_STAGES[6], "analyze");
    assert_eq!(BUILD_STAGES[7], "build");
    assert_eq!(BUILD_STAGES[8], "upload");
}
