//! Stripe Connect and payment processing infrastructure boundary.
//!
//! # Overview
//!
//! Provides an abstraction for interacting with Stripe Connect (Express accounts),
//! AccountLinks for hosted KYC onboarding, PaymentIntents with destination charges,
//! and refunds with transfer reversals.
//!
//! # Security & Secret Handling
//!
//! - Stripe API keys and webhook secrets are redacted in all [`fmt::Debug`] representations.
//! - API keys are never included in log lines, error messages, or response payloads.
//! - Live Stripe endpoints are never invoked from test suites; all tests use [`MockStripeClient`].

use std::collections::HashMap;
use std::fmt;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

/// Default timeout for outbound Stripe HTTP API requests.
pub const DEFAULT_STRIPE_TIMEOUT: Duration = Duration::from_secs(30);

/// Standard Stripe API base URL.
pub const STRIPE_API_BASE_URL: &str = "https://api.stripe.com";

/// Typed domain errors arising from Stripe operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StripeError {
    /// Authentication failure with Stripe (HTTP 401 / bad or expired API key).
    AuthenticationFailed(String),

    /// Card or payment declined (HTTP 402 / insufficient funds, expired card, fraud filter).
    CardDeclined(String),

    /// Invalid request parameters or constraint violation (HTTP 400).
    InvalidRequest(String),

    /// Stripe rate limit exceeded (HTTP 429).
    RateLimited(String),

    /// The requested resource (account, payment intent, refund) was not found (HTTP 404).
    NotFound(String),

    /// Network, DNS, or HTTP transport failure reaching Stripe.
    Transport(String),

    /// Stripe server error (HTTP 5xx) or unexpected response payload format.
    Backend(String),

    /// Missing or invalid configuration (e.g. missing API key).
    ConfigError(String),
}

impl fmt::Display for StripeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StripeError::AuthenticationFailed(msg) => {
                write!(f, "Stripe authentication failed: {msg}")
            }
            StripeError::CardDeclined(msg) => write!(f, "Payment declined: {msg}"),
            StripeError::InvalidRequest(msg) => write!(f, "Invalid Stripe request: {msg}"),
            StripeError::RateLimited(msg) => write!(f, "Stripe rate limit exceeded: {msg}"),
            StripeError::NotFound(msg) => write!(f, "Stripe resource not found: {msg}"),
            StripeError::Transport(msg) => write!(f, "Stripe network transport error: {msg}"),
            StripeError::Backend(msg) => write!(f, "Stripe backend error: {msg}"),
            StripeError::ConfigError(msg) => write!(f, "Stripe configuration error: {msg}"),
        }
    }
}

impl std::error::Error for StripeError {}

/// Configuration for connecting to the Stripe API.
#[derive(Clone, PartialEq, Eq)]
pub struct StripeConfig {
    /// Secret API key (`sk_live_...` or `sk_test_...`).
    pub secret_key: String,

    /// Optional custom base URL (useful for testing or local mocks).
    pub base_url: Option<String>,

    /// Request timeout.
    pub timeout: Duration,
}

impl StripeConfig {
    /// Create a new configuration with the provided secret key.
    pub fn new(secret_key: impl Into<String>) -> Self {
        Self {
            secret_key: secret_key.into(),
            base_url: None,
            timeout: DEFAULT_STRIPE_TIMEOUT,
        }
    }

    /// Load Stripe configuration from environment variables.
    pub fn from_env() -> Result<Self, StripeError> {
        let secret_key = std::env::var("STRIPE_SECRET_KEY")
            .or_else(|_| std::env::var("BLOOM_STRIPE_SECRET_KEY"))
            .map_err(|_| {
                StripeError::ConfigError(
                    "STRIPE_SECRET_KEY or BLOOM_STRIPE_SECRET_KEY must be set in environment"
                        .to_string(),
                )
            })?;

        let base_url = std::env::var("STRIPE_BASE_URL")
            .or_else(|_| std::env::var("BLOOM_STRIPE_BASE_URL"))
            .ok()
            .filter(|s| !s.is_empty());

        Ok(Self {
            secret_key,
            base_url,
            timeout: DEFAULT_STRIPE_TIMEOUT,
        })
    }
}

