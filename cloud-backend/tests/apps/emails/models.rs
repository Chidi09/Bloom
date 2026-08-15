use bloom_cloud_backend::apps::emails::models::{
    Campaign, CampaignSend, EmailLog, EmailSuppression, EmailTemplateVersion,
    NotificationPreference, VALID_CAMPAIGN_KEYS, VALID_EMAIL_STATUSES, VALID_PREFERENCE_CATEGORIES,
    VALID_PREFERENCE_VALUES, VALID_SUPPRESSION_REASONS, VALID_TRANSACTIONAL_KEYS,
};
use djangors_orm::meta::DefaultValue;

#[test]
fn test_email_log_model_metadata() {
    let meta = EmailLog::meta();
    assert_eq!(meta.app_label, "emails");
    assert_eq!(meta.table_name, "emails_emaillog");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on EmailLog");
    assert_eq!(public_id_field.max_length, Some(36));

    let template_key_field = meta
        .fields
        .iter()
        .find(|f| f.name == "template_key")
        .expect("template_key field must exist on EmailLog");
    assert_eq!(template_key_field.max_length, Some(128));

    let recipient_field = meta
        .fields
        .iter()
        .find(|f| f.name == "recipient")
        .expect("recipient field must exist on EmailLog");
    assert_eq!(recipient_field.max_length, Some(254));

    let org_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on EmailLog");
    assert!(org_field.nullable);

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on EmailLog");
    assert_eq!(status_field.max_length, Some(32));

    let provider_msg_field = meta
        .fields
        .iter()
        .find(|f| f.name == "provider_message_id")
        .expect("provider_message_id field must exist on EmailLog");
    assert!(provider_msg_field.nullable);
    assert_eq!(provider_msg_field.max_length, Some(255));

    let error_field = meta
        .fields
        .iter()
        .find(|f| f.name == "error")
        .expect("error field must exist on EmailLog");
    assert!(error_field.nullable);

    let promo_field = meta
        .fields
        .iter()
        .find(|f| f.name == "is_promotional")
        .expect("is_promotional field must exist on EmailLog");
    assert_eq!(promo_field.default, DefaultValue::Bool(false));
}

#[test]
fn test_notification_preference_model_metadata() {
    let meta = NotificationPreference::meta();
    assert_eq!(meta.app_label, "emails");
    assert_eq!(meta.table_name, "emails_notificationpreference");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on NotificationPreference");
    assert_eq!(public_id_field.max_length, Some(36));

    let user_field = meta
        .fields
        .iter()
        .find(|f| f.name == "user_id")
        .expect("user_id field must exist on NotificationPreference");
    assert!(!user_field.nullable);

    let org_field = meta
        .fields
        .iter()
        .find(|f| f.name == "organization_id")
        .expect("organization_id field must exist on NotificationPreference");
    assert!(!org_field.nullable);

    let category_field = meta
        .fields
        .iter()
        .find(|f| f.name == "category")
        .expect("category field must exist on NotificationPreference");
    assert_eq!(category_field.max_length, Some(32));

    let value_field = meta
        .fields
        .iter()
        .find(|f| f.name == "value")
        .expect("value field must exist on NotificationPreference");
    assert_eq!(value_field.max_length, Some(32));
}

#[test]
fn test_email_suppression_model_metadata() {
    let meta = EmailSuppression::meta();
    assert_eq!(meta.app_label, "emails");
    assert_eq!(meta.table_name, "emails_emailsuppression");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on EmailSuppression");
    assert_eq!(public_id_field.max_length, Some(36));

    let address_field = meta
        .fields
        .iter()
        .find(|f| f.name == "address")
        .expect("address field must exist on EmailSuppression");
    assert_eq!(address_field.max_length, Some(254));

    let reason_field = meta
        .fields
        .iter()
        .find(|f| f.name == "reason")
        .expect("reason field must exist on EmailSuppression");
    assert_eq!(reason_field.max_length, Some(32));
}

