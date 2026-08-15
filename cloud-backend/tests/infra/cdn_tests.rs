//! Unit tests for Cloudflare CDN cache invalidation client and chunking boundaries.

use bloom_cloud_backend::infra::cdn::{
    CdnClient, CdnError, CloudflarePurgeResult, CloudflareResponse, PurgeByFilesRequest,
    PurgeByPrefixRequest, PurgeEverythingRequest, PurgeOutcome, MAX_PREFIXES_PER_PURGE,
    MAX_URLS_PER_PURGE,
};
use bloom_cloud_backend::settings::CloudflareSettings;

#[test]
fn test_cloudflare_constants() {
    // Assert chunk limits required by EXTERNAL_APIS.txt
    assert_eq!(MAX_PREFIXES_PER_PURGE, 30);
    assert_eq!(MAX_URLS_PER_PURGE, 100);
}

#[test]
fn test_chunk_items_prefix_boundaries() {
    // 0 items
    let empty: Vec<String> = vec![];
    let chunks = CdnClient::chunk_items(&empty, MAX_PREFIXES_PER_PURGE);
    assert_eq!(chunks.len(), 0);

    // Exactly 30 prefixes -> 1 batch of 30
    let items_30: Vec<String> = (0..30).map(|i| format!("example.com/prefix-{i}")).collect();
    let chunks_30 = CdnClient::chunk_items(&items_30, MAX_PREFIXES_PER_PURGE);
    assert_eq!(chunks_30.len(), 1);
    assert_eq!(chunks_30[0].len(), 30);

    // Exactly 31 prefixes -> 2 batches (30, 1)
    let items_31: Vec<String> = (0..31).map(|i| format!("example.com/prefix-{i}")).collect();
    let chunks_31 = CdnClient::chunk_items(&items_31, MAX_PREFIXES_PER_PURGE);
    assert_eq!(chunks_31.len(), 2);
    assert_eq!(chunks_31[0].len(), 30);
    assert_eq!(chunks_31[1].len(), 1);

    // 60 prefixes -> 2 batches of 30
    let items_60: Vec<String> = (0..60).map(|i| format!("example.com/prefix-{i}")).collect();
    let chunks_60 = CdnClient::chunk_items(&items_60, MAX_PREFIXES_PER_PURGE);
    assert_eq!(chunks_60.len(), 2);
    assert_eq!(chunks_60[0].len(), 30);
    assert_eq!(chunks_60[1].len(), 30);
}

#[test]
fn test_chunk_items_urls_boundaries() {
    // Exactly 100 URLs -> 1 batch of 100
    let urls_100: Vec<String> = (0..100)
        .map(|i| format!("https://example.com/asset-{i}.js"))
        .collect();
    let chunks_100 = CdnClient::chunk_items(&urls_100, MAX_URLS_PER_PURGE);
    assert_eq!(chunks_100.len(), 1);
    assert_eq!(chunks_100[0].len(), 100);

    // Exactly 101 URLs -> 2 batches (100, 1)
    let urls_101: Vec<String> = (0..101)
        .map(|i| format!("https://example.com/asset-{i}.js"))
        .collect();
    let chunks_101 = CdnClient::chunk_items(&urls_101, MAX_URLS_PER_PURGE);
    assert_eq!(chunks_101.len(), 2);
    assert_eq!(chunks_101[0].len(), 100);
    assert_eq!(chunks_101[1].len(), 1);

    // 250 URLs -> 3 batches (100, 100, 50)
    let urls_250: Vec<String> = (0..250)
        .map(|i| format!("https://example.com/asset-{i}.js"))
        .collect();
    let chunks_250 = CdnClient::chunk_items(&urls_250, MAX_URLS_PER_PURGE);
    assert_eq!(chunks_250.len(), 3);
    assert_eq!(chunks_250[0].len(), 100);
    assert_eq!(chunks_250[1].len(), 100);
    assert_eq!(chunks_250[2].len(), 50);
}

