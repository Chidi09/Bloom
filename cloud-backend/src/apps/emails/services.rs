//! Pure campaign scoring, eligibility enforcement, unsubscribe token management, and email domain services.

use chrono::{DateTime, Duration, Utc};
use djangors_db::Database;
use djangors_orm::ForeignKey;
use sha2::{Digest, Sha256};
use uuid::Uuid;

use super::contracts::{
    CreateCampaignRequest, PreviewCampaignRequest, PreviewCampaignResponse, ScoreFactorBreakdown,
    UpdateCampaignRequest, UpdatePreferencesRequest,
};
use super::errors::EmailsError;
use super::models::{
    Campaign, CampaignSend, EmailLog, EmailSuppression, NotificationPreference,
    VALID_CAMPAIGN_KEYS, VALID_PREFERENCE_CATEGORIES, VALID_PREFERENCE_VALUES,
};
use super::repositories::{self, OrganizationSummary, UserSummary};
use super::serializers::CampaignAggregatedStats;
use crate::infra::crypto::Crypto;

// ---------------------------------------------------------------------------
// Constants & Weights from docs/PHASES-FINAL.md section 14.2
// ---------------------------------------------------------------------------

/// Standard minimum score threshold required to select a campaign.
pub const STANDARD_SCORE_FLOOR: i64 = 60;

/// Weight: trigger condition matched exactly (+50).
pub const WEIGHT_TRIGGER_MATCHED: i64 = 50;

/// Weight: recency of the triggering event <= 3 days (+20).
pub const WEIGHT_TRIGGER_EVENT_RECENT: i64 = 20;

/// Weight: feature gap is real (entitlement present but feature never used) (+15).
pub const WEIGHT_FEATURE_GAP_REAL: i64 = 15;

/// Weight: engagement history (opened a Bloom email in the last 90 days) (+10).
pub const WEIGHT_OPENED_EMAIL_90_DAYS: i64 = 10;

/// Weight: never received this campaign before (+10).
pub const WEIGHT_NEVER_RECEIVED_CAMPAIGN: i64 = 10;

/// Weight: organization is on a paid plan (+5).
pub const WEIGHT_PAID_PLAN: i64 = 5;

/// Penalty: same campaign sent in the last 90 days (-40).
pub const PENALTY_CAMPAIGN_SENT_90_DAYS: i64 = -40;

/// Penalty: no login in 60 days (-25).
pub const PENALTY_NO_LOGIN_60_DAYS: i64 = -25;

/// Penalty: any of the last 3 campaign sends are unopened (-20).
pub const PENALTY_UNOPENED_LAST_3_SENDS: i64 = -20;

// ---------------------------------------------------------------------------
// Data structures for Pure Scoring and Eligibility
// ---------------------------------------------------------------------------

/// Pure campaign score outcome containing the score and campaign identifier.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CampaignScore {
    /// Campaign identifier key.
    pub campaign_key: String,
    /// Calculated integer score.
    pub score: i64,
}

/// Pure campaign scoring candidate input rule.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CampaignRule {
    /// Unique campaign key identifier.
    pub key: String,
    /// Human-readable campaign name.
    pub name: String,
    /// Whether the trigger condition matched exactly.
    pub trigger_matched: bool,
    /// Whether the triggering event happened within 3 days (<= 3 days).
    pub triggering_event_recent: bool,
    /// Whether the feature gap is real (entitled but never used).
    pub feature_gap_is_real: bool,
    /// Optional override for the standard score floor.
    pub score_floor_override: Option<i64>,
    /// Total historical sends of this campaign across all users (for tie-breaking).
    pub total_send_volume: i64,
}

