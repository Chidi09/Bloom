//! Shorebird OTA code push infrastructure client.
//!
//! # Architecture & Scope
//!
//! Provides native Over-The-Air (OTA) Dart code push capabilities by driving the
//! `shorebird` command-line interface.
//!
//! Bloom Cloud does not build a competing OTA engine; it orchestrates the `shorebird` CLI
//! to create native binary releases ([`ShorebirdAction::Release`]) and dynamic Dart patches
//! ([`ShorebirdAction::Patch`]).
//!
//! There is no REST API for Shorebird OTA operations; all interactions shell out to the
//! `shorebird` CLI binary directly via direct argv vectors.
//!
//! # Authentication & Deprecation Notice
//!
//! Authentication is provided exclusively via the `SHOREBIRD_TOKEN` environment variable passed
//! to child processes.
//!
//! **CRITICAL DEPRECATION NOTICE (September 2026):**
//! `shorebird login:ci` is deprecated. Tokens minted via `login:ci` stop working in September 2026.
//! All credentials must be console-issued API keys read from `credentials::Credential` with
//! provider `shorebird`, encrypted at rest using `crate::infra::crypto::Crypto`.
//! Do not write or re-introduce anything depending on `login:ci`.
//!
//! # Process Safety & Injection Prevention
//!
//! All CLI arguments are constructed as a pure [`Vec<String>`] via [`build_shorebird_args`]
//! and passed directly to the OS process execution API. User-controlled strings (such as product
//! flavors, target entrypoints, or version strings) are never passed through a shell (`sh -c`),
//! completely eliminating command injection vulnerabilities.
//!
//! The `SHOREBIRD_TOKEN` is passed strictly in the child process environment (`.env("SHOREBIRD_TOKEN", ...)`).
//! It is never passed on argv, never logged, and redacted in all [`Debug`](std::fmt::Debug) representations.

use std::fmt;
use std::path::Path;
use std::process::Stdio;
use tokio::process::Command;

/// Default deployment track for Shorebird releases and patches.
/// Authorised by EXTERNAL_APIS.txt line 246.
pub const DEFAULT_SHOREBIRD_TRACK: &str = "stable";

/// Supported Shorebird operational action verbs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShorebirdAction {
    /// Create a release for the native binary (`shorebird release <platform>`).
    Release,
    /// Create a Dart patch (`shorebird patch <platform>`).
    Patch,
}

impl ShorebirdAction {
    /// Returns the CLI subcommand string.
    pub fn as_str(&self) -> &'static str {
        match self {
            ShorebirdAction::Release => "release",
            ShorebirdAction::Patch => "patch",
        }
    }
}

impl fmt::Display for ShorebirdAction {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Target platform supported by Shorebird CLI.
/// Authorised by EXTERNAL_APIS.txt line 240.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ShorebirdPlatform {
    /// Android platform (`android`).
    Android,
    /// iOS platform (`ios`).
    Ios,
    /// Linux desktop platform (`linux`).
    Linux,
    /// macOS desktop platform (`macos`).
    Macos,
    /// Windows desktop platform (`windows`).
    Windows,
}

impl ShorebirdPlatform {
    /// Returns the canonical CLI platform identifier string.
    pub fn as_str(&self) -> &'static str {
        match self {
            ShorebirdPlatform::Android => "android",
            ShorebirdPlatform::Ios => "ios",
            ShorebirdPlatform::Linux => "linux",
            ShorebirdPlatform::Macos => "macos",
            ShorebirdPlatform::Windows => "windows",
        }
    }

    /// Parses a platform string into a [`ShorebirdPlatform`] variant.
    pub fn from_str_opt(s: &str) -> Option<Self> {
        match s.trim().to_ascii_lowercase().as_str() {
            "android" => Some(ShorebirdPlatform::Android),
            "ios" => Some(ShorebirdPlatform::Ios),
            "linux" => Some(ShorebirdPlatform::Linux),
            "macos" => Some(ShorebirdPlatform::Macos),
            "windows" => Some(ShorebirdPlatform::Windows),
            _ => None,
        }
    }
}

