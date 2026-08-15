//! Unit tests for the deploy worker, CDN purge outcomes, and Caddy site configuration.

use bloom_cloud_backend::apps::webhosting::services::build_web_storage_prefix;
use bloom_cloud_backend::infra::caddy::caddy_site_id;
use bloom_cloud_backend::infra::cdn::{CdnClient, PurgeOutcome};
use bloom_cloud_backend::infra::queue::{InMemoryJobQueue, Job};
use bloom_cloud_backend::infra::storage::{InMemoryStorage, ObjectStorage};
use bytes::Bytes;

#[tokio::test]
async fn test_deploy_worker_storage_prefix_and_caddy_id_match_canonical_helpers() {
    let org_id = "org_11111111-1111-1111-1111-111111111111";
    let prj_id = "prj_22222222-2222-2222-2222-222222222222";
    let app_id = "app_33333333-3333-3333-3333-333333333333";
    let dep_id = "dep_99999999-9999-9999-9999-999999999999";

    let expected_prefix = format!("orgs/{org_id}/projects/{prj_id}/apps/{app_id}/web/{dep_id}");
    let actual_prefix = build_web_storage_prefix(org_id, prj_id, app_id, dep_id);
    assert_eq!(actual_prefix, expected_prefix);

    let expected_caddy_id = format!("bloom-site-{dep_id}");
    let actual_caddy_id = caddy_site_id(dep_id);
    assert_eq!(actual_caddy_id, expected_caddy_id);
}

#[tokio::test]
async fn test_deploy_worker_unconfigured_cdn_skips_without_failure() {
    let cdn = CdnClient::unconfigured();
    assert!(!cdn.is_configured());

    let prefixes = vec!["orgs/org-1/projects/p-1/apps/a-1/web/dep-1".to_string()];
    let outcome = cdn
        .purge_prefixes(&prefixes)
        .await
        .expect("purge prefixes on unconfigured CDN");

    match outcome {
        PurgeOutcome::Skipped { ref reason } => {
            assert!(reason.contains("not configured"));
        }
        PurgeOutcome::Purged { .. } => panic!("Expected PurgeOutcome::Skipped, got Purged"),
    }
}

#[tokio::test]
async fn test_deploy_worker_claim_ack_on_success() {
    let queue = InMemoryJobQueue::new();
    let storage = InMemoryStorage::new();

    let deploy_job = Job::Deploy {
        deployment_id: "dep_success_01".to_string(),
        organization_id: "org_01".to_string(),
        release_id: Some("rel_01".to_string()),
        artifact_id: "art_01".to_string(),
        platform: "web".to_string(),
        target: "production".to_string(),
    };

    let stream_id = queue
        .push(deploy_job.clone())
        .await
        .expect("push deploy job");

    let claimed_opt = queue
        .claim("worker-deployer-01")
        .await
        .expect("claim deploy job");
    assert!(claimed_opt.is_some());
    let claimed = claimed_opt.unwrap();
    assert_eq!(claimed.stream_id, stream_id);
    assert_eq!(claimed.job, deploy_job);

    // Upload web bundle assets
    let prefix = build_web_storage_prefix("org_01", "prj_01", "app_01", "dep_success_01");
    let index_key = format!("{prefix}/index.html");
    let main_js_key = format!("{prefix}/main.dart.js");

    storage
        .put(
            &index_key,
            Bytes::from("<html><body>App</body></html>"),
            "text/html",
        )
        .await
        .expect("put index.html");
    storage
        .put(
            &main_js_key,
            Bytes::from("console.log('web bundle');"),
            "application/javascript",
        )
        .await
        .expect("put main.dart.js");

    assert!(storage.exists(&index_key).await.unwrap());
    assert!(storage.exists(&main_js_key).await.unwrap());

    // Successful completion acks the job
    queue.ack(&claimed.stream_id).await.expect("ack deploy job");
    assert_eq!(queue.pending_count().await, 0);
    assert_eq!(queue.dead_letter_count().await, 0);
}

#[tokio::test]
async fn test_deploy_worker_fail_dead_letters_after_max_retries() {
    let queue = InMemoryJobQueue::new().with_max_retries(1);

    let deploy_job = Job::Deploy {
        deployment_id: "dep_fatal_01".to_string(),
        organization_id: "org_01".to_string(),
        release_id: None,
        artifact_id: "art_01".to_string(),
        platform: "web".to_string(),
        target: "preview".to_string(),
    };

    queue.push(deploy_job).await.expect("push job");

    let claimed = queue
        .claim("worker-deployer-02")
        .await
        .unwrap()
        .expect("claimed");

    // Single failure with max_retries = 1 should immediately move to dead letter queue
    let error_reason = "Caddy route configuration rejected: port in use";
    queue
        .fail(&claimed.stream_id, error_reason)
        .await
        .expect("fail job");

    assert_eq!(queue.pending_count().await, 0);
    assert_eq!(queue.dead_letter_count().await, 1);
}
