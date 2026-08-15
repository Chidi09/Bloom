//! Business logic, domain rules, and transactional workflows for `webhosting`.

use chrono::Utc;
use djangors_db::Database;
use djangors_orm::ForeignKey;
use uuid::Uuid;

use super::contracts::{CreateCustomDomainRequest, DeployWebRequest, RequiredDnsRecord};
use super::errors::WebHostingError;
use super::models::{CustomDomain, WebDeployment};
use super::permissions::OrganizationRole;
use super::repositories;
use crate::infra::caddy::{caddy_custom_domain_id, CaddyClient};
use crate::infra::crypto::Crypto;
use crate::infra::dns::DnsResolver;
use crate::infra::storage::ObjectStorage;

/// Valid deployment target types.
pub const VALID_TARGETS: &[&str] = &["preview", "production"];

/// Valid deployment lifecycle statuses.
pub const VALID_DEPLOYMENT_STATUSES: &[&str] = &["deploying", "live", "failed", "rolled_back"];

/// Valid custom domain certificate statuses.
pub const VALID_CERTIFICATE_STATUSES: &[&str] = &["pending", "issuing", "active", "failed"];

/// Default apex domain when `CloudflareSettings.apex_domain` is unconfigured.
pub const DEFAULT_APEX_DOMAIN: &str = "bloomcloud.dev";

/// Default edge A record IP address for apex domain routing.
pub const DEFAULT_EDGE_A_RECORD_IP: &str = "76.76.21.21";

/// Validates that a certificate status is one of the allowed choices.
pub fn validate_certificate_status(status: &str) -> Result<(), WebHostingError> {
    if VALID_CERTIFICATE_STATUSES.contains(&status) {
        Ok(())
    } else {
        Err(WebHostingError::ValidationError(format!(
            "Invalid certificate status '{status}'. Allowed: {VALID_CERTIFICATE_STATUSES:?}"
        )))
    }
}

/// Detailed web deployment with resolved related public UUIDs for wire serialization.
#[derive(Debug, Clone)]
pub struct WebDeploymentDetail {
    /// The underlying web deployment record.
    pub deployment: WebDeployment,
    /// External public UUID of the parent app.
    pub app_public_id: String,
    /// External public UUID of the target environment.
    pub environment_public_id: String,
    /// Optional external public UUID of the associated release.
    pub release_public_id: Option<String>,
    /// Public identifier string of the deploying user.
    pub deployed_by_public_id: String,
}

/// Detailed custom domain with resolved parent app public UUID and required DNS records.
#[derive(Debug, Clone)]
pub struct CustomDomainDetail {
    /// The underlying custom domain record.
    pub domain: CustomDomain,
    /// External public UUID of the parent app.
    pub app_public_id: String,
    /// Instructions for DNS records the customer must configure.
    pub required_records: Vec<RequiredDnsRecord>,
}

/// Returns `true` when `from -> to` is a legal deployment status transition.
pub fn can_transition(from: &str, to: &str) -> bool {
    matches!(
        (from, to),
        ("deploying", "live") | ("deploying", "failed") | ("live", "rolled_back")
    )
}

/// Sanitizes a Git branch name for use as a subdomain component.
pub fn sanitize_branch_slug(branch: &str) -> String {
    let mut sanitized = String::with_capacity(branch.len());
    let mut last_was_dash = true;
    for c in branch.chars() {
        if c.is_ascii_alphanumeric() {
            sanitized.push(c.to_ascii_lowercase());
            last_was_dash = false;
        } else if !last_was_dash {
            sanitized.push('-');
            last_was_dash = true;
        }
    }

    let trimmed = sanitized.trim_matches('-');
    if trimmed.is_empty() {
        "preview".to_string()
    } else {
        trimmed.to_string()
    }
}

/// Constructs a preview URL under the configured Cloudflare apex domain.
pub fn build_preview_url(
    apex_domain: Option<&str>,
    branch: &str,
    app_slug: &str,
    project_slug: &str,
) -> String {
    let apex = apex_domain
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_APEX_DOMAIN);

    let clean_branch = sanitize_branch_slug(branch);
    let clean_app = app_slug.trim().to_ascii_lowercase();
    let clean_project = project_slug.trim().to_ascii_lowercase();

    format!("https://{clean_branch}-{clean_app}-{clean_project}.{apex}")
}

