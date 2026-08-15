//! Unit tests for Google Play Android Developer API v3 infra client.

use bloom_cloud_backend::infra::googleplay::{
    AppEdit, Bundle, CountryTargeting, GooglePlayClient, GooglePlayConfig, GooglePlayError,
    GoogleServiceAccountClaims, GoogleServiceAccountKey, LocalizedText, ReleaseStatus, Track,
    TrackRelease, ANDROID_PUBLISHER_SCOPE, BUNDLE_UPLOAD_TIMEOUT, DEFAULT_GOOGLE_PLAY_BASE_URL,
    GOOGLE_JWT_LIFETIME_SECS, GOOGLE_OAUTH2_TOKEN_URL,
};
use bloom_cloud_backend::settings::GooglePlaySettings;

/// A REAL, throwaway RSA-2048 private key, generated solely for these tests.
///
/// It must be genuine: RS256 signing rejects an invalid key, and the constant that stood
/// here before was fabricated base64 that merely looked like a key. Never point this at a
/// key used anywhere real.
const TEST_RSA_PRIVATE_KEY_PEM: &str = concat!(
    "-----BEGIN PRIVATE KEY-----\n",
    "MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDGNjCFAM3q1LEa\n",
    "wiPkT4GL48w50pUi0Bqzc+Iu7xQ7rrCUZLY+XEErWwDnOweZrtxpuumwvy3gyJYC\n",
    "KfdvjYrbM9FCkyNOV8Swp0+M9trydNQoEKIPQ6FX3drTRcGyUeqzSHGjq0SOESm4\n",
    "yrwBPaOfUOSoAjaA77acQkFoaUK3e4Oy35gcVSpsZss3zxioV+yz1W2VyOXjLjjI\n",
    "QxqhhE0a9tRFVdmZXUv50z/WC12DYq2nOx8qpoH9lmdacjijhbb0yVYAPmzFFq4i\n",
    "4YFFIvkHCM9YwZR058gkyVe7INLx6gxAwWa0yNUBM7O9AQ+6Hyd2/zpUF163vBQa\n",
    "CZY93q8XAgMBAAECggEAN4n8m3AHwuq4+2n1u6YJgySf133pmvkb2je443TLQxPm\n",
    "V5ZGuH+KJTdZL/GK5iWojhm5HHTdSpR57/5JXmEXTOeelZx78ppGO0eOU03iOLjC\n",
    "r71FY6iMH35DMBrmNOyeKoE8kmNNkM8/VQ+9kU1vuRbmEyuXkRZaITuxbyu7bYS4\n",
    "nsy2Lt4HusETW6FJjoERzftLU9YiajKJg4KJg+z4rfkALTgiSDTs7RvpsiKn2Vsd\n",
    "zkb/Zl0smYUKWTLsHnkrSp05JjkuZXHezXDzJhqgv8YBYrOBglzvqA/6P6QU/SKv\n",
    "PVeLoikuvk/fpjHjw/9i5yy7rrgdK3LHL+DexYLVZQKBgQDrBxvKwVXkucA7beAc\n",
    "frmq3SBuG0lfdw4IS02q/B95beMuKEolE7yHUc1lHh2op0Z2irHB/YtAUipuRZhm\n",
    "PklCiyt3UXd3lLWud36bxx+B2Qo0k+mAtwSiQ8QQIArKRpoNWeGMoe5fcmPhLOT0\n",
    "q+Rs2m0Momrep+Twi5MHxt6DowKBgQDX5hEzf3L4wxw/Wuaca7dcLc6fpfkFkFnv\n",
    "kM13wMtjGUgs45lHp4IKgXcTky7UpsJ4Q8oS/+qqrqPeuu35xbySsd04PQ7sybdE\n",
    "a7AQXbkYDoNNyRcrdrMruFxXjWRGM00zzKl0oZvRacbWmQnLjajB3exQZmr1qGMf\n",
    "XXmGFpB9/QKBgQDk+lX/YgE3CCnbPJ8949EsQKfZ3kfL9If9WLBgx6Y6fe76B1LF\n",
    "cMca532+6Gpo6B/kWhf5MfY7QlIIgVGLO1/Qrxo382z7Wizvv4fgaU2vCi/BLeIu\n",
    "/yBKns8kDrO0griQDWOLyjAdWasptL2UCuxPiTb5Ojv4lYadPL6QsxYTFQKBgGdA\n",
    "Ac3tD6DkPmgWIt9/rCsLRRuYlmUQydIGIB07OIlmF9xP5IgeFdTMYZQc+XJ9Zdd6\n",
    "I/O+LA4AgyILp6+h3zMQmMlCehbHyTuRfJv3FoPovObAWrJQjBNGkfLVDbV851j0\n",
    "cb3zY79cpNkQS1zrnF9KsK8qq9Bb/TuMyodT1zpJAoGBAKk2TbKqaNocLGihcHba\n",
    "YCdMEC7tSr+OHn5hFV0NUDGV0EzaktG0pmZ6gCgX9jcLQQ3ZCVmcpWZ6+4lGlVco\n",
    "NGz/873wQGjv1Tk8NwrrWpE4fwL6BcN7k+tWRsUGtI7zAesvmxUIH2neLygkweY4\n",
    "xANoo6E3ZvXl8SQwxgh5/QJ1\n",
    "-----END PRIVATE KEY-----\n",
);

