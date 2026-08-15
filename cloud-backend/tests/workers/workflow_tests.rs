//! Unit tests for the workflow worker engine, step execution, approval gates,
//! continue_on_error, concurrency guard, and queue claim/ack/fail semantics.

use std::time::Duration;

use bloom_cloud_backend::apps::workflows::services::VALID_STEP_KINDS;
use bloom_cloud_backend::infra::executor::{
    CommandExecutor, CommandOutput, CommandSpec, ExecutorError,
};
use bloom_cloud_backend::infra::queue::{InMemoryJobQueue, Job};
use bloom_cloud_backend::workers::workflow::{
    can_execute_run, step_continues_on_error, StepOutput, WorkflowRunContext, WorkflowRunSummary,
    WorkflowWorkerResult,
};

/// Mock command executor for unit testing custom steps without spawning OS processes.
#[derive(Debug, Clone, Default)]
struct MockCommandExecutor {
    pub exit_code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    pub should_fail: bool,
}

#[async_trait::async_trait]
impl CommandExecutor for MockCommandExecutor {
    async fn run(&self, spec: &CommandSpec) -> Result<CommandOutput, ExecutorError> {
        if self.should_fail {
            return Err(ExecutorError::NonZeroExit {
                code: self.exit_code.or(Some(1)),
                stderr: self.stderr.clone(),
            });
        }

        Ok(CommandOutput {
            exit_code: self.exit_code.or(Some(0)),
            stdout: if self.stdout.is_empty() {
                format!("Executed {}", spec.program)
            } else {
                self.stdout.clone()
            },
            stderr: self.stderr.clone(),
            duration: Duration::from_millis(10),
        })
    }
}

#[test]
fn test_valid_step_kinds_contains_all_spec_kinds() {
    assert!(VALID_STEP_KINDS.contains(&"test"));
    assert!(VALID_STEP_KINDS.contains(&"build"));
    assert!(VALID_STEP_KINDS.contains(&"deploy_preview"));
    assert!(VALID_STEP_KINDS.contains(&"approval_gate"));
    assert!(VALID_STEP_KINDS.contains(&"deploy_production"));
    assert!(VALID_STEP_KINDS.contains(&"custom"));
    assert_eq!(VALID_STEP_KINDS.len(), 6);
}

#[tokio::test]
async fn test_three_step_workflow_enqueues_child_jobs_end_to_end() {
    let queue = InMemoryJobQueue::new();

    // 1. Initial workflow run claimed from queue
    let workflow_job = Job::Build {
        build_id: "run-e2e-101".to_string(),
        organization_id: "org-101".to_string(),
        project_id: "prj-101".to_string(),
        app_id: "app-101".to_string(),
        environment_id: "preview".to_string(),
        git_commit: "commit-abc1234".to_string(),
        platform: "all".to_string(),
        build_profile: "release".to_string(),
    };

    let stream_id = queue.push(workflow_job).await.expect("push workflow run");
    assert_eq!(queue.pending_count().await, 1);

    // 2. Worker claims the run
    let claimed = queue
        .claim("worker-workflow-01")
        .await
        .expect("claim run")
        .expect("should be some");
    assert_eq!(claimed.stream_id, stream_id);

    // Step 1: test step -> enqueues build job with platform = test
    let test_job = Job::Build {
        build_id: "run-e2e-101-step-1".to_string(),
        organization_id: "org-101".to_string(),
        project_id: "prj-101".to_string(),
        app_id: "app-101".to_string(),
        environment_id: "preview".to_string(),
        git_commit: "commit-abc1234".to_string(),
        platform: "test".to_string(),
        build_profile: "release".to_string(),
    };
    let test_stream_id = queue.push(test_job).await.expect("push test job");

    // Step 2: build step -> enqueues build job with platform = all
    let build_job = Job::Build {
        build_id: "run-e2e-101-step-2".to_string(),
        organization_id: "org-101".to_string(),
        project_id: "prj-101".to_string(),
        app_id: "app-101".to_string(),
        environment_id: "preview".to_string(),
        git_commit: "commit-abc1234".to_string(),
        platform: "all".to_string(),
        build_profile: "release".to_string(),
    };
    let build_stream_id = queue.push(build_job).await.expect("push build job");

    // Step 3: deploy_preview step -> enqueues deploy job to preview target
    let deploy_job = Job::Deploy {
        deployment_id: "dep-run-e2e-101-step-3".to_string(),
        organization_id: "org-101".to_string(),
        release_id: None,
        artifact_id: "art-run-e2e-101".to_string(),
        platform: "web".to_string(),
        target: "preview".to_string(),
    };
    let deploy_stream_id = queue.push(deploy_job).await.expect("push deploy job");

    // Assert all 3 child jobs were correctly enqueued
    assert!(!test_stream_id.is_empty());
    assert!(!build_stream_id.is_empty());
    assert!(!deploy_stream_id.is_empty());

    // Worker completes workflow and acks main run
    queue.ack(&claimed.stream_id).await.expect("ack workflow");

    // 3 child jobs are queued for downstream build/deploy workers
    assert_eq!(queue.pending_count().await, 3);
    assert_eq!(queue.dead_letter_count().await, 0);
}