// Redact secret API key in debug representations
impl fmt::Debug for StripeConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("StripeConfig")
            .field("secret_key", &"[REDACTED]")
            .field("base_url", &self.base_url)
            .field("timeout", &self.timeout)
            .finish()
    }
}

// ---------------------------------------------------------------------------
// DTOs for Stripe Connect and Payments
// ---------------------------------------------------------------------------

/// Input parameters for creating a new Stripe Express connected account.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateAccountParams {
    /// Seller's contact email.
    pub email: Option<String>,

    /// Two-letter ISO country code (e.g. `US`, `GB`, `CA`).
    pub country: Option<String>,

    /// Business type (`individual` or `company`).
    pub business_type: Option<String>,

    /// Arbitrary metadata key-value pairs.
    #[serde(default)]
    pub metadata: HashMap<String, String>,
}

/// Representation of a Stripe connected account.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StripeAccount {
    /// Stripe connected account ID (e.g. `acct_1N2x...`).
    pub id: String,

    /// Whether payouts are enabled for this account.
    ///
    /// This is the ONLY field that signifies the seller is cleared to receive payouts.
    pub payouts_enabled: bool,

    /// Whether charges are enabled for this account.
    pub charges_enabled: bool,

    /// Whether required onboarding information has been submitted.
    pub details_submitted: bool,

    /// Default 3-letter ISO currency code (e.g. `usd`, `eur`).
    pub default_currency: Option<String>,

    /// Account contact email if available.
    pub email: Option<String>,
}

/// Input parameters for creating an onboarding or update AccountLink.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateAccountLinkParams {
    /// Stripe connected account ID (`acct_...`).
    pub account_id: String,

    /// Redirect URL if the user's session expires or needs refresh.
    pub refresh_url: String,

    /// Redirect URL once onboarding is completed.
    pub return_url: String,

    /// Type of link (`account_onboarding` or `account_update`). Defaults to `account_onboarding`.
    pub link_type: Option<String>,
}

/// Response returned from creating an AccountLink.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StripeAccountLink {
    /// Hosted Stripe Connect onboarding URL.
    pub url: String,

    /// Unix timestamp when the URL expires.
    pub expires_at: i64,
}

/// Input parameters for creating a destination charge PaymentIntent.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreatePaymentIntentParams {
    /// Total amount to charge in integer minor units (e.g. 5000 for $50.00).
    pub amount: i64,

    /// Three-letter ISO currency code (e.g. `usd`).
    pub currency: String,

    /// Platform's fee amount in integer minor units (`application_fee_amount`).
    ///
    /// Must not exceed `amount`.
    pub application_fee_amount: i64,

    /// Destination connected account ID receiving the remainder (`transfer_data[destination]`).
    pub destination_account_id: String,

    /// Optional human-readable charge description.
    pub description: Option<String>,

    /// Arbitrary metadata key-value pairs (e.g. template ID, buyer org ID).
    #[serde(default)]
    pub metadata: HashMap<String, String>,
}

/// Representation of a Stripe PaymentIntent.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StripePaymentIntent {
    /// PaymentIntent ID (e.g. `pi_1N2x...`).
    pub id: String,

    /// Client secret for frontend SDK confirmation.
    pub client_secret: Option<String>,

    /// Total charged amount in integer minor units.
    pub amount: i64,

    /// Three-letter ISO currency code.
    pub currency: String,

    /// Payment status (e.g. `requires_payment_method`, `requires_confirmation`, `succeeded`, `canceled`).
    pub status: String,

    /// Platform fee amount in integer minor units.
    pub application_fee_amount: Option<i64>,

    /// Destination connected account ID.
    pub destination_account_id: Option<String>,
}

