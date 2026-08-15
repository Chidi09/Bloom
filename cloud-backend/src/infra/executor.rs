//! Sandboxed command execution layer for Flutter builds and worker pipelines.
//!
//! # Architecture & Scope
//!
//! Provides the [`CommandExecutor`] trait for abstract process execution, separating
//! build stage execution logic from host process spawning. This ensures:
//! - Hermetic and deterministic unit testing without spawning real child processes.
//! - Sandboxed execution on local worker hosts ([`LocalExecutor`]) with active timeouts and process cleanup.
//! - Container-isolated execution ([`ContainerExecutor`]) for multi-tenant and secure worker runners.
//! - Mandatory secret and credential redaction across debug representations, stdout, and stderr.

use std::fmt;
use std::path::PathBuf;
use std::process::Stdio;
use std::time::{Duration, Instant};

use async_trait::async_trait;
use tokio::process::Command;
use tokio::time::timeout;

/// Default container runtime binary name.
pub const DEFAULT_CONTAINER_RUNTIME: &str = "docker";

/// Default per-command execution timeout (15 minutes).
pub const DEFAULT_COMMAND_TIMEOUT: Duration = Duration::from_secs(15 * 60);

/// Errors arising from command execution operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExecutorError {
    /// Failed to spawn the child process.
    Spawn(String),
    /// Command execution exceeded its allotted timeout and was killed.
    Timeout {
        /// The timeout limit in seconds that was exceeded.
        seconds: u64,
    },
    /// The command exited with a non-zero exit code.
    NonZeroExit {
        /// The exit code returned by the process, if available.
        code: Option<i32>,
        /// Captured standard error output, redacted of any sensitive tokens.
        stderr: String,
    },
    /// Low-level I/O error during process interaction or pipeline setup.
    Io(String),
}

impl fmt::Display for ExecutorError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ExecutorError::Spawn(msg) => write!(f, "Failed to spawn command: {msg}"),
            ExecutorError::Timeout { seconds } => {
                write!(f, "Command timed out after {seconds} seconds")
            }
            ExecutorError::NonZeroExit { code, stderr } => match code {
                Some(c) => write!(f, "Command failed with exit code {c}: {stderr}"),
                None => write!(f, "Command terminated by signal: {stderr}"),
            },
            ExecutorError::Io(msg) => write!(f, "Command I/O error: {msg}"),
        }
    }
}

impl std::error::Error for ExecutorError {}

impl From<std::io::Error> for ExecutorError {
    fn from(err: std::io::Error) -> Self {
        ExecutorError::Io(err.to_string())
    }
}

/// Specification of a command to be executed by a [`CommandExecutor`].
///
/// Contains the program name, arguments, working directory, environment overlays,
/// and execution timeout.
///
/// # Security & Secret Redaction
///
/// Implements [`fmt::Debug`] manually to ensure that environment variable values
/// (which may contain Git credentials, OAuth tokens, or signing keys) are never logged
/// in plaintext.
#[derive(Clone, PartialEq, Eq)]
pub struct CommandSpec {
    /// The binary or executable program to run.
    pub program: String,
    /// Positional command-line arguments.
    pub args: Vec<String>,
    /// Working directory in which to execute the command.
    pub working_dir: PathBuf,
    /// Key-value environment variable pairs to overlay on the execution environment.
    pub env: Vec<(String, String)>,
    /// Per-command timeout before terminating the child process.
    pub timeout: Duration,
}

impl CommandSpec {
    /// Creates a new `CommandSpec` builder with the specified program and working directory.
    pub fn new(program: impl Into<String>, working_dir: impl Into<PathBuf>) -> Self {
        Self {
            program: program.into(),
            args: Vec::new(),
            working_dir: working_dir.into(),
            env: Vec::new(),
            timeout: DEFAULT_COMMAND_TIMEOUT,
        }
    }

    /// Sets the command-line arguments.
    pub fn with_args<I, S>(mut self, args: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        self.args = args.into_iter().map(Into::into).collect();
        self
    }

    /// Appends a single argument to the command.
    pub fn with_arg(mut self, arg: impl Into<String>) -> Self {
        self.args.push(arg.into());
        self
    }

    /// Sets the working directory.
    pub fn with_working_dir(mut self, working_dir: impl Into<PathBuf>) -> Self {
        self.working_dir = working_dir.into();
        self
    }