impl fmt::Display for ShorebirdPlatform {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Target platform specification: either a single platform or multiple platforms in one invocation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ShorebirdPlatforms {
    /// A single target platform (e.g. `shorebird patch android`).
    Single(ShorebirdPlatform),
    /// Multiple target platforms (e.g. `shorebird patch --platforms=android,ios`).
    Multiple(Vec<ShorebirdPlatform>),
}

/// iOS export method options for Shorebird release/patch commands.
/// Authorised by EXTERNAL_APIS.txt line 251.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IosExportMethod {
    /// App Store distribution (`app-store`).
    AppStore,
    /// Ad-hoc distribution (`ad-hoc`).
    AdHoc,
    /// Development testing (`development`).
    Development,
    /// Enterprise distribution (`enterprise`).
    Enterprise,
}

impl IosExportMethod {
    /// Returns the export method flag string.
    pub fn as_str(&self) -> &'static str {
        match self {
            IosExportMethod::AppStore => "app-store",
            IosExportMethod::AdHoc => "ad-hoc",
            IosExportMethod::Development => "development",
            IosExportMethod::Enterprise => "enterprise",
        }
    }
}

impl fmt::Display for IosExportMethod {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Verified CLI options for `shorebird release` and `shorebird patch` invocations.
///
/// Only verified flags per `EXTERNAL_APIS.txt` §7 are supported:
/// - `--release-version <version>`
/// - `--flavor <name>`
/// - `--target <path>`
/// - `--track <track>` (defaults to `stable`)
/// - `--dry-run` / `-n`
/// - `--allow-asset-diffs`
/// - `--allow-native-diffs`
/// - iOS-specific: `--no-codesign`, `--export-options-plist <path>`, `--export-method <method>`, `--min-link-percentage <value>`
#[derive(Debug, Clone, PartialEq, Default)]
pub struct ShorebirdOptions {
    /// Target release version (e.g. `1.0.0` or `latest`).
    pub release_version: Option<String>,
    /// Build product flavor name.
    pub flavor: Option<String>,
    /// Main entrypoint target file path (e.g. `lib/main.dart`).
    pub target: Option<String>,
    /// Deployment track name. Defaults to `stable` if [`None`].
    pub track: Option<String>,
    /// Build and validate without uploading (`--dry-run`).
    pub dry_run: bool,
    /// Permit asset differences between base and patch (`--allow-asset-diffs`).
    pub allow_asset_diffs: bool,
    /// Permit native code differences between base and patch (`--allow-native-diffs`).
    pub allow_native_diffs: bool,
    /// Disable codesigning on iOS (`--no-codesign`).
    pub no_codesign: bool,
    /// Path to `ExportOptions.plist` for iOS builds (`--export-options-plist <path>`).
    pub export_options_plist: Option<String>,
    /// iOS export method (`--export-method <method>`).
    pub export_method: Option<IosExportMethod>,
    /// Minimum link percentage for iOS builds (`--min-link-percentage <value>`).
    pub min_link_percentage: Option<f64>,
}

/// Errors arising from Shorebird CLI operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ShorebirdError {
    /// Shorebird token or CLI is not configured.
    NotConfigured(String),
    /// OS I/O or process spawning failure.
    Io(String),
    /// Process exited with non-zero status code.
    ExecutionFailed {
        /// Process exit code if available.
        exit_code: Option<i32>,
        /// Standard output from the process.
        stdout: String,
        /// Standard error from the process.
        stderr: String,
    },
    /// Invalid command or platform arguments.
    InvalidArguments(String),
    /// Output parsing error.
    OutputParsing(String),
}