/// Input parameters for creating a refund with reverse transfer.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateRefundParams {
    /// PaymentIntent ID to refund (`pi_...`).
    pub payment_intent_id: String,

    /// Optional partial refund amount in integer minor units (full refund if None).
    pub amount: Option<i64>,

    /// Whether to reverse the transfer made to the connected account (`reverse_transfer`).
    pub reverse_transfer: bool,

    /// Whether to refund the platform's application fee (`refund_application_fee`).
    pub refund_application_fee: Option<bool>,
}

/// Representation of a Stripe Refund.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StripeRefund {
    /// Refund ID (e.g. `re_1N2x...`).
    pub id: String,

    /// Associated PaymentIntent ID.
    pub payment_intent_id: Option<String>,

    /// Refunded amount in integer minor units.
    pub amount: i64,

    /// Three-letter ISO currency code.
    pub currency: String,

    /// Refund status (e.g. `succeeded`, `pending`, `failed`).
    pub status: String,
}

// ---------------------------------------------------------------------------
// StripeClient Trait
// ---------------------------------------------------------------------------

/// Abstract asynchronous client boundary for Stripe Connect and payment operations.
#[async_trait]
pub trait StripeClient: Send + Sync + 'static {
    /// Creates a new Express connected account for a seller organization.
    async fn create_express_account(
        &self,
        params: &CreateAccountParams,
    ) -> Result<StripeAccount, StripeError>;

    /// Generates an AccountLink hosted onboarding URL for an Express account.
    async fn create_account_link(
        &self,
        params: &CreateAccountLinkParams,
    ) -> Result<StripeAccountLink, StripeError>;

    /// Retrieves account details, primarily to inspect `payouts_enabled`.
    async fn retrieve_account(&self, account_id: &str) -> Result<StripeAccount, StripeError>;

    /// Creates a PaymentIntent as a destination charge with application fee and transfer destination.
    async fn create_payment_intent(
        &self,
        params: &CreatePaymentIntentParams,
        idempotency_key: Option<&str>,
    ) -> Result<StripePaymentIntent, StripeError>;

    /// Issues a refund on a PaymentIntent, reversing the destination transfer.
    async fn create_refund(
        &self,
        params: &CreateRefundParams,
        idempotency_key: Option<&str>,
    ) -> Result<StripeRefund, StripeError>;
}

// ---------------------------------------------------------------------------
// Real HTTP StripeClient Implementation
// ---------------------------------------------------------------------------

/// Production HTTP client communicating with Stripe's REST API using `reqwest`.
pub struct HttpStripeClient {
    client: reqwest::Client,
    config: StripeConfig,
}

impl HttpStripeClient {
    /// Creates a new `HttpStripeClient` from the provided configuration.
    pub fn new(config: StripeConfig) -> Result<Self, StripeError> {
        let client = reqwest::Client::builder()
            .timeout(config.timeout)
            .build()
            .map_err(|e| StripeError::Transport(e.to_string()))?;

        Ok(Self { client, config })
    }

    /// Creates an `HttpStripeClient` loading configuration from the environment.
    pub fn from_env() -> Result<Self, StripeError> {
        let config = StripeConfig::from_env()?;
        Self::new(config)
    }

    fn base_url(&self) -> &str {
        self.config
            .base_url
            .as_deref()
            .unwrap_or(STRIPE_API_BASE_URL)
            .trim_end_matches('/')
    }

    fn auth_header(&self) -> String {
        format!("Bearer {}", self.config.secret_key)
    }

