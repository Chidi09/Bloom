//! Flutter SDK version resolution, channel management, and toolchain caching.
//!
//! # Architecture & Scope
//!
//! Implements Flutter toolchain resolution (PHASES-FINAL.md Phase 9, Deliverables 3 & 5):
//! - Version parsing and ordering for semantic Flutter versions (e.g. `3.24.1`, `3.24.1-stable`).
//! - Release channel modeling (`stable`, `beta`, `master`).
//! - Stable, deterministic per-runner SDK cache key generation.
//! - Lockfile-based dependency cache key derivation (using SHA-256) for pub, Gradle, and CocoaPods caches.
//! - Non-networked SDK resolution via [`ToolchainResolver`] using an injected [`CommandExecutor`].

use std::fmt;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::time::Duration;

use sha2::{Digest, Sha256};

use crate::infra::executor::{CommandExecutor, CommandSpec, ExecutorError};

/// Default timeout for running `flutter --version` discovery command (30 seconds).
pub const TOOLCHAIN_PROBE_TIMEOUT: Duration = Duration::from_secs(30);

/// Supported release channels for the Flutter SDK.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FlutterChannel {
    /// Stable release channel, recommended for production builds.
    Stable,
    /// Beta preview channel, containing pre-release features and fixes.
    Beta,
    /// Master bleeding-edge tracking channel.
    Master,
}

impl FlutterChannel {
    /// Returns the canonical lower-case string identifier for the channel.
    pub fn as_str(&self) -> &'static str {
        match self {
            FlutterChannel::Stable => "stable",
            FlutterChannel::Beta => "beta",
            FlutterChannel::Master => "master",
        }
    }
}

impl fmt::Display for FlutterChannel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

impl FromStr for FlutterChannel {
    type Err = ToolchainError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_lowercase().as_str() {
            "stable" => Ok(FlutterChannel::Stable),
            "beta" => Ok(FlutterChannel::Beta),
            "master" | "main" => Ok(FlutterChannel::Master),
            other => Err(ToolchainError::InvalidChannel(other.to_string())),
        }
    }
}

/// Parsed, comparable Flutter semantic version (e.g., `3.24.1` or `3.24.1-stable`).
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct FlutterVersion {
    /// Major version number.
    pub major: u64,
    /// Minor version number.
    pub minor: u64,
    /// Patch version number.
    pub patch: u64,
    /// Optional pre-release or channel suffix tag (e.g. `stable`, `pre.1`).
    pub pre_release: Option<String>,
}

impl FlutterVersion {
    /// Creates a new `FlutterVersion` with explicit components.
    pub fn new(major: u64, minor: u64, patch: u64, pre_release: Option<String>) -> Self {
        Self {
            major,
            minor,
            patch,
            pre_release,
        }
    }
}

impl fmt::Display for FlutterVersion {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if let Some(ref pre) = self.pre_release {
            write!(f, "{}.{}.{}-{}", self.major, self.minor, self.patch, pre)
        } else {
            write!(f, "{}.{}.{}", self.major, self.minor, self.patch)
        }
    }
}

impl FromStr for FlutterVersion {
    type Err = ToolchainError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let trimmed = s.trim();
        if trimmed.is_empty() {
            return Err(ToolchainError::InvalidVersion(
                "Version string is empty".to_string(),
            ));
        }

        // Split base version from pre-release suffix (e.g. "3.24.1-stable" -> "3.24.1", "stable")
        let (base, pre_release) = match trimmed.split_once('-') {
            Some((v, pre)) => (v, Some(pre.to_string())),
            None => (trimmed, None),
        };

        let parts: Vec<&str> = base.split('.').collect();
        if parts.len() < 2 || parts.len() > 3 {
            return Err(ToolchainError::InvalidVersion(format!(
                "Invalid version format '{trimmed}': expected 'major.minor' or 'major.minor.patch'"
            )));
        }

