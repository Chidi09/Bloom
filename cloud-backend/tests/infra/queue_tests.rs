//! Unit tests for job payload serialization, queue semantics, claim timeouts, and dead-letter queue.

use serde_json::json;
use std::time::Duration;

use bloom_cloud_backend::infra::queue::{InMemoryJobQueue, Job};

#[test]
fn test_job_payload_build_serialization_roundtrip() {
    let build_job = Job::Build {
        build_id: "bld_12345678-1234-1234-1234-123456789abc".to_string(),
        organization_id: "org_11111111-1111-1111-1111-111111111111".to_string(),
        project_id: "prj_22222222-2222-2222-2222-222222222222".to_string(),
        app_id: "app_33333333-3333-3333-3333-333333333333".to_string(),
        environment_id: "env_44444444-4444-4444-4444-444444444444".to_string(),
        git_commit: "9f83acde9238472910fae1234567890abcdef123".to_string(),
        platform: "ios".to_string(),
        build_profile: "release".to_string(),
    };

    assert_eq!(build_job.id(), "bld_12345678-1234-1234-1234-123456789abc");
    assert_eq!(build_job.job_type(), "Build");

    let json_str = serde_json::to_string(&build_job).expect("serialize build job");
    assert!(json_str.contains("\"job_type\":\"Build\""));
    assert!(json_str.contains("\"platform\":\"ios\""));

    let deserialized: Job = serde_json::from_str(&json_str).expect("deserialize build job");
    assert_eq!(deserialized, build_job);
}

#[test]
fn test_job_payload_deploy_serialization_roundtrip() {
    let deploy_job = Job::Deploy {
        deployment_id: "dep_98765432-4321-4321-4321-987654321cba".to_string(),
        organization_id: "org_11111111-1111-1111-1111-111111111111".to_string(),
        release_id: Some("rel_55555555-5555-5555-5555-555555555555".to_string()),
        artifact_id: "art_66666666-6666-6666-6666-666666666666".to_string(),
        platform: "android".to_string(),
        target: "testflight".to_string(),
    };

    assert_eq!(deploy_job.id(), "dep_98765432-4321-4321-4321-987654321cba");
    assert_eq!(deploy_job.job_type(), "Deploy");

    let json_str = serde_json::to_string(&deploy_job).expect("serialize deploy job");
    assert!(json_str.contains("\"job_type\":\"Deploy\""));

    let deserialized: Job = serde_json::from_str(&json_str).expect("deserialize deploy job");
    assert_eq!(deserialized, deploy_job);
}

#[test]
fn test_job_payload_webhook_serialization_roundtrip() {
    let webhook_job = Job::Webhook {
        delivery_id: "wh_delivery_abc123".to_string(),
        provider: "github".to_string(),
        payload: json!({
            "ref": "refs/heads/main",
            "after": "9f83acde",
            "repository": { "full_name": "bloom-org/my-app" }
        }),
        signature: "sha256=abcdef123456".to_string(),
    };

    assert_eq!(webhook_job.id(), "wh_delivery_abc123");
    assert_eq!(webhook_job.job_type(), "Webhook");

    let json_str = serde_json::to_string(&webhook_job).expect("serialize webhook job");
    assert!(json_str.contains("\"job_type\":\"Webhook\""));
    assert!(json_str.contains("\"provider\":\"github\""));

    let deserialized: Job = serde_json::from_str(&json_str).expect("deserialize webhook job");
    assert_eq!(deserialized, webhook_job);
}