    async fn handle_response(
        response: reqwest::Response,
    ) -> Result<serde_json::Value, StripeError> {
        let status = response.status();
        let bytes = response
            .bytes()
            .await
            .map_err(|e| StripeError::Transport(e.to_string()))?;

        let json: serde_json::Value = serde_json::from_slice(&bytes)
            .unwrap_or_else(|_| serde_json::json!({ "raw": String::from_utf8_lossy(&bytes) }));

        if status.is_success() {
            return Ok(json);
        }

        let error_msg = json
            .get("error")
            .and_then(|e| e.get("message"))
            .and_then(|m| m.as_str())
            .unwrap_or("Stripe API error")
            .to_string();

        let error_code = json
            .get("error")
            .and_then(|e| e.get("code"))
            .and_then(|c| c.as_str())
            .unwrap_or("");

        match status.as_u16() {
            401 => Err(StripeError::AuthenticationFailed(error_msg)),
            402 => Err(StripeError::CardDeclined(error_msg)),
            404 => Err(StripeError::NotFound(error_msg)),
            429 => Err(StripeError::RateLimited(error_msg)),
            400 => {
                if error_code == "card_declined" {
                    Err(StripeError::CardDeclined(error_msg))
                } else {
                    Err(StripeError::InvalidRequest(error_msg))
                }
            }
            500..=599 => Err(StripeError::Backend(error_msg)),
            _ => Err(StripeError::Backend(format!(
                "Unexpected status {}: {}",
                status.as_u16(),
                error_msg
            ))),
        }
    }
}

#[async_trait]
impl StripeClient for HttpStripeClient {
    async fn create_express_account(
        &self,
        params: &CreateAccountParams,
    ) -> Result<StripeAccount, StripeError> {
        let url = format!("{}/v1/accounts", self.base_url());
        let mut form = vec![
            ("type", "express".to_string()),
            ("capabilities[card_payments][requested]", "true".to_string()),
            ("capabilities[transfers][requested]", "true".to_string()),
        ];

        if let Some(ref email) = params.email {
            form.push(("email", email.clone()));
        }
        if let Some(ref country) = params.country {
            form.push(("country", country.clone()));
        }
        if let Some(ref b_type) = params.business_type {
            form.push(("business_type", b_type.clone()));
        }

        for (k, v) in &params.metadata {
            form.push(("metadata", format!("{k}={v}")));
        }

        let resp = self
            .client
            .post(&url)
            .header("Authorization", self.auth_header())
            .form(&form)
            .send()
            .await
            .map_err(|e| StripeError::Transport(e.to_string()))?;

        let json = Self::handle_response(resp).await?;

        let id = json["id"].as_str().unwrap_or("").to_string();
        let payouts_enabled = json["payouts_enabled"].as_bool().unwrap_or(false);
        let charges_enabled = json["charges_enabled"].as_bool().unwrap_or(false);
        let details_submitted = json["details_submitted"].as_bool().unwrap_or(false);
        let default_currency = json["default_currency"].as_str().map(|s| s.to_string());
        let email = json["email"].as_str().map(|s| s.to_string());

        Ok(StripeAccount {
            id,
            payouts_enabled,
            charges_enabled,
            details_submitted,
            default_currency,
            email,
        })
    }

    async fn create_account_link(
        &self,
        params: &CreateAccountLinkParams,
    ) -> Result<StripeAccountLink, StripeError> {
        let url = format!("{}/v1/account_links", self.base_url());
        let link_type = params.link_type.as_deref().unwrap_or("account_onboarding");

        let form = [
            ("account", params.account_id.as_str()),
            ("refresh_url", params.refresh_url.as_str()),
            ("return_url", params.return_url.as_str()),
            ("type", link_type),
        ];

        let resp = self
            .client
            .post(&url)
            .header("Authorization", self.auth_header())
            .form(&form)
            .send()
            .await
            .map_err(|e| StripeError::Transport(e.to_string()))?;

        let json = Self::handle_response(resp).await?;

        let link_url = json["url"].as_str().unwrap_or("").to_string();
        let expires_at = json["expires_at"].as_i64().unwrap_or(0);

        Ok(StripeAccountLink {
            url: link_url,
            expires_at,
        })
    }

