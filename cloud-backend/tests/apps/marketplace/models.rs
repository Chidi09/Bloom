use bloom_cloud_backend::apps::marketplace::models::{
    SellerAccount, Template, TemplatePurchase, TemplateVersion,
};
use djangors_orm::meta::{DefaultValue, OnDelete, RelationKind};

#[test]
fn test_template_model_metadata() {
    let meta = Template::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_template");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on Template");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on Template");
    assert_eq!(public_id_field.max_length, Some(36));

    let name_field = meta
        .fields
        .iter()
        .find(|f| f.name == "name")
        .expect("name field must exist on Template");
    assert_eq!(name_field.max_length, Some(255));

    let slug_field = meta
        .fields
        .iter()
        .find(|f| f.name == "slug")
        .expect("slug field must exist on Template");
    assert_eq!(slug_field.max_length, Some(64));

    let desc_field = meta
        .fields
        .iter()
        .find(|f| f.name == "description")
        .expect("description field must exist on Template");
    assert!(desc_field.nullable, "description must be nullable");
    assert_eq!(desc_field.max_length, Some(2000));

    let vis_field = meta
        .fields
        .iter()
        .find(|f| f.name == "visibility")
        .expect("visibility field must exist on Template");
    assert_eq!(vis_field.max_length, Some(32));
    assert!(vis_field.db_index, "visibility must be indexed");

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on Template");
    assert_eq!(status_field.max_length, Some(32));
    assert!(status_field.db_index, "status must be indexed");

    let is_free_field = meta
        .fields
        .iter()
        .find(|f| f.name == "is_free")
        .expect("is_free field must exist on Template");
    assert_eq!(is_free_field.default, DefaultValue::Bool(true));

    let price_amount_field = meta
        .fields
        .iter()
        .find(|f| f.name == "price_amount")
        .expect("price_amount field must exist on Template");
    assert_eq!(price_amount_field.default, DefaultValue::I64(0));

    let price_currency_field = meta
        .fields
        .iter()
        .find(|f| f.name == "price_currency")
        .expect("price_currency field must exist on Template");
    assert_eq!(price_currency_field.default, DefaultValue::Text("usd"));

    let meta_field = meta
        .fields
        .iter()
        .find(|f| f.name == "metadata")
        .expect("metadata field must exist on Template");
    assert_eq!(meta_field.default, DefaultValue::Text("{}"));

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on Template");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
    assert_eq!((org_rel.target)().table_name, "organizations_organization");
}

#[test]
fn test_template_version_model_metadata() {
    let meta = TemplateVersion::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_templateversion");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on TemplateVersion");
    assert!(id_field.primary_key, "id must be primary key");
    assert!(id_field.auto, "id must be auto-incremented");

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id field must exist on TemplateVersion");
    assert_eq!(public_id_field.max_length, Some(36));

    let version_field = meta
        .fields
        .iter()
        .find(|f| f.name == "version")
        .expect("version field must exist on TemplateVersion");
    assert_eq!(version_field.max_length, Some(64));
    assert!(version_field.db_index, "version must be indexed");

    let manifest_field = meta
        .fields
        .iter()
        .find(|f| f.name == "manifest")
        .expect("manifest field must exist on TemplateVersion");
    assert_eq!(manifest_field.default, DefaultValue::Text("{}"));

    let tmpl_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "template_id")
        .expect("template_id relation must exist on TemplateVersion");
    assert_eq!(tmpl_rel.kind, RelationKind::ForeignKey);
    assert_eq!(tmpl_rel.on_delete, OnDelete::Cascade);
    assert_eq!((tmpl_rel.target)().table_name, "marketplace_template");
}

#[test]
fn test_seller_account_model_metadata() {
    let meta = SellerAccount::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_selleraccount");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on SellerAccount");
    assert!(id_field.primary_key);

    let stripe_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "stripe_account_id")
        .expect("stripe_account_id must exist on SellerAccount");
    assert_eq!(stripe_id_field.max_length, Some(255));

    let payouts_field = meta
        .fields
        .iter()
        .find(|f| f.name == "payouts_enabled")
        .expect("payouts_enabled must exist on SellerAccount");
    assert_eq!(payouts_field.default, DefaultValue::Bool(false));

    let charges_field = meta
        .fields
        .iter()
        .find(|f| f.name == "charges_enabled")
        .expect("charges_enabled must exist on SellerAccount");
    assert_eq!(charges_field.default, DefaultValue::Bool(false));

    let org_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "organization_id")
        .expect("organization_id relation must exist on SellerAccount");
    assert_eq!(org_rel.kind, RelationKind::ForeignKey);
    assert_eq!(org_rel.on_delete, OnDelete::Cascade);
    assert_eq!((org_rel.target)().table_name, "organizations_organization");
}

#[test]
fn test_template_purchase_model_metadata() {
    let meta = TemplatePurchase::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_templatepurchase");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on TemplatePurchase");
    assert!(id_field.primary_key);

    let amount_field = meta
        .fields
        .iter()
        .find(|f| f.name == "amount")
        .expect("amount field must exist on TemplatePurchase");
    assert!(!amount_field.nullable);

    let platform_fee_field = meta
        .fields
        .iter()
        .find(|f| f.name == "platform_fee")
        .expect("platform_fee field must exist on TemplatePurchase");
    assert!(!platform_fee_field.nullable);

    let seller_amount_field = meta
        .fields
        .iter()
        .find(|f| f.name == "seller_amount")
        .expect("seller_amount field must exist on TemplatePurchase");
    assert!(!seller_amount_field.nullable);

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status field must exist on TemplatePurchase");
    assert_eq!(status_field.default, DefaultValue::Text("pending"));

    let idem_field = meta
        .fields
        .iter()
        .find(|f| f.name == "idempotency_key")
        .expect("idempotency_key field must exist on TemplatePurchase");
    assert_eq!(idem_field.max_length, Some(128));

    // Nullable foreign key rule (l): template_version_id is Option<i64> so it is in fields, not relations
    let ver_field = meta
        .fields
        .iter()
        .find(|f| f.name == "template_version_id")
        .expect("template_version_id field must exist");
    assert!(ver_field.nullable);

    // Required foreign keys are in relations
    let buyer_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "buyer_organization_id")
        .expect("buyer_organization_id relation must exist");
    assert_eq!(buyer_rel.kind, RelationKind::ForeignKey);
    assert_eq!(buyer_rel.on_delete, OnDelete::Cascade);

    let tmpl_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "template_id")
        .expect("template_id relation must exist");
    assert_eq!(tmpl_rel.kind, RelationKind::ForeignKey);
    assert_eq!(tmpl_rel.on_delete, OnDelete::Cascade);

    let seller_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "seller_organization_id")
        .expect("seller_organization_id relation must exist");
    assert_eq!(seller_rel.kind, RelationKind::ForeignKey);
    assert_eq!(seller_rel.on_delete, OnDelete::Cascade);
}