    /// Sets the environment overlay variables.
    pub fn with_env<I, K, V>(mut self, env: I) -> Self
    where
        I: IntoIterator<Item = (K, V)>,
        K: Into<String>,
        V: Into<String>,
    {
        self.env = env.into_iter().map(|(k, v)| (k.into(), v.into())).collect();
        self
    }

    /// Appends a single environment key-value pair to the overlay.
    pub fn with_env_var(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.env.push((key.into(), value.into()));
        self
    }

    /// Sets the command execution timeout.
    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }
}

// Manual Debug implementation to redact secret environment variable values
impl fmt::Debug for CommandSpec {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let redacted_env: Vec<(&str, &str)> = self
            .env
            .iter()
            .map(|(k, _)| (k.as_str(), "[redacted]"))
            .collect();

        f.debug_struct("CommandSpec")
            .field("program", &self.program)
            .field("args", &self.args)
            .field("working_dir", &self.working_dir)
            .field("env", &redacted_env)
            .field("timeout", &self.timeout)
            .finish()
    }
}

/// Output captured from a completed command execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommandOutput {
    /// Process exit code, or `None` if terminated by an unhandled signal.
    pub exit_code: Option<i32>,
    /// Standard output stream content.
    pub stdout: String,
    /// Standard error stream content.
    pub stderr: String,
    /// Wall-clock execution duration.
    pub duration: Duration,
}

impl CommandOutput {
    /// Returns `true` if the command exited with status code `0`.
    pub fn is_success(&self) -> bool {
        self.exit_code == Some(0)
    }
}

/// Abstract contract for executing commands in an isolated or sandboxed environment.
#[async_trait]
pub trait CommandExecutor: Send + Sync {
    /// Executes the specified command synchronously with respect to the caller,
    /// returning the captured output or an execution error.
    async fn run(&self, spec: &CommandSpec) -> Result<CommandOutput, ExecutorError>;
}

/// Replaces every occurrence of each secret string in `text` with `"[redacted]"`.
///
/// Empty secrets are ignored to avoid corrupting text by splitting every character.
pub fn redact(text: &str, secrets: &[&str]) -> String {
    let mut result = text.to_string();
    for secret in secrets {
        if !secret.is_empty() {
            result = result.replace(secret, "[redacted]");
        }
    }
    result
}

/// Extracts secret values from a [`CommandSpec`]'s environment variables for redaction.
fn extract_env_secrets(spec: &CommandSpec) -> Vec<&str> {
    spec.env
        .iter()
        .map(|(_, v)| v.as_str())
        .filter(|s| !s.is_empty())
        .collect()
}

/// Local process executor that spawns child processes using [`tokio::process::Command`].
///
/// Designed for bare-metal worker nodes and self-hosted runners. Enforces timeouts and
/// explicitly kills child processes upon timeout expiry to prevent leaking resources.
#[derive(Debug, Clone, Default)]
pub struct LocalExecutor;

impl LocalExecutor {
    /// Creates a new `LocalExecutor`.
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl CommandExecutor for LocalExecutor {
    async fn run(&self, spec: &CommandSpec) -> Result<CommandOutput, ExecutorError> {
        let start_time = Instant::now();
        let secrets = extract_env_secrets(spec);

        let mut cmd = Command::new(&spec.program);
        cmd.args(&spec.args)
            .current_dir(&spec.working_dir)
            .envs(spec.env.iter().cloned())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true);

        let child = cmd.spawn().map_err(|e| {
            ExecutorError::Spawn(format!("Failed to spawn '{}': {e}", spec.program))
        })?;

        let timeout_fut = timeout(spec.timeout, child.wait_with_output());
        let output_res = timeout_fut.await.map_err(|_| ExecutorError::Timeout {
            seconds: spec.timeout.as_secs(),
        })?;

        let output = output_res.map_err(|e| ExecutorError::Io(e.to_string()))?;
        let duration = start_time.elapsed();

        let raw_stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let raw_stderr = String::from_utf8_lossy(&output.stderr).to_string();

        let stdout = redact(&raw_stdout, &secrets);
        let stderr = redact(&raw_stderr, &secrets);
        let exit_code = output.status.code();

        if !output.status.success() {
            return Err(ExecutorError::NonZeroExit {
                code: exit_code,
                stderr,
            });
        }

        Ok(CommandOutput {
            exit_code,
            stdout,
            stderr,
            duration,
        })
    }
}