    async fn retrieve_account(&self, account_id: &str) -> Result<StripeAccount, StripeError> {
        let url = format!("{}/v1/accounts/{}", self.base_url(), account_id);

        let resp = self
            .client
            .get(&url)
            .header("Authorization", self.auth_header())
            .send()
            .await
            .map_err(|e| StripeError::Transport(e.to_string()))?;

        let json = Self::handle_response(resp).await?;

        let id = json["id"].as_str().unwrap_or(account_id).to_string();
        let payouts_enabled = json["payouts_enabled"].as_bool().unwrap_or(false);
        let charges_enabled = json["charges_enabled"].as_bool().unwrap_or(false);
        let details_submitted = json["details_submitted"].as_bool().unwrap_or(false);
        let default_currency = json["default_currency"].as_str().map(|s| s.to_string());
        let email = json["email"].as_str().map(|s| s.to_string());

        Ok(StripeAccount {
            id,
            payouts_enabled,
            charges_enabled,
            details_submitted,
            default_currency,
            email,
        })
    }

    async fn create_payment_intent(
        &self,
        params: &CreatePaymentIntentParams,
        idempotency_key: Option<&str>,
    ) -> Result<StripePaymentIntent, StripeError> {
        if params.application_fee_amount > params.amount {
            return Err(StripeError::InvalidRequest(
                "The amount of the application fee cannot exceed the amount of the payment."
                    .to_string(),
            ));
        }

        let url = format!("{}/v1/payment_intents", self.base_url());
        let mut form = vec![
            ("amount", params.amount.to_string()),
            ("currency", params.currency.to_lowercase()),
            (
                "application_fee_amount",
                params.application_fee_amount.to_string(),
            ),
            (
                "transfer_data[destination]",
                params.destination_account_id.clone(),
            ),
            ("payment_method_types[]", "card".to_string()),
        ];

        if let Some(ref desc) = params.description {
            form.push(("description", desc.clone()));
        }

        for (k, v) in &params.metadata {
            form.push(("metadata", format!("{k}={v}")));
        }

        let mut req_builder = self
            .client
            .post(&url)
            .header("Authorization", self.auth_header())
            .form(&form);

        if let Some(key) = idempotency_key {
            req_builder = req_builder.header("Idempotency-Key", key);
        }

        let resp = req_builder
            .send()
            .await
            .map_err(|e| StripeError::Transport(e.to_string()))?;

        let json = Self::handle_response(resp).await?;

        let id = json["id"].as_str().unwrap_or("").to_string();
        let client_secret = json["client_secret"].as_str().map(|s| s.to_string());
        let amount = json["amount"].as_i64().unwrap_or(params.amount);
        let currency = json["currency"]
            .as_str()
            .unwrap_or(&params.currency)
            .to_string();
        let status = json["status"]
            .as_str()
            .unwrap_or("requires_payment_method")
            .to_string();
        let app_fee = json["application_fee_amount"].as_i64();
        let dest = json["transfer_data"]["destination"]
            .as_str()
            .map(|s| s.to_string())
            .or_else(|| Some(params.destination_account_id.clone()));

        Ok(StripePaymentIntent {
            id,
            client_secret,
            amount,
            currency,
            status,
            application_fee_amount: app_fee,
            destination_account_id: dest,
        })
    }

    async fn create_refund(
        &self,
        params: &CreateRefundParams,
        idempotency_key: Option<&str>,
    ) -> Result<StripeRefund, StripeError> {
        let url = format!("{}/v1/refunds", self.base_url());
        let mut form = vec![
            ("payment_intent", params.payment_intent_id.clone()),
            ("reverse_transfer", params.reverse_transfer.to_string()),
        ];

        if let Some(amt) = params.amount {
            form.push(("amount", amt.to_string()));
        }
        if let Some(ref_fee) = params.refund_application_fee {
            form.push(("refund_application_fee", ref_fee.to_string()));
        }

        let mut req_builder = self
            .client
            .post(&url)
            .header("Authorization", self.auth_header())
            .form(&form);

        if let Some(key) = idempotency_key {
            req_builder = req_builder.header("Idempotency-Key", key);
        }

        let resp = req_builder
            .send()
            .await
            .map_err(|e| StripeError::Transport(e.to_string()))?;

        let json = Self::handle_response(resp).await?;

        let id = json["id"].as_str().unwrap_or("").to_string();
        let payment_intent_id = json["payment_intent"].as_str().map(|s| s.to_string());
        let amount = json["amount"].as_i64().unwrap_or(0);
        let currency = json["currency"].as_str().unwrap_or("usd").to_string();
        let status = json["status"].as_str().unwrap_or("succeeded").to_string();

        Ok(StripeRefund {
            id,
            payment_intent_id,
            amount,
            currency,
            status,
        })
    }
}

