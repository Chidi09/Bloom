use bloom_cloud_backend::apps::marketplace::models::{
    ReviewReport, SellerAccount, Template, TemplateInstall, TemplateInstallDedup, TemplatePurchase,
    TemplateReview, TemplateVersion,
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

    let rating_count_field = meta
        .fields
        .iter()
        .find(|f| f.name == "rating_count")
        .expect("rating_count field must exist on Template");
    assert_eq!(rating_count_field.default, DefaultValue::I64(0));

    let rating_sum_field = meta
        .fields
        .iter()
        .find(|f| f.name == "rating_sum")
        .expect("rating_sum field must exist on Template");
    assert_eq!(rating_sum_field.default, DefaultValue::I64(0));

    let rating_bayesian_field = meta
        .fields
        .iter()
        .find(|f| f.name == "rating_bayesian_milli")
        .expect("rating_bayesian_milli field must exist on Template");
    assert_eq!(rating_bayesian_field.default, DefaultValue::I64(0));
    assert!(rating_bayesian_field.db_index);

    let install_count_field = meta
        .fields
        .iter()
        .find(|f| f.name == "install_count")
        .expect("install_count field must exist on Template");
    assert_eq!(install_count_field.default, DefaultValue::I64(0));
    assert!(install_count_field.db_index);

    let featured_type_field = meta
        .fields
        .iter()
        .find(|f| f.name == "featured_type")
        .expect("featured_type field must exist on Template");
    assert_eq!(featured_type_field.max_length, Some(32));
    assert_eq!(featured_type_field.default, DefaultValue::Text("none"));
    assert!(featured_type_field.db_index);

    let featured_until_field = meta
        .fields
        .iter()
        .find(|f| f.name == "featured_until")
        .expect("featured_until field must exist on Template");
    assert!(featured_until_field.nullable);

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

    let install_count_field = meta
        .fields
        .iter()
        .find(|f| f.name == "install_count")
        .expect("install_count field must exist on TemplateVersion");
    assert_eq!(install_count_field.default, DefaultValue::I64(0));

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

#[test]
fn test_template_review_model_metadata() {
    let meta = TemplateReview::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_templatereview");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on TemplateReview");
    assert!(id_field.primary_key);
    assert!(id_field.auto);

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id must exist on TemplateReview");
    assert_eq!(public_id_field.max_length, Some(36));

    let title_field = meta
        .fields
        .iter()
        .find(|f| f.name == "title")
        .expect("title must exist on TemplateReview");
    assert_eq!(title_field.max_length, Some(255));
    assert_eq!(title_field.default, DefaultValue::Text(""));

    let comment_field = meta
        .fields
        .iter()
        .find(|f| f.name == "comment")
        .expect("comment must exist on TemplateReview");
    assert_eq!(comment_field.default, DefaultValue::Text(""));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status must exist on TemplateReview");
    assert_eq!(status_field.max_length, Some(32));
    assert_eq!(status_field.default, DefaultValue::Text("published"));
    assert!(status_field.db_index);

    let author_resp_field = meta
        .fields
        .iter()
        .find(|f| f.name == "author_response")
        .expect("author_response must exist on TemplateReview");
    assert!(author_resp_field.nullable);

    let author_resp_at_field = meta
        .fields
        .iter()
        .find(|f| f.name == "author_responded_at")
        .expect("author_responded_at must exist on TemplateReview");
    assert!(author_resp_at_field.nullable);

    let author_resp_by_field = meta
        .fields
        .iter()
        .find(|f| f.name == "author_responded_by_id")
        .expect("author_responded_by_id must exist on TemplateReview");
    assert!(author_resp_by_field.nullable);

    let tmpl_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "template_id")
        .expect("template_id relation must exist on TemplateReview");
    assert_eq!(tmpl_rel.kind, RelationKind::ForeignKey);
    assert_eq!(tmpl_rel.on_delete, OnDelete::Cascade);
    assert_eq!((tmpl_rel.target)().table_name, "marketplace_template");

    let buyer_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "buyer_organization_id")
        .expect("buyer_organization_id relation must exist on TemplateReview");
    assert_eq!(buyer_rel.kind, RelationKind::ForeignKey);
    assert_eq!(buyer_rel.on_delete, OnDelete::Cascade);
    assert_eq!(
        (buyer_rel.target)().table_name,
        "organizations_organization"
    );
}

