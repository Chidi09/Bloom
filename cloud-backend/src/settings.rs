//! Typed application settings.
//!
//! # The pattern
//!
//! Every setting in Bloom Cloud is declared here with `#[derive(Settings)]` from
//! `djangors-macros`. Nothing in this codebase calls `std::env::var` directly.
//!
//! The derive is **flat**: each field maps to the environment variable
//! `{PREFIX}_{FIELD_NAME_UPPERCASED}`. It supports:
//!
//! * `#[djangors(prefix = "...")]` on the struct,
//! * `#[djangors(default = ...)]` on a field, used when the variable is unset,
//! * `Option<T>` fields, which become `None` when unset and never fail to load.
//!
//! There is no nested-struct support, so each integration gets its OWN struct with
//! its own prefix rather than one giant struct. Load only what a subsystem needs:
//! the mailer loads [`ZeptoMailSettings`], the web-deploy worker loads
//! [`CloudflareSettings`] and [`CaddySettings`], and so on.
//!
//! # Adding a new integration
//!
//! 1. Add a struct here with `#[djangors(prefix = "BLOOM_<NAME>")]`.
//! 2. Make every credential `Option<String>` unless the process genuinely cannot
//!    start without it — an unset optional is a disabled integration, not a crash.
//! 3. Document each field with a `///` comment; that comment is the contract.
//! 4. Add the variables to `.env.example` with placeholder values.
//! 5. Never log a secret. Never add `#[derive(Debug)]` output of a raw secret to a
//!    response or a log line.

use djangors_macros::Settings;

/// Core application settings.
///
/// These are the values the process cannot start without (plus a small number of
/// tuning knobs with defaults).
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM")]
pub struct BloomSettings {
    /// PostgreSQL database connection URL.
    pub database_url: String,

    /// Redis connection URL for caching, queues, and pub/sub.
    pub redis_url: String,

    /// Public URL for the Bloom Cloud API.
    pub api_url: String,

    /// Secret key used for signing and verifying JWT tokens.
    pub jwt_secret: String,

    /// Timeout in seconds before an uncompleted claimed worker job is returned to the queue.
    #[djangors(default = 30)]
    pub worker_claim_timeout_secs: u64,

    /// Master 256-bit encryption key (hex-encoded) for cryptographic signing and AES-256-GCM encryption.
    /// Required for application boot.
    pub encryption_key: String,

    /// Master key (base64) for AES-256-GCM encryption of secrets and credentials.
    /// Consumed by `crate::infra::crypto`.
    pub encryption_master_key: Option<String>,

    /// Active encryption key version, used as the ciphertext version prefix so old
    /// ciphertext stays decryptable across key rotations.
    #[djangors(default = String::from("v1"))]
    pub encryption_key_version: String,

    /// Optional Sentry DSN for error reporting.
    pub sentry_dsn: Option<String>,
}

/// Object storage (Cloudflare R2 or any S3-compatible backend).
///
/// Consumed by `crate::infra::storage`. Artifacts and build logs are private by
/// default and served only through short-lived presigned URLs.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_S3")]
pub struct ObjectStorageSettings {
    /// S3/R2 endpoint URL. For R2 this is the account-specific endpoint.
    pub endpoint: Option<String>,
    /// Bucket holding build artifacts, logs, and web deploy bundles.
    pub bucket: Option<String>,
    /// Access key id.
    pub access_key_id: Option<String>,
    /// Secret access key.
    pub secret_access_key: Option<String>,
    /// Region. R2 uses `auto`.
    #[djangors(default = String::from("auto"))]
    pub region: String,
    /// Lifetime in seconds for generated presigned download URLs.
    #[djangors(default = 900)]
    pub presign_expiry_secs: u64,
}

/// ZeptoMail transactional email.
///
/// Used for member invites, device-login notifications, build/deploy failure
/// alerts, and expiring-signing-material warnings.
///
/// NOTE: there is no `docs/integrations/zeptomail.md` specification yet. These fields
/// cover ZeptoMail's documented send API surface; reconcile them with a spec
/// before the mailer is implemented.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_ZEPTOMAIL")]
pub struct ZeptoMailSettings {
    /// ZeptoMail send-mail API token (the `Zoho-enczapikey ...` value).
    pub api_token: Option<String>,
    /// API base URL; differs between the .com and .eu data centres.
    #[djangors(default = String::from("https://api.zeptomail.com/v1.1/email"))]
    pub api_url: String,
    /// Verified sender address.
    pub from_address: Option<String>,
    /// Display name on outbound mail.
    #[djangors(default = String::from("Bloom Cloud"))]
    pub from_name: String,
    /// When false, the mailer logs the message instead of sending it. Intended for
    /// local development so no real mail leaves the machine.
    #[djangors(default = false)]
    pub enabled: bool,
}

/// Cloudflare — DNS, CDN cache invalidation, and custom domains for web hosting.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_CLOUDFLARE")]
pub struct CloudflareSettings {
    /// API token with DNS edit and cache purge scopes.
    pub api_token: Option<String>,
    /// Zone id for the Bloom-managed apex domain.
    pub zone_id: Option<String>,
    /// Account id, required by the R2 and Pages APIs.
    pub account_id: Option<String>,
    /// Apex domain under which preview and production app URLs are issued.
    pub apex_domain: Option<String>,
}

/// Caddy — the reverse proxy fronting deployed web apps and custom domains.
///
/// Bloom Cloud drives Caddy through its admin API to add/remove site blocks as
/// web deployments and custom domains come and go.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_CADDY")]
pub struct CaddySettings {
    /// Caddy admin API endpoint.
    #[djangors(default = String::from("http://localhost:2019"))]
    pub admin_url: String,
    /// Optional bearer token if the admin API is protected.
    pub admin_token: Option<String>,
    /// Email used for ACME/Let's Encrypt certificate registration.
    pub acme_email: Option<String>,
}