#[test]
fn test_request_body_json_shapes() {
    // 1. By prefix
    let prefix_req = PurgeByPrefixRequest {
        prefixes: vec![
            "example.com/foo".to_string(),
            "images.example.com/bar".to_string(),
        ],
    };
    let prefix_json = serde_json::to_string(&prefix_req).expect("serialize prefix req");
    assert_eq!(
        prefix_json,
        r#"{"prefixes":["example.com/foo","images.example.com/bar"]}"#
    );

    // 2. By files
    let files_req = PurgeByFilesRequest {
        files: vec![
            "https://example.com/a.js".to_string(),
            "https://example.com/b.css".to_string(),
        ],
    };
    let files_json = serde_json::to_string(&files_req).expect("serialize files req");
    assert_eq!(
        files_json,
        r#"{"files":["https://example.com/a.js","https://example.com/b.css"]}"#
    );

    // 3. Purge everything
    let everything_req = PurgeEverythingRequest {
        purge_everything: true,
    };
    let everything_json = serde_json::to_string(&everything_req).expect("serialize everything req");
    assert_eq!(everything_json, r#"{"purge_everything":true}"#);
}

#[test]
fn test_response_envelope_parsing_success() {
    let raw_success = r#"{
        "success": true,
        "result": { "id": "023e105f4ecef8ad9ca31a8372d0c353" },
        "errors": [],
        "messages": []
    }"#;

    let parsed: CloudflareResponse =
        serde_json::from_str(raw_success).expect("parse success envelope");
    assert!(parsed.success);
    assert_eq!(
        parsed.result,
        Some(CloudflarePurgeResult {
            id: Some("023e105f4ecef8ad9ca31a8372d0c353".to_string())
        })
    );
    assert!(parsed.errors.is_empty());
}

#[test]
fn test_response_envelope_parsing_failure() {
    let raw_failure = r#"{
        "success": false,
        "result": null,
        "errors": [
            {
                "code": 1012,
                "message": "Request must contain at least one of \"purge_everything\", \"files\", \"tags\", \"hosts\" or \"prefixes\"",
                "documentation_url": "https://developers.cloudflare.com/api/errors/1012"
            }
        ],
        "messages": [
            {
                "code": 1234,
                "message": "Informational notice",
                "documentation_url": null
            }
        ]
    }"#;

    let parsed: CloudflareResponse =
        serde_json::from_str(raw_failure).expect("parse failure envelope");
    assert!(!parsed.success);
    assert_eq!(parsed.errors.len(), 1);
    assert_eq!(parsed.errors[0].code, 1012);
    assert!(parsed.errors[0].message.contains("Request must contain"));
    assert_eq!(
        parsed.errors[0].documentation_url.as_deref(),
        Some("https://developers.cloudflare.com/api/errors/1012")
    );

    let err = CdnError::Api {
        status: 200,
        errors: parsed.errors,
    };
    let err_str = format!("{err}");
    assert!(err_str.contains("Cloudflare CDN API error (HTTP 200)"));
    assert!(err_str.contains("[code 1012]"));
}

#[tokio::test]
async fn test_unconfigured_cdn_client_skips_without_error() {
    let settings = CloudflareSettings {
        api_token: None,
        zone_id: None,
        account_id: None,
        apex_domain: None,
    };

    let client = CdnClient::new(&settings);
    assert!(!client.is_configured());

    // 1. Purge prefixes when unconfigured returns PurgeOutcome::Skipped
    let prefixes = vec!["bloom.app/web/dep-123".to_string()];
    let outcome = client
        .purge_prefixes(&prefixes)
        .await
        .expect("unconfigured purge prefixes should not error");

    assert!(matches!(outcome, PurgeOutcome::Skipped { .. }));

    // 2. Purge files when unconfigured returns PurgeOutcome::Skipped
    let urls = vec!["https://bloom.app/main.dart.js".to_string()];
    let outcome_files = client
        .purge_files(&urls)
        .await
        .expect("unconfigured purge files should not error");

    assert!(matches!(outcome_files, PurgeOutcome::Skipped { .. }));

    // 3. Dangerous purge everything when unconfigured returns PurgeOutcome::Skipped
    let outcome_everything = client
        .dangerous_purge_zone_everything()
        .await
        .expect("unconfigured dangerous purge should not error");

    assert!(matches!(outcome_everything, PurgeOutcome::Skipped { .. }));
}

#[tokio::test]
async fn test_empty_slices_return_zero_batches() {
    let settings = CloudflareSettings {
        api_token: Some("dummy_token".to_string()),
        zone_id: Some("dummy_zone".to_string()),
        account_id: None,
        apex_domain: None,
    };

    let client = CdnClient::new(&settings);
    assert!(client.is_configured());

    let outcome_prefixes = client
        .purge_prefixes(&[])
        .await
        .expect("empty prefixes returns Ok");
    assert_eq!(outcome_prefixes, PurgeOutcome::Purged { batches_sent: 0 });

    let outcome_files = client
        .purge_files(&[])
        .await
        .expect("empty files returns Ok");
    assert_eq!(outcome_files, PurgeOutcome::Purged { batches_sent: 0 });
}

#[test]
fn test_purge_endpoint_url_generation() {
    let url = CdnClient::purge_endpoint_url("zone_abc123");
    assert_eq!(
        url,
        "https://api.cloudflare.com/client/v4/zones/zone_abc123/purge_cache"
    );
}