#[test]
fn test_review_report_model_metadata() {
    let meta = ReviewReport::meta();
    assert_eq!(meta.app_label, "marketplace");
    assert_eq!(meta.table_name, "marketplace_reviewreport");

    let id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "id")
        .expect("id field must exist on ReviewReport");
    assert!(id_field.primary_key);

    let public_id_field = meta
        .fields
        .iter()
        .find(|f| f.name == "public_id")
        .expect("public_id must exist on ReviewReport");
    assert_eq!(public_id_field.max_length, Some(36));

    let reason_field = meta
        .fields
        .iter()
        .find(|f| f.name == "reason")
        .expect("reason must exist on ReviewReport");
    assert_eq!(reason_field.max_length, Some(64));

    let details_field = meta
        .fields
        .iter()
        .find(|f| f.name == "details")
        .expect("details must exist on ReviewReport");
    assert_eq!(details_field.default, DefaultValue::Text(""));

    let status_field = meta
        .fields
        .iter()
        .find(|f| f.name == "status")
        .expect("status must exist on ReviewReport");
    assert_eq!(status_field.max_length, Some(32));
    assert_eq!(status_field.default, DefaultValue::Text("pending"));
    assert!(status_field.db_index);

    let review_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "review_id")
        .expect("review_id relation must exist on ReviewReport");
    assert_eq!(review_rel.kind, RelationKind::ForeignKey);
    assert_eq!(review_rel.on_delete, OnDelete::Cascade);
    assert_eq!(
        (review_rel.target)().table_name,
        "marketplace_templatereview"
    );

    let reporter_rel = meta
        .relations
        .iter()
        .find(|r| r.field_name == "reporter_organization_id")
        .expect("reporter_organization_id relation must exist on ReviewReport");
    assert_eq!(reporter_rel.kind, RelationKind::ForeignKey);
    assert_eq!(reporter_rel.on_delete, OnDelete::Cascade);
    assert_eq!(
        (reporter_rel.target)().table_name,
        "organizations_organization"
    );
}

#[test]
fn test_template_install_dedup_and_install_models_metadata() {
    let meta_dedup = TemplateInstallDedup::meta();
    assert_eq!(meta_dedup.app_label, "marketplace");
    assert_eq!(meta_dedup.table_name, "marketplace_templateinstalldedup");

    let actor_hash_field = meta_dedup
        .fields
        .iter()
        .find(|f| f.name == "actor_hash")
        .expect("actor_hash must exist on TemplateInstallDedup");
    assert_eq!(actor_hash_field.max_length, Some(64));

    let date_bucket_field = meta_dedup
        .fields
        .iter()
        .find(|f| f.name == "date_bucket")
        .expect("date_bucket must exist on TemplateInstallDedup");
    assert_eq!(date_bucket_field.max_length, Some(10));

    let tmpl_rel = meta_dedup
        .relations
        .iter()
        .find(|r| r.field_name == "template_id")
        .expect("template_id relation must exist on TemplateInstallDedup");
    assert_eq!(tmpl_rel.kind, RelationKind::ForeignKey);
    assert_eq!(tmpl_rel.on_delete, OnDelete::Cascade);

    let meta_install = TemplateInstall::meta();
    assert_eq!(meta_install.app_label, "marketplace");
    assert_eq!(meta_install.table_name, "marketplace_templateinstall");

    let buyer_rel = meta_install
        .relations
        .iter()
        .find(|r| r.field_name == "buyer_organization_id")
        .expect("buyer_organization_id relation must exist on TemplateInstall");
    assert_eq!(buyer_rel.kind, RelationKind::ForeignKey);
    assert_eq!(buyer_rel.on_delete, OnDelete::Cascade);
}