#[test]
fn test_email_template_version_model_metadata() {
    let meta = EmailTemplateVersion::meta();
    assert_eq!(meta.app_label, "emails");
    assert_eq!(meta.table_name, "emails_emailtemplateversion");

    let template_key_field = meta
        .fields
        .iter()
        .find(|f| f.name == "template_key")
        .expect("template_key field must exist on EmailTemplateVersion");
    assert_eq!(template_key_field.max_length, Some(128));

    let version_field = meta
        .fields
        .iter()
        .find(|f| f.name == "version")
        .expect("version field must exist on EmailTemplateVersion");
    assert_eq!(version_field.max_length, Some(64));

    let checksum_field = meta
        .fields
        .iter()
        .find(|f| f.name == "checksum")
        .expect("checksum field must exist on EmailTemplateVersion");
    assert_eq!(checksum_field.max_length, Some(64));
}

#[test]
fn test_campaign_model_metadata() {
    let meta = Campaign::meta();
    assert_eq!(meta.app_label, "emails");
    assert_eq!(meta.table_name, "emails_campaign");

    let key_field = meta
        .fields
        .iter()
        .find(|f| f.name == "key")
        .expect("key field must exist on Campaign");
    assert_eq!(key_field.max_length, Some(128));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Campaign");
    assert_eq!(name_field.max_length, Some(255));

    let trigger_rule_field = meta
        .fields
        .iter()
        .find(|f| f.name == "trigger_rule")
        .expect("trigger_rule field must exist on Campaign");
    assert_eq!(trigger_rule_field.default, DefaultValue::Text("{}"));

    let active_field = meta
        .fields
        .iter()
        .find(|f| f.name == "active")
        .expect("active field must exist on Campaign");
    assert_eq!(active_field.default, DefaultValue::Bool(true));

    let floor_override_field = meta
        .fields
        .iter()
        .find(|f| f.name == "score_floor_override")
        .expect("score_floor_override field must exist on Campaign");
    assert!(floor_override_field.nullable);
}

#[test]
fn test_campaign_send_model_metadata() {
    let meta = CampaignSend::meta();
    assert_eq!(meta.app_label, "emails");
    assert_eq!(meta.table_name, "emails_campaignsend");

    let campaign_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "campaign_id")
        .expect("campaign_id foreign key relation must exist on CampaignSend");
    assert_eq!((campaign_rel.target)().table_name, "emails_campaign");

    let score_field = meta
        .fields
        .iter()
        .find(|f| f.name == "score_at_send")
        .expect("score_at_send field must exist on CampaignSend");
    assert!(!score_field.nullable);

    let opened_field = meta
        .fields
        .iter()
        .find(|f| f.name == "opened_at")
        .expect("opened_at field must exist on CampaignSend");
    assert!(opened_field.nullable);

    let clicked_field = meta
        .fields
        .iter()
        .find(|f| f.name == "clicked_at")
        .expect("clicked_at field must exist on CampaignSend");
    assert!(clicked_field.nullable);

    let converted_field = meta
        .fields
        .iter()
        .find(|f| f.name == "converted_at")
        .expect("converted_at field must exist on CampaignSend");
    assert!(converted_field.nullable);
}

#[test]
fn test_valid_constants_definitions() {
    assert_eq!(
        VALID_EMAIL_STATUSES,
        &["queued", "sent", "failed", "bounced", "complained"]
    );
    assert_eq!(
        VALID_PREFERENCE_CATEGORIES,
        &[
            "builds",
            "deployments",
            "releases",
            "security",
            "billing",
            "product"
        ]
    );
    assert_eq!(
        VALID_PREFERENCE_VALUES,
        &["all", "mine_only", "digest", "none"]
    );
    assert_eq!(
        VALID_SUPPRESSION_REASONS,
        &["hard_bounce", "spam_complaint", "manual", "unsubscribed"]
    );
    assert!(VALID_CAMPAIGN_KEYS.contains(&"promo.first_build_success"));
    assert!(VALID_CAMPAIGN_KEYS.contains(&"promo.git_not_connected"));
    assert!(VALID_TRANSACTIONAL_KEYS.contains(&"build.failed"));
    assert!(VALID_TRANSACTIONAL_KEYS.contains(&"billing.receipt"));
}