        let major = parts[0].parse::<u64>().map_err(|e| {
            ToolchainError::InvalidVersion(format!("Invalid major version '{}': {e}", parts[0]))
        })?;

        let minor = parts[1].parse::<u64>().map_err(|e| {
            ToolchainError::InvalidVersion(format!("Invalid minor version '{}': {e}", parts[1]))
        })?;

        let patch = if parts.len() == 3 {
            parts[2].parse::<u64>().map_err(|e| {
                ToolchainError::InvalidVersion(format!("Invalid patch version '{}': {e}", parts[2]))
            })?
        } else {
            0
        };

        Ok(FlutterVersion {
            major,
            minor,
            patch,
            pre_release,
        })
    }
}

/// Errors arising from Flutter toolchain resolution and parsing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ToolchainError {
    /// Provided version string cannot be parsed as semver.
    InvalidVersion(String),
    /// Unrecognised Flutter channel name.
    InvalidChannel(String),
    /// Failed to execute `flutter --version` via command executor.
    ExecutionFailed(String),
    /// Output from `flutter --version` was malformed or missing version/channel data.
    MalformedVersionOutput(String),
    /// Requested toolchain configuration is unavailable or invalid.
    ResolutionFailed(String),
}

impl fmt::Display for ToolchainError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ToolchainError::InvalidVersion(msg) => write!(f, "Invalid Flutter version: {msg}"),
            ToolchainError::InvalidChannel(msg) => write!(f, "Invalid Flutter channel: {msg}"),
            ToolchainError::ExecutionFailed(msg) => {
                write!(f, "Toolchain discovery execution failed: {msg}")
            }
            ToolchainError::MalformedVersionOutput(msg) => {
                write!(f, "Malformed 'flutter --version' output: {msg}")
            }
            ToolchainError::ResolutionFailed(msg) => {
                write!(f, "Flutter toolchain resolution failed: {msg}")
            }
        }
    }
}

impl std::error::Error for ToolchainError {}

impl From<ExecutorError> for ToolchainError {
    fn from(err: ExecutorError) -> Self {
        ToolchainError::ExecutionFailed(err.to_string())
    }
}

/// Specification of the toolchain requested by a project environment.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolchainRequest {
    /// Desired Flutter release channel (default: [`FlutterChannel::Stable`]).
    pub channel: FlutterChannel,
    /// Explicit pinned Flutter version, or `None` to resolve current channel latest.
    pub version: Option<FlutterVersion>,
}

impl ToolchainRequest {
    /// Creates a new unpinned request targeting the specified channel.
    pub fn for_channel(channel: FlutterChannel) -> Self {
        Self {
            channel,
            version: None,
        }
    }

    /// Creates a new pinned request for a specific version and channel.
    pub fn pinned(channel: FlutterChannel, version: FlutterVersion) -> Self {
        Self {
            channel,
            version: Some(version),
        }
    }
}

/// Concrete resolved Flutter toolchain selected for a build run.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResolvedToolchain {
    /// Concrete resolved Flutter semantic version.
    pub version: FlutterVersion,
    /// Release channel of the resolved SDK.
    pub channel: FlutterChannel,
    /// Absolute filesystem path to the Flutter SDK root.
    pub sdk_path: PathBuf,
}

/// Computes the canonical per-runner cache key for a resolved Flutter SDK.
///
/// Hierarchy:
/// `toolchains/flutter/{channel}/{version}`
pub fn cache_key(resolved: &ResolvedToolchain) -> String {
    format!(
        "toolchains/flutter/{}/{}",
        resolved.channel.as_str(),
        resolved.version
    )
}