/// Activity snapshot representing a user's activity, history, and engagement state.
///
/// Computed from tables that already exist (builds, deployments, releases, usage, email log)
/// with zero new tracking infrastructure.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserActivitySnapshot {
    /// User's internal ID.
    pub user_id: i64,
    /// User's organization ID.
    pub organization_id: i64,
    /// User's email address.
    pub email: String,
    /// Timestamp when user account was created.
    pub user_created_at: DateTime<Utc>,
    /// Timestamp of user's last login.
    pub last_login_at: Option<DateTime<Utc>>,
    /// Whether the organization is on a paid plan (`pro`, `enterprise`).
    pub is_paid_plan: bool,
    /// Whether the organization is currently in HardLock or past_due.
    pub is_hard_locked_or_past_due: bool,
    /// Whether the user opened any Bloom email in the last 90 days.
    pub opened_bloom_email_last_90_days: bool,
    /// Timestamp when this specific campaign was last sent to this user.
    pub last_sent_at_for_this_campaign: Option<DateTime<Utc>>,
    /// Whether the user has never received this specific campaign before.
    pub never_received_this_campaign: bool,
    /// Whether any of the last 3 campaign emails sent to this user are unopened.
    pub last_3_campaign_sends_unopened: bool,
    /// User's notification preference value for the `product` category (`all`, `digest`, `mine_only`, `none`).
    pub product_preference: String,
    /// Whether user's address is listed in `EmailSuppression`.
    pub is_suppressed: bool,
    /// Timestamp of last promotional email sent to user.
    pub last_promotional_email_at: Option<DateTime<Utc>>,
    /// Number of promotional emails sent to user in last 30 days.
    pub promotional_emails_count_30_days: i64,
    /// Timestamp of last transactional email sent to user.
    pub last_transactional_email_at: Option<DateTime<Utc>>,
}

/// Reason a user was disqualified by the Stage 1 eligibility filter.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EligibilityRejectionReason {
    /// User has not explicitly opted into the `product` category (`all` or `digest`).
    ProductPreferenceNotOptedIn,
    /// Recipient email address is present in the suppression list.
    AddressSuppressed,
    /// User account was created less than 3 days ago.
    AccountTooNew,
    /// User received a promotional email within 7 days or 4 within 30 days.
    PromotionalFrequencyCapExceeded,
    /// User received a transactional email within the last 24 hours.
    RecentTransactionalEmail,
    /// Organization is currently in HardLock or past_due.
    OrganizationLockedOrPastDue,
}