impl fmt::Display for ShorebirdError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ShorebirdError::NotConfigured(msg) => write!(f, "Shorebird not configured: {msg}"),
            ShorebirdError::Io(msg) => write!(f, "Shorebird process I/O error: {msg}"),
            ShorebirdError::ExecutionFailed {
                exit_code,
                stdout,
                stderr,
            } => {
                let code_str = exit_code
                    .map(|c| c.to_string())
                    .unwrap_or_else(|| "signal".to_string());
                write!(
                    f,
                    "Shorebird CLI execution failed (exit code {code_str}): stderr: {stderr}; stdout: {stdout}"
                )
            }
            ShorebirdError::InvalidArguments(msg) => {
                write!(f, "Invalid Shorebird CLI arguments: {msg}")
            }
            ShorebirdError::OutputParsing(msg) => {
                write!(f, "Failed parsing Shorebird CLI output: {msg}")
            }
        }
    }
}

impl std::error::Error for ShorebirdError {}

/// Constructs the pure, unit-testable argv list for a Shorebird command.
///
/// Passes arguments directly without shell interpretation to avoid command injection.
///
/// # Authorised by
/// `EXTERNAL_APIS.txt` §7 ("ARGUMENT CONSTRUCTION MUST BE A PURE, UNIT-TESTABLE FUNCTION returning Vec<String>").
pub fn build_shorebird_args(
    action: ShorebirdAction,
    platforms: &ShorebirdPlatforms,
    options: &ShorebirdOptions,
) -> Vec<String> {
    let mut args = Vec::new();

    // 1. Action subcommand (release or patch)
    args.push(action.as_str().to_string());

    // 2. Target platform(s)
    match platforms {
        ShorebirdPlatforms::Single(platform) => {
            args.push(platform.as_str().to_string());
        }
        ShorebirdPlatforms::Multiple(platform_list) => {
            if platform_list.is_empty() {
                // If empty list passed, default to no extra platform argument
            } else if platform_list.len() == 1 {
                args.push(platform_list[0].as_str().to_string());
            } else {
                let joined = platform_list
                    .iter()
                    .map(|p| p.as_str())
                    .collect::<Vec<_>>()
                    .join(",");
                args.push(format!("--platforms={joined}"));
            }
        }
    }

    // 3. Verified flags
    if let Some(ref version) = options.release_version {
        args.push("--release-version".to_string());
        args.push(version.clone());
    }

    if let Some(ref flavor) = options.flavor {
        args.push("--flavor".to_string());
        args.push(flavor.clone());
    }

    if let Some(ref target) = options.target {
        args.push("--target".to_string());
        args.push(target.clone());
    }

    // Track flag: defaults to "stable"
    let track_val = options.track.as_deref().unwrap_or(DEFAULT_SHOREBIRD_TRACK);
    args.push("--track".to_string());
    args.push(track_val.to_string());

    if options.dry_run {
        args.push("--dry-run".to_string());
    }

    if options.allow_asset_diffs {
        args.push("--allow-asset-diffs".to_string());
    }

    if options.allow_native_diffs {
        args.push("--allow-native-diffs".to_string());
    }

    // iOS-specific flags
    if options.no_codesign {
        args.push("--no-codesign".to_string());
    }

    if let Some(ref plist) = options.export_options_plist {
        args.push("--export-options-plist".to_string());
        args.push(plist.clone());
    }

    if let Some(ref method) = options.export_method {
        args.push("--export-method".to_string());
        args.push(method.as_str().to_string());
    }

    if let Some(min_link) = options.min_link_percentage {
        args.push("--min-link-percentage".to_string());
        args.push(min_link.to_string());
    }

    args
}

/// Parses the release or patch ID from Shorebird CLI standard output.
///
/// If the output format cannot be definitively determined, returns [`None`].
pub fn parse_release_or_patch_id(output: &str) -> Option<String> {
    // TODO(spec): shorebird CLI output parsing unverified
    for line in output.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("Release ID:") {
            let id = rest.trim();
            if !id.is_empty() {
                return Some(id.to_string());
            }
        }
        if let Some(rest) = trimmed.strip_prefix("Patch ID:") {
            let id = rest.trim();
            if !id.is_empty() {
                return Some(id.to_string());
            }
        }
    }
    None
}

