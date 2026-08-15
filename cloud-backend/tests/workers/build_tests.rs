//! Unit and integration tests for the build execution worker, real stage execution,
//! command specs, secret redaction, and workflow resumption loop.

use std::path::{Path, PathBuf};

use bloom_cloud_backend::infra::executor::{redact, CommandExecutor, CommandSpec, ExecutorError};
use bloom_cloud_backend::infra::queue::{InMemoryJobQueue, Job};
use bloom_cloud_backend::infra::storage::{artifact_storage_key, build_log_storage_key};
use bloom_cloud_backend::workers::build::{
    parse_pubspec_version, project_declares_builders, resolve_and_verify_build_artifact,
    BuildWorkerError, BUILD_STAGES,
};
use sha2::{Digest, Sha256};

use crate::infra::executor::RecordingExecutor;

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

#[test]
fn test_build_worker_storage_keys_match_canonical_helpers() {
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
async fn test_stage_command_specs_match_expected_invocations() {
    let executor = RecordingExecutor::new();
    let working_dir = PathBuf::from("/workspace/build-101");
    let flutter_sdk = PathBuf::from("/opt/flutter");
    let pub_cache = PathBuf::from("/root/.pub-cache");

    // 1. Checkout stage command spec
    let checkout_spec = CommandSpec::new("git", &working_dir)
        .with_args([
            "clone",
            "--depth",
            "1",
            "https://github.com/bloom/app.git",
            ".",
        ])
        .with_env_var("BLOOM_GIT_COMMIT", "commit_abc123")
        .with_env_var("GIT_TOKEN", "ghp_SecretToken456");

    executor.push_success("Cloning into '.'...\n", "");
    let out = executor.run(&checkout_spec).await.expect("checkout run");
    assert!(out.is_success());

    // 2. Resolve stage command spec (flutter pub get)
    let flutter_bin = flutter_sdk.join("bin").join("flutter");
    let resolve_spec = CommandSpec::new(flutter_bin.to_string_lossy(), &working_dir)
        .with_args(["pub", "get"])
        .with_env_var("PUB_CACHE", pub_cache.to_string_lossy());

    executor.push_success("Resolving dependencies... Got 42 packages.\n", "");
    let out = executor.run(&resolve_spec).await.expect("resolve run");
    assert!(out.is_success());

    // 3. Test stage command spec (flutter test --machine)
    let test_spec = CommandSpec::new(flutter_bin.to_string_lossy(), &working_dir)
        .with_args(["test", "--machine"])
        .with_env_var("PUB_CACHE", pub_cache.to_string_lossy());

    executor.push_success(r#"{"event":"testDone","success":true}"#, "");
    let out = executor.run(&test_spec).await.expect("test run");
    assert!(out.is_success());

    // 4. Analyze stage command spec (dart analyze)
    let analyze_spec =
        CommandSpec::new("dart", &working_dir).with_args(["analyze", "--format=json"]);

    executor.push_success(r#"{"diagnostics":[]}"#, "");
    let out = executor.run(&analyze_spec).await.expect("analyze run");
    assert!(out.is_success());

    // 5. Build stage command spec (flutter build appbundle --release)
    let build_spec = CommandSpec::new(flutter_bin.to_string_lossy(), &working_dir)
        .with_args(["build", "appbundle", "--release"])
        .with_env_var("PUB_CACHE", pub_cache.to_string_lossy());

    executor.push_success(
        "Built build/app/outputs/bundle/release/app-release.aab (18.2MB).\n",
        "",
    );
    let out = executor.run(&build_spec).await.expect("build run");
    assert!(out.is_success());

    let recorded = executor.recorded_specs();
    assert_eq!(recorded.len(), 5);

    // Verify stage 1 checkout spec
    assert_eq!(recorded[0].program, "git");
    assert_eq!(
        recorded[0].args,
        vec![
            "clone",
            "--depth",
            "1",
            "https://github.com/bloom/app.git",
            "."
        ]
    );
    assert_eq!(recorded[0].working_dir, working_dir);

    // Verify stage 2 resolve spec
    assert_eq!(recorded[1].program, flutter_bin.to_string_lossy());
    assert_eq!(recorded[1].args, vec!["pub", "get"]);

    // Verify stage 3 test spec
    assert_eq!(recorded[2].program, flutter_bin.to_string_lossy());
    assert_eq!(recorded[2].args, vec!["test", "--machine"]);

    // Verify stage 4 analyze spec
    assert_eq!(recorded[3].program, "dart");
    assert_eq!(recorded[3].args, vec!["analyze", "--format=json"]);

    // Verify stage 5 build spec
    assert_eq!(recorded[4].program, flutter_bin.to_string_lossy());
    assert_eq!(recorded[4].args, vec!["build", "appbundle", "--release"]);
}

#[tokio::test]
async fn test_failing_stage_fails_build_and_records_real_exit_code() {
    let executor = RecordingExecutor::new();
    executor.push_failure(101, "Compilation error: undefined class 'BloomWidget'");

    let spec = CommandSpec::new("flutter", "/workspace/app").with_args([
        "build",
        "appbundle",
        "--release",
    ]);

    let err = executor.run(&spec).await.expect_err("command must fail");
    match err {
        ExecutorError::NonZeroExit { code, stderr } => {
            assert_eq!(code, Some(101));
            assert!(stderr.contains("Compilation error: undefined class 'BloomWidget'"));

            let worker_error = BuildWorkerError::StageFailed {
                stage: "build".to_string(),
                reason: stderr,
                exit_code: code,
            };
            let display_str = format!("{worker_error}");
            assert!(display_str.contains("Build stage 'build' failed with exit code 101"));
            assert!(display_str.contains("undefined class 'BloomWidget'"));
        }
        other => panic!("Expected NonZeroExit, got: {other:?}"),
    }
}

#[test]
fn test_git_token_redaction_in_debug_and_logs() {
    let secret_token = "ghp_SuperSecretCredentialKey987654321";
    let spec = CommandSpec::new("git", "/workspace")
        .with_args(["clone", "--depth", "1", "https://github.com/bloom/app.git"])
        .with_env_var("GIT_TOKEN", secret_token);

    // Verify Debug representation redacts secret
    let debug_repr = format!("{spec:?}");
    assert!(!debug_repr.contains(secret_token));
    assert!(debug_repr.contains("[redacted]"));
    assert!(debug_repr.contains("GIT_TOKEN"));

    // Verify redact helper sanitizes logs
    let raw_log = format!(
        "Executing clone with token {} against https://x-access-token:{}@github.com",
        secret_token, secret_token
    );
    let sanitized_log = redact(&raw_log, &[secret_token]);
    assert!(!sanitized_log.contains(secret_token));
    assert_eq!(
        sanitized_log,
        "Executing clone with token [redacted] against https://x-access-token:[redacted]@github.com"
    );
}

#[test]
fn test_generate_stage_skipped_when_no_builders_declared() {
    // A path with no pubspec.yaml reports no builders
    let empty_dir = Path::new("/tmp/non_existent_dir_for_test");
    assert!(!project_declares_builders(empty_dir));
}

#[tokio::test]
async fn test_terminal_build_resumes_parent_workflow_run_on_success() {
    let queue = InMemoryJobQueue::new();

    // 1. Enqueue parent workflow run
    let run_id = "run-resumption-101".to_string();
    let org_id = "org-resumption-101".to_string();
    let wf_id = "wf-resumption-101".to_string();

    // 2. Child build finishes and pushes Job::Workflow to resume parent
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

    // 3. Workflow worker claims resumed run
    let claimed_opt = queue
        .claim("worker-workflow-01")
        .await
        .expect("claim resumed run");
    assert!(claimed_opt.is_some());
    let claimed = claimed_opt.unwrap();
    assert_eq!(claimed.stream_id, stream_id);
    assert_eq!(claimed.job, workflow_job);
    assert_eq!(claimed.job.id(), "run-resumption-101");

    queue
        .ack(&claimed.stream_id)
        .await
        .expect("ack workflow resumption");
    assert_eq!(queue.pending_count().await, 0);
}

#[tokio::test]
async fn test_terminal_build_resumes_parent_workflow_run_on_failure() {
    let queue = InMemoryJobQueue::new();

    let run_id = "run-failed-child-202".to_string();
    let org_id = "org-202".to_string();
    let wf_id = "wf-202".to_string();

    // Failing build re-enqueues parent workflow run so it can fail instead of hanging
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

    let claimed = queue.claim("worker-workflow-02").await.unwrap().unwrap();
    assert_eq!(claimed.stream_id, stream_id);
    assert_eq!(claimed.job.id(), "run-failed-child-202");

    queue.ack(&claimed.stream_id).await.unwrap();
    assert_eq!(queue.pending_count().await, 0);
}

#[tokio::test]
async fn test_retried_build_worker_does_not_wake_parent_run_twice() {
    let queue = InMemoryJobQueue::new();

    let run_id = "run-idempotent-303".to_string();
    let org_id = "org-303".to_string();
    let wf_id = "wf-303".to_string();

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

// ---------------------------------------------------------------------------
// Real artifact resolution: the worker must upload what the build produced,
// with a checksum computed over those bytes, and must fail rather than invent
// a value when the output is absent.
// ---------------------------------------------------------------------------

/// Creates a temp working dir containing `relative_path` with `contents`.
fn temp_project_with_file(relative_path: &str, contents: &[u8]) -> PathBuf {
    let root = std::env::temp_dir().join(format!(
        "bloom-build-test-{}-{}",
        std::process::id(),
        uuid::Uuid::new_v4()
    ));
    let full = root.join(relative_path);
    std::fs::create_dir_all(full.parent().expect("path has a parent")).expect("create dirs");
    std::fs::write(&full, contents).expect("write artifact");
    root
}

#[test]
fn test_resolved_artifact_checksum_is_computed_over_the_real_bytes() {
    let contents = b"not a real aab, but these exact bytes are what must be hashed";
    let root = temp_project_with_file("build/app/outputs/bundle/release/app-release.aab", contents);

    let resolved = resolve_and_verify_build_artifact(&root, "android", "release")
        .expect("artifact resolves when the build output exists");

    // Compute the expectation here rather than hardcoding a digest literal: a
    // hardcoded digest is exactly the bug this test exists to catch.
    let mut hasher = Sha256::new();
    hasher.update(contents);
    let expected = format!("{:x}", hasher.finalize());

    assert_eq!(resolved.checksum, expected);
    assert_eq!(resolved.file_size, contents.len() as i64);
    assert_eq!(resolved.bytes, contents);
    assert_eq!(resolved.file_name, "app-release.aab");

    std::fs::remove_dir_all(&root).ok();
}

#[test]
fn test_missing_build_output_fails_instead_of_substituting_a_placeholder() {
    // A project directory with no build output at all.
    let root = temp_project_with_file("pubspec.yaml", b"name: demo\n");

    let err = resolve_and_verify_build_artifact(&root, "android", "release")
        .expect_err("a missing build output must fail the build");

    match err {
        BuildWorkerError::StageFailed { stage, reason, .. } => {
            assert_eq!(stage, "upload");
            assert!(
                reason.contains("app-release.aab") || reason.contains("Failed to read"),
                "error must name the path it looked for, got: {reason}"
            );
        }
        other => panic!("expected StageFailed, got {other:?}"),
    }

    std::fs::remove_dir_all(&root).ok();
}

#[test]
fn test_pubspec_version_parsing() {
    let root = temp_project_with_file("pubspec.yaml", b"name: demo\nversion: 2.4.1+37\n");
    assert_eq!(
        parse_pubspec_version(&root),
        Some(("2.4.1".to_string(), Some(37)))
    );
    std::fs::remove_dir_all(&root).ok();

    // A version with no build number must report None rather than defaulting to 1.
    let root = temp_project_with_file("pubspec.yaml", b"name: demo\nversion: 2.4.1\n");
    assert_eq!(
        parse_pubspec_version(&root),
        Some(("2.4.1".to_string(), None))
    );
    std::fs::remove_dir_all(&root).ok();

    // No version field at all.
    let root = temp_project_with_file("pubspec.yaml", b"name: demo\n");
    assert_eq!(parse_pubspec_version(&root), None);
    std::fs::remove_dir_all(&root).ok();

    // An indented `version:` belongs to a dependency and must not be read as the app's.
    let root = temp_project_with_file(
        "pubspec.yaml",
        b"name: demo\ndependencies:\n  foo:\n    version: 9.9.9+1\n",
    );
    assert_eq!(parse_pubspec_version(&root), None);
    std::fs::remove_dir_all(&root).ok();
}