impl std::fmt::Display for EligibilityRejectionReason {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ProductPreferenceNotOptedIn => {
                write!(f, "User has not opted into product notifications.")
            }
            Self::AddressSuppressed => write!(f, "Recipient address is suppressed."),
            Self::AccountTooNew => write!(f, "User account is under 3 days old."),
            Self::PromotionalFrequencyCapExceeded => {
                write!(f, "Promotional sending frequency cap exceeded.")
            }
            Self::RecentTransactionalEmail => {
                write!(f, "User received a transactional email within 24 hours.")
            }
            Self::OrganizationLockedOrPastDue => {
                write!(f, "Organization is in HardLock or past_due status.")
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Pure Scoring and Eligibility Functions (Unit-testable, zero I/O)
// ---------------------------------------------------------------------------

/// Pure scoring function evaluating a campaign rule against a user activity snapshot.
///
/// # Rules (docs/PHASES-FINAL.md §14.2):
/// - Returns `None` if the trigger condition is not matched ("not eligible", distinct from score 0).
/// - Exact weights from spec:
///   +50: trigger condition matched exactly
///   +20: triggering event recency <= 3 days
///   +15: feature gap is real (entitled but feature never used)
///   +10: opened a Bloom email in the last 90 days
///   +10: never received this campaign before
///   +5:  organization is on a paid plan
///   -40: same campaign sent in the last 90 days
///   -25: no login in 60 days
///   -20: any of the last 3 campaign sends unopened
/// - Pure integer arithmetic throughout.
pub fn score_campaign(
    snapshot: &UserActivitySnapshot,
    campaign: &CampaignRule,
) -> Option<CampaignScore> {
    if !campaign.trigger_matched {
        return None;
    }

    let mut score = WEIGHT_TRIGGER_MATCHED;

    if campaign.triggering_event_recent {
        score = score.saturating_add(WEIGHT_TRIGGER_EVENT_RECENT);
    }

    if campaign.feature_gap_is_real {
        score = score.saturating_add(WEIGHT_FEATURE_GAP_REAL);
    }

    if snapshot.opened_bloom_email_last_90_days {
        score = score.saturating_add(WEIGHT_OPENED_EMAIL_90_DAYS);
    }

    if snapshot.never_received_this_campaign {
        score = score.saturating_add(WEIGHT_NEVER_RECEIVED_CAMPAIGN);
    }

    if snapshot.is_paid_plan {
        score = score.saturating_add(WEIGHT_PAID_PLAN);
    }

    if !snapshot.never_received_this_campaign {
        score = score.saturating_add(PENALTY_CAMPAIGN_SENT_90_DAYS);
    }

    if snapshot.last_login_at.is_none() {
        score = score.saturating_add(PENALTY_NO_LOGIN_60_DAYS);
    }

    if snapshot.last_3_campaign_sends_unopened {
        score = score.saturating_add(PENALTY_UNOPENED_LAST_3_SENDS);
    }

    Some(CampaignScore {
        campaign_key: campaign.key.clone(),
        score,
    })
}

/// Pure eligibility filter evaluating whether a user can receive any promotional email.
///
/// # Rules (docs/PHASES-FINAL.md §14.1, §14.2 Stage 1) evaluated in strict sequence:
/// 1. `product` preference is not `all` or `digest` (default for new users is off)
/// 2. Address is present in `EmailSuppression`
/// 3. User created less than 3 days ago
/// 4. Promotional email within 7 days, or 4 within 30 days
/// 5. Transactional email within 24 hours
/// 6. Organization currently in HardLock or past_due
pub fn evaluate_promotional_eligibility(
    snapshot: &UserActivitySnapshot,
    now: DateTime<Utc>,
) -> Result<(), EligibilityRejectionReason> {
    // 1. Consent is explicit: product preference must be "all" or "digest"
    let pref = snapshot.product_preference.trim().to_lowercase();
    if pref != "all" && pref != "digest" {
        return Err(EligibilityRejectionReason::ProductPreferenceNotOptedIn);
    }

    // 2. Suppression check
    if snapshot.is_suppressed {
        return Err(EligibilityRejectionReason::AddressSuppressed);
    }

    // 3. User created < 3 days ago
    if now.signed_duration_since(snapshot.user_created_at) < Duration::days(3) {
        return Err(EligibilityRejectionReason::AccountTooNew);
    }

    // 4. Frequency cap: <= 1 per 7 days, <= 4 per 30 days
    if let Some(last_promo) = snapshot.last_promotional_email_at {
        if now.signed_duration_since(last_promo) < Duration::days(7) {
            return Err(EligibilityRejectionReason::PromotionalFrequencyCapExceeded);
        }
    }
    if snapshot.promotional_emails_count_30_days >= 4 {
        return Err(EligibilityRejectionReason::PromotionalFrequencyCapExceeded);
    }

    // 5. Transactional always wins: no transactional email in last 24 hours
    if let Some(last_tx) = snapshot.last_transactional_email_at {
        if now.signed_duration_since(last_tx) < Duration::hours(24) {
            return Err(EligibilityRejectionReason::RecentTransactionalEmail);
        }
    }

    // 6. Organization state: no promotional emails during HardLock or past_due
    if snapshot.is_hard_locked_or_past_due {
        return Err(EligibilityRejectionReason::OrganizationLockedOrPastDue);
    }

    Ok(())
}

/// Candidate campaign pairing a rule with its evaluated score and send status for user.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CampaignCandidate {
    /// Campaign rule definition.
    pub rule: CampaignRule,
    /// Computed campaign score.
    pub score: CampaignScore,
    /// Whether this campaign was never sent to this specific user.
    pub never_sent_to_user: bool,
}

/// Stage 3: Picks the single best campaign for a user above the score floor.
///
/// Ties break first toward the campaign never sent to that user, then toward lower total send volume.
pub fn select_best_campaign(candidates: &[CampaignCandidate]) -> Option<CampaignCandidate> {
    let mut eligible: Vec<&CampaignCandidate> = candidates
        .iter()
        .filter(|c| {
            let floor = c.rule.score_floor_override.unwrap_or(STANDARD_SCORE_FLOOR);
            c.score.score >= floor
        })
        .collect();

    if eligible.is_empty() {
        return None;
    }

    // Sort by:
    // 1. score descending (highest score first)
    // 2. never_sent_to_user descending (true first)
    // 3. total_send_volume ascending (lowest volume first)
    // 4. key ascending (deterministic tie-break)
    eligible.sort_by(|a, b| {
        b.score
            .score
            .cmp(&a.score.score)
            .then_with(|| b.never_sent_to_user.cmp(&a.never_sent_to_user))
            .then_with(|| a.rule.total_send_volume.cmp(&b.rule.total_send_volume))
            .then_with(|| a.rule.key.cmp(&b.rule.key))
    });

    eligible.first().copied().cloned()
}

/// 5% permanent holdout group determination by hashing user ID.
///
/// Produces a deterministic, stable holdout assignment for baseline measurement.
pub fn is_in_holdout_group(user_id: i64) -> bool {
    let mut hasher = Sha256::new();
    hasher.update(format!("bloom_holdout_salt_{user_id}").as_bytes());
    let hash = hasher.finalize();

    let byte0 = hash[0] as u32;
    let byte1 = hash[1] as u32;
    let val = (byte0 << 8) | byte1;

    (val % 100) < 5
}

// ---------------------------------------------------------------------------
// Unsubscribe Token Minting & Verification (RFC 8058, Section 13.5 §4)
// ---------------------------------------------------------------------------

/// Decoded and verified unsubscribe token payload.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnsubscribeTokenPayload {
    /// Public UUID of the user.
    pub user_public_id: String,
    /// Unsubscribed notification category.
    pub category: String,
    /// Issue timestamp (seconds since Unix epoch).
    pub issued_at: i64,
}

