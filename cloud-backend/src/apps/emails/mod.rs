//! The `emails` domain app.
//!
//! Provides notification preferences, address suppression, email audit logging,
//! template version tracking, and promotional campaign scoring and lifecycle automation.

pub mod contracts;
pub mod errors;
pub mod models;
pub mod permissions;
pub mod repositories;
pub mod serializers;
pub mod services;
pub mod urls;
pub mod views;

pub use models::{
    Campaign, CampaignSend, EmailLog, EmailSuppression, EmailTemplateVersion,
    NotificationPreference, VALID_CAMPAIGN_KEYS, VALID_EMAIL_STATUSES, VALID_PREFERENCE_CATEGORIES,
    VALID_PREFERENCE_VALUES, VALID_SUPPRESSION_REASONS, VALID_TRANSACTIONAL_KEYS,
};
pub use services::{
    evaluate_promotional_eligibility, is_in_holdout_group, mint_unsubscribe_token, score_campaign,
    select_best_campaign, verify_unsubscribe_token, CampaignCandidate, CampaignRule, CampaignScore,
    EligibilityRejectionReason, UnsubscribeTokenPayload, UserActivitySnapshot,
    PENALTY_CAMPAIGN_SENT_90_DAYS, PENALTY_NO_LOGIN_60_DAYS, PENALTY_UNOPENED_LAST_3_SENDS,
    STANDARD_SCORE_FLOOR, WEIGHT_FEATURE_GAP_REAL, WEIGHT_NEVER_RECEIVED_CAMPAIGN,
    WEIGHT_OPENED_EMAIL_90_DAYS, WEIGHT_PAID_PLAN, WEIGHT_TRIGGER_EVENT_RECENT,
    WEIGHT_TRIGGER_MATCHED,
};
pub use urls::urls;