/// Constructs a production URL under the configured Cloudflare apex domain.
pub fn build_production_url(
    apex_domain: Option<&str>,
    app_slug: &str,
    project_slug: &str,
) -> String {
    let apex = apex_domain
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_APEX_DOMAIN);

    let clean_app = app_slug.trim().to_ascii_lowercase();
    let clean_project = project_slug.trim().to_ascii_lowercase();

    format!("https://{clean_app}-{clean_project}.{apex}")
}

/// Constructs the canonical object-storage path prefix for a web deployment.
pub fn build_web_storage_prefix(
    org_public_id: &str,
    project_public_id: &str,
    app_public_id: &str,
    deployment_public_id: &str,
) -> String {
    format!(
        "orgs/{org_public_id}/projects/{project_public_id}/apps/{app_public_id}/web/{deployment_public_id}"
    )
}

/// Validates that a target is one of `preview` or `production`.
pub fn validate_target(target: &str) -> Result<(), WebHostingError> {
    if VALID_TARGETS.contains(&target) {
        Ok(())
    } else {
        Err(WebHostingError::InvalidTarget)
    }
}

/// Validates a custom domain string format.
pub fn validate_domain(domain: &str) -> Result<String, WebHostingError> {
    let trimmed = domain.trim().to_ascii_lowercase();
    if trimmed.is_empty() || trimmed.len() > 255 {
        return Err(WebHostingError::InvalidDomain);
    }
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") || trimmed.contains('/') {
        return Err(WebHostingError::InvalidDomain);
    }
    if !trimmed.contains('.') || trimmed.starts_with('.') || trimmed.ends_with('.') {
        return Err(WebHostingError::InvalidDomain);
    }
    let valid_chars = trimmed
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == '*');
    if !valid_chars {
        return Err(WebHostingError::InvalidDomain);
    }
    Ok(trimmed)
}

/// Returns `true` if the domain appears to be an apex/root domain (e.g. `example.com`).
pub fn is_apex_domain(domain: &str) -> bool {
    let clean = domain.trim().trim_end_matches('.');
    let parts: Vec<&str> = clean.split('.').collect();
    if parts.len() <= 2 {
        return true;
    }
    // Handle standard two-part ccTLDs e.g. co.uk, com.ng, org.uk
    if parts.len() == 3
        && matches!(
            parts[1],
            "co" | "com" | "org" | "net" | "edu" | "gov" | "ac"
        )
    {
        return true;
    }
    false
}

/// Computes the DNS TXT challenge hostname for ownership verification.
///
/// Example: `_bloom-challenge.app.example.com`
pub fn compute_challenge_hostname(domain: &str) -> String {
    let clean = domain.trim().trim_start_matches("*.").trim_end_matches('.');
    format!("_bloom-challenge.{clean}")
}

/// Computes the required DNS records the customer must create to verify and route their domain.
pub fn compute_required_dns_records(
    domain: &str,
    verification_token: &str,
    app_slug: &str,
    project_slug: &str,
    apex_domain: Option<&str>,
) -> Vec<RequiredDnsRecord> {
    let apex = apex_domain
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_APEX_DOMAIN);

    let clean_domain = domain.trim().to_ascii_lowercase();
    let challenge_host = compute_challenge_hostname(&clean_domain);
    let target_cname = format!("{app_slug}-{project_slug}.{apex}");

    let mut records = vec![RequiredDnsRecord {
        record_type: "TXT".to_string(),
        host: challenge_host,
        value: verification_token.to_string(),
        purpose: "Domain ownership verification".to_string(),
    }];

    if is_apex_domain(&clean_domain) {
        records.push(RequiredDnsRecord {
            record_type: "A".to_string(),
            host: clean_domain.clone(),
            value: DEFAULT_EDGE_A_RECORD_IP.to_string(),
            purpose: "Traffic routing (Apex A record)".to_string(),
        });
        records.push(RequiredDnsRecord {
            record_type: "CNAME".to_string(),
            host: clean_domain,
            value: target_cname,
            purpose: "Traffic routing (CNAME alias / flattening)".to_string(),
        });
    } else {
        records.push(RequiredDnsRecord {
            record_type: "CNAME".to_string(),
            host: clean_domain,
            value: target_cname,
            purpose: "Traffic routing (CNAME)".to_string(),
        });
    }

    records
}