/// Bachs (`api.bachs.io`) — payment provider for Bloom Cloud billing.
///
/// Supported natively by the framework: `djangors_contrib_payments::bachs::BachsProvider`
/// implements `PaymentProvider` (charges, refunds, webhook signature verification).
/// Do NOT hand-roll an HTTP client for this — construct `BachsProvider::new(secret_key)`
/// (or `::sandbox(...)`) and use the trait.
///
/// Billing scope, plans, and the free-tier quota model belong in `docs/apps/billing.md`.
/// Product intent is a generous free tier matching Vercel's limits for Flutter and
/// Bloom apps; those limits are NOT yet specified or enforced anywhere in this
/// codebase, and must be written into `docs/apps/billing.md` before they can be.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_BACHS")]
pub struct BachsSettings {
    /// Bachs secret key, passed to `BachsProvider::new`.
    pub secret_key: Option<String>,
    /// Override the API base URL. Unset uses the provider default
    /// (`https://api.bachs.io`); use `BachsProvider::sandbox` for test mode.
    pub base_url: Option<String>,
    /// Secret used to verify inbound webhook signatures. Webhooks whose signature
    /// does not verify must be rejected before any state change.
    pub webhook_secret: Option<String>,
    /// When false, Bachs is not offered as a payment method.
    #[djangors(default = false)]
    pub enabled: bool,
}

/// Paystack — alternative payment provider.
///
/// Also native: `djangors_contrib_payments::paystack::PaystackProvider` implements the
/// same `PaymentProvider` trait, so billing code stays provider-agnostic and can select
/// between Bachs and Paystack at runtime.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_PAYSTACK")]
pub struct PaystackSettings {
    /// Paystack secret key, passed to `PaystackProvider::new`.
    pub secret_key: Option<String>,
    /// Override the API base URL; unset uses the provider default.
    pub base_url: Option<String>,
    /// Secret used to verify inbound webhook signatures.
    pub webhook_secret: Option<String>,
    /// When false, Paystack is not offered as a payment method.
    #[djangors(default = false)]
    pub enabled: bool,
}

/// Shorebird — over-the-air Dart code push.
///
/// Contract: `docs/integrations/shorebird.md`.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_SHOREBIRD")]
pub struct ShorebirdSettings {
    /// Shorebird API base URL.
    #[djangors(default = String::from("https://api.shorebird.dev"))]
    pub api_url: String,
    /// Shorebird auth token used by the deploy worker to publish patches.
    pub api_token: Option<String>,
}

/// Google Play — Android track publishing.
///
/// Contract: `integrations/google-play.md`. Per-organization publishing
/// credentials live encrypted in the `credentials` app; these settings are the
/// platform-level defaults only.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_GPLAY")]
pub struct GooglePlaySettings {
    /// Android Publisher API base URL.
    #[djangors(default = String::from("https://androidpublisher.googleapis.com"))]
    pub api_url: String,
    /// Path to a platform-level service-account JSON, when one is used.
    pub service_account_json_path: Option<String>,
}

/// Apple App Store Connect / TestFlight.
///
/// Contract: `docs/integrations/testflight.md`. Per-organization signing material lives
/// encrypted in the `signing` app; these are platform-level defaults only.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_TESTFLIGHT")]
pub struct TestFlightSettings {
    /// App Store Connect API base URL.
    #[djangors(default = String::from("https://api.appstoreconnect.apple.com"))]
    pub api_url: String,
    /// Issuer id for the App Store Connect API key.
    pub issuer_id: Option<String>,
    /// Key id for the App Store Connect API key.
    pub key_id: Option<String>,
    /// Private key (PEM) for the App Store Connect API key.
    pub private_key: Option<String>,
}

/// GitHub — repository connections, webhooks, and build triggers.
///
/// Contract: `docs/integrations/github.md` and `docs/apps/git_connections.md`.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_GITHUB")]
pub struct GitHubSettings {
    /// GitHub App id.
    pub app_id: Option<String>,
    /// GitHub App private key (PEM) used to mint installation tokens.
    pub app_private_key: Option<String>,
    /// OAuth client id, for "Connect GitHub" in the dashboard.
    pub oauth_client_id: Option<String>,
    /// OAuth client secret.
    pub oauth_client_secret: Option<String>,
    /// Shared secret used to verify inbound webhook signatures. Webhooks whose
    /// signature does not verify must be rejected.
    pub webhook_secret: Option<String>,
    /// API base URL; override for GitHub Enterprise.
    #[djangors(default = String::from("https://api.github.com"))]
    pub api_url: String,
}

/// Google OAuth — "Sign in with Google" for the dashboard.
///
/// Distinct from [`GooglePlaySettings`]: this is end-user identity, not publishing.
///
/// NOTE: no specification covers this yet; the device-code CLI flow in `accounts`
/// is the currently specified login path. Reconcile with `docs/apps/accounts.md` before
/// implementing.
#[derive(Settings, Debug, Clone)]
#[djangors(prefix = "BLOOM_GOOGLE_AUTH")]
pub struct GoogleAuthSettings {
    /// OAuth 2.0 client id.
    pub client_id: Option<String>,
    /// OAuth 2.0 client secret.
    pub client_secret: Option<String>,
    /// Redirect URI registered with Google; must match exactly.
    pub redirect_uri: Option<String>,
    /// When false, Google sign-in is not offered.
    #[djangors(default = false)]
    pub enabled: bool,
}