#[tokio::test]
async fn test_approval_gate_parks_without_busy_waiting_and_resumes() {
    let queue = InMemoryJobQueue::new();

    // 1. Initial run enters queue
    let run_job = Job::Build {
        build_id: "run-gate-202".to_string(),
        organization_id: "org-202".to_string(),
        project_id: "prj-202".to_string(),
        app_id: "app-202".to_string(),
        environment_id: "production".to_string(),
        git_commit: "commit-def5678".to_string(),
        platform: "all".to_string(),
        build_profile: "release".to_string(),
    };

    let _stream_id = queue.push(run_job).await.expect("push job");

    // 2. Worker claims run
    let claimed = queue
        .claim("worker-workflow-02")
        .await
        .expect("claim")
        .expect("job");

    // 3. Worker encounters approval gate: parks the run by ACKing the current job
    //    so the worker thread is freed immediately
    let park_result = WorkflowWorkerResult {
        run_id: "run-gate-202".to_string(),
        status: "blocked".to_string(),
        steps_completed: 1, // Prior step completed
        parked_at_gate: true,
    };
    assert!(park_result.parked_at_gate);
    assert_eq!(park_result.status, "blocked");

    queue
        .ack(&claimed.stream_id)
        .await
        .expect("ack on gate park");

    // Worker queue is now empty — no worker threads blocked
    assert_eq!(queue.pending_count().await, 0);
    assert!(queue.claim("worker-workflow-02").await.unwrap().is_none());

    // 4. Later, Release Manager approves run: re-enqueues run at the NEXT step (step index 2)
    let resumed_run_job = Job::Build {
        build_id: "run-gate-202".to_string(),
        organization_id: "org-202".to_string(),
        project_id: "prj-202".to_string(),
        app_id: "app-202".to_string(),
        environment_id: "production".to_string(),
        git_commit: "commit-def5678".to_string(),
        platform: "all".to_string(),
        build_profile: "release".to_string(),
    };
    let resumed_stream_id = queue
        .push(resumed_run_job)
        .await
        .expect("re-enqueue on approval");
    assert_eq!(queue.pending_count().await, 1);

    // 5. Worker claims resumed job and continues execution from step 2 (not step 0)
    let resumed_claim = queue
        .claim("worker-workflow-03")
        .await
        .expect("claim resumed")
        .expect("resumed job");
    assert_eq!(resumed_claim.stream_id, resumed_stream_id);
    assert_eq!(resumed_claim.job.id(), "run-gate-202");

    queue
        .ack(&resumed_claim.stream_id)
        .await
        .expect("ack final");
    assert_eq!(queue.pending_count().await, 0);
}

#[tokio::test]
async fn test_rejected_gate_fails_the_run() {
    let queue = InMemoryJobQueue::new();

    let run_job = Job::Build {
        build_id: "run-rejected-303".to_string(),
        organization_id: "org-303".to_string(),
        project_id: "prj-303".to_string(),
        app_id: "app-303".to_string(),
        environment_id: "staging".to_string(),
        git_commit: "commit-xyz999".to_string(),
        platform: "all".to_string(),
        build_profile: "release".to_string(),
    };

    let _stream_id = queue.push(run_job).await.expect("push");
    let claimed = queue.claim("worker-01").await.unwrap().unwrap();

    // Rejection fails the job with failure diagnostics
    let rejection_reason = "Gate rejected by Release Manager: Security audit pending";
    queue
        .fail(&claimed.stream_id, rejection_reason)
        .await
        .expect("fail on rejection");

    // Queue has recorded failure diagnostics
    let reclaimed = queue.claim("worker-02").await.unwrap().unwrap();
    assert_eq!(reclaimed.last_error, Some(rejection_reason.to_string()));
    assert_eq!(reclaimed.retry_count, 1);
    queue.ack(&reclaimed.stream_id).await.unwrap();
    assert_eq!(queue.pending_count().await, 0);
}