/// Generates a cryptographically strong, unique domain verification token.
pub fn generate_verification_token() -> String {
    format!("bloom_verify_{}", Uuid::new_v4().simple())
}

/// Emits an event to the events log.
pub async fn emit_event(
    db: &Database,
    event_type: &str,
    organization_id: Option<i64>,
    project_id: Option<i64>,
    app_id: Option<i64>,
    actor_id: Option<i64>,
    payload: serde_json::Value,
) {
    crate::apps::events::emit(
        db,
        event_type,
        organization_id,
        project_id,
        app_id,
        actor_id,
        payload,
    )
    .await;
}

/// Initiates a new Flutter Web deployment.
pub async fn deploy_web(
    db: &Database,
    _storage: &dyn ObjectStorage,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    apex_domain: Option<&str>,
    req: DeployWebRequest,
) -> Result<WebDeploymentDetail, WebHostingError> {
    let target = req.target.trim().to_string();
    validate_target(&target)?;

    if target == "production" && user_role < OrganizationRole::ReleaseManager {
        return Err(WebHostingError::Forbidden);
    }
    if target == "preview" && user_role < OrganizationRole::Developer {
        return Err(WebHostingError::Forbidden);
    }

    let org = repositories::organization_summary_by_id(db, organization_id)
        .await?
        .ok_or(WebHostingError::OrganizationNotFound)?;

    let app = repositories::app_summary_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let project = repositories::project_summary_by_id(db, app.project_id)
        .await?
        .ok_or(WebHostingError::ProjectNotFound)?;

    let env = repositories::environment_summary_by_public_id_and_org(
        db,
        &req.environment_id,
        organization_id,
    )
    .await?
    .ok_or(WebHostingError::EnvironmentNotFound)?;

    if env.app_id != app.id {
        return Err(WebHostingError::EnvironmentNotFound);
    }

    let artifact =
        repositories::artifact_summary_by_public_id_and_org(db, &req.artifact_id, organization_id)
            .await?
            .ok_or(WebHostingError::ArtifactNotFound)?;

    if artifact.kind != "web_bundle" {
        return Err(WebHostingError::InvalidArtifactKind);
    }

    let release = if let Some(ref rel_id) = req.release_id {
        let r = repositories::release_summary_by_public_id_and_org(db, rel_id, organization_id)
            .await?
            .ok_or(WebHostingError::ReleaseNotFound)?;
        Some(r)
    } else {
        None
    };

    let deployment_public_id = Uuid::new_v4().to_string();
    let branch = req
        .git_branch
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(&app.default_branch);

    let deployed_url = match target.as_str() {
        "preview" => build_preview_url(apex_domain, branch, &app.slug, &project.slug),
        "production" => build_production_url(apex_domain, &app.slug, &project.slug),
        _ => return Err(WebHostingError::InvalidTarget),
    };

    let storage_prefix = build_web_storage_prefix(
        &org.public_id,
        &project.public_id,
        &app.public_id,
        &deployment_public_id,
    );

    let metadata_json = match req.metadata {
        Some(val) => serde_json::to_string(&val)
            .map_err(|e| WebHostingError::InvalidMetadata(e.to_string()))?,
        None => "{}".to_string(),
    };

    let now = Utc::now();
    let deployment = WebDeployment {
        id: 0,
        public_id: deployment_public_id,
        app_id: ForeignKey::new(app.id),
        organization_id,
        environment_id: ForeignKey::new(env.id),
        artifact_id: ForeignKey::new(artifact.id),
        release_id: release.as_ref().map(|r| r.id),
        target: target.clone(),
        url: deployed_url.clone(),
        storage_prefix,
        status: "deploying".to_string(),
        metadata: metadata_json,
        deployed_by_id: user_id,
        created_at: now,
    };

    let mut saved = repositories::insert_deployment(db, deployment).await?;

    if can_transition(&saved.status, "live") {
        saved.status = "live".to_string();
        repositories::update_deployment(db, &saved).await?;
    }

    emit_event(
        db,
        "webhosting.deployed",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        Some(user_id),
        serde_json::json!({
            "deployment_id": saved.public_id,
            "url": saved.url,
        }),
    )
    .await;

    Ok(WebDeploymentDetail {
        deployment: saved,
        app_public_id: app.public_id,
        environment_public_id: env.public_id,
        release_public_id: release.map(|r| r.public_id),
        deployed_by_public_id: user_id.to_string(),
    })
}