/// Computes a stable dependency cache key by hashing the contents of project lockfiles.
///
/// Hashes the provided lockfile contents (e.g. `pubspec.lock`, `Podfile.lock`, `build.gradle`)
/// using SHA-256. The same lockfile contents will always produce the identical 64-character
/// hex key.
pub fn dependency_cache_key(lockfile_contents: &[&str]) -> String {
    let mut hasher = Sha256::new();
    for (i, content) in lockfile_contents.iter().enumerate() {
        hasher.update((i as u64).to_le_bytes());
        hasher.update((content.len() as u64).to_le_bytes());
        hasher.update(content.as_bytes());
    }
    format!("{:x}", hasher.finalize())
}

/// Parses the output of `flutter --version` without assuming a fixed column layout.
///
/// Scans tokens for semver-shaped strings (e.g. `3.24.1`, `3.24.1-stable`) and channel names
/// (`stable`, `beta`, `master`).
pub fn parse_flutter_version_output(
    output: &str,
) -> Result<(FlutterVersion, FlutterChannel), ToolchainError> {
    let mut found_version: Option<FlutterVersion> = None;
    let mut found_channel: Option<FlutterChannel> = None;

    for line in output.lines() {
        for word in line.split_whitespace() {
            let clean = word.trim_matches(|c: char| !c.is_alphanumeric() && c != '.' && c != '-');

            // Look for channel match if not found yet
            if found_channel.is_none() {
                if let Ok(ch) = FlutterChannel::from_str(clean) {
                    found_channel = Some(ch);
                    continue;
                }
            }

            // Look for semver match if not found yet
            if found_version.is_none() {
                if let Ok(ver) = FlutterVersion::from_str(clean) {
                    // Ensure it looks like a Flutter semver (has dots)
                    if clean.contains('.') {
                        found_version = Some(ver);
                    }
                }
            }
        }
    }

    let version = found_version.ok_or_else(|| {
        ToolchainError::MalformedVersionOutput(
            "Could not detect semantic version in 'flutter --version' output".to_string(),
        )
    })?;

    // Default to Stable channel if output did not explicitly list one
    let channel = found_channel.unwrap_or(FlutterChannel::Stable);

    Ok((version, channel))
}

/// Resolves requested Flutter toolchains against a runner's installed SDKs
/// using a provided [`CommandExecutor`].
pub struct ToolchainResolver<'a> {
    executor: &'a dyn CommandExecutor,
    default_sdk_path: PathBuf,
}

impl<'a> ToolchainResolver<'a> {
    /// Creates a new `ToolchainResolver` with the injected executor and default SDK path.
    pub fn new(executor: &'a dyn CommandExecutor, default_sdk_path: impl Into<PathBuf>) -> Self {
        Self {
            executor,
            default_sdk_path: default_sdk_path.into(),
        }
    }

    /// Resolves a [`ToolchainRequest`] to a [`ResolvedToolchain`].
    ///
    /// Invokes `flutter --version` to discover the active runner toolchain details.
    /// Does not make any external network requests.
    pub async fn resolve(
        &self,
        request: &ToolchainRequest,
        working_dir: &Path,
    ) -> Result<ResolvedToolchain, ToolchainError> {
        let flutter_bin = self.default_sdk_path.join("bin").join("flutter");
        let flutter_bin_str = flutter_bin.to_string_lossy().to_string();

        let spec = CommandSpec::new(flutter_bin_str, working_dir)
            .with_arg("--version")
            .with_timeout(TOOLCHAIN_PROBE_TIMEOUT);

        let output = self.executor.run(&spec).await?;

        let (probed_version, probed_channel) =
            parse_flutter_version_output(&format!("{}\n{}", output.stdout, output.stderr))?;

        let resolved_version = match &request.version {
            Some(pinned) => pinned.clone(),
            None => probed_version,
        };

        let resolved_channel = if request.channel != FlutterChannel::Stable {
            request.channel
        } else {
            probed_channel
        };

        Ok(ResolvedToolchain {
            version: resolved_version,
            channel: resolved_channel,
            sdk_path: self.default_sdk_path.clone(),
        })
    }
}
