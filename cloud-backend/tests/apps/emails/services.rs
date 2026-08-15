use bloom_cloud_backend::apps::emails::services::{
    evaluate_promotional_eligibility, is_in_holdout_group, mint_unsubscribe_token, score_campaign,
    select_best_campaign, verify_unsubscribe_token, CampaignCandidate, CampaignRule, CampaignScore,
    EligibilityRejectionReason, UserActivitySnapshot, PENALTY_CAMPAIGN_SENT_90_DAYS,
    PENALTY_NO_LOGIN_60_DAYS, PENALTY_UNOPENED_LAST_3_SENDS, STANDARD_SCORE_FLOOR,
    WEIGHT_FEATURE_GAP_REAL, WEIGHT_NEVER_RECEIVED_CAMPAIGN, WEIGHT_OPENED_EMAIL_90_DAYS,
    WEIGHT_PAID_PLAN, WEIGHT_TRIGGER_EVENT_RECENT, WEIGHT_TRIGGER_MATCHED,
};
use chrono::{DateTime, Duration, Utc};

fn make_base_snapshot(now: DateTime<Utc>) -> UserActivitySnapshot {
    UserActivitySnapshot {
        user_id: 42,
        organization_id: 10,
        email: "developer@bloom.dev".to_string(),
        user_created_at: now - Duration::days(30),
        last_login_at: Some(now - Duration::days(5)),
        is_paid_plan: false,
        is_hard_locked_or_past_due: false,
        opened_bloom_email_last_90_days: false,
        last_sent_at_for_this_campaign: None,
        never_received_this_campaign: false,
        last_3_campaign_sends_unopened: false,
        product_preference: "all".to_string(),
        is_suppressed: false,
        last_promotional_email_at: None,
        promotional_emails_count_30_days: 0,
        last_transactional_email_at: None,
    }
}

fn make_base_rule() -> CampaignRule {
    CampaignRule {
        key: "promo.git_not_connected".to_string(),
        name: "Connect Git Repository".to_string(),
        trigger_matched: true,
        triggering_event_recent: false,
        feature_gap_is_real: false,
        score_floor_override: None,
        total_send_volume: 100,
    }
}

// ---------------------------------------------------------------------------
// Pure Campaign Scoring Unit Tests (NO Database Access)
// ---------------------------------------------------------------------------

#[test]
fn test_scoring_weights_constants_verbatim() {
    assert_eq!(WEIGHT_TRIGGER_MATCHED, 50);
    assert_eq!(WEIGHT_TRIGGER_EVENT_RECENT, 20);
    assert_eq!(WEIGHT_FEATURE_GAP_REAL, 15);
    assert_eq!(WEIGHT_OPENED_EMAIL_90_DAYS, 10);
    assert_eq!(WEIGHT_NEVER_RECEIVED_CAMPAIGN, 10);
    assert_eq!(WEIGHT_PAID_PLAN, 5);
    assert_eq!(PENALTY_CAMPAIGN_SENT_90_DAYS, -40);
    assert_eq!(PENALTY_NO_LOGIN_60_DAYS, -25);
    assert_eq!(PENALTY_UNOPENED_LAST_3_SENDS, -20);
    assert_eq!(STANDARD_SCORE_FLOOR, 60);
}

#[test]
fn test_scoring_returns_none_when_trigger_not_matched() {
    let now = Utc::now();
    let snapshot = make_base_snapshot(now);
    let mut rule = make_base_rule();
    rule.trigger_matched = false;

    let res = score_campaign(&snapshot, &rule);
    assert_eq!(res, None, "Unmatched trigger must return None (ineligible)");
}

#[test]
fn test_scoring_base_trigger_matched_only() {
    let now = Utc::now();
    let snapshot = make_base_snapshot(now);
    let rule = make_base_rule();

    let res = score_campaign(&snapshot, &rule).expect("Must be eligible");
    // Trigger matched = +50, plus penalty for not never_received_this_campaign = -40
    assert_eq!(res.score, 50 - 40);
}

#[test]
fn test_scoring_all_positive_signals() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);
    snapshot.opened_bloom_email_last_90_days = true; // +10
    snapshot.never_received_this_campaign = true; // +10
    snapshot.is_paid_plan = true; // +5

    let mut rule = make_base_rule();
    rule.trigger_matched = true; // +50
    rule.triggering_event_recent = true; // +20
    rule.feature_gap_is_real = true; // +15

    let res = score_campaign(&snapshot, &rule).expect("Must be eligible");
    let expected = 50 + 20 + 15 + 10 + 10 + 5;
    assert_eq!(res.score, expected);
    assert_eq!(res.score, 110);
}