/// Configuration credentials and binary path for Shorebird CLI.
#[derive(Clone, PartialEq, Eq)]
pub struct ShorebirdConfig {
    /// Console-issued Shorebird API key token.
    pub token: String,
    /// Path to the `shorebird` executable binary (default `"shorebird"`).
    pub cli_path: String,
}

// Redact token in Debug representations to prevent credential leaks in logs
impl fmt::Debug for ShorebirdConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ShorebirdConfig")
            .field("cli_path", &self.cli_path)
            .field("token", &"[REDACTED]")
            .finish()
    }
}

/// Output captured from a completed Shorebird CLI execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ShorebirdExecutionResult {
    /// Extracted release or patch ID if present in output.
    pub release_or_patch_id: Option<String>,
    /// Captured standard output.
    pub stdout: String,
    /// Captured standard error.
    pub stderr: String,
    /// Process exit code.
    pub exit_code: i32,
}

/// Shorebird OTA infrastructure client.
#[derive(Clone, Debug)]
pub struct ShorebirdClient {
    config: Option<ShorebirdConfig>,
}

impl ShorebirdClient {
    /// Creates a new `ShorebirdClient` with optional token and CLI path.
    pub fn new(token: Option<String>, cli_path: Option<String>) -> Self {
        let config = token
            .filter(|t| !t.trim().is_empty())
            .map(|t| ShorebirdConfig {
                token: t.trim().to_string(),
                cli_path: cli_path
                    .filter(|p| !p.trim().is_empty())
                    .unwrap_or_else(|| "shorebird".to_string()),
            });

        Self { config }
    }

    /// Creates an explicitly unconfigured `ShorebirdClient`.
    pub fn unconfigured() -> Self {
        Self { config: None }
    }

    /// Returns `true` if the client holds valid authentication credentials.
    pub fn is_configured(&self) -> bool {
        self.config.is_some()
    }

    /// Executes `shorebird release` with the given platforms and options.
    pub async fn release(
        &self,
        platforms: &ShorebirdPlatforms,
        options: &ShorebirdOptions,
        working_dir: Option<&Path>,
    ) -> Result<ShorebirdExecutionResult, ShorebirdError> {
        let args = build_shorebird_args(ShorebirdAction::Release, platforms, options);
        self.run_command(&args, working_dir).await
    }

    /// Executes `shorebird patch` with the given platforms and options.
    pub async fn patch(
        &self,
        platforms: &ShorebirdPlatforms,
        options: &ShorebirdOptions,
        working_dir: Option<&Path>,
    ) -> Result<ShorebirdExecutionResult, ShorebirdError> {
        let args = build_shorebird_args(ShorebirdAction::Patch, platforms, options);
        self.run_command(&args, working_dir).await
    }

    /// Runs a `shorebird` CLI invocation with raw arguments in the child process.
    ///
    /// Sets `SHOREBIRD_TOKEN` in the child environment only; never logs or prints it.
    pub async fn run_command(
        &self,
        args: &[String],
        working_dir: Option<&Path>,
    ) -> Result<ShorebirdExecutionResult, ShorebirdError> {
        let config = self.config.as_ref().ok_or_else(|| {
            ShorebirdError::NotConfigured(
                "Shorebird credentials (SHOREBIRD_TOKEN) not configured".to_string(),
            )
        })?;

        let mut cmd = Command::new(&config.cli_path);
        cmd.args(args);
        cmd.env("SHOREBIRD_TOKEN", &config.token);
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());

        if let Some(dir) = working_dir {
            cmd.current_dir(dir);
        }

        let output = cmd
            .output()
            .await
            .map_err(|e| ShorebirdError::Io(format!("Failed to execute shorebird CLI: {e}")))?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        let exit_code = output.status.code().unwrap_or(-1);

        if !output.status.success() {
            return Err(ShorebirdError::ExecutionFailed {
                exit_code: output.status.code(),
                stdout,
                stderr,
            });
        }

        let release_or_patch_id = parse_release_or_patch_id(&stdout);

        Ok(ShorebirdExecutionResult {
            release_or_patch_id,
            stdout,
            stderr,
            exit_code,
        })
    }
}
