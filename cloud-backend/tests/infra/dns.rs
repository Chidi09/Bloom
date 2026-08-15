//! Integration tests for the DNS resolver boundary and static test double.

use std::net::{IpAddr, Ipv4Addr};

use bloom_cloud_backend::infra::dns::{
    DnsError, DnsResolver, StaticDnsResolver, SystemDnsResolver, DEFAULT_DNS_TIMEOUT,
};

#[tokio::test]
async fn test_static_dns_resolver_txt_lookup() {
    let resolver = StaticDnsResolver::new()
        .with_txt(
            "_bloom-challenge.app.example.com",
            vec!["bloom_verify_token_12345".to_string()],
        )
        .await;

    // Direct lookup succeeds
    let records = resolver
        .lookup_txt("_bloom-challenge.app.example.com")
        .await
        .expect("lookup txt succeeds");
    assert_eq!(records, vec!["bloom_verify_token_12345"]);

    // Case-insensitive lookup succeeds
    let records_upper = resolver
        .lookup_txt("_BLOOM-CHALLENGE.APP.EXAMPLE.COM")
        .await
        .expect("case-insensitive lookup succeeds");
    assert_eq!(records_upper, vec!["bloom_verify_token_12345"]);

    // Trailing dot lookup succeeds
    let records_dot = resolver
        .lookup_txt("_bloom-challenge.app.example.com.")
        .await
        .expect("trailing dot lookup succeeds");
    assert_eq!(records_dot, vec!["bloom_verify_token_12345"]);

    // Unconfigured host returns NotFound
    let missing = resolver.lookup_txt("missing.example.com").await;
    assert!(matches!(missing, Err(DnsError::NotFound(_))));
}

#[tokio::test]
async fn test_static_dns_resolver_cname_lookup() {
    let resolver = StaticDnsResolver::new()
        .with_cname("app.example.com", "my-app-web.bloomcloud.dev")
        .await;

    let target = resolver
        .lookup_cname("app.example.com")
        .await
        .expect("lookup cname succeeds");
    assert_eq!(target, Some("my-app-web.bloomcloud.dev".to_string()));

    let target_upper = resolver
        .lookup_cname("APP.EXAMPLE.COM.")
        .await
        .expect("case-insensitive cname lookup succeeds");
    assert_eq!(target_upper, Some("my-app-web.bloomcloud.dev".to_string()));

    let missing = resolver
        .lookup_cname("other.example.com")
        .await
        .expect("unconfigured returns Ok(None)");
    assert_eq!(missing, None);
}

#[tokio::test]
async fn test_static_dns_resolver_a_lookup() {
    let ip = IpAddr::V4(Ipv4Addr::new(76, 76, 21, 21));
    let resolver = StaticDnsResolver::new()
        .with_a("example.com", vec![ip])
        .await;

    let ips = resolver
        .lookup_a("example.com")
        .await
        .expect("lookup A succeeds");
    assert_eq!(ips, vec![ip]);

    let missing = resolver.lookup_a("missing.com").await;
    assert!(matches!(missing, Err(DnsError::NotFound(_))));
}

#[tokio::test]
async fn test_static_dns_resolver_mutation_and_clear() {
    let resolver = StaticDnsResolver::new();

    resolver
        .insert_txt("sub.test.dev", vec!["token-abc".to_string()])
        .await;
    resolver
        .insert_cname("sub.test.dev", "target.bloomcloud.dev")
        .await;
    resolver
        .insert_a("sub.test.dev", vec![IpAddr::V4(Ipv4Addr::new(1, 1, 1, 1))])
        .await;

    assert!(resolver.lookup_txt("sub.test.dev").await.is_ok());
    assert!(resolver
        .lookup_cname("sub.test.dev")
        .await
        .unwrap()
        .is_some());
    assert!(resolver.lookup_a("sub.test.dev").await.is_ok());

    resolver.clear().await;

    assert!(resolver.lookup_txt("sub.test.dev").await.is_err());
    assert_eq!(resolver.lookup_cname("sub.test.dev").await.unwrap(), None);
    assert!(resolver.lookup_a("sub.test.dev").await.is_err());
}

#[test]
fn test_dns_error_display_and_traits() {
    let not_found = DnsError::NotFound("no records".to_string());
    assert_eq!(format!("{not_found}"), "DNS record not found: no records");

    let timeout = DnsError::Timeout("timed out after 5s".to_string());
    assert_eq!(
        format!("{timeout}"),
        "DNS query timed out: timed out after 5s"
    );

    let resolution = DnsError::Resolution("NXDOMAIN".to_string());
    assert_eq!(format!("{resolution}"), "DNS resolution failed: NXDOMAIN");
}

#[test]
fn test_system_dns_resolver_defaults() {
    let resolver = SystemDnsResolver::new();
    let resolver_default = SystemDnsResolver::default();
    assert_eq!(DEFAULT_DNS_TIMEOUT, std::time::Duration::from_secs(5));
    let _ = resolver;
    let _ = resolver_default;
}