/// Container-isolated command executor running commands inside an OCI container
/// (such as Docker or Podman).
#[derive(Debug, Clone)]
pub struct ContainerExecutor {
    /// The container runtime binary name or path (e.g. `docker`, `podman`).
    pub runtime_binary: String,
    /// Container image name (e.g. `ghcr.io/bloom/flutter-builder:3.24.1`).
    pub image: String,
    /// Optional container volume mounts in `host_path:container_path` format.
    pub volume_mounts: Vec<(PathBuf, PathBuf)>,
    /// Additional flags to pass to `docker run`.
    pub extra_flags: Vec<String>,
}

impl ContainerExecutor {
    /// Creates a new `ContainerExecutor` with default runtime (`docker`) and specified image.
    pub fn new(image: impl Into<String>) -> Self {
        Self {
            runtime_binary: DEFAULT_CONTAINER_RUNTIME.to_string(),
            image: image.into(),
            volume_mounts: Vec::new(),
            extra_flags: Vec::new(),
        }
    }

    /// Sets the container runtime binary (e.g. `podman` or `/usr/bin/docker`).
    pub fn with_runtime_binary(mut self, runtime_binary: impl Into<String>) -> Self {
        self.runtime_binary = runtime_binary.into();
        self
    }

    /// Adds a volume mount mapping `host_path` to `container_path`.
    pub fn with_volume_mount(
        mut self,
        host_path: impl Into<PathBuf>,
        container_path: impl Into<PathBuf>,
    ) -> Self {
        self.volume_mounts
            .push((host_path.into(), container_path.into()));
        self
    }

    /// Sets extra flags to pass to the container runtime.
    pub fn with_extra_flags<I, S>(mut self, flags: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        self.extra_flags = flags.into_iter().map(Into::into).collect();
        self
    }

    /// Builds the argument list for the container execution command.
    pub fn build_container_args(&self, spec: &CommandSpec) -> Vec<String> {
        let mut args = vec!["run".to_string(), "--rm".to_string(), "-i".to_string()];

        // Add volume mounts
        for (host, container) in &self.volume_mounts {
            args.push("-v".to_string());
            args.push(format!("{}:{}", host.display(), container.display()));
        }

        // Add working directory mount if not already covered
        args.push("-v".to_string());
        args.push(format!(
            "{}:{}",
            spec.working_dir.display(),
            spec.working_dir.display()
        ));

        // Set container working directory
        args.push("-w".to_string());
        args.push(spec.working_dir.display().to_string());

        // Forward environment variables
        for (k, v) in &spec.env {
            args.push("-e".to_string());
            args.push(format!("{k}={v}"));
        }

        // Extra runtime flags
        args.extend(self.extra_flags.clone());

        // Target image
        args.push(self.image.clone());

        // Program and arguments
        args.push(spec.program.clone());
        args.extend(spec.args.clone());

        args
    }
}

#[async_trait]
impl CommandExecutor for ContainerExecutor {
    async fn run(&self, spec: &CommandSpec) -> Result<CommandOutput, ExecutorError> {
        let start_time = Instant::now();
        let secrets = extract_env_secrets(spec);
        let container_args = self.build_container_args(spec);

        let mut cmd = Command::new(&self.runtime_binary);
        cmd.args(&container_args)
            .current_dir(&spec.working_dir)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true);

        let child = cmd.spawn().map_err(|e| {
            ExecutorError::Spawn(format!(
                "Failed to spawn container runtime '{}': {e}",
                self.runtime_binary
            ))
        })?;

        let timeout_fut = timeout(spec.timeout, child.wait_with_output());
        let output_res = timeout_fut.await.map_err(|_| ExecutorError::Timeout {
            seconds: spec.timeout.as_secs(),
        })?;

        let output = output_res.map_err(|e| ExecutorError::Io(e.to_string()))?;
        let duration = start_time.elapsed();

        let raw_stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let raw_stderr = String::from_utf8_lossy(&output.stderr).to_string();

        let stdout = redact(&raw_stdout, &secrets);
        let stderr = redact(&raw_stderr, &secrets);
        let exit_code = output.status.code();

        if !output.status.success() {
            return Err(ExecutorError::NonZeroExit {
                code: exit_code,
                stderr,
            });
        }

        Ok(CommandOutput {
            exit_code,
            stdout,
            stderr,
            duration,
        })
    }
}