/// Rollback a web deployment to the previous live deployment for that app and target.
pub async fn rollback_web_deployment(
    db: &Database,
    organization_id: i64,
    user_id: i64,
    user_role: OrganizationRole,
    deployment_public_id: &str,
) -> Result<WebDeploymentDetail, WebHostingError> {
    let mut current =
        repositories::deployment_by_public_id_and_org(db, deployment_public_id, organization_id)
            .await?
            .ok_or(WebHostingError::DeploymentNotFound)?;

    if current.target == "production" && user_role < OrganizationRole::ReleaseManager {
        return Err(WebHostingError::Forbidden);
    }
    if current.target == "preview" && user_role < OrganizationRole::Developer {
        return Err(WebHostingError::Forbidden);
    }

    if !can_transition(&current.status, "rolled_back") {
        return Err(WebHostingError::InvalidStatus);
    }

    let mut previous = repositories::previous_deployment_for_app_and_target(
        db,
        current.app_id.id,
        organization_id,
        &current.target,
        current.id,
    )
    .await?
    .ok_or(WebHostingError::NoPreviousDeployment)?;

    current.status = "rolled_back".to_string();
    repositories::update_deployment(db, &current).await?;

    previous.status = "live".to_string();
    repositories::update_deployment(db, &previous).await?;

    let app = repositories::app_summary_by_id(db, current.app_id.id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let env = repositories::environment_summary_by_id(db, current.environment_id.id)
        .await?
        .ok_or(WebHostingError::EnvironmentNotFound)?;

    let release_public_id = match current.release_id {
        Some(ref rel) => repositories::release_summary_by_id(db, *rel)
            .await?
            .map(|r| r.public_id),
        None => None,
    };

    emit_event(
        db,
        "webhosting.rolled_back",
        Some(organization_id),
        Some(app.project_id),
        Some(app.id),
        Some(user_id),
        serde_json::json!({
            "deployment_id": current.public_id,
            "previous_deployment_id": previous.public_id,
        }),
    )
    .await;

    Ok(WebDeploymentDetail {
        deployment: current,
        app_public_id: app.public_id,
        environment_public_id: env.public_id,
        release_public_id,
        deployed_by_public_id: user_id.to_string(),
    })
}

/// Retrieve a web deployment by its public UUID within an organization.
pub async fn get_web_deployment(
    db: &Database,
    organization_id: i64,
    deployment_public_id: &str,
) -> Result<WebDeploymentDetail, WebHostingError> {
    let deployment =
        repositories::deployment_by_public_id_and_org(db, deployment_public_id, organization_id)
            .await?
            .ok_or(WebHostingError::DeploymentNotFound)?;

    let app = repositories::app_summary_by_id(db, deployment.app_id.id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let env = repositories::environment_summary_by_id(db, deployment.environment_id.id)
        .await?
        .ok_or(WebHostingError::EnvironmentNotFound)?;

    let release_public_id = match deployment.release_id {
        Some(ref rel) => repositories::release_summary_by_id(db, *rel)
            .await?
            .map(|r| r.public_id),
        None => None,
    };

    let user_id_str = deployment.deployed_by_id.to_string();

    Ok(WebDeploymentDetail {
        deployment,
        app_public_id: app.public_id,
        environment_public_id: env.public_id,
        release_public_id,
        deployed_by_public_id: user_id_str,
    })
}

/// Caller-supplied filters for a web deployment listing, in wire terms.
///
/// The service resolves `app_public_id`/`environment_public_id` to internal keys before
/// handing the rest down to the repository; grouping them keeps the public IDs and the
/// free-text filters from being transposed at the call site.
#[derive(Debug, Default, Clone, Copy)]
pub struct WebDeploymentListFilters<'a> {
    /// External public UUID of an app to restrict to.
    pub app_public_id: Option<&'a str>,
    /// External public UUID of an environment to restrict to.
    pub environment_public_id: Option<&'a str>,
    /// Deployment target to restrict to (e.g. `production`).
    pub target: Option<&'a str>,
    /// Deployment status to restrict to (e.g. `live`).
    pub status: Option<&'a str>,
}

/// List web deployments in an organization with pagination, SQL-level filtering, and batch entity lookups.
pub async fn list_web_deployments(
    db: &Database,
    organization_id: i64,
    filters: WebDeploymentListFilters<'_>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<WebDeploymentDetail>, i64), WebHostingError> {
    let WebDeploymentListFilters {
        app_public_id,
        environment_public_id,
        target: target_filter,
        status: status_filter,
    } = filters;
    let app_id = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_summary_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(WebHostingError::AppNotFound)?;
        Some(app.id)
    } else {
        None
    };

    let environment_id = if let Some(env_pub_id) = environment_public_id {
        let env =
            repositories::environment_summary_by_public_id_and_org(db, env_pub_id, organization_id)
                .await?
                .ok_or(WebHostingError::EnvironmentNotFound)?;
        Some(env.id)
    } else {
        None
    };

    let (deployments, total) = repositories::list_web_deployments_query(
        db,
        organization_id,
        repositories::WebDeploymentFilters {
            app_id,
            environment_id,
            target: target_filter,
            status: status_filter,
        },
        limit,
        offset,
    )
    .await?;

    if deployments.is_empty() {
        return Ok((Vec::new(), total));
    }

    // 1. Batch lookup apps in ONE query
    let mut app_ids: Vec<i64> = deployments.iter().map(|d| d.app_id.id).collect();
    app_ids.sort_unstable();
    app_ids.dedup();
    let app_map = repositories::app_summaries_by_ids(db, &app_ids).await?;

    // 2. Batch lookup environments in ONE query
    let mut env_ids: Vec<i64> = deployments.iter().map(|d| d.environment_id.id).collect();
    env_ids.sort_unstable();
    env_ids.dedup();
    let env_map = repositories::environment_summaries_by_ids(db, &env_ids).await?;

    // 3. Batch lookup releases in ONE query
    let mut release_ids: Vec<i64> = deployments.iter().filter_map(|d| d.release_id).collect();
    release_ids.sort_unstable();
    release_ids.dedup();
    let release_map = repositories::release_summaries_by_ids(db, &release_ids).await?;

    // 4. Batch lookup user profiles in ONE query
    let mut user_ids: Vec<i64> = deployments.iter().map(|d| d.deployed_by_id).collect();
    user_ids.sort_unstable();
    user_ids.dedup();
    let user_map = repositories::user_public_ids_by_ids(db, &user_ids).await?;

    let mut results = Vec::with_capacity(deployments.len());
    for d in deployments {
        let app_pub_id = app_map
            .get(&d.app_id.id)
            .map(|a| a.public_id.clone())
            .unwrap_or_else(|| "unknown".to_string());

        let env_pub_id = env_map
            .get(&d.environment_id.id)
            .map(|e| e.public_id.clone())
            .unwrap_or_else(|| "unknown".to_string());

        let release_pub_id = d
            .release_id
            .and_then(|rid| release_map.get(&rid).map(|r| r.public_id.clone()));

        let user_id_str = user_map
            .get(&d.deployed_by_id)
            .cloned()
            .unwrap_or_else(|| d.deployed_by_id.to_string());

        results.push(WebDeploymentDetail {
            deployment: d,
            app_public_id: app_pub_id,
            environment_public_id: env_pub_id,
            release_public_id: release_pub_id,
            deployed_by_public_id: user_id_str,
        });
    }

    Ok((results, total))
}

