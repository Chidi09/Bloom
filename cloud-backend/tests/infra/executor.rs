//! Unit tests for CommandExecutor, LocalExecutor, ContainerExecutor, and RecordingExecutor.

use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use async_trait::async_trait;
use bloom_cloud_backend::infra::executor::{
    redact, CommandExecutor, CommandOutput, CommandSpec, ContainerExecutor, ExecutorError,
    LocalExecutor,
};

/// Scriptable test double for [`CommandExecutor`] that records invocations
/// and returns predetermined outputs.
#[derive(Clone, Default)]
pub struct RecordingExecutor {
    recorded: Arc<Mutex<Vec<CommandSpec>>>,
    responses: Arc<Mutex<Vec<Result<CommandOutput, ExecutorError>>>>,
}

impl RecordingExecutor {
    /// Creates a new `RecordingExecutor` with empty call history and no queued responses.
    pub fn new() -> Self {
        Self {
            recorded: Arc::new(Mutex::new(Vec::new())),
            responses: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Appends a response to return from subsequent [`CommandExecutor::run`] calls.
    pub fn push_response(&self, res: Result<CommandOutput, ExecutorError>) {
        self.responses.lock().unwrap().push(res);
    }

    /// Helper to enqueue a successful command output response.
    pub fn push_success(&self, stdout: impl Into<String>, stderr: impl Into<String>) {
        self.push_response(Ok(CommandOutput {
            exit_code: Some(0),
            stdout: stdout.into(),
            stderr: stderr.into(),
            duration: Duration::from_millis(10),
        }));
    }

    /// Helper to enqueue a non-zero exit error response.
    pub fn push_failure(&self, code: i32, stderr: impl Into<String>) {
        self.push_response(Err(ExecutorError::NonZeroExit {
            code: Some(code),
            stderr: stderr.into(),
        }));
    }

    /// Returns a clone of all recorded command specifications.
    pub fn recorded_specs(&self) -> Vec<CommandSpec> {
        self.recorded.lock().unwrap().clone()
    }

    /// Returns the number of commands executed through this executor.
    pub fn call_count(&self) -> usize {
        self.recorded.lock().unwrap().len()
    }
}

#[async_trait]
impl CommandExecutor for RecordingExecutor {
    async fn run(&self, spec: &CommandSpec) -> Result<CommandOutput, ExecutorError> {
        self.recorded.lock().unwrap().push(spec.clone());

        let mut responses = self.responses.lock().unwrap();
        if !responses.is_empty() {
            responses.remove(0)
        } else {
            Ok(CommandOutput {
                exit_code: Some(0),
                stdout: String::new(),
                stderr: String::new(),
                duration: Duration::from_millis(1),
            })
        }
    }
}

#[tokio::test]
async fn test_recording_executor_records_specs_and_returns_scripted_output() {
    let executor = RecordingExecutor::new();
    executor.push_success("Flutter 3.24.1 • channel stable\n", "");

    let spec = CommandSpec::new("flutter", "/tmp/project")
        .with_arg("--version")
        .with_env_var("GIT_TOKEN", "secret123");

    let output = executor.run(&spec).await.expect("successful run");
    assert_eq!(output.stdout, "Flutter 3.24.1 • channel stable\n");
    assert!(output.is_success());

    let recorded = executor.recorded_specs();
    assert_eq!(recorded.len(), 1);
    assert_eq!(recorded[0].program, "flutter");
    assert_eq!(recorded[0].args, vec!["--version".to_string()]);
    assert_eq!(recorded[0].working_dir, PathBuf::from("/tmp/project"));
}

#[tokio::test]
async fn test_local_executor_successful_run() {
    let executor = LocalExecutor::new();
    let spec = CommandSpec::new("/bin/echo", "/tmp")
        .with_arg("hello bloom")
        .with_timeout(Duration::from_secs(5));

    let output = executor.run(&spec).await.expect("command succeeds");
    assert_eq!(output.exit_code, Some(0));
    assert!(output.stdout.contains("hello bloom"));
    assert!(output.is_success());
}

#[tokio::test]
async fn test_local_executor_non_zero_exit() {
    let executor = LocalExecutor::new();
    let spec = CommandSpec::new("/bin/sh", "/tmp")
        .with_args(["-c", "echo 'something went wrong' >&2; exit 42"])
        .with_timeout(Duration::from_secs(5));

    let err = executor.run(&spec).await.expect_err("command must fail");
    match err {
        ExecutorError::NonZeroExit { code, stderr } => {
            assert_eq!(code, Some(42));
            assert!(stderr.contains("something went wrong"));
        }
        other => panic!("Expected NonZeroExit, got: {other:?}"),
    }
}

#[tokio::test]
async fn test_local_executor_secret_redaction_in_stderr() {
    let secret = "ghp_SuperSecretGitToken98765";
    let executor = LocalExecutor::new();

    let spec = CommandSpec::new("/bin/sh", "/tmp")
        .with_args([
            "-c",
            "echo \"error accessing repo with $MY_SECRET\" >&2; exit 1",
        ])
        .with_env_var("MY_SECRET", secret)
        .with_timeout(Duration::from_secs(5));

    let err = executor.run(&spec).await.expect_err("command fails");
    match err {
        ExecutorError::NonZeroExit { stderr, .. } => {
            assert!(!stderr.contains(secret));
            assert!(stderr.contains("[redacted]"));
        }
        other => panic!("Expected NonZeroExit, got: {other:?}"),
    }
}

#[test]
fn test_command_spec_debug_redacts_environment_values() {
    let spec = CommandSpec::new("git", "/workspace")
        .with_args(["clone", "https://github.com/org/repo"])
        .with_env_var("GITHUB_TOKEN", "ghp_TopSecretCredential123")
        .with_env_var("KEY_PASSWORD", "SuperSecurePassword!");

    let debug_repr = format!("{spec:?}");
    assert!(!debug_repr.contains("ghp_TopSecretCredential123"));
    assert!(!debug_repr.contains("SuperSecurePassword!"));
    assert!(debug_repr.contains("GITHUB_TOKEN"));
    assert!(debug_repr.contains("KEY_PASSWORD"));
    assert!(debug_repr.contains("[redacted]"));
}

#[test]
fn test_redact_helper_function() {
    let text =
        "Failed to clone https://x-access-token:ghp_123456@github.com/repo with key my_cert_pw";
    let secrets = &["ghp_123456", "my_cert_pw"];

    let sanitized = redact(text, secrets);
    assert_eq!(
        sanitized,
        "Failed to clone https://x-access-token:[redacted]@github.com/repo with key [redacted]"
    );
}

#[test]
fn test_container_executor_argument_building() {
    let container_exec = ContainerExecutor::new("ghcr.io/bloom/flutter-builder:3.24.1")
        .with_runtime_binary("podman")
        .with_volume_mount("/host/cache", "/root/.pub-cache")
        .with_extra_flags(["--cap-drop=ALL", "--memory=4g"]);

    let spec = CommandSpec::new("flutter", "/workspace/app")
        .with_args(["build", "apk", "--release"])
        .with_env_var("PUB_CACHE", "/root/.pub-cache");

    let args = container_exec.build_container_args(&spec);

    assert_eq!(args[0], "run");
    assert!(args.contains(&"--rm".to_string()));
    assert!(args.contains(&"-i".to_string()));
    assert!(args.contains(&"-v".to_string()));
    assert!(args.contains(&"/host/cache:/root/.pub-cache".to_string()));
    assert!(args.contains(&"-w".to_string()));
    assert!(args.contains(&"/workspace/app".to_string()));
    assert!(args.contains(&"-e".to_string()));
    assert!(args.contains(&"PUB_CACHE=/root/.pub-cache".to_string()));
    assert!(args.contains(&"--cap-drop=ALL".to_string()));
    assert!(args.contains(&"--memory=4g".to_string()));
    assert!(args.contains(&"ghcr.io/bloom/flutter-builder:3.24.1".to_string()));
    assert!(args.contains(&"flutter".to_string()));
}

/// The scripted-failure and call-counting helpers are the surface the workflow and build
/// workers drive their tests through, so they are exercised here to keep them honest: a
/// queued failure must surface as the exact error that was scripted, and every call must
/// be counted whether it succeeded or failed.
#[tokio::test]
async fn recording_executor_scripts_failures_and_counts_every_call() {
    let exec = RecordingExecutor::new();
    exec.push_success("ok", "");
    exec.push_failure(17, "gradle daemon died");

    let spec = CommandSpec::new("flutter", "/workspace/app").with_args(["build", "apk"]);

    assert!(exec.run(&spec).await.is_ok());

    match exec.run(&spec).await {
        Err(ExecutorError::NonZeroExit { code, stderr }) => {
            assert_eq!(code, Some(17));
            assert_eq!(stderr, "gradle daemon died");
        }
        other => panic!("Expected the scripted NonZeroExit, got: {other:?}"),
    }

    // Both the successful and the failed run are recorded; a worker asserting on the
    // commands it issued must see the failing one too.
    assert_eq!(exec.call_count(), 2);
    assert_eq!(exec.recorded_specs().len(), 2);
}
