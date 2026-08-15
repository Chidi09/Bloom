//! Unit tests for Shorebird CLI argument construction, platform flags, and secret hygiene.

use bloom_cloud_backend::infra::shorebird::{
    build_shorebird_args, parse_release_or_patch_id, IosExportMethod, ShorebirdAction,
    ShorebirdClient, ShorebirdConfig, ShorebirdError, ShorebirdOptions, ShorebirdPlatform,
    ShorebirdPlatforms, DEFAULT_SHOREBIRD_TRACK,
};

#[test]
fn test_shorebird_default_track_constant() {
    assert_eq!(DEFAULT_SHOREBIRD_TRACK, "stable");
}

#[test]
fn test_build_shorebird_args_release_single_platform_default_track() {
    let action = ShorebirdAction::Release;
    let platforms = ShorebirdPlatforms::Single(ShorebirdPlatform::Android);
    let options = ShorebirdOptions::default();

    let args = build_shorebird_args(action, &platforms, &options);

    // --json/--no-input ride on every invocation: a worker has no TTY and must not be
    // handed spinner output or an interactive prompt.
    assert_eq!(
        args,
        vec![
            "release",
            "--json",
            "--no-input",
            "android",
            "--track",
            "stable"
        ]
    );
}

#[test]
fn test_build_shorebird_args_patch_multiple_platforms() {
    let action = ShorebirdAction::Patch;
    let platforms =
        ShorebirdPlatforms::Multiple(vec![ShorebirdPlatform::Android, ShorebirdPlatform::Ios]);
    let options = ShorebirdOptions::default();

    let args = build_shorebird_args(action, &platforms, &options);

    assert_eq!(
        args,
        vec![
            "patch",
            "--json",
            "--no-input",
            "--platforms=android,ios",
            "--track",
            "stable"
        ]
    );
}

#[test]
fn test_build_shorebird_args_all_platforms() {
    let action = ShorebirdAction::Patch;
    let platforms = ShorebirdPlatforms::Multiple(vec![
        ShorebirdPlatform::Android,
        ShorebirdPlatform::Ios,
        ShorebirdPlatform::Linux,
        ShorebirdPlatform::Macos,
        ShorebirdPlatform::Windows,
    ]);
    let options = ShorebirdOptions::default();

    let args = build_shorebird_args(action, &platforms, &options);

    assert_eq!(
        args,
        vec![
            "patch",
            "--json",
            "--no-input",
            "--platforms=android,ios,linux,macos,windows",
            "--track",
            "stable"
        ]
    );
}

#[test]
fn test_build_shorebird_args_verified_flags() {
    let action = ShorebirdAction::Release;
    let platforms = ShorebirdPlatforms::Single(ShorebirdPlatform::Ios);
    let options = ShorebirdOptions {
        release_version: Some("1.2.0+42".to_string()),
        flavor: Some("production".to_string()),
        target: Some("lib/main_prod.dart".to_string()),
        track: Some("beta".to_string()),
        dry_run: true,
        allow_asset_diffs: true,
        allow_native_diffs: true,
        no_codesign: true,
        export_options_plist: Some("/opt/bloom/ExportOptions.plist".to_string()),
        export_method: Some(IosExportMethod::AppStore),
        min_link_percentage: Some(90.0),
    };

    let args = build_shorebird_args(action, &platforms, &options);

    assert_eq!(
        args,
        vec![
            "release",
            "--json",
            "--no-input",
            "ios",
            "--release-version",
            "1.2.0+42",
            "--flavor",
            "production",
            "--target",
            "lib/main_prod.dart",
            "--track",
            "beta",
            "--dry-run",
            "--allow-asset-diffs",
            "--allow-native-diffs",
            "--no-codesign",
            "--export-options-plist",
            "/opt/bloom/ExportOptions.plist",
            "--export-method",
            "app-store",
            "--min-link-percentage",
            "90",
        ]
    );
}