/// Register a custom domain for an application and return required DNS records.
pub async fn create_custom_domain(
    db: &Database,
    organization_id: i64,
    apex_domain: Option<&str>,
    req: CreateCustomDomainRequest,
) -> Result<CustomDomainDetail, WebHostingError> {
    let clean_domain = validate_domain(&req.domain)?;

    let app = repositories::app_summary_by_public_id_and_org(db, &req.app_id, organization_id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let project = repositories::project_summary_by_id(db, app.project_id)
        .await?
        .ok_or(WebHostingError::ProjectNotFound)?;

    if repositories::custom_domain_by_app_and_domain(db, app.id, &clean_domain)
        .await?
        .is_some()
    {
        return Err(WebHostingError::DomainAlreadyExists);
    }

    let verification_token = generate_verification_token();

    let domain = CustomDomain {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        app_id: ForeignKey::new(app.id),
        organization_id,
        domain: clean_domain.clone(),
        verification_token: verification_token.clone(),
        certificate_status: "pending".to_string(),
        certificate_expires_at: None,
        verified_at: None,
        failure_reason: None,
        created_at: Utc::now(),
    };

    let saved = repositories::insert_custom_domain(db, domain).await?;

    let required_records = compute_required_dns_records(
        &clean_domain,
        &verification_token,
        &app.slug,
        &project.slug,
        apex_domain,
    );

    Ok(CustomDomainDetail {
        domain: saved,
        app_public_id: app.public_id,
        required_records,
    })
}

/// Parameters required to verify and optionally provision a custom domain.
#[derive(Clone)]
pub struct VerifyDomainParams<'a> {
    /// Database handle.
    pub db: &'a Database,
    /// DNS resolver trait instance.
    pub dns: &'a dyn DnsResolver,
    /// Optional Caddy client handle.
    pub caddy: Option<&'a CaddyClient>,
    /// Organization primary key.
    pub organization_id: i64,
    /// Public UUID of the custom domain to verify.
    pub domain_public_id: &'a str,
    /// Optional apex domain.
    pub apex_domain: Option<&'a str>,
    /// Optional Cloudflare API token for DNS-01 ACME challenge provisioning.
    pub cloudflare_api_token: Option<&'a str>,
    /// Optional ACME registration email.
    pub acme_email: Option<&'a str>,
}