#[test]
fn test_scoring_negative_penalties() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);
    snapshot.never_received_this_campaign = false; // triggers -40 same campaign sent in 90 days
    snapshot.last_login_at = None; // triggers -25 no login in 60 days
    snapshot.last_3_campaign_sends_unopened = true; // triggers -20 unopened

    let rule = make_base_rule(); // +50

    let res = score_campaign(&snapshot, &rule).expect("Must be eligible");
    let expected = 50 - 40 - 25 - 20;
    assert_eq!(res.score, expected);
    assert_eq!(res.score, -35);
}

#[test]
fn test_candidate_selection_floor_and_tie_breaking() {
    let rule_a = CampaignRule {
        key: "promo.a".to_string(),
        name: "Campaign A".to_string(),
        trigger_matched: true,
        triggering_event_recent: false,
        feature_gap_is_real: false,
        score_floor_override: None,
        total_send_volume: 500,
    };

    let rule_b = CampaignRule {
        key: "promo.b".to_string(),
        name: "Campaign B".to_string(),
        trigger_matched: true,
        triggering_event_recent: false,
        feature_gap_is_real: false,
        score_floor_override: None,
        total_send_volume: 200,
    };

    let rule_c = CampaignRule {
        key: "promo.c".to_string(),
        name: "Campaign C".to_string(),
        trigger_matched: true,
        triggering_event_recent: false,
        feature_gap_is_real: false,
        score_floor_override: None,
        total_send_volume: 100,
    };

    // 1. Highest score wins
    let candidates = vec![
        CampaignCandidate {
            rule: rule_a.clone(),
            score: CampaignScore {
                campaign_key: "promo.a".to_string(),
                score: 80,
            },
            never_sent_to_user: false,
        },
        CampaignCandidate {
            rule: rule_b.clone(),
            score: CampaignScore {
                campaign_key: "promo.b".to_string(),
                score: 65,
            },
            never_sent_to_user: true,
        },
    ];

    let winner = select_best_campaign(&candidates).expect("Should pick winner");
    assert_eq!(winner.rule.key, "promo.a");

    // 2. Score below floor (60) is rejected
    let below_floor = vec![CampaignCandidate {
        rule: rule_c.clone(),
        score: CampaignScore {
            campaign_key: "promo.c".to_string(),
            score: 55,
        },
        never_sent_to_user: true,
    }];
    assert_eq!(select_best_campaign(&below_floor), None);

    // 3. Custom floor override
    let mut rule_custom_floor = rule_c.clone();
    rule_custom_floor.score_floor_override = Some(50);
    let with_override = vec![CampaignCandidate {
        rule: rule_custom_floor,
        score: CampaignScore {
            campaign_key: "promo.c".to_string(),
            score: 55,
        },
        never_sent_to_user: true,
    }];
    assert!(select_best_campaign(&with_override).is_some());

    // 4. Equal score tie breaks toward campaign never sent to user
    let tie_candidates = vec![
        CampaignCandidate {
            rule: rule_a.clone(),
            score: CampaignScore {
                campaign_key: "promo.a".to_string(),
                score: 75,
            },
            never_sent_to_user: false,
        },
        CampaignCandidate {
            rule: rule_b.clone(),
            score: CampaignScore {
                campaign_key: "promo.b".to_string(),
                score: 75,
            },
            never_sent_to_user: true,
        },
    ];
    let tie_winner = select_best_campaign(&tie_candidates).expect("Winner");
    assert_eq!(tie_winner.rule.key, "promo.b");

    // 5. Equal score + both never sent breaks toward lower total send volume
    let volume_candidates = vec![
        CampaignCandidate {
            rule: rule_a.clone(), // volume 500
            score: CampaignScore {
                campaign_key: "promo.a".to_string(),
                score: 75,
            },
            never_sent_to_user: true,
        },
        CampaignCandidate {
            rule: rule_b.clone(), // volume 200
            score: CampaignScore {
                campaign_key: "promo.b".to_string(),
                score: 75,
            },
            never_sent_to_user: true,
        },
    ];
    let vol_winner = select_best_campaign(&volume_candidates).expect("Winner");
    assert_eq!(vol_winner.rule.key, "promo.b");
}

// ---------------------------------------------------------------------------
// Pure Eligibility Filter Unit Tests (Stage 1)
// ---------------------------------------------------------------------------