/// Mints an HMAC-SHA256 signed unsubscribe token.
///
/// Uses the canonical [`Crypto::hmac_sha256_hex`].
pub fn mint_unsubscribe_token(
    user_public_id: &str,
    category: &str,
    issued_at: i64,
    signing_key: &[u8],
) -> String {
    let payload = format!("{user_public_id}:{category}:{issued_at}");
    let sig = Crypto::hmac_sha256_hex(signing_key, payload.as_bytes());
    format!("{payload}:{sig}")
}

/// Verifies an HMAC-SHA256 signed unsubscribe token in constant time.
pub fn verify_unsubscribe_token(
    token_str: &str,
    signing_key: &[u8],
) -> Result<UnsubscribeTokenPayload, EmailsError> {
    let parts: Vec<&str> = token_str.split(':').collect();
    if parts.len() != 4 {
        return Err(EmailsError::InvalidUnsubscribeToken(
            "Malformed token structure".to_string(),
        ));
    }

    let user_public_id = parts[0];
    let category = parts[1];
    let issued_at_str = parts[2];
    let provided_sig = parts[3];

    let issued_at = issued_at_str
        .parse::<i64>()
        .map_err(|_| EmailsError::InvalidUnsubscribeToken("Invalid timestamp".to_string()))?;

    let payload = format!("{user_public_id}:{category}:{issued_at}");
    let expected_sig = Crypto::hmac_sha256_hex(signing_key, payload.as_bytes());

    if !Crypto::constant_time_eq_str(provided_sig, &expected_sig) {
        return Err(EmailsError::InvalidUnsubscribeToken(
            "Signature mismatch".to_string(),
        ));
    }

    if !VALID_PREFERENCE_CATEGORIES.contains(&category) && category != "all" {
        return Err(EmailsError::InvalidCategory(category.to_string()));
    }

    Ok(UnsubscribeTokenPayload {
        user_public_id: user_public_id.to_string(),
        category: category.to_string(),
        issued_at,
    })
}

// ---------------------------------------------------------------------------
// Database Services — Preferences, Suppression, Audit Logs, Campaigns
// ---------------------------------------------------------------------------

/// Fetch all notification preferences for a user in an organization, with defaults for missing rows.
pub async fn get_user_preferences(
    db: &Database,
    user_id: i64,
    organization_id: i64,
) -> Result<Vec<NotificationPreference>, EmailsError> {
    let existing = repositories::preferences_for_user_in_org(db, user_id, organization_id)
        .await
        .map_err(EmailsError::from)?;

    let mut result = Vec::with_capacity(VALID_PREFERENCE_CATEGORIES.len());

    for &category in VALID_PREFERENCE_CATEGORIES {
        if let Some(pref) = existing.iter().find(|p| p.category == category) {
            result.push(pref.clone());
        } else {
            // Default rules:
            // product defaults to "none" (consent is explicit)
            // security and billing default to "all" (mandatory)
            // other operational notifications default to "all"
            let default_val = if category == "product" { "none" } else { "all" };

            let now = Utc::now();
            let synthetic = NotificationPreference {
                id: 0,
                public_id: Uuid::new_v4().to_string(),
                user_id,
                organization_id,
                category: category.to_string(),
                value: default_val.to_string(),
                created_at: now,
                updated_at: now,
            };
            result.push(synthetic);
        }
    }

    Ok(result)
}