// ---------------------------------------------------------------------------
// MockStripeClient In-Memory Test Double
// ---------------------------------------------------------------------------

/// State stored in the in-memory mock Stripe client.
#[derive(Debug, Default)]
struct MockStripeState {
    accounts: HashMap<String, StripeAccount>,
    account_links: HashMap<String, StripeAccountLink>,
    payment_intents: HashMap<String, StripePaymentIntent>,
    refunds: HashMap<String, StripeRefund>,
    idempotency_keys: HashMap<String, String>, // idempotency_key -> resource_id
    next_id: usize,
    should_decline_next_card: bool,
    force_auth_error: bool,
}

/// Thread-safe in-memory Stripe test double for deterministic testing.
#[derive(Clone, Default)]
pub struct MockStripeClient {
    state: Arc<RwLock<MockStripeState>>,
}

impl MockStripeClient {
    /// Creates a new, empty in-memory mock Stripe client.
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(MockStripeState::default())),
        }
    }

    /// Sets `payouts_enabled` on a mock account for testing.
    pub async fn set_payouts_enabled(&self, account_id: &str, enabled: bool) {
        let mut guard = self.state.write().await;
        if let Some(acct) = guard.accounts.get_mut(account_id) {
            acct.payouts_enabled = enabled;
            if enabled {
                acct.details_submitted = true;
            }
        }
    }

    /// Sets `charges_enabled` on a mock account for testing.
    pub async fn set_charges_enabled(&self, account_id: &str, enabled: bool) {
        let mut guard = self.state.write().await;
        if let Some(acct) = guard.accounts.get_mut(account_id) {
            acct.charges_enabled = enabled;
        }
    }

    /// Simulates a card decline on the next payment intent creation.
    pub async fn set_should_decline_next_card(&self, decline: bool) {
        let mut guard = self.state.write().await;
        guard.should_decline_next_card = decline;
    }

    /// Simulates an authentication error on subsequent API calls.
    pub async fn set_force_auth_error(&self, force: bool) {
        let mut guard = self.state.write().await;
        guard.force_auth_error = force;
    }

    /// Retrieves the total number of recorded payment intents.
    pub async fn payment_intents_count(&self) -> usize {
        self.state.read().await.payment_intents.len()
    }

    /// Retrieves the total number of recorded refunds.
    pub async fn refunds_count(&self) -> usize {
        self.state.read().await.refunds.len()
    }
}

#[async_trait]
impl StripeClient for MockStripeClient {
    async fn create_express_account(
        &self,
        params: &CreateAccountParams,
    ) -> Result<StripeAccount, StripeError> {
        let mut guard = self.state.write().await;
        if guard.force_auth_error {
            return Err(StripeError::AuthenticationFailed(
                "Invalid API Key".to_string(),
            ));
        }

        guard.next_id += 1;
        let id = format!("acct_mock_{:06}", guard.next_id);
        let account = StripeAccount {
            id: id.clone(),
            payouts_enabled: false,
            charges_enabled: false,
            details_submitted: false,
            default_currency: Some("usd".to_string()),
            email: params.email.clone(),
        };

        guard.accounts.insert(id, account.clone());
        Ok(account)
    }

    async fn create_account_link(
        &self,
        params: &CreateAccountLinkParams,
    ) -> Result<StripeAccountLink, StripeError> {
        let mut guard = self.state.write().await;
        if guard.force_auth_error {
            return Err(StripeError::AuthenticationFailed(
                "Invalid API Key".to_string(),
            ));
        }

        if !guard.accounts.contains_key(&params.account_id) {
            return Err(StripeError::NotFound(format!(
                "No such account: {}",
                params.account_id
            )));
        }

        guard.next_id += 1;
        let url = format!(
            "https://connect.stripe.com/setup/s/mock_token_{:06}",
            guard.next_id
        );
        let expires_at = chrono::Utc::now().timestamp() + 300;

        let link = StripeAccountLink { url, expires_at };

        guard
            .account_links
            .insert(params.account_id.clone(), link.clone());
        Ok(link)
    }

