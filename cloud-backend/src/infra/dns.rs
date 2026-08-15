//! DNS resolution abstraction for domain verification and ACME challenge validation.
//!
//! # Architecture & Boundary
//!
//! All DNS lookups across Bloom Cloud flow through the [`DnsResolver`] trait to maintain a
//! strict isolation boundary between business logic and the network stack. This ensures:
//! - Unit and integration tests never make live network calls or depend on public DNS availability.
//! - Test doubles ([`StaticDnsResolver`]) can inject exact DNS responses, simulated network
//!   delays, or simulated DNS outages in memory.
//! - Production resolves through [`SystemDnsResolver`] via standard system utilities.
//!
//! # Long-Term Architecture Note
//!
//! `SystemDnsResolver` currently shells out to the system resolver (`dig` / system CLI) via
//! `tokio::process::Command` with strict timeouts and defensive parsing to avoid adding new
//! third-party dependencies to `Cargo.toml` (per project policy). The recommended long-term
//! production architecture is to incorporate a native pure-Rust async resolver crate such as
//! `hickory-resolver` (formerly `trust-dns-resolver`) once third-party crate additions are
//! unlocked.

use std::collections::HashMap;
use std::fmt;
use std::net::IpAddr;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use tokio::sync::RwLock;

/// Default timeout duration for system DNS queries (5 seconds).
pub const DEFAULT_DNS_TIMEOUT: Duration = Duration::from_secs(5);

/// Errors originating from DNS query and resolution operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DnsError {
    /// The requested DNS record type was not found for the queried domain name.
    NotFound(String),
    /// The DNS query timed out before a response was received.
    Timeout(String),
    /// DNS query execution or record parsing failed.
    Resolution(String),
}

impl fmt::Display for DnsError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NotFound(msg) => write!(f, "DNS record not found: {msg}"),
            Self::Timeout(msg) => write!(f, "DNS query timed out: {msg}"),
            Self::Resolution(msg) => write!(f, "DNS resolution failed: {msg}"),
        }
    }
}

impl std::error::Error for DnsError {}

/// Abstract DNS resolver contract for domain verification and routing validation.
#[async_trait]
pub trait DnsResolver: Send + Sync {
    /// Looks up TXT records for the specified fully-qualified domain name.
    async fn lookup_txt(&self, name: &str) -> Result<Vec<String>, DnsError>;

    /// Looks up the canonical name (CNAME) target for the specified domain name.
    ///
    /// Returns `Ok(Some(target))` if a CNAME is configured, or `Ok(None)` if no CNAME exists.
    async fn lookup_cname(&self, name: &str) -> Result<Option<String>, DnsError>;

    /// Looks up A/AAAA IP addresses for the specified domain name.
    async fn lookup_a(&self, name: &str) -> Result<Vec<IpAddr>, DnsError>;
}

/// Concrete production DNS resolver shelling out to system utilities (`dig`).
///
/// Uses `tokio::process::Command` with defensive output parsing and timeout enforcement.
#[derive(Debug, Clone)]
pub struct SystemDnsResolver {
    timeout: Duration,
}

impl SystemDnsResolver {
    /// Creates a new `SystemDnsResolver` with the default 5-second timeout.
    pub fn new() -> Self {
        Self {
            timeout: DEFAULT_DNS_TIMEOUT,
        }
    }

    /// Creates a `SystemDnsResolver` with a custom query timeout.
    pub fn with_timeout(timeout: Duration) -> Self {
        Self { timeout }
    }

    /// Helper to execute `dig +short` command with timeout and error handling.
    async fn exec_dig(&self, qtype: &str, name: &str) -> Result<String, DnsError> {
        let clean_name = name.trim().trim_end_matches('.');
        if clean_name.is_empty() {
            return Err(DnsError::Resolution(
                "Domain name cannot be empty".to_string(),
            ));
        }

        let cmd_future = tokio::process::Command::new("dig")
            .args(["+short", "+time=2", "+tries=2", qtype, clean_name])
            .output();

        let output = tokio::time::timeout(self.timeout, cmd_future)
            .await
            .map_err(|_| {
                DnsError::Timeout(format!(
                    "Query for {qtype} on '{clean_name}' timed out after {:?}",
                    self.timeout
                ))
            })?
            .map_err(|e| {
                DnsError::Resolution(format!(
                    "Failed to execute system resolver for '{clean_name}': {e}"
                ))
            })?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(DnsError::Resolution(format!(
                "Resolver exited with status {}: {stderr}",
                output.status
            )));
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}

impl Default for SystemDnsResolver {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl DnsResolver for SystemDnsResolver {
    async fn lookup_txt(&self, name: &str) -> Result<Vec<String>, DnsError> {
        let stdout = self.exec_dig("TXT", name).await?;
        let mut records = Vec::new();

        for line in stdout.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            // `dig +short TXT` quotes string records: "value" -> value
            let unquoted = trimmed.trim_matches('"').replace("\" \"", "");
            if !unquoted.is_empty() {
                records.push(unquoted);
            }
        }

