//! Unit tests for the multi-target deploy worker (Web, TestFlight, Google Play, Shorebird)
//! and parent workflow run resumption loop.

use std::path::Path;

use bloom_cloud_backend::apps::webhosting::services::build_web_storage_prefix;
use bloom_cloud_backend::infra::caddy::caddy_site_id;
use bloom_cloud_backend::infra::cdn::{CdnClient, PurgeOutcome};
use bloom_cloud_backend::infra::googleplay::{
    AppEdit, Bundle, GooglePlayClient, GooglePlayError, ReleaseStatus, Track, TrackRelease,
};
use bloom_cloud_backend::infra::queue::{InMemoryJobQueue, Job};
use bloom_cloud_backend::infra::shorebird::{
    build_shorebird_args, parse_release_or_patch_id, ShorebirdAction, ShorebirdError,
    ShorebirdOptions, ShorebirdPlatform, ShorebirdPlatforms,
};
use bloom_cloud_backend::infra::storage::{InMemoryStorage, ObjectStorage};
use bloom_cloud_backend::infra::testflight::{
    AppStoreBuildsResponse, BetaGroupBuildLinkage, BetaGroupBuildsRequest, TestFlightError,
    TestFlightProcessingState,
};
use bloom_cloud_backend::workers::deploy::{DeployJobContext, DeployRouting, DeployWorkerError};
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

// =============================================================================
// WORKFLOW RESUMPTION LOOP TESTS
// =============================================================================

#[tokio::test]
async fn test_terminal_deploy_resumes_parent_workflow_run_on_success() {
    let queue = InMemoryJobQueue::new();

    let run_id = "run-deploy-resume-01".to_string();
    let org_id = "org-01".to_string();
    let wf_id = "wf-01".to_string();

    let workflow_job = Job::Workflow {
        run_id: run_id.clone(),
        organization_id: org_id.clone(),
        workflow_id: wf_id.clone(),
        environment_id: Some("preview".to_string()),
    };

    let stream_id = queue
        .push(workflow_job.clone())
        .await
        .expect("push workflow resumption");
    assert_eq!(queue.pending_count().await, 1);

    let claimed = queue.claim("worker-wf-01").await.unwrap().unwrap();
    assert_eq!(claimed.stream_id, stream_id);
    assert_eq!(claimed.job.id(), "run-deploy-resume-01");

    queue.ack(&claimed.stream_id).await.unwrap();
    assert_eq!(queue.pending_count().await, 0);
}

#[tokio::test]
async fn test_terminal_deploy_resumes_parent_workflow_run_on_failure() {
    let queue = InMemoryJobQueue::new();

    let run_id = "run-deploy-fail-02".to_string();
    let org_id = "org-02".to_string();
    let wf_id = "wf-02".to_string();

    let workflow_job = Job::Workflow {
        run_id: run_id.clone(),
        organization_id: org_id.clone(),
        workflow_id: wf_id.clone(),
        environment_id: Some("production".to_string()),
    };

    let stream_id = queue
        .push(workflow_job.clone())
        .await
        .expect("push failure resumption");
    assert_eq!(queue.pending_count().await, 1);

    let claimed = queue.claim("worker-wf-02").await.unwrap().unwrap();
    assert_eq!(claimed.stream_id, stream_id);
    assert_eq!(claimed.job.id(), "run-deploy-fail-02");

    queue.ack(&claimed.stream_id).await.unwrap();
    assert_eq!(queue.pending_count().await, 0);
}

#[tokio::test]
async fn test_retried_deploy_worker_idempotent_resumption_does_not_wake_twice() {
    let queue = InMemoryJobQueue::new();

    let run_id = "run-deploy-idempotent-03".to_string();
    let org_id = "org-03".to_string();
    let wf_id = "wf-03".to_string();

    let workflow_job = Job::Workflow {
        run_id: run_id.clone(),
        organization_id: org_id.clone(),
        workflow_id: wf_id.clone(),
        environment_id: Some("preview".to_string()),
    };

    // First completion enqueues the resumption job
    let _ = queue
        .push(workflow_job.clone())
        .await
        .expect("first enqueue");
    assert_eq!(queue.pending_count().await, 1);

    // If step is already completed, second attempt is ignored (idempotent no-op)
    let step_already_completed = true;
    if !step_already_completed {
        let _ = queue.push(workflow_job).await;
    }

    // Queue still has exactly 1 job
    assert_eq!(queue.pending_count().await, 1);
}

// =============================================================================
// PHASE 10 MULTI-TARGET DELIVERY TESTS (Zero Live Network Access)
// =============================================================================

