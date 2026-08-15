//! Unit tests for Caddy reverse proxy admin API client and scoped `@id` routing.

use serde_json::json;

use bloom_cloud_backend::infra::caddy::{
    caddy_site_id, CaddyClient, CaddyError, CaddyFileServerHandler, CaddyMatchRule,
    CaddyReverseProxyHandler, CaddySiteBlock, CaddyUpstream,
};
use bloom_cloud_backend::settings::CaddySettings;

#[test]
fn test_caddy_site_id_derivation() {
    let deployment_id = "dep_9f83acde-9238-4729-10fa-e1234567890a";
    let site_id = caddy_site_id(deployment_id);
    assert_eq!(
        site_id,
        "bloom-site-dep_9f83acde-9238-4729-10fa-e1234567890a"
    );

    // Trims whitespace
    let untrimmed_id = "   dep_12345   ";
    assert_eq!(caddy_site_id(untrimmed_id), "bloom-site-dep_12345");
}

#[test]
fn test_caddy_url_builders() {
    let settings = CaddySettings {
        admin_url: "http://127.0.0.1:2019/".to_string(),
        admin_token: Some("secret-admin-token".to_string()),
        acme_email: Some("ops@bloom.sh".to_string()),
    };

    let client = CaddyClient::new(&settings);
    assert_eq!(client.admin_url(), "http://127.0.0.1:2019");

    // Scoped /id endpoint
    assert_eq!(
        client.id_endpoint_url("bloom-site-123"),
        "http://127.0.0.1:2019/id/bloom-site-123"
    );

    // Scoped /id subpath endpoint
    assert_eq!(
        client.id_subpath_endpoint_url("bloom-site-123", "handle/0"),
        "http://127.0.0.1:2019/id/bloom-site-123/handle/0"
    );
    assert_eq!(
        client.id_subpath_endpoint_url("bloom-site-123", "/handle/0/"),
        "http://127.0.0.1:2019/id/bloom-site-123/handle/0/"
    );

    // /config endpoint
    assert_eq!(
        client.config_endpoint_url("apps/http/servers/srv0/routes"),
        "http://127.0.0.1:2019/config/apps/http/servers/srv0/routes"
    );
    assert_eq!(
        client.config_endpoint_url("/apps/http/servers/srv0/routes/..."),
        "http://127.0.0.1:2019/config/apps/http/servers/srv0/routes/..."
    );
}

#[test]
fn test_caddy_site_block_serialization_with_id() {
    let deployment_id = "dep_test_123";
    let site_id = caddy_site_id(deployment_id);

    let site_block = CaddySiteBlock {
        id: site_id.clone(),
        r#match: Some(vec![CaddyMatchRule {
            host: Some(vec!["myapp.bloom.app".to_string()]),
        }]),
        handle: vec![json!({
            "handler": "file_server",
            "root": "/var/www/deployments/dep_test_123",
            "index_names": ["index.html"]
        })],
        terminal: Some(true),
    };

    let serialized = serde_json::to_string(&site_block).expect("serialize site block");

    // Verify @id key is present at root of JSON object
    assert!(serialized.contains(r#""@id":"bloom-site-dep_test_123""#));
    assert!(serialized.contains(r#""host":["myapp.bloom.app"]"#));
    assert!(serialized.contains(r#""handler":"file_server""#));
    assert!(serialized.contains(r#""terminal":true"#));

    // Verify roundtrip deserialization
    let deserialized: CaddySiteBlock =
        serde_json::from_str(&serialized).expect("deserialize site block");
    assert_eq!(deserialized.id, site_id);
    assert_eq!(deserialized.terminal, Some(true));
    assert_eq!(deserialized.handle.len(), 1);
}

#[test]
fn test_caddy_reverse_proxy_handler_serialization() {
    let handler = CaddyReverseProxyHandler {
        handler: "reverse_proxy".to_string(),
        upstreams: vec![CaddyUpstream {
            dial: "127.0.0.1:8080".to_string(),
        }],
    };

    let val = serde_json::to_value(&handler).expect("to value");
    assert_eq!(val["handler"], "reverse_proxy");
    assert_eq!(val["upstreams"][0]["dial"], "127.0.0.1:8080");
}

#[test]
fn test_caddy_file_server_handler_serialization() {
    let handler = CaddyFileServerHandler {
        handler: "file_server".to_string(),
        root: Some("/srv/www".to_string()),
        index_names: Some(vec!["index.html".to_string(), "main.dart.js".to_string()]),
    };

    let val = serde_json::to_value(&handler).expect("to value");
    assert_eq!(val["handler"], "file_server");
    assert_eq!(val["root"], "/srv/www");
    assert_eq!(val["index_names"][0], "index.html");
}

#[test]
fn test_caddy_error_display() {
    let config_err = CaddyError::Config("Invalid admin url".to_string());
    assert_eq!(
        format!("{config_err}"),
        "Caddy configuration error: Invalid admin url"
    );

    let api_err = CaddyError::Api {
        status: 404,
        message: "unknown @id: bloom-site-999".to_string(),
    };
    assert_eq!(
        format!("{api_err}"),
        "Caddy Admin API error (HTTP 404): unknown @id: bloom-site-999"
    );
}