/// The matching public key. Signature verification needs the PUBLIC half -- the previous
/// version of this test passed the private PEM to `from_rsa_pem`.
const TEST_RSA_PUBLIC_KEY_PEM: &str = concat!(
    "-----BEGIN PUBLIC KEY-----\n",
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxjYwhQDN6tSxGsIj5E+B\n",
    "i+PMOdKVItAas3PiLu8UO66wlGS2PlxBK1sA5zsHma7cabrpsL8t4MiWAin3b42K\n",
    "2zPRQpMjTlfEsKdPjPba8nTUKBCiD0OhV93a00XBslHqs0hxo6tEjhEpuMq8AT2j\n",
    "n1DkqAI2gO+2nEJBaGlCt3uDst+YHFUqbGbLN88YqFfss9Vtlcjl4y44yEMaoYRN\n",
    "GvbURVXZmV1L+dM/1gtdg2KtpzsfKqaB/ZZnWnI4o4W29MlWAD5sxRauIuGBRSL5\n",
    "BwjPWMGUdOfIJMlXuyDS8eoMQMFmtMjVATOzvQEPuh8ndv86VBdet7wUGgmWPd6v\n",
    "FwIDAQAB\n",
    "-----END PUBLIC KEY-----\n",
);

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
    assert_eq!(
        GOOGLE_OAUTH2_TOKEN_URL,
        "https://oauth2.googleapis.com/token"
    );
    assert_eq!(GOOGLE_JWT_LIFETIME_SECS, 3600);
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

    // 3. Delete / abandon edit
    let delete_url = GooglePlayClient::delete_edit_url(base, pkg, edit_id);
    assert_eq!(
        delete_url,
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765"
    );

    // 4. Bundle upload URL — MUST contain `/upload/` host path and `uploadType=media` query param
    let upload_url = GooglePlayClient::bundle_upload_url(base, pkg, edit_id, None);
    assert_eq!(
        upload_url,
        "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765/bundles?uploadType=media"
    );
    assert!(upload_url.contains("/upload/androidpublisher/v3/"));
    assert!(upload_url.contains("uploadType=media"));

    // 4b. Bundle upload URL with deviceTierConfigId query param
    let upload_url_tier = GooglePlayClient::bundle_upload_url(base, pkg, edit_id, Some("LATEST"));
    assert_eq!(
        upload_url_tier,
        "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/com.bloom.app/edits/edit-98765/bundles?uploadType=media&deviceTierConfigId=LATEST"
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
fn test_google_service_account_jwt_assertion_header_and_claims() {
    let client_email = "test-deployer@bloom-mobile-prod.iam.gserviceaccount.com";
    let private_key_id = "key-id-998877665544332211";
    let now = 1700000000_i64;

    let assertion = GooglePlayClient::create_service_account_assertion(
        client_email,
        private_key_id,
        TEST_RSA_PRIVATE_KEY_PEM,
        now,
    )
    .expect("minting RS256 assertion should succeed");

    // 1. Assert on decoded JWT header
    let header = jsonwebtoken::decode_header(&assertion).expect("decode JWT header");
    assert_eq!(header.alg, jsonwebtoken::Algorithm::RS256);
    assert_eq!(header.typ.as_deref(), Some("JWT"));
    assert_eq!(header.kid.as_deref(), Some(private_key_id));

    // 2. Decode claims payload and verify fields
    let decoding_key = jsonwebtoken::DecodingKey::from_rsa_pem(TEST_RSA_PUBLIC_KEY_PEM.as_bytes())
        .expect("build decoding key from RSA test public PEM");
    let mut validation = jsonwebtoken::Validation::new(jsonwebtoken::Algorithm::RS256);
    validation.set_audience(&[GOOGLE_OAUTH2_TOKEN_URL]);
    validation.validate_exp = false; // deterministic verification with fixed timestamps

    let token_data =
        jsonwebtoken::decode::<GoogleServiceAccountClaims>(&assertion, &decoding_key, &validation)
            .expect("decode and verify token signature");

    assert_eq!(token_data.claims.iss, client_email);
    assert_eq!(
        token_data.claims.scope,
        "https://www.googleapis.com/auth/androidpublisher"
    );
    assert_eq!(token_data.claims.aud, "https://oauth2.googleapis.com/token");
    assert_eq!(token_data.claims.iat, now);
    assert_eq!(token_data.claims.exp, now + 3600);
    // Lifetime must be exactly 3600s (Google maximum ceiling)
    assert_eq!(token_data.claims.exp - token_data.claims.iat, 3600);
}

#[test]
fn test_google_service_account_json_malformed_errors() {
    let client = GooglePlayClient::unconfigured();

    // 1. Invalid JSON syntax
    let err_syntax = tokio::runtime::Runtime::new()
        .unwrap()
        .block_on(client.mint_service_account_token("not-a-json-string"));
    assert!(matches!(err_syntax, Err(GooglePlayError::Auth(_))));

    // 2. Missing client_email
    let json_no_email = r#"{
        "private_key_id": "key123",
        "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC6m8N1u7a/6v8y\n-----END PRIVATE KEY-----"
    }"#;
    let err_email = tokio::runtime::Runtime::new()
        .unwrap()
        .block_on(client.mint_service_account_token(json_no_email));
    match err_email {
        Err(GooglePlayError::Auth(msg)) => assert!(msg.contains("client_email")),
        other => panic!("expected Auth error naming client_email, got {other:?}"),
    }

    // 3. Missing private_key
    let json_no_key = r#"{
        "client_email": "test@project.iam.gserviceaccount.com",
        "private_key_id": "key123"
    }"#;
    let err_key = tokio::runtime::Runtime::new()
        .unwrap()
        .block_on(client.mint_service_account_token(json_no_key));
    match err_key {
        Err(GooglePlayError::Auth(msg)) => assert!(msg.contains("private_key")),
        other => panic!("expected Auth error naming private_key, got {other:?}"),
    }

    // 4. Missing private_key_id
    let json_no_kid = r#"{
        "client_email": "test@project.iam.gserviceaccount.com",
        "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC6m8N1u7a/6v8y\n-----END PRIVATE KEY-----"
    }"#;
    let err_kid = tokio::runtime::Runtime::new()
        .unwrap()
        .block_on(client.mint_service_account_token(json_no_kid));
    match err_kid {
        Err(GooglePlayError::Auth(msg)) => assert!(msg.contains("private_key_id")),
        other => panic!("expected Auth error naming private_key_id, got {other:?}"),
    }

    // 5. Corrupt RSA private key PEM
    let json_corrupt_pem = r#"{
        "client_email": "test@project.iam.gserviceaccount.com",
        "private_key_id": "key123",
        "private_key": "-----BEGIN PRIVATE KEY-----\ninvalid-base64-content\n-----END PRIVATE KEY-----"
    }"#;
    let err_pem = tokio::runtime::Runtime::new()
        .unwrap()
        .block_on(client.mint_service_account_token(json_corrupt_pem));
    assert!(matches!(err_pem, Err(GooglePlayError::Auth(_))));
}

#[test]
fn test_google_service_account_key_debug_redaction() {
    let key_struct = GoogleServiceAccountKey {
        client_email: Some("secret-sa@project.iam.gserviceaccount.com".to_string()),
        private_key: Some("SUPER_SECRET_RSA_PRIVATE_KEY_MATERIAL".to_string()),
        private_key_id: Some("key-id-12345".to_string()),
        token_uri: Some("https://oauth2.googleapis.com/token".to_string()),
    };

    let debug_output = format!("{key_struct:?}");
    assert!(!debug_output.contains("SUPER_SECRET_RSA_PRIVATE_KEY_MATERIAL"));
    assert!(debug_output.contains("[REDACTED]"));
    assert!(debug_output.contains("secret-sa@project.iam.gserviceaccount.com"));
    assert!(debug_output.contains("key-id-12345"));
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