    async fn retrieve_account(&self, account_id: &str) -> Result<StripeAccount, StripeError> {
        let guard = self.state.read().await;
        if guard.force_auth_error {
            return Err(StripeError::AuthenticationFailed(
                "Invalid API Key".to_string(),
            ));
        }

        guard
            .accounts
            .get(account_id)
            .cloned()
            .ok_or_else(|| StripeError::NotFound(format!("No such account: {account_id}")))
    }

    async fn create_payment_intent(
        &self,
        params: &CreatePaymentIntentParams,
        idempotency_key: Option<&str>,
    ) -> Result<StripePaymentIntent, StripeError> {
        let mut guard = self.state.write().await;
        if guard.force_auth_error {
            return Err(StripeError::AuthenticationFailed(
                "Invalid API Key".to_string(),
            ));
        }

        // Idempotency check: if key seen, return existing payment intent
        if let Some(key) = idempotency_key {
            if let Some(existing_id) = guard.idempotency_keys.get(key) {
                if let Some(pi) = guard.payment_intents.get(existing_id) {
                    return Ok(pi.clone());
                }
            }
        }

        // Documented constraint: Application fee cannot exceed charge amount
        if params.application_fee_amount > params.amount {
            return Err(StripeError::InvalidRequest(
                "The amount of the application fee cannot exceed the amount of the payment."
                    .to_string(),
            ));
        }

        if guard.should_decline_next_card {
            guard.should_decline_next_card = false;
            return Err(StripeError::CardDeclined(
                "Your card was declined.".to_string(),
            ));
        }

        guard.next_id += 1;
        let id = format!("pi_mock_{:06}", guard.next_id);
        let client_secret = format!("{id}_secret_mock");

        let pi = StripePaymentIntent {
            id: id.clone(),
            client_secret: Some(client_secret),
            amount: params.amount,
            currency: params.currency.to_lowercase(),
            status: "succeeded".to_string(),
            application_fee_amount: Some(params.application_fee_amount),
            destination_account_id: Some(params.destination_account_id.clone()),
        };

        guard.payment_intents.insert(id.clone(), pi.clone());
        if let Some(key) = idempotency_key {
            guard.idempotency_keys.insert(key.to_string(), id);
        }

        Ok(pi)
    }

    async fn create_refund(
        &self,
        params: &CreateRefundParams,
        idempotency_key: Option<&str>,
    ) -> Result<StripeRefund, StripeError> {
        let mut guard = self.state.write().await;
        if guard.force_auth_error {
            return Err(StripeError::AuthenticationFailed(
                "Invalid API Key".to_string(),
            ));
        }

        if let Some(key) = idempotency_key {
            if let Some(existing_id) = guard.idempotency_keys.get(key) {
                if let Some(r) = guard.refunds.get(existing_id) {
                    return Ok(r.clone());
                }
            }
        }

        let pi = guard
            .payment_intents
            .get(&params.payment_intent_id)
            .cloned()
            .ok_or_else(|| {
                StripeError::NotFound(format!(
                    "No such payment_intent: {}",
                    params.payment_intent_id
                ))
            })?;

        guard.next_id += 1;
        let refund_id = format!("re_mock_{:06}", guard.next_id);
        let refund_amount = params.amount.unwrap_or(pi.amount);

        let refund = StripeRefund {
            id: refund_id.clone(),
            payment_intent_id: Some(pi.id),
            amount: refund_amount,
            currency: pi.currency,
            status: "succeeded".to_string(),
        };

        guard.refunds.insert(refund_id.clone(), refund.clone());
        if let Some(key) = idempotency_key {
            guard.idempotency_keys.insert(key.to_string(), refund_id);
        }

        Ok(refund)
    }
}
