//! Unit tests for Google Play Android Developer API v3 infra client.

use bloom_cloud_backend::infra::googleplay::{
    AppEdit, Bundle, CountryTargeting, GooglePlayClient, GooglePlayConfig, GooglePlayError,
    LocalizedText, ReleaseStatus, Track, TrackRelease, ANDROID_PUBLISHER_SCOPE,
    BUNDLE_UPLOAD_TIMEOUT, DEFAULT_GOOGLE_PLAY_BASE_URL,
};
use bloom_cloud_backend::settings::GooglePlaySettings;

#[test]
fn test_googleplay_constants() {
    assert_eq!(
        DEFAULT_GOOGLE_PLAY_BASE_URL,
        "https://androidpublisher.googleapis.com"
    );
    assert_eq!(
        ANDROID_PUBLISHER_SCOPE,
        "https://www.googleapis.com/auth/androidpublisher"
    );
    // Bundle upload timeout must be at least 2 minutes (120s) per Google Play spec
    assert!(BUNDLE_UPLOAD_TIMEOUT.as_secs() >= 120);
    assert_eq!(BUNDLE_UPLOAD_TIMEOUT.as_secs(), 150);
}

#[test]
fn test_endpoint_url_construction() {
    let base = "https://androidpublisher.googleapis.com";
    let pkg = "com.bloom.app";
    let edit_id = "edit-98765";

    // 1. Create edit
    let create_url = GooglePlayClient::create_edit_url(base, pkg);
    assert_eq!(
        create_url,
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bloom.app/edits"
    );

    // 2. Get edit
    let get_url = GooglePlayClient::get_edit_url(base, pkg, edit_id);
    assert_eq!(
        get_url,
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765"
    );

    // 3. Delete edit
    let delete_url = GooglePlayClient::delete_edit_url(base, pkg, edit_id);
    assert_eq!(
        delete_url,
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765"
    );

    // 4. Bundle upload URL — MUST contain `/upload/` host path per EXTERNAL_APIS.txt line 123
    let upload_url = GooglePlayClient::bundle_upload_url(base, pkg, edit_id, None);
    assert_eq!(
        upload_url,
        "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765/bundles"
    );
    assert!(upload_url.contains("/upload/androidpublisher/v3/"));

    // 4b. Bundle upload URL with deviceTierConfigId query param
    let upload_url_tier = GooglePlayClient::bundle_upload_url(base, pkg, edit_id, Some("LATEST"));
    assert_eq!(
        upload_url_tier,
        "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765/bundles?deviceTierConfigId=LATEST"
    );

    // 5. Track assignment & polling URL
    let track_url = GooglePlayClient::tracks_url(base, pkg, edit_id, "production");
    assert_eq!(
        track_url,
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765/tracks/production"
    );

    // 6. Validate edit URL (colon syntax)
    let validate_url = GooglePlayClient::validate_edit_url(base, pkg, edit_id);
    assert_eq!(
        validate_url,
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765:validate"
    );

    // 7. Commit edit URL (colon syntax)
    let commit_url = GooglePlayClient::commit_edit_url(base, pkg, edit_id);
    assert_eq!(
        commit_url,
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765:commit"
    );
}