/// Verifies domain ownership via DNS TXT record and routing records, enforcing strict matching.
///
/// # Security Rule
///
/// Sets `verified_at` ONLY when the expected verification token matches via constant-time comparison
/// AND routing is pointed correctly. An unverified domain is NEVER written to Caddy configuration.
pub async fn verify_custom_domain(
    params: VerifyDomainParams<'_>,
) -> Result<CustomDomainDetail, WebHostingError> {
    let VerifyDomainParams {
        db,
        dns,
        caddy,
        organization_id,
        domain_public_id,
        apex_domain,
        cloudflare_api_token,
        acme_email,
    } = params;

    let mut domain =
        repositories::custom_domain_by_public_id_and_org(db, domain_public_id, organization_id)
            .await?
            .ok_or(WebHostingError::DomainNotFound)?;

    let app = repositories::app_summary_by_id(db, domain.app_id.id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let project = repositories::project_summary_by_id(db, app.project_id)
        .await?
        .ok_or(WebHostingError::ProjectNotFound)?;

    let challenge_host = compute_challenge_hostname(&domain.domain);
    let expected_token = domain.verification_token.trim().to_string();

    // 1. Ownership verification: Lookup TXT record at `_bloom-challenge.<domain>`
    let txt_result = dns.lookup_txt(&challenge_host).await;
    let txt_verified = match txt_result {
        Ok(records) => {
            let matched = records
                .iter()
                .any(|r| Crypto::constant_time_eq_str(r.trim(), &expected_token));
            if !matched {
                let first_val = records.first().map(String::as_str).unwrap_or("");
                let reason = format!(
                    "TXT record at '{challenge_host}' contains incorrect token '{first_val}', expected '{expected_token}'."
                );
                domain.certificate_status = "failed".to_string();
                domain.failure_reason = Some(reason.clone());
                repositories::update_custom_domain(db, &domain).await?;
                emit_event(
                    db,
                    "domain.verification_failed",
                    Some(organization_id),
                    Some(app.project_id),
                    Some(app.id),
                    None,
                    serde_json::json!({
                        "domain_id": domain.public_id,
                        "domain": domain.domain,
                        "failed_record": "TXT",
                        "reason": reason,
                    }),
                )
                .await;
                return Err(WebHostingError::VerificationFailed(reason));
            }
            true
        }
        Err(err) => {
            let reason = format!(
                "TXT verification record at '{challenge_host}' not found or unreachable: {err}"
            );
            domain.certificate_status = "failed".to_string();
            domain.failure_reason = Some(reason.clone());
            repositories::update_custom_domain(db, &domain).await?;
            emit_event(
                db,
                "domain.verification_failed",
                Some(organization_id),
                Some(app.project_id),
                Some(app.id),
                None,
                serde_json::json!({
                    "domain_id": domain.public_id,
                    "domain": domain.domain,
                    "failed_record": "TXT",
                    "reason": reason,
                }),
            )
            .await;
            return Err(WebHostingError::VerificationFailed(reason));
        }
    };

    // 2. Traffic routing verification: Lookup CNAME or A record for the domain itself
    let apex = apex_domain
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_APEX_DOMAIN);
    let expected_target = format!("{}-{}.{apex}", app.slug, project.slug);

    if is_apex_domain(&domain.domain) {
        // Apex domains must have an A record or CNAME flattening configured
        let a_result = dns.lookup_a(&domain.domain).await;
        let cname_result = dns.lookup_cname(&domain.domain).await;

        let a_ok = a_result.is_ok();
        let cname_ok = cname_result
            .as_ref()
            .ok()
            .and_then(Option::as_ref)
            .map(|t| t.eq_ignore_ascii_case(&expected_target))
            .unwrap_or(false);

        if !a_ok && !cname_ok {
            let reason = format!(
                "Apex domain '{0}' routing records not found. Configure an A record pointing to {DEFAULT_EDGE_A_RECORD_IP} or a CNAME to '{expected_target}'.",
                domain.domain
            );
            domain.certificate_status = "failed".to_string();
            domain.failure_reason = Some(reason.clone());
            repositories::update_custom_domain(db, &domain).await?;
            return Err(WebHostingError::VerificationFailed(reason));
        }
    } else {
        // Subdomains must have a CNAME pointing to the expected Bloom target
        match dns.lookup_cname(&domain.domain).await {
            Ok(Some(target)) => {
                if !target.eq_ignore_ascii_case(&expected_target) {
                    let reason = format!(
                        "CNAME record for '{0}' points to '{target}', expected '{expected_target}'.",
                        domain.domain
                    );
                    domain.certificate_status = "failed".to_string();
                    domain.failure_reason = Some(reason.clone());
                    repositories::update_custom_domain(db, &domain).await?;
                    return Err(WebHostingError::VerificationFailed(reason));
                }
            }
            Ok(None) | Err(_) => {
                let reason = format!(
                    "CNAME record for '{0}' is missing. Configure a CNAME record pointing to '{expected_target}'.",
                    domain.domain
                );
                domain.certificate_status = "failed".to_string();
                domain.failure_reason = Some(reason.clone());
                repositories::update_custom_domain(db, &domain).await?;
                return Err(WebHostingError::VerificationFailed(reason));
            }
        }
    }

    // 3. Mark domain verified and transition certificate status
    if txt_verified {
        domain.verified_at = Some(Utc::now());
        domain.certificate_status = "active".to_string();
        domain.failure_reason = None;
        repositories::update_custom_domain(db, &domain).await?;

        // 4. Provision in Caddy reverse proxy only after successful verification (Security Rule)
        if let Some(caddy_client) = caddy {
            let org = repositories::organization_summary_by_id(db, organization_id)
                .await?
                .ok_or(WebHostingError::OrganizationNotFound)?;

            let storage_prefix = format!(
                "orgs/{}/projects/{}/apps/{}/custom_domains/{}",
                org.public_id, project.public_id, app.public_id, domain.public_id
            );

            // Provisioning strictly checks domain.verified_at.is_some()
            let _ = caddy_client
                .provision_verified_custom_domain(
                    &domain.public_id,
                    &domain.domain,
                    &storage_prefix,
                    domain.verified_at.is_some(),
                    cloudflare_api_token,
                    acme_email,
                )
                .await;
        }

        emit_event(
            db,
            "webhosting.domain_verified",
            Some(organization_id),
            Some(app.project_id),
            Some(app.id),
            None,
            serde_json::json!({
                "domain_id": domain.public_id,
                "domain": domain.domain,
                "verified_at": domain.verified_at.map(|t| t.to_rfc3339()),
            }),
        )
        .await;
    }

    let required_records = compute_required_dns_records(
        &domain.domain,
        &domain.verification_token,
        &app.slug,
        &project.slug,
        apex_domain,
    );

    Ok(CustomDomainDetail {
        domain,
        app_public_id: app.public_id,
        required_records,
    })
}