#[test]
fn test_eligibility_product_preference_defaults_and_opt_in() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);

    // Default or "none" => rejected
    snapshot.product_preference = "none".to_string();
    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::ProductPreferenceNotOptedIn)
    );

    snapshot.product_preference = "mine_only".to_string();
    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::ProductPreferenceNotOptedIn)
    );

    // Opted in: "all" or "digest" => passes preference check
    snapshot.product_preference = "all".to_string();
    assert_eq!(evaluate_promotional_eligibility(&snapshot, now), Ok(()));

    snapshot.product_preference = "digest".to_string();
    assert_eq!(evaluate_promotional_eligibility(&snapshot, now), Ok(()));
}

#[test]
fn test_eligibility_suppressed_address() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);
    snapshot.is_suppressed = true;

    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::AddressSuppressed)
    );
}

#[test]
fn test_eligibility_account_under_3_days_old() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);
    snapshot.user_created_at = now - Duration::days(2); // 2 days old

    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::AccountTooNew)
    );

    snapshot.user_created_at = now - Duration::days(3); // 3 days old exactly
    assert_eq!(evaluate_promotional_eligibility(&snapshot, now), Ok(()));
}

#[test]
fn test_eligibility_promotional_frequency_caps() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);

    // 1. Promotional email within 7 days
    snapshot.last_promotional_email_at = Some(now - Duration::days(6));
    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::PromotionalFrequencyCapExceeded)
    );

    snapshot.last_promotional_email_at = Some(now - Duration::days(8));
    assert_eq!(evaluate_promotional_eligibility(&snapshot, now), Ok(()));

    // 2. 4 promotional emails within 30 days
    snapshot.promotional_emails_count_30_days = 4;
    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::PromotionalFrequencyCapExceeded)
    );
}

#[test]
fn test_eligibility_transactional_email_within_24_hours() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);

    snapshot.last_transactional_email_at = Some(now - Duration::hours(12));
    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::RecentTransactionalEmail)
    );

    snapshot.last_transactional_email_at = Some(now - Duration::hours(25));
    assert_eq!(evaluate_promotional_eligibility(&snapshot, now), Ok(()));
}

#[test]
fn test_eligibility_hard_lock_or_past_due() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);
    snapshot.is_hard_locked_or_past_due = true;

    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::OrganizationLockedOrPastDue)
    );
}

// ---------------------------------------------------------------------------
// 30-Day Frequency Simulation & Consent Tests (Exit Gates)
// ---------------------------------------------------------------------------

#[test]
fn test_30_day_frequency_simulation_no_user_exceeds_caps() {
    let start_time = Utc::now() - Duration::days(30);

    let mut user_snapshot = make_base_snapshot(start_time);
    user_snapshot.user_created_at = start_time - Duration::days(10);
    user_snapshot.product_preference = "all".to_string();

    let campaign = CampaignRule {
        key: "promo.web_hosting_unused".to_string(),
        name: "Deploy Web Hosting".to_string(),
        trigger_matched: true,
        triggering_event_recent: true,
        feature_gap_is_real: true,
        score_floor_override: None,
        total_send_volume: 50,
    };

    let mut sent_days = Vec::new();
    let mut promo_sends_in_window = Vec::<DateTime<Utc>>::new();

    for day in 0..30 {
        let current_day = start_time + Duration::days(day);

        // Filter promo_sends_in_window to last 30 days
        promo_sends_in_window
            .retain(|&t| current_day.signed_duration_since(t) <= Duration::days(30));
        user_snapshot.promotional_emails_count_30_days = promo_sends_in_window.len() as i64;
        user_snapshot.last_promotional_email_at = promo_sends_in_window.last().copied();

        let eligible = evaluate_promotional_eligibility(&user_snapshot, current_day);
        if eligible.is_ok() {
            if let Some(score) = score_campaign(&user_snapshot, &campaign) {
                if score.score >= STANDARD_SCORE_FLOOR {
                    sent_days.push(day);
                    promo_sends_in_window.push(current_day);
                }
            }
        }
    }

    // Verify frequency cap constraints:
    // 1. Total sends in 30 days <= 4
    assert!(
        sent_days.len() <= 4,
        "Total promotional sends across 30 days was {}, expected <= 4",
        sent_days.len()
    );

    // 2. Minimum spacing between sends >= 7 days
    for i in 1..sent_days.len() {
        let gap = sent_days[i] - sent_days[i - 1];
        assert!(
            gap >= 7,
            "Spacing between send {} and {} was only {} days, expected >= 7",
            i - 1,
            i,
            gap
        );
    }
}