#[test]
fn test_build_shorebird_args_ios_export_methods() {
    let methods = vec![
        (IosExportMethod::AppStore, "app-store"),
        (IosExportMethod::AdHoc, "ad-hoc"),
        (IosExportMethod::Development, "development"),
        (IosExportMethod::Enterprise, "enterprise"),
    ];

    for (method, expected_str) in methods {
        assert_eq!(method.as_str(), expected_str);

        let options = ShorebirdOptions {
            export_method: Some(method),
            ..Default::default()
        };

        let args = build_shorebird_args(
            ShorebirdAction::Patch,
            &ShorebirdPlatforms::Single(ShorebirdPlatform::Ios),
            &options,
        );

        assert!(args.contains(&"--export-method".to_string()));
        assert!(args.contains(&expected_str.to_string()));
    }
}

#[test]
fn test_shell_metacharacters_safety_single_argv_element() {
    let action = ShorebirdAction::Patch;
    let platforms = ShorebirdPlatforms::Single(ShorebirdPlatform::Android);
    let options = ShorebirdOptions {
        release_version: Some("1.0.0; rm -rf /".to_string()),
        flavor: Some("flavor && cat /etc/passwd".to_string()),
        target: Some("lib/main.dart | echo pwned".to_string()),
        track: Some("stable`id`".to_string()),
        ..Default::default()
    };

    let args = build_shorebird_args(action, &platforms, &options);

    // Assert dangerous strings are held as single elements and not split by shell
    assert!(args.contains(&"1.0.0; rm -rf /".to_string()));
    assert!(args.contains(&"flavor && cat /etc/passwd".to_string()));
    assert!(args.contains(&"lib/main.dart | echo pwned".to_string()));
    assert!(args.contains(&"stable`id`".to_string()));
}

#[test]
fn test_shorebird_config_debug_redacts_token() {
    let token = "shorebird_api_key_secret_998877665544";
    let config = ShorebirdConfig {
        token: token.to_string(),
        cli_path: "/usr/local/bin/shorebird".to_string(),
    };

    let debug_output = format!("{config:?}");

    assert!(!debug_output.contains(token));
    assert!(debug_output.contains("[REDACTED]"));
    assert!(debug_output.contains("/usr/local/bin/shorebird"));
}

#[test]
fn test_unconfigured_shorebird_client() {
    let client = ShorebirdClient::unconfigured();
    assert!(!client.is_configured());

    let client_with_empty = ShorebirdClient::new(Some("".to_string()), None);
    assert!(!client_with_empty.is_configured());

    let client_configured = ShorebirdClient::new(
        Some("valid_token".to_string()),
        Some("shorebird".to_string()),
    );
    assert!(client_configured.is_configured());
}

#[test]
fn test_parse_release_or_patch_id() {
    let sample_release_output = "Building release...\nRelease ID: rel_abc123xyz\nDone!";
    assert_eq!(
        parse_release_or_patch_id(sample_release_output),
        Some("rel_abc123xyz".to_string())
    );

    let sample_patch_output = "Applying patch...\nPatch ID: patch_789qwe\nDone!";
    assert_eq!(
        parse_release_or_patch_id(sample_patch_output),
        Some("patch_789qwe".to_string())
    );

    let no_id_output = "No identifiable ID in this output\nDone!";
    assert_eq!(parse_release_or_patch_id(no_id_output), None);
}

#[test]
fn test_shorebird_error_display() {
    let not_cfg = ShorebirdError::NotConfigured("missing token".to_string());
    assert_eq!(
        format!("{not_cfg}"),
        "Shorebird not configured: missing token"
    );

    let exec_err = ShorebirdError::ExecutionFailed {
        exit_code: Some(1),
        stdout: "out".to_string(),
        stderr: "err".to_string(),
    };
    let exec_str = format!("{exec_err}");
    assert!(exec_str.contains("exit code 1"));
    assert!(exec_str.contains("stderr: err"));
}