/// Re-verifies an existing custom domain.
///
/// If DNS stops resolving, the domain is FLAGGED (`certificate_status = "failed"`), NOT silently dropped.
pub async fn reverify_custom_domain(
    params: VerifyDomainParams<'_>,
) -> Result<CustomDomainDetail, WebHostingError> {
    let domain_public_id = params.domain_public_id;
    let organization_id = params.organization_id;
    let db = params.db;

    match verify_custom_domain(params).await {
        Ok(detail) => Ok(detail),
        Err(err) => {
            // Re-fetch domain to ensure failure flag was persisted without dropping row
            if let Some(mut domain) = repositories::custom_domain_by_public_id_and_org(
                db,
                domain_public_id,
                organization_id,
            )
            .await?
            {
                domain.certificate_status = "failed".to_string();
                domain.failure_reason = Some(err.to_string());
                repositories::update_custom_domain(db, &domain).await?;
            }
            Err(err)
        }
    }
}

/// Delete a custom domain by its public UUID within an organization.
///
/// Idempotent: Deleting a non-existent or already-deleted domain succeeds cleanly without error.
pub async fn delete_custom_domain(
    db: &Database,
    caddy: Option<&CaddyClient>,
    organization_id: i64,
    domain_public_id: &str,
) -> Result<(), WebHostingError> {
    let domain =
        repositories::custom_domain_by_public_id_and_org(db, domain_public_id, organization_id)
            .await?;

    if let Some(d) = domain {
        // Clean up Caddy reverse proxy site block
        if let Some(caddy_client) = caddy {
            let site_id = caddy_custom_domain_id(&d.public_id);
            // remove_site_block treats 404 as successful no-op for idempotency
            let _ = caddy_client.remove_site_block(&site_id).await;
        }

        repositories::delete_custom_domain_by_id(db, d.id).await?;

        emit_event(
            db,
            "webhosting.domain_deleted",
            Some(organization_id),
            None,
            Some(d.app_id.id),
            None,
            serde_json::json!({
                "domain_id": d.public_id,
                "domain": d.domain,
            }),
        )
        .await;
    }

    Ok(())
}