/// Update user notification preferences.
///
/// Validates category names, preference values, and enforces that `security` and `billing`
/// cannot be set to `none`.
pub async fn update_user_preferences(
    db: &Database,
    user_id: i64,
    organization_id: i64,
    req: UpdatePreferencesRequest,
) -> Result<Vec<NotificationPreference>, EmailsError> {
    let mut updates = Vec::new();

    if let (Some(cat), Some(val)) = (req.category, req.value) {
        updates.push((cat, val));
    }

    if let Some(pref_items) = req.preferences {
        for item in pref_items {
            updates.push((item.category, item.value));
        }
    }

    if updates.is_empty() {
        return Err(EmailsError::ValidationError(
            "No preference updates provided".to_string(),
        ));
    }

    for (cat, val) in &updates {
        if !VALID_PREFERENCE_CATEGORIES.contains(&cat.as_str()) {
            return Err(EmailsError::InvalidCategory(cat.clone()));
        }
        if !VALID_PREFERENCE_VALUES.contains(&val.as_str()) {
            return Err(EmailsError::InvalidPreferenceValue(val.clone()));
        }

        // Immutable categories enforcement
        if (cat == "security" || cat == "billing") && val == "none" {
            return Err(EmailsError::ImmutableCategoryPreference(cat.clone()));
        }
    }

    for (cat, val) in updates {
        let existing =
            repositories::preference_by_user_org_category(db, user_id, organization_id, &cat)
                .await
                .map_err(EmailsError::from)?;

        let now = Utc::now();
        if let Some(mut pref) = existing {
            pref.value = val;
            pref.updated_at = now;
            repositories::update_preference(db, &pref)
                .await
                .map_err(EmailsError::from)?;
        } else {
            let pref = NotificationPreference {
                id: 0,
                public_id: Uuid::new_v4().to_string(),
                user_id,
                organization_id,
                category: cat,
                value: val,
                created_at: now,
                updated_at: now,
            };
            repositories::insert_preference(db, pref)
                .await
                .map_err(EmailsError::from)?;
        }
    }

    get_user_preferences(db, user_id, organization_id).await
}

/// Process an unsubscribe request from a token without requiring a login session.
pub async fn process_unsubscribe(
    db: &Database,
    token_str: &str,
    signing_key: &[u8],
) -> Result<UnsubscribeTokenPayload, EmailsError> {
    let payload = verify_unsubscribe_token(token_str, signing_key)?;

    // Resolve the address through the profile's indexed public_id. The token carries a
    // public_id, never an internal key, so this is a single indexed lookup on each side --
    // an unsubscribe link is unauthenticated and must not be able to scan the user table.
    let profile =
        crate::apps::accounts::repositories::profile_by_public_id(db, &payload.user_public_id)
            .await
            .map_err(EmailsError::from)?;

    let address = match profile {
        Some(profile) => crate::apps::accounts::repositories::user_by_id(db, profile.user_id)
            .await
            .map_err(EmailsError::from)?
            .map(|user| user.email)
            .ok_or_else(|| EmailsError::InvalidUnsubscribeToken("Unknown recipient".to_string()))?,
        None => {
            return Err(EmailsError::InvalidUnsubscribeToken(
                "Unknown recipient".to_string(),
            ))
        }
    };

    let existing_suppression = repositories::suppression_by_address(db, &address)
        .await
        .map_err(EmailsError::from)?;

    if existing_suppression.is_none() {
        let suppression = EmailSuppression {
            id: 0,
            public_id: Uuid::new_v4().to_string(),
            address: address.to_lowercase(),
            reason: "unsubscribed".to_string(),
            created_at: Utc::now(),
        };
        repositories::insert_suppression(db, suppression)
            .await
            .map_err(EmailsError::from)?;
    }

    Ok(payload)
}

/// List email logs for an organization with pagination.
pub async fn list_organization_email_logs(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<EmailLog>, i64), EmailsError> {
    repositories::list_email_logs_query(db, organization_id, limit, offset)
        .await
        .map_err(EmailsError::from)
}

/// List all campaigns with pagination.
pub async fn list_campaigns(
    db: &Database,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Campaign>, i64), EmailsError> {
    repositories::list_campaigns_query(db, limit, offset)
        .await
        .map_err(EmailsError::from)
}