#[test]
fn test_release_status_camelcase_serialization() {
    // Exact five values verified per EXTERNAL_APIS.txt line 137-138
    let s_unspecified = serde_json::to_string(&ReleaseStatus::StatusUnspecified).unwrap();
    assert_eq!(s_unspecified, r#""statusUnspecified""#);

    let s_draft = serde_json::to_string(&ReleaseStatus::Draft).unwrap();
    assert_eq!(s_draft, r#""draft""#);

    let s_inprogress = serde_json::to_string(&ReleaseStatus::InProgress).unwrap();
    assert_eq!(s_inprogress, r#""inProgress""#);

    let s_halted = serde_json::to_string(&ReleaseStatus::Halted).unwrap();
    assert_eq!(s_halted, r#""halted""#);

    let s_completed = serde_json::to_string(&ReleaseStatus::Completed).unwrap();
    assert_eq!(s_completed, r#""completed""#);

    // Deserialization roundtrip
    assert_eq!(
        serde_json::from_str::<ReleaseStatus>(r#""inProgress""#).unwrap(),
        ReleaseStatus::InProgress
    );
}

#[test]
fn test_track_release_json_shapes() {
    let release = TrackRelease {
        name: Some("v1.2.0 Release".to_string()),
        version_codes: Some(vec!["10200".to_string()]),
        release_notes: Some(vec![LocalizedText {
            language: "en-US".to_string(),
            text: "Bug fixes and performance improvements.".to_string(),
        }]),
        status: Some(ReleaseStatus::InProgress),
        user_fraction: Some(0.25),
        country_targeting: Some(CountryTargeting {
            countries: Some(vec!["US".to_string(), "GB".to_string()]),
            include_rest_of_world: Some(false),
        }),
        in_app_update_priority: Some(3),
    };

    let track = Track {
        track: "production".to_string(),
        releases: vec![release],
    };

    let json_str = serde_json::to_string(&track).expect("serialize Track");
    assert!(json_str.contains(r#""track":"production""#));
    assert!(json_str.contains(r#""versionCodes":["10200"]"#));
    assert!(json_str.contains(r#""status":"inProgress""#));
    assert!(json_str.contains(r#""userFraction":0.25"#));
    assert!(json_str.contains(r#""inAppUpdatePriority":3"#));
    assert!(json_str.contains(r#""language":"en-US""#));
}

#[test]
fn test_user_fraction_validation_rules() {
    // 1. Valid fraction for inProgress
    let valid_release = TrackRelease {
        status: Some(ReleaseStatus::InProgress),
        user_fraction: Some(0.1),
        ..Default::default()
    };
    assert!(GooglePlayClient::validate_track_release(&valid_release).is_ok());

    // 2. Reject 0.0 or negative
    let zero_release = TrackRelease {
        status: Some(ReleaseStatus::InProgress),
        user_fraction: Some(0.0),
        ..Default::default()
    };
    assert!(matches!(
        GooglePlayClient::validate_track_release(&zero_release),
        Err(GooglePlayError::InvalidUserFraction(_))
    ));

    // 3. Reject 1.0 (EXTERNAL_APIS.txt: "Reject or refuse to send userFraction = 1.0")
    let one_release = TrackRelease {
        status: Some(ReleaseStatus::InProgress),
        user_fraction: Some(1.0),
        ..Default::default()
    };
    assert!(matches!(
        GooglePlayClient::validate_track_release(&one_release),
        Err(GooglePlayError::InvalidUserFraction(_))
    ));

    // 4. Reject fraction >= 1.0
    let over_release = TrackRelease {
        status: Some(ReleaseStatus::InProgress),
        user_fraction: Some(1.5),
        ..Default::default()
    };
    assert!(matches!(
        GooglePlayClient::validate_track_release(&over_release),
        Err(GooglePlayError::InvalidUserFraction(_))
    ));

    // 5. Reject userFraction when status is Completed
    let completed_with_fraction = TrackRelease {
        status: Some(ReleaseStatus::Completed),
        user_fraction: Some(0.5),
        ..Default::default()
    };
    assert!(matches!(
        GooglePlayClient::validate_track_release(&completed_with_fraction),
        Err(GooglePlayError::InvalidUserFraction(_))
    ));
}

#[test]
fn test_app_edit_expiry_handling() {
    let edit = AppEdit {
        id: "edit_123".to_string(),
        expiry_time_seconds: Some("1700000000".to_string()),
    };

    assert_eq!(edit.expiry_epoch_seconds(), Some(1700000000));
    assert!(!edit.is_expired(1699999999));
    assert!(edit.is_expired(1700000000));
    assert!(edit.is_expired(1700000001));

    let no_expiry = AppEdit {
        id: "edit_456".to_string(),
        expiry_time_seconds: None,
    };
    assert_eq!(no_expiry.expiry_epoch_seconds(), None);
    assert!(!no_expiry.is_expired(2000000000));
}

#[test]
fn test_bundle_response_deserialization() {
    let raw = r#"{
        "versionCode": 42,
        "sha1": "da39a3ee5e6b4b0d3255bfef95601890afd80709",
        "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    }"#;

    let bundle: Bundle = serde_json::from_str(raw).expect("parse bundle JSON");
    assert_eq!(bundle.version_code, Some(42));
    assert_eq!(
        bundle.sha1.as_deref(),
        Some("da39a3ee5e6b4b0d3255bfef95601890afd80709")
    );
    assert_eq!(
        bundle.sha256.as_deref(),
        Some("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    );
}

#[test]
fn test_redacted_debug_does_not_print_secrets() {
    let config = GooglePlayConfig {
        base_url: "https://androidpublisher.googleapis.com".to_string(),
        access_token: Some("ya29.secret_oauth_token_value".to_string()),
        service_account_json: Some(
            r#"{"private_key":"-----BEGIN RSA PRIVATE KEY-----"}"#.to_string(),
        ),
    };

    let debug_str = format!("{config:?}");
    assert!(!debug_str.contains("ya29.secret_oauth_token_value"));
    assert!(!debug_str.contains("BEGIN RSA PRIVATE KEY"));
    assert!(debug_str.contains("[REDACTED]"));
}

#[test]
fn test_unconfigured_client() {
    let settings = GooglePlaySettings {
        api_url: "https://androidpublisher.googleapis.com".to_string(),
        service_account_json_path: None,
    };

    let client = GooglePlayClient::new(&settings, None);
    assert!(!client.is_configured());

    let client_unconfigured = GooglePlayClient::unconfigured();
    assert!(!client_unconfigured.is_configured());
}