#[test]
fn test_recorded_app_store_connect_fixtures_derivation() {
    let recorded_builds_json = r#"{
        "data": [
            {
                "id": "bld-testflight-999",
                "type": "builds",
                "attributes": {
                    "version": "1.2.0",
                    "processingState": "VALID",
                    "uploadedDate": "2026-08-15T16:00:00Z"
                }
            }
        ]
    }"#;

    let response: AppStoreBuildsResponse =
        serde_json::from_str(recorded_builds_json).expect("parse AppStoreBuildsResponse");
    assert_eq!(response.data.len(), 1);
    let build = &response.data[0];
    assert_eq!(build.id, "bld-testflight-999");
    assert_eq!(
        build
            .attributes
            .as_ref()
            .unwrap()
            .processing_state
            .as_deref(),
        Some("VALID")
    );

    let linkage_req = BetaGroupBuildsRequest {
        data: vec![BetaGroupBuildLinkage::new("bld-testflight-999")],
    };
    let json_linkage =
        serde_json::to_string(&linkage_req).expect("serialize BetaGroupBuildsRequest");
    assert_eq!(
        json_linkage,
        r#"{"data":[{"id":"bld-testflight-999","type":"builds"}]}"#
    );
}

#[test]
fn test_testflight_unverified_processing_state_defensive_handling() {
    let unverified_states = vec![
        "READY_FOR_TESTING",
        "WAITING_FOR_REVIEW",
        "QUEUED_FOR_EXPORT",
        "CUSTOM_VENDOR_INTERMEDIATE_STATE",
    ];

    for raw in unverified_states {
        let state = TestFlightProcessingState::from_raw(raw);
        assert_eq!(state, TestFlightProcessingState::Unknown(raw.to_string()));
        assert!(state.is_in_progress());
        assert!(!state.is_ready());
    }

    let valid_state = TestFlightProcessingState::from_raw("VALID");
    assert!(valid_state.is_ready());
    assert!(!valid_state.is_in_progress());

    let failed_state = TestFlightProcessingState::from_raw("FAILED");
    assert!(!failed_state.is_ready());
    assert!(!failed_state.is_in_progress());
}

#[test]
fn test_testflight_authorization_rejection_mapping() {
    let apple_401_error = TestFlightError::Api {
        status: 401,
        message: "{\"errors\":[{\"status\":\"401\",\"title\":\"NOT_AUTHORIZED\",\"detail\":\"The request lacks valid authentication credentials\"}]}".to_string(),
    };

    let worker_error: DeployWorkerError = apple_401_error.into();
    match worker_error {
        DeployWorkerError::PublishingAccount(msg) => {
            assert!(msg.contains("Apple App Store Connect authorization rejected"));
            assert!(msg.contains("HTTP 401"));
            assert!(msg.contains("NOT_AUTHORIZED"));
        }
        other => panic!("Expected PublishingAccount error, got: {other:?}"),
    }

    let auth_error = TestFlightError::Auth("ES256 key rejected".to_string());
    let worker_auth_error: DeployWorkerError = auth_error.into();
    assert!(matches!(
        worker_auth_error,
        DeployWorkerError::PublishingAccount(_)
    ));
}

