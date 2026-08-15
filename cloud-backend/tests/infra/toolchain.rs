//! Unit tests for Flutter toolchain resolution, version parsing, channel mapping, and caching keys.

use std::path::Path;
use std::str::FromStr;

use bloom_cloud_backend::infra::toolchain::{
    cache_key, dependency_cache_key, parse_flutter_version_output, FlutterChannel, FlutterVersion,
    ResolvedToolchain, ToolchainError, ToolchainRequest, ToolchainResolver,
};

use crate::infra::executor::RecordingExecutor;

#[test]
fn test_flutter_version_parsing_valid() {
    // 3-part semver
    let v1 = FlutterVersion::from_str("3.24.1").expect("parse 3.24.1");
    assert_eq!(v1.major, 3);
    assert_eq!(v1.minor, 24);
    assert_eq!(v1.patch, 1);
    assert_eq!(v1.pre_release, None);
    assert_eq!(v1.to_string(), "3.24.1");

    // With pre-release / suffix
    let v2 = FlutterVersion::from_str("3.24.1-stable").expect("parse 3.24.1-stable");
    assert_eq!(v2.major, 3);
    assert_eq!(v2.minor, 24);
    assert_eq!(v2.patch, 1);
    assert_eq!(v2.pre_release, Some("stable".to_string()));
    assert_eq!(v2.to_string(), "3.24.1-stable");

    // 2-part semver
    let v3 = FlutterVersion::from_str("3.22").expect("parse 3.22");
    assert_eq!(v3.major, 3);
    assert_eq!(v3.minor, 22);
    assert_eq!(v3.patch, 0);

    // Pre-release build tag
    let v4 = FlutterVersion::from_str("3.25.0-0.1.pre").expect("parse pre");
    assert_eq!(v4.major, 3);
    assert_eq!(v4.minor, 25);
    assert_eq!(v4.patch, 0);
    assert_eq!(v4.pre_release, Some("0.1.pre".to_string()));
}

#[test]
fn test_flutter_version_parsing_invalid() {
    assert!(matches!(
        FlutterVersion::from_str(""),
        Err(ToolchainError::InvalidVersion(_))
    ));
    assert!(matches!(
        FlutterVersion::from_str("invalid"),
        Err(ToolchainError::InvalidVersion(_))
    ));
    assert!(matches!(
        FlutterVersion::from_str("1"),
        Err(ToolchainError::InvalidVersion(_))
    ));
    assert!(matches!(
        FlutterVersion::from_str("1.2.3.4.5"),
        Err(ToolchainError::InvalidVersion(_))
    ));
}

#[test]
fn test_flutter_channel_roundtrip() {
    assert_eq!(
        FlutterChannel::from_str("stable").unwrap(),
        FlutterChannel::Stable
    );
    assert_eq!(
        FlutterChannel::from_str("beta").unwrap(),
        FlutterChannel::Beta
    );
    assert_eq!(
        FlutterChannel::from_str("master").unwrap(),
        FlutterChannel::Master
    );
    assert_eq!(
        FlutterChannel::from_str("main").unwrap(),
        FlutterChannel::Master
    );

    assert_eq!(FlutterChannel::Stable.as_str(), "stable");
    assert_eq!(FlutterChannel::Beta.as_str(), "beta");
    assert_eq!(FlutterChannel::Master.as_str(), "master");

    assert!(matches!(
        FlutterChannel::from_str("nightly"),
        Err(ToolchainError::InvalidChannel(_))
    ));
}

#[test]
fn test_canonical_cache_key_builder() {
    let resolved = ResolvedToolchain {
        version: FlutterVersion::new(3, 24, 1, None),
        channel: FlutterChannel::Stable,
        sdk_path: "/opt/flutter/3.24.1".into(),
    };

    let key = cache_key(&resolved);
    assert_eq!(key, "toolchains/flutter/stable/3.24.1");
}

#[test]
fn test_dependency_cache_key_determinism() {
    let lockfile1 = "packages:\n  flutter:\n    dependency: sdk\n    version: 0.0.0\n";
    let lockfile2 = "PODS:\n  - Flutter (1.0.0)\n";

    let key1 = dependency_cache_key(&[lockfile1, lockfile2]);
    let key2 = dependency_cache_key(&[lockfile1, lockfile2]);

    // Deterministic: identical inputs produce identical hash
    assert_eq!(key1, key2);
    assert_eq!(key1.len(), 64); // SHA-256 hex string

    // Different inputs produce different hash
    let key_different = dependency_cache_key(&[lockfile1, "PODS:\n  - Flutter (2.0.0)\n"]);
    assert_ne!(key1, key_different);
}

#[test]
fn test_parse_flutter_version_output() {
    let raw_output = r#"
Flutter 3.24.1 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 58d039a4c0 (10 days ago) • 2024-08-01 12:00:00 -0700
Engine • revision 8008e37376
Tools • Dart 3.5.1 • DevTools 2.37.2
"#;

    let (ver, ch) = parse_flutter_version_output(raw_output).expect("parse version output");
    assert_eq!(ver.major, 3);
    assert_eq!(ver.minor, 24);
    assert_eq!(ver.patch, 1);
    assert_eq!(ch, FlutterChannel::Stable);
}

#[tokio::test]
async fn test_toolchain_resolver_unpinned_resolution() {
    let executor = RecordingExecutor::new();
    executor.push_success(
        "Flutter 3.24.0 • channel beta • https://github.com/flutter/flutter.git\nFramework • revision abc\n",
        "",
    );

    let resolver = ToolchainResolver::new(&executor, "/opt/flutter");
    let request = ToolchainRequest::for_channel(FlutterChannel::Stable);

    let resolved = resolver
        .resolve(&request, Path::new("/workspace"))
        .await
        .expect("resolve toolchain");

    assert_eq!(resolved.version, FlutterVersion::new(3, 24, 0, None));
    assert_eq!(resolved.sdk_path, Path::new("/opt/flutter"));

    let specs = executor.recorded_specs();
    assert_eq!(specs.len(), 1);
    assert!(specs[0].program.contains("flutter"));
    assert_eq!(specs[0].args, vec!["--version".to_string()]);
}

#[tokio::test]
async fn test_toolchain_resolver_pinned_request() {
    let executor = RecordingExecutor::new();
    executor.push_success(
        "Flutter 3.24.1 • channel stable • https://github.com/flutter/flutter.git\n",
        "",
    );

    let resolver = ToolchainResolver::new(&executor, "/opt/flutter");
    let pinned_version = FlutterVersion::new(3, 24, 1, None);
    let request = ToolchainRequest::pinned(FlutterChannel::Stable, pinned_version.clone());

    let resolved = resolver
        .resolve(&request, Path::new("/workspace"))
        .await
        .expect("resolve pinned toolchain");

    assert_eq!(resolved.version, pinned_version);
    assert_eq!(resolved.channel, FlutterChannel::Stable);
}