        if records.is_empty() {
            Err(DnsError::NotFound(format!(
                "No TXT records found for '{name}'"
            )))
        } else {
            Ok(records)
        }
    }

    async fn lookup_cname(&self, name: &str) -> Result<Option<String>, DnsError> {
        let stdout = self.exec_dig("CNAME", name).await?;
        for line in stdout.lines() {
            let trimmed = line.trim();
            if !trimmed.is_empty() {
                // Strip trailing FQDN dot for clean comparison
                let clean_target = trimmed.trim_end_matches('.').to_string();
                return Ok(Some(clean_target));
            }
        }
        Ok(None)
    }

    async fn lookup_a(&self, name: &str) -> Result<Vec<IpAddr>, DnsError> {
        let stdout = self.exec_dig("A", name).await?;
        let mut ips = Vec::new();

        for line in stdout.lines() {
            let trimmed = line.trim();
            if let Ok(ip) = trimmed.parse::<IpAddr>() {
                ips.push(ip);
            }
        }

        if ips.is_empty() {
            Err(DnsError::NotFound(format!(
                "No A/AAAA records found for '{name}'"
            )))
        } else {
            Ok(ips)
        }
    }
}

/// In-memory static DNS resolver for unit and integration testing.
///
/// Holds predefined records in thread-safe memory to ensure tests never touch live DNS.
#[derive(Debug, Clone, Default)]
pub struct StaticDnsResolver {
    txt_records: Arc<RwLock<HashMap<String, Vec<String>>>>,
    cname_records: Arc<RwLock<HashMap<String, String>>>,
    a_records: Arc<RwLock<HashMap<String, Vec<IpAddr>>>>,
}

impl StaticDnsResolver {
    /// Creates an empty in-memory static resolver.
    pub fn new() -> Self {
        Self {
            txt_records: Arc::new(RwLock::new(HashMap::new())),
            cname_records: Arc::new(RwLock::new(HashMap::new())),
            a_records: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Builder helper to insert TXT records for a domain.
    pub async fn with_txt(self, name: impl Into<String>, records: Vec<String>) -> Self {
        self.txt_records
            .write()
            .await
            .insert(name.into().to_ascii_lowercase(), records);
        self
    }

    /// Builder helper to insert a CNAME target for a domain.
    pub async fn with_cname(self, name: impl Into<String>, target: impl Into<String>) -> Self {
        self.cname_records
            .write()
            .await
            .insert(name.into().to_ascii_lowercase(), target.into());
        self
    }

    /// Builder helper to insert IP addresses for a domain.
    pub async fn with_a(self, name: impl Into<String>, ips: Vec<IpAddr>) -> Self {
        self.a_records
            .write()
            .await
            .insert(name.into().to_ascii_lowercase(), ips);
        self
    }

    /// Inserts TXT records for a domain.
    pub async fn insert_txt(&self, name: impl Into<String>, records: Vec<String>) {
        self.txt_records
            .write()
            .await
            .insert(name.into().to_ascii_lowercase(), records);
    }

    /// Inserts a CNAME target for a domain.
    pub async fn insert_cname(&self, name: impl Into<String>, target: impl Into<String>) {
        self.cname_records
            .write()
            .await
            .insert(name.into().to_ascii_lowercase(), target.into());
    }

    /// Inserts A/AAAA IP records for a domain.
    pub async fn insert_a(&self, name: impl Into<String>, ips: Vec<IpAddr>) {
        self.a_records
            .write()
            .await
            .insert(name.into().to_ascii_lowercase(), ips);
    }

    /// Removes all configured records.
    pub async fn clear(&self) {
        self.txt_records.write().await.clear();
        self.cname_records.write().await.clear();
        self.a_records.write().await.clear();
    }
}

#[async_trait]
impl DnsResolver for StaticDnsResolver {
    async fn lookup_txt(&self, name: &str) -> Result<Vec<String>, DnsError> {
        let clean = name.trim().trim_end_matches('.').to_ascii_lowercase();
        let guard = self.txt_records.read().await;
        match guard.get(&clean) {
            Some(records) if !records.is_empty() => Ok(records.clone()),
            _ => Err(DnsError::NotFound(format!(
                "No static TXT record configured for '{clean}'"
            ))),
        }
    }

    async fn lookup_cname(&self, name: &str) -> Result<Option<String>, DnsError> {
        let clean = name.trim().trim_end_matches('.').to_ascii_lowercase();
        let guard = self.cname_records.read().await;
        Ok(guard.get(&clean).cloned())
    }

    async fn lookup_a(&self, name: &str) -> Result<Vec<IpAddr>, DnsError> {
        let clean = name.trim().trim_end_matches('.').to_ascii_lowercase();
        let guard = self.a_records.read().await;
        match guard.get(&clean) {
            Some(ips) if !ips.is_empty() => Ok(ips.clone()),
            _ => Err(DnsError::NotFound(format!(
                "No static A record configured for '{clean}'"
            ))),
        }
    }
}