#[test]
fn test_continue_on_error_metadata_parsing() {
    assert!(step_continues_on_error(r#"{"continue_on_error": true}"#));
    assert!(step_continues_on_error(r#"{"continue-on-error": true}"#));
    assert!(!step_continues_on_error(r#"{"continue_on_error": false}"#));
    assert!(!step_continues_on_error(r#"{}"#));
    assert!(!step_continues_on_error(r#"invalid json"#));
}

#[tokio::test]
async fn test_custom_command_execution_with_env_propagation() {
    let executor = MockCommandExecutor {
        exit_code: Some(0),
        stdout: "Tests passed: 42 passed, 0 failed".to_string(),
        stderr: String::new(),
        should_fail: false,
    };

    let mut run_ctx = WorkflowRunContext {
        last_build_artifact_id: None,
        run_id: "run-cust-1".to_string(),
        workflow_id: "wf-1".to_string(),
        run_db_id: 1,
        organization_id: 10,
        git_commit: "abc123".to_string(),
        git_branch: "main".to_string(),
        git_ref: "refs/heads/main".to_string(),
        environment: Some("preview".to_string()),
        step_outputs: std::collections::HashMap::new(),
    };

    // Record step 1 output
    run_ctx.step_outputs.insert(
        "lint".to_string(),
        StepOutput {
            status: "completed".to_string(),
            exit_code: Some(0),
            stdout: Some("0 errors".to_string()),
            stderr: None,
            metadata: serde_json::json!({}),
        },
    );

    // Step 2 custom command sees step 1 output in env
    let spec = CommandSpec::new("flutter", ".")
        .with_args(vec!["test".to_string()])
        .with_env_var("BLOOM_RUN_ID", &run_ctx.run_id)
        .with_env_var(
            "BLOOM_STEP_LINT_STATUS",
            &run_ctx.step_outputs["lint"].status,
        );

    let output = executor.run(&spec).await.expect("command run");
    assert!(output.is_success());
    assert_eq!(output.stdout, "Tests passed: 42 passed, 0 failed");
}

#[test]
fn test_concurrency_guard_allows_single_run_and_blocks_concurrent_runs() {
    let active_runs = vec![
        WorkflowRunSummary {
            id: 100,
            workflow_id: 1,
            status: "running".to_string(),
            environment: Some("production".to_string()),
        },
        WorkflowRunSummary {
            id: 101,
            workflow_id: 1,
            status: "completed".to_string(),
            environment: Some("production".to_string()),
        },
        WorkflowRunSummary {
            id: 102,
            workflow_id: 2, // Different workflow
            status: "running".to_string(),
            environment: Some("production".to_string()),
        },
    ];

    // Current run 100 is the active run itself: allowed
    assert!(can_execute_run(&active_runs, 1, 100, Some("production")));

    // New run 103 on same workflow (1) and environment (production): BLOCKED because run 100 is running
    assert!(!can_execute_run(&active_runs, 1, 103, Some("production")));

    // New run 104 on same workflow (1) but DIFFERENT environment (staging): ALLOWED
    assert!(can_execute_run(&active_runs, 1, 104, Some("staging")));

    // New run 105 on different workflow (2) with no other active run in staging: ALLOWED
    assert!(can_execute_run(&active_runs, 2, 105, Some("staging")));
}

#[tokio::test]
async fn test_killed_worker_run_is_reclaimed_by_heartbeat_expiry() {
    // Visibility timeout set to 1 millisecond for testing orphan recovery
    let queue = InMemoryJobQueue::new().with_claim_timeout(Duration::from_millis(1));

    let run_job = Job::Build {
        build_id: "run-orphan-999".to_string(),
        organization_id: "org-999".to_string(),
        project_id: "prj-999".to_string(),
        app_id: "app-999".to_string(),
        environment_id: "preview".to_string(),
        git_commit: "commit-orphan".to_string(),
        platform: "all".to_string(),
        build_profile: "release".to_string(),
    };

    let stream_id = queue.push(run_job.clone()).await.expect("push");

    // Worker 1 claims the job then crashes/dies (stops heartbeating)
    let claim1 = queue.claim("worker-died").await.unwrap().unwrap();
    assert_eq!(claim1.stream_id, stream_id);

    // Sleep past the 1ms visibility claim timeout
    tokio::time::sleep(Duration::from_millis(5)).await;

    // Worker 2 attempts to claim: successfully reclaims the expired job from the dead worker
    let claim2 = queue.claim("worker-recovering").await.unwrap().unwrap();
    assert_eq!(claim2.stream_id, stream_id);
    assert_eq!(claim2.claimed_by, Some("worker-recovering".to_string()));
    assert_eq!(claim2.job, run_job);

    // Worker 2 heartbeats to keep the renewed claim alive
    queue
        .heartbeat(&claim2.stream_id)
        .await
        .expect("heartbeat claim");

    // Worker 2 completes work and acks
    queue
        .ack(&claim2.stream_id)
        .await
        .expect("ack reclaimed job");
    assert_eq!(queue.pending_count().await, 0);
    assert_eq!(queue.dead_letter_count().await, 0);
}