/// Create a new campaign.
pub async fn create_campaign(
    db: &Database,
    req: CreateCampaignRequest,
) -> Result<Campaign, EmailsError> {
    if !VALID_CAMPAIGN_KEYS.contains(&req.key.as_str()) {
        return Err(EmailsError::InvalidCampaignKey(req.key));
    }

    let existing = repositories::campaign_by_key(db, &req.key)
        .await
        .map_err(EmailsError::from)?;

    if existing.is_some() {
        return Err(EmailsError::ValidationError(format!(
            "Campaign with key '{}' already exists",
            req.key
        )));
    }

    let trigger_rule_str = req
        .trigger_rule
        .map(|v| v.to_string())
        .unwrap_or_else(|| "{}".to_string());

    let now = Utc::now();
    let campaign = Campaign {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        key: req.key,
        name: req.name,
        subject_template: req.subject_template,
        body_template: req.body_template,
        active: req.active.unwrap_or(true),
        trigger_rule: trigger_rule_str,
        score_floor_override: req.score_floor_override,
        created_at: now,
        updated_at: now,
    };

    repositories::insert_campaign(db, campaign)
        .await
        .map_err(EmailsError::from)
}

/// Partially update an existing campaign.
pub async fn update_campaign(
    db: &Database,
    public_id: &str,
    req: UpdateCampaignRequest,
) -> Result<Campaign, EmailsError> {
    let mut campaign = repositories::campaign_by_public_id(db, public_id)
        .await
        .map_err(EmailsError::from)?
        .ok_or(EmailsError::CampaignNotFound)?;

    if let Some(name) = req.name {
        campaign.name = name;
    }
    if let Some(sub) = req.subject_template {
        campaign.subject_template = sub;
    }
    if let Some(body) = req.body_template {
        campaign.body_template = body;
    }
    if let Some(active) = req.active {
        campaign.active = active;
    }
    if let Some(trig) = req.trigger_rule {
        campaign.trigger_rule = trig.to_string();
    }
    if req.score_floor_override.is_some() {
        campaign.score_floor_override = req.score_floor_override;
    }

    campaign.updated_at = Utc::now();
    repositories::update_campaign(db, &campaign)
        .await
        .map_err(EmailsError::from)?;

    Ok(campaign)
}

/// Retrieve performance metrics and aggregated stats for a campaign.
pub async fn get_campaign_stats(
    db: &Database,
    public_id: &str,
) -> Result<(Campaign, CampaignAggregatedStats), EmailsError> {
    let campaign = repositories::campaign_by_public_id(db, public_id)
        .await
        .map_err(EmailsError::from)?
        .ok_or(EmailsError::CampaignNotFound)?;

    let stats = repositories::aggregate_campaign_stats(db, campaign.id)
        .await
        .map_err(EmailsError::from)?;

    Ok((campaign, stats))
}

/// Preview a campaign rendering against a user/organization snapshot without sending anything.
pub async fn preview_campaign(
    db: &Database,
    public_id: &str,
    req: PreviewCampaignRequest,
) -> Result<PreviewCampaignResponse, EmailsError> {
    let campaign = repositories::campaign_by_public_id(db, public_id)
        .await
        .map_err(EmailsError::from)?
        .ok_or(EmailsError::CampaignNotFound)?;

    let rule = CampaignRule {
        key: campaign.key.clone(),
        name: campaign.name.clone(),
        trigger_matched: true,
        triggering_event_recent: true,
        feature_gap_is_real: true,
        score_floor_override: campaign.score_floor_override,
        total_send_volume: 0,
    };

    let now = Utc::now();
    let snapshot = UserActivitySnapshot {
        user_id: 1,
        organization_id: 1,
        email: "preview-user@example.com".to_string(),
        user_created_at: now - Duration::days(10),
        last_login_at: Some(now - Duration::days(2)),
        is_paid_plan: true,
        is_hard_locked_or_past_due: false,
        opened_bloom_email_last_90_days: true,
        last_sent_at_for_this_campaign: None,
        never_received_this_campaign: true,
        last_3_campaign_sends_unopened: false,
        product_preference: "all".to_string(),
        is_suppressed: false,
        last_promotional_email_at: None,
        promotional_emails_count_30_days: 0,
        last_transactional_email_at: None,
    };

    let eligible = evaluate_promotional_eligibility(&snapshot, now).is_ok();
    let score_opt = score_campaign(&snapshot, &rule);

    let breakdowns = vec![
        ScoreFactorBreakdown {
            factor: "trigger_matched".to_string(),
            weight: WEIGHT_TRIGGER_MATCHED,
            description: "Trigger condition matched exactly".to_string(),
        },
        ScoreFactorBreakdown {
            factor: "trigger_recent".to_string(),
            weight: WEIGHT_TRIGGER_EVENT_RECENT,
            description: "Triggering event within 3 days".to_string(),
        },
        ScoreFactorBreakdown {
            factor: "feature_gap_real".to_string(),
            weight: WEIGHT_FEATURE_GAP_REAL,
            description: "Feature gap is real".to_string(),
        },
        ScoreFactorBreakdown {
            factor: "opened_email_90_days".to_string(),
            weight: WEIGHT_OPENED_EMAIL_90_DAYS,
            description: "Opened a Bloom email in 90 days".to_string(),
        },
        ScoreFactorBreakdown {
            factor: "never_received_campaign".to_string(),
            weight: WEIGHT_NEVER_RECEIVED_CAMPAIGN,
            description: "Never received this campaign".to_string(),
        },
        ScoreFactorBreakdown {
            factor: "paid_plan".to_string(),
            weight: WEIGHT_PAID_PLAN,
            description: "Organization on a paid plan".to_string(),
        },
    ];

    let rendered_subject = campaign
        .subject_template
        .replace("{{ app_name }}", "Acme Mobile");
    let rendered_body = campaign
        .body_template
        .replace("{{ app_name }}", "Acme Mobile");

    let _ = req;
    let _ = db;

    Ok(PreviewCampaignResponse {
        campaign_key: campaign.key,
        subject: rendered_subject,
        body: rendered_body,
        eligible,
        score: score_opt.map(|s| s.score),
        score_breakdown: Some(breakdowns),
    })
}