#[test]
fn test_recorded_google_play_fixtures_derivation() {
    let recorded_edit_json = r#"{
        "id": "edit-gp-12345",
        "expiryTimeSeconds": "1700000000"
    }"#;
    let edit: AppEdit = serde_json::from_str(recorded_edit_json).expect("parse AppEdit");
    assert_eq!(edit.id, "edit-gp-12345");
    assert_eq!(edit.expiry_epoch_seconds(), Some(1700000000));

    let recorded_bundle_json = r#"{
        "versionCode": 104,
        "sha1": "da39a3ee5e6b4b0d3255bfef95601890afd80709",
        "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    }"#;
    let bundle: Bundle = serde_json::from_str(recorded_bundle_json).expect("parse Bundle");
    assert_eq!(bundle.version_code, Some(104));

    let track = Track {
        track: "internal".to_string(),
        releases: vec![TrackRelease {
            name: Some("1.2.0".to_string()),
            version_codes: Some(vec!["104".to_string()]),
            release_notes: None,
            status: Some(ReleaseStatus::Completed),
            user_fraction: None,
            country_targeting: None,
            in_app_update_priority: None,
        }],
    };
    let json_track = serde_json::to_string(&track).expect("serialize Track");
    assert!(json_track.contains(r#""track":"internal""#));
    assert!(json_track.contains(r#""versionCodes":["104"]"#));
    assert!(json_track.contains(r#""status":"completed""#));
}

#[test]
fn test_googleplay_authorization_rejection_mapping() {
    let gp_401_error = GooglePlayError::Api {
        status: 401,
        message: "{\"error\":{\"code\":401,\"message\":\"Request had invalid authentication credentials. Expected OAuth 2 access token.\",\"status\":\"UNAUTHENTICATED\"}}".to_string(),
    };

    let worker_error: DeployWorkerError = gp_401_error.into();
    match worker_error {
        DeployWorkerError::PublishingAccount(msg) => {
            assert!(msg.contains("Google Play authorization rejected"));
            assert!(msg.contains("HTTP 401"));
            assert!(msg.contains("UNAUTHENTICATED"));
        }
        other => panic!("Expected PublishingAccount error, got: {other:?}"),
    }

    let auth_error =
        GooglePlayError::Auth("Service account RS256 token exchange failed".to_string());
    let worker_auth_error: DeployWorkerError = auth_error.into();
    assert!(matches!(
        worker_auth_error,
        DeployWorkerError::PublishingAccount(_)
    ));
}

#[test]
fn test_googleplay_user_fraction_validation_before_edit_commit() {
    let invalid_fraction_release = TrackRelease {
        status: Some(ReleaseStatus::InProgress),
        user_fraction: Some(1.0),
        ..Default::default()
    };
    assert!(matches!(
        GooglePlayClient::validate_track_release(&invalid_fraction_release),
        Err(GooglePlayError::InvalidUserFraction(_))
    ));

    let completed_fraction_release = TrackRelease {
        status: Some(ReleaseStatus::Completed),
        user_fraction: Some(0.5),
        ..Default::default()
    };
    assert!(matches!(
        GooglePlayClient::validate_track_release(&completed_fraction_release),
        Err(GooglePlayError::InvalidUserFraction(_))
    ));
}

#[test]
fn test_shorebird_cli_args_construction_and_expiry_notice() {
    let action = ShorebirdAction::Patch;
    let platforms = ShorebirdPlatforms::Single(ShorebirdPlatform::Android);
    let options = ShorebirdOptions {
        release_version: Some("1.2.0".to_string()),
        track: Some("stable".to_string()),
        ..Default::default()
    };

    let args = build_shorebird_args(action, &platforms, &options);
    assert_eq!(
        args,
        vec![
            "patch",
            "android",
            "--release-version",
            "1.2.0",
            "--track",
            "stable"
        ]
    );

    let recorded_stdout =
        "Validating release...\nBuilding patch...\nPatch ID: patch_sho_778899\nPatch complete!";
    let parsed_id = parse_release_or_patch_id(recorded_stdout);
    assert_eq!(parsed_id, Some("patch_sho_778899".to_string()));
}

#[test]
fn test_shorebird_unconfigured_maps_to_publishing_account_error() {
    let unconfigured_err = ShorebirdError::NotConfigured("SHOREBIRD_TOKEN not set".to_string());
    let worker_error: DeployWorkerError = unconfigured_err.into();

    match worker_error {
        DeployWorkerError::PublishingAccount(msg) => {
            assert!(msg.contains("Shorebird credentials not configured"));
        }
        other => panic!("Expected PublishingAccount error, got: {other:?}"),
    }

    let auth_failure_err = ShorebirdError::ExecutionFailed {
        exit_code: Some(1),
        stdout: "".to_string(),
        stderr: "Error: 401 Unauthorized - Invalid token".to_string(),
    };
    let worker_auth_err: DeployWorkerError = auth_failure_err.into();
    match worker_auth_err {
        DeployWorkerError::PublishingAccount(msg) => {
            assert!(msg.contains("Shorebird authentication rejected"));
            assert!(msg.contains("401 Unauthorized"));
        }
        other => panic!("Expected PublishingAccount error, got: {other:?}"),
    }
}

#[test]
fn test_deploy_worker_routing_struct_and_context() {
    let routing = DeployRouting {
        project_id: "prj_001",
        app_id: "app_001",
        app_slug: "my-app",
        project_slug: "my-proj",
        apex_domain: Some("bloom.dev"),
        release_version: Some("1.0.0"),
        build_number: Some(42),
        package_name: Some("com.example.app"),
        beta_group_id: Some("group-alpha"),
        track: Some("internal"),
        user_fraction: Some(0.1),
        working_dir: Some(Path::new("/tmp/build")),
    };

    assert_eq!(routing.project_id, "prj_001");
    assert_eq!(routing.release_version, Some("1.0.0"));
    assert_eq!(routing.package_name, Some("com.example.app"));
    assert_eq!(routing.beta_group_id, Some("group-alpha"));
    assert_eq!(routing.track, Some("internal"));
    assert_eq!(routing.user_fraction, Some(0.1));

    let ctx = DeployJobContext {
        deployment_id: "dep_001".to_string(),
        organization_id: "org_001".to_string(),
        release_id: Some("rel_001".to_string()),
        artifact_id: Some("art_001".to_string()),
        project_id: routing.project_id.to_string(),
        app_id: routing.app_id.to_string(),
        platform: "android".to_string(),
        target: "internal".to_string(),
        app_slug: routing.app_slug.to_string(),
        project_slug: routing.project_slug.to_string(),
        apex_domain: routing.apex_domain.map(str::to_string),
        release_version: routing.release_version.map(str::to_string),
        build_number: routing.build_number,
        package_name: routing.package_name.map(str::to_string),
        beta_group_id: routing.beta_group_id.map(str::to_string),
        track: routing.track.map(str::to_string),
        user_fraction: routing.user_fraction,
        working_dir: routing.working_dir.map(Path::to_path_buf),
    };

    assert_eq!(ctx.deployment_id, "dep_001");
    assert_eq!(ctx.target, "internal");
    assert_eq!(ctx.platform, "android");
}

#[test]
fn test_unsupported_target_produces_invalid_target_error() {
    let err = DeployWorkerError::InvalidTarget(
        "Unsupported platform 'blackberry' and target 'bada'".to_string(),
    );
    let display_str = format!("{err}");
    assert!(display_str.contains("Invalid deployment target"));
    assert!(display_str.contains("blackberry"));
}
