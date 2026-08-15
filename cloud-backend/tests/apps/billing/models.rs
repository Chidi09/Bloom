use bloom_cloud_backend::apps::billing::models::{Invoice, Plan, Subscription, UsageRecord};
use djangors_orm::meta::DefaultValue;

#[test]
fn test_plan_model_metadata() {
    let meta = Plan::meta();
    assert_eq!(meta.app_label, "billing");
    assert_eq!(meta.table_name, "billing_plan");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Plan");
    assert_eq!(public_id_field.max_length, Some(36));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Plan");
    assert_eq!(name_field.max_length, Some(32));

    let desc_field = meta
        .fields
        .iter()
        .find(|f| f.name == "description")
        .expect("description field must exist on Plan");
    assert!(desc_field.nullable);

    let entitlements_field = meta
        .fields
        .iter()
        .find(|f| f.name == "entitlements")
        .expect("entitlements field must exist on Plan");
    assert_eq!(entitlements_field.default, DefaultValue::Text("{}"));

    let active_field = meta
        .fields
        .iter()
        .find(|f| f.name == "active")
        .expect("active field must exist on Plan");
    assert_eq!(active_field.default, DefaultValue::Bool(true));
}

#[test]
fn test_subscription_model_metadata() {
    let meta = Subscription::meta();
    assert_eq!(meta.app_label, "billing");
    assert_eq!(meta.table_name, "billing_subscription");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Subscription");
    assert_eq!(public_id_field.max_length, Some(36));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on Subscription");
    assert_eq!(status_field.max_length, Some(32));

    let trial_ends_field = meta
        .fields
        .iter()
        .find(|f| f.name == "trial_ends_at")
        .expect("trial_ends_at field must exist on Subscription");
    assert!(trial_ends_field.nullable);

    let activated_field = meta
        .fields
        .iter()
        .find(|f| f.name == "activated_at")
        .expect("activated_at field must exist on Subscription");
    assert!(activated_field.nullable);

    let cust_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "stripe_customer_id")
        .expect("stripe_customer_id field must exist on Subscription");
    assert!(cust_id_field.nullable);
    assert_eq!(cust_id_field.max_length, Some(255));

    let sub_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "stripe_subscription_id")
        .expect("stripe_subscription_id field must exist on Subscription");
    assert!(sub_id_field.nullable);
    assert_eq!(sub_id_field.max_length, Some(255));

    // Relations check: organization_id and plan_id are required ForeignKeys
    assert!(meta
        .relations
        .iter()
        .any(|r| r.field_name == "organization_id"));
    assert!(meta.relations.iter().any(|r| r.field_name == "plan_id"));
}

#[test]
fn test_usage_record_model_metadata() {
    let meta = UsageRecord::meta();
    assert_eq!(meta.app_label, "billing");
    assert_eq!(meta.table_name, "billing_usagerecord");

    let metric_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metric")
        .expect("metric field must exist on UsageRecord");
    assert_eq!(metric_field.max_length, Some(32));

    let meta_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metadata")
        .expect("metadata field must exist on UsageRecord");
    assert_eq!(meta_field.default, DefaultValue::Text("{}"));

    assert!(meta
        .relations
        .iter()
        .any(|r| r.field_name == "organization_id"));
}

#[test]
fn test_invoice_model_metadata() {
    let meta = Invoice::meta();
    assert_eq!(meta.app_label, "billing");
    assert_eq!(meta.table_name, "billing_invoice");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Invoice");
    assert_eq!(public_id_field.max_length, Some(36));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on Invoice");
    assert_eq!(status_field.max_length, Some(32));

    let paid_at_field = meta
        .fields
        .iter()
        .find(|f| f.name == "paid_at")
        .expect("paid_at field must exist on Invoice");
    assert!(paid_at_field.nullable);

    let inv_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "stripe_invoice_id")
        .expect("stripe_invoice_id field must exist on Invoice");
    assert!(inv_id_field.nullable);
    assert_eq!(inv_id_field.max_length, Some(255));

    assert!(meta
        .relations
        .iter()
        .any(|r| r.field_name == "subscription_id"));
    assert!(meta
        .relations
        .iter()
        .any(|r| r.field_name == "organization_id"));
}