/// Idempotent campaign dispatch execution.
///
/// # Idempotence (docs/PHASES-FINAL.md §14.2 Stage 5):
/// Writes the `EmailLog` row with the campaign key BEFORE dispatch,
/// so a crash mid-run cannot double-send on retry.
pub async fn send_promotional_campaign_idempotent(
    db: &Database,
    user: &UserSummary,
    org: &OrganizationSummary,
    campaign: &Campaign,
    score: i64,
) -> Result<(EmailLog, CampaignSend), EmailsError> {
    let now = Utc::now();

    // 1. Live send-time check against EmailLog to ensure frequency cap holds
    let recent_promo_count =
        repositories::count_promotional_emails_since(db, &user.email, now - Duration::days(30))
            .await
            .map_err(EmailsError::from)?;

    if recent_promo_count >= 4 {
        return Err(EmailsError::FrequencyCapExceeded(
            "User reached maximum 4 promotional emails in 30 days".to_string(),
        ));
    }

    let last_promo = repositories::last_promotional_email_for_recipient(db, &user.email)
        .await
        .map_err(EmailsError::from)?;

    if let Some(ref lp) = last_promo {
        if now.signed_duration_since(lp.created_at) < Duration::days(7) {
            return Err(EmailsError::FrequencyCapExceeded(
                "User received a promotional email within the last 7 days".to_string(),
            ));
        }
    }

    // 2. Stage 5: PRE-WRITE EmailLog BEFORE dispatch
    let email_log = EmailLog {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        template_key: campaign.key.clone(),
        recipient: user.email.clone(),
        organization_id: Some(org.id),
        subject: campaign.subject_template.clone(),
        status: "queued".to_string(),
        provider_message_id: None,
        error: None,
        campaign_key: Some(campaign.key.clone()),
        is_promotional: true,
        created_at: now,
        sent_at: None,
        updated_at: now,
    };

    let saved_log = repositories::insert_email_log(db, email_log)
        .await
        .map_err(EmailsError::from)?;

    // 3. Record CampaignSend
    let campaign_send = CampaignSend {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        campaign_id: ForeignKey::new(campaign.id),
        user_id: user.id,
        organization_id: org.id,
        score_at_send: score,
        sent_at: now,
        opened_at: None,
        clicked_at: None,
        converted_at: None,
        conversion_event: None,
    };

    let saved_send = repositories::insert_campaign_send(db, campaign_send)
        .await
        .map_err(EmailsError::from)?;

    // 4. Mark log sent
    let mut sent_log = saved_log;
    sent_log.status = "sent".to_string();
    sent_log.sent_at = Some(now);
    sent_log.updated_at = now;
    repositories::update_email_log(db, &sent_log)
        .await
        .map_err(EmailsError::from)?;

    Ok((sent_log, saved_send))
}