#[test]
fn test_never_opted_in_user_receives_zero_over_30_days() {
    let start_time = Utc::now() - Duration::days(30);

    let mut user_snapshot = make_base_snapshot(start_time);
    user_snapshot.user_created_at = start_time - Duration::days(10);
    // User never opted in: default "none"
    user_snapshot.product_preference = "none".to_string();

    let mut sent_count = 0;

    for day in 0..30 {
        let current_day = start_time + Duration::days(day);
        if evaluate_promotional_eligibility(&user_snapshot, current_day).is_ok() {
            sent_count += 1;
        }
    }

    assert_eq!(
        sent_count, 0,
        "A user who never opted in must receive zero promotional emails across 30 days"
    );
}

#[test]
fn test_hard_locked_organization_receives_zero_promotional_emails() {
    let now = Utc::now();
    let mut snapshot = make_base_snapshot(now);
    snapshot.is_hard_locked_or_past_due = true;

    assert_eq!(
        evaluate_promotional_eligibility(&snapshot, now),
        Err(EligibilityRejectionReason::OrganizationLockedOrPastDue),
        "Hard-locked organization must receive zero promotional emails"
    );
}

// ---------------------------------------------------------------------------
// Unsubscribe Token Tests (Constant-Time HMAC Verification)
// ---------------------------------------------------------------------------

#[test]
fn test_unsubscribe_token_mint_and_verify_roundtrip() {
    let key = b"secret_hmac_signing_key_for_testing_12345";
    let user_pub_id = "550e8400-e29b-41d4-a716-446655440000";
    let category = "product";
    let issued_at = 1718000000_i64;

    let token = mint_unsubscribe_token(user_pub_id, category, issued_at, key);
    let verified = verify_unsubscribe_token(&token, key).expect("Valid token must verify");

    assert_eq!(verified.user_public_id, user_pub_id);
    assert_eq!(verified.category, category);
    assert_eq!(verified.issued_at, issued_at);
}

#[test]
fn test_tampered_unsubscribe_token_rejected() {
    let key = b"secret_hmac_signing_key_for_testing_12345";
    let token = mint_unsubscribe_token("user-uuid-1", "product", 1718000000, key);

    // Tamper signature
    let tampered_sig = format!("{token}tampered");
    assert!(verify_unsubscribe_token(&tampered_sig, key).is_err());

    // Tamper user id in payload
    let parts: Vec<&str> = token.split(':').collect();
    let tampered_user = format!("user-uuid-2:{}:{}:{}", parts[1], parts[2], parts[3]);
    assert!(verify_unsubscribe_token(&tampered_user, key).is_err());

    // Tamper category in payload
    let tampered_cat = format!("{}:builds:{}:{}", parts[0], parts[2], parts[3]);
    assert!(verify_unsubscribe_token(&tampered_cat, key).is_err());
}

// ---------------------------------------------------------------------------
// Holdout Group Tests
// ---------------------------------------------------------------------------

#[test]
fn test_holdout_group_stability_and_distribution() {
    // Holdout is deterministic for the same user ID
    let is_holdout_1 = is_in_holdout_group(100);
    let is_holdout_2 = is_in_holdout_group(100);
    assert_eq!(is_holdout_1, is_holdout_2);

    // Sample across 1000 users: roughly 5% (between 2% and 8%)
    let mut holdout_count = 0;
    for uid in 1..=1000 {
        if is_in_holdout_group(uid) {
            holdout_count += 1;
        }
    }
    assert!(
        (20..=80).contains(&holdout_count),
        "Holdout count was {}, expected ~50 out of 1000",
        holdout_count
    );
}

/// The email log and suppression writers use string literals rather than a caller-supplied
/// value, so nothing untrusted reaches those columns. That also means a typo in one of the
/// literals would never be caught by validation -- it would simply write a status no reader
/// recognises. These assertions pin the literals to the declared vocabularies.
#[test]
fn status_literals_written_by_services_are_declared_valid() {
    use bloom_cloud_backend::apps::emails::{VALID_EMAIL_STATUSES, VALID_SUPPRESSION_REASONS};

    // Written by the enqueue path in `services::queue_email`.
    assert!(
        VALID_EMAIL_STATUSES.contains(&"queued"),
        "the enqueue path writes status=\"queued\"; it must remain a declared status"
    );

    // Written by the unsubscribe path in `services::process_unsubscribe`.
    assert!(
        VALID_SUPPRESSION_REASONS.contains(&"unsubscribed"),
        "the unsubscribe path writes reason=\"unsubscribed\"; it must remain a declared reason"
    );
}