#[tokio::test]
async fn test_in_memory_queue_claim_and_ack() {
    let queue = InMemoryJobQueue::new();

    let job = Job::Build {
        build_id: "bld-001".to_string(),
        organization_id: "org-001".to_string(),
        project_id: "prj-001".to_string(),
        app_id: "app-001".to_string(),
        environment_id: "env-001".to_string(),
        git_commit: "abc1234".to_string(),
        platform: "web".to_string(),
        build_profile: "release".to_string(),
    };

    // 1. Push job
    let stream_id = queue.push(job.clone()).await.expect("push job");
    assert_eq!(queue.pending_count().await, 1);

    // 2. Claim job by Worker A
    let claimed_opt = queue.claim("worker-a").await.expect("claim job");
    assert!(claimed_opt.is_some());
    let claimed = claimed_opt.unwrap();
    assert_eq!(claimed.stream_id, stream_id);
    assert_eq!(claimed.claimed_by, Some("worker-a".to_string()));
    assert_eq!(claimed.job, job);
    assert_eq!(queue.pending_count().await, 0);

    // 3. Worker B tries to claim - queue is empty
    let empty_claim = queue.claim("worker-b").await.expect("claim job");
    assert!(empty_claim.is_none());

    // 4. Worker A acks job
    queue.ack(&claimed.stream_id).await.expect("ack job");

    // 5. Subsequent claim still empty
    assert!(queue.claim("worker-a").await.unwrap().is_none());
    assert_eq!(queue.dead_letter_count().await, 0);
}

#[tokio::test]
async fn test_in_memory_queue_retry_and_dead_letter() {
    // Queue configured with max 2 retries
    let queue = InMemoryJobQueue::new().with_max_retries(2);

    let job = Job::Webhook {
        delivery_id: "del-999".to_string(),
        provider: "gitlab".to_string(),
        payload: json!({ "event": "push" }),
        signature: "sig-xyz".to_string(),
    };

    queue.push(job.clone()).await.expect("push job");

    // --- Attempt 1 ---
    let claim1 = queue.claim("worker-1").await.unwrap().expect("claimed 1");
    assert_eq!(claim1.retry_count, 0);
    // Worker 1 fails
    queue
        .fail(
            &claim1.stream_id,
            "Network timeout connecting to git provider",
        )
        .await
        .unwrap();
    assert_eq!(queue.dead_letter_count().await, 0);
    assert_eq!(queue.pending_count().await, 1);

    // --- Attempt 2 ---
    let claim2 = queue.claim("worker-2").await.unwrap().expect("claimed 2");
    assert_eq!(claim2.retry_count, 1);
    assert_eq!(
        claim2.last_error,
        Some("Network timeout connecting to git provider".to_string())
    );
    // Worker 2 fails again (total attempts now 2 == max_retries)
    queue
        .fail(&claim2.stream_id, "Git provider 500 Internal Error")
        .await
        .unwrap();

    // Now moved to dead letter queue
    assert_eq!(queue.pending_count().await, 0);
    assert_eq!(queue.dead_letter_count().await, 1);
}

#[tokio::test]
async fn test_in_memory_queue_claim_timeout_recovery() {
    // Short claim timeout for testing (50ms)
    let queue = InMemoryJobQueue::new().with_claim_timeout(Duration::from_millis(50));

    let job = Job::Deploy {
        deployment_id: "dep-timeout-test".to_string(),
        organization_id: "org-1".to_string(),
        release_id: None,
        artifact_id: "art-1".to_string(),
        platform: "ios".to_string(),
        target: "testflight".to_string(),
    };

    queue.push(job.clone()).await.expect("push job");

    // Worker 1 claims job
    let claim1 = queue
        .claim("worker-1")
        .await
        .unwrap()
        .expect("claimed by worker 1");
    assert_eq!(claim1.claimed_by, Some("worker-1".to_string()));

    // Worker 2 immediately tries to claim -> None
    assert!(queue.claim("worker-2").await.unwrap().is_none());

    // Worker 1 dies without heartbeating or acking -> wait 60ms for timeout to expire
    tokio::time::sleep(Duration::from_millis(60)).await;

    // Worker 2 claims -> reclaims the abandoned job!
    let claim2 = queue
        .claim("worker-2")
        .await
        .unwrap()
        .expect("reclaimed by worker 2");
    assert_eq!(claim2.stream_id, claim1.stream_id);
    assert_eq!(claim2.claimed_by, Some("worker-2".to_string()));
}