/// Retrieve a single custom domain by its public UUID within an organization.
pub async fn get_custom_domain(
    db: &Database,
    organization_id: i64,
    domain_public_id: &str,
    apex_domain: Option<&str>,
) -> Result<CustomDomainDetail, WebHostingError> {
    let domain =
        repositories::custom_domain_by_public_id_and_org(db, domain_public_id, organization_id)
            .await?
            .ok_or(WebHostingError::DomainNotFound)?;

    let app = repositories::app_summary_by_id(db, domain.app_id.id)
        .await?
        .ok_or(WebHostingError::AppNotFound)?;

    let project = repositories::project_summary_by_id(db, app.project_id)
        .await?
        .ok_or(WebHostingError::ProjectNotFound)?;

    let required_records = compute_required_dns_records(
        &domain.domain,
        &domain.verification_token,
        &app.slug,
        &project.slug,
        apex_domain,
    );

    Ok(CustomDomainDetail {
        domain,
        app_public_id: app.public_id,
        required_records,
    })
}

/// List custom domains in an organization with pagination, app filtering, and batch entity lookups.
pub async fn list_custom_domains(
    db: &Database,
    organization_id: i64,
    app_public_id: Option<&str>,
    apex_domain: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<CustomDomainDetail>, i64), WebHostingError> {
    let app_id = if let Some(app_pub_id) = app_public_id {
        let app = repositories::app_summary_by_public_id_and_org(db, app_pub_id, organization_id)
            .await?
            .ok_or(WebHostingError::AppNotFound)?;
        Some(app.id)
    } else {
        None
    };

    let (domains, total) =
        repositories::list_custom_domains_query(db, organization_id, app_id, limit, offset).await?;

    if domains.is_empty() {
        return Ok((Vec::new(), total));
    }

    // 1. Batch lookup apps in ONE query
    let mut app_ids: Vec<i64> = domains.iter().map(|d| d.app_id.id).collect();
    app_ids.sort_unstable();
    app_ids.dedup();
    let app_map = repositories::app_summaries_by_ids(db, &app_ids).await?;

    // 2. Batch lookup projects for these apps in ONE query
    let mut project_ids: Vec<i64> = app_map.values().map(|a| a.project_id).collect();
    project_ids.sort_unstable();
    project_ids.dedup();
    let project_map = repositories::project_summaries_by_ids(db, &project_ids).await?;

    let mut results = Vec::with_capacity(domains.len());
    for d in domains {
        if let Some(app) = app_map.get(&d.app_id.id) {
            let project = project_map.get(&app.project_id);
            let project_slug = project.map(|p| p.slug.as_str()).unwrap_or("app");

            let required_records = compute_required_dns_records(
                &d.domain,
                &d.verification_token,
                &app.slug,
                project_slug,
                apex_domain,
            );

            results.push(CustomDomainDetail {
                domain: d,
                app_public_id: app.public_id.clone(),
                required_records,
            });
        }
    }

    Ok((results, total))
}
