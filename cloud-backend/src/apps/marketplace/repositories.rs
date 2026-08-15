//! Database queries and persistence operations for the `marketplace` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{
    ReviewReport, SellerAccount, Template, TemplateInstall, TemplateInstallDedup, TemplatePurchase,
    TemplateReview, TemplateVersion,
};

/// Lightweight summary projection of an organization from another app.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key of the organization.
    pub id: i64,
    /// External public UUID v4 identifier.
    pub public_id: String,
}

// ---------------------------------------------------------------------------
// Template Queries
// ---------------------------------------------------------------------------

/// Fetch a [`Template`] by its internal primary key.
pub async fn template_by_id(db: &Database, id: i64) -> Result<Option<Template>, OrmError> {
    Template::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a [`Template`] by its external public UUID v4 identifier.
pub async fn template_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Template>, OrmError> {
    Template::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a [`Template`] by its external public UUID within a specific organization.
pub async fn template_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Template>, OrmError> {
    Template::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a [`Template`] by unique slug within an organization.
pub async fn template_by_slug_and_org(
    db: &Database,
    slug: &str,
    organization_id: i64,
) -> Result<Option<Template>, OrmError> {
    Template::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(slug = slug.to_owned()))?
        .first(db)
        .await
}

/// Check if a template slug already exists within an organization.
pub async fn template_slug_exists_in_org(
    db: &Database,
    organization_id: i64,
    slug: &str,
) -> Result<bool, OrmError> {
    Template::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(slug = slug.to_owned()))?
        .exists(db)
        .await
}

/// List all templates belonging to an organization, newest first (`-created_at`).
pub async fn templates_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Template>, OrmError> {
    Template::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List templates belonging to an organization with optional limit and offset.
pub async fn list_org_templates_query(
    db: &Database,
    organization_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Template>, i64), OrmError> {
    let mut qs = Template::objects().filter(q!(organization_id = organization_id))?;
    let total = qs.clone().count(db).await?;
    qs = qs.order_by("-created_at")?;
    if let Some(l) = limit {
        qs = qs.limit(l);
    }
    if let Some(o) = offset {
        qs = qs.offset(o);
    }
    let rows = qs.all(db).await?;
    Ok((rows, total))
}

/// List all public and published templates for the marketplace catalog, newest first.
pub async fn public_published_templates(
    db: &Database,
    search: Option<&str>,
) -> Result<Vec<Template>, OrmError> {
    let all = Template::objects()
        .filter(q!(visibility = "public".to_string()))?
        .filter(q!(status = "published".to_string()))?
        .order_by("-created_at")?
        .all(db)
        .await?;

    if let Some(s) = search {
        let s_lower = s.to_lowercase();
        Ok(all
            .into_iter()
            .filter(|t| {
                t.name.to_lowercase().contains(&s_lower)
                    || t.slug.to_lowercase().contains(&s_lower)
                    || t.description
                        .as_deref()
                        .map(|d| d.to_lowercase().contains(&s_lower))
                        .unwrap_or(false)
            })
            .collect())
    } else {
        Ok(all)
    }
}

/// List public and published templates with optional search, limit, and offset.
pub async fn list_public_published_templates_query(
    db: &Database,
    search: Option<&str>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<Template>, i64), OrmError> {
    let mut qs = Template::objects()
        .filter(q!(visibility = "public".to_string()))?
        .filter(q!(status = "published".to_string()))?;
    if let Some(s) = search {
        let s_trimmed = s.trim();
        if !s_trimmed.is_empty() {
            qs = qs.filter(q!(name__icontains = s_trimmed.to_string()))?;
        }
    }
    let total = qs.clone().count(db).await?;
    qs = qs.order_by("-created_at")?;
    if let Some(l) = limit {
        qs = qs.limit(l);
    }
    if let Some(o) = offset {
        qs = qs.offset(o);
    }
    let rows = qs.all(db).await?;
    Ok((rows, total))
}

/// Look up a public and published template by public UUID.
pub async fn public_published_template_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Template>, OrmError> {
    Template::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(visibility = "public".to_string()))?
        .filter(q!(status = "published".to_string()))?
        .first(db)
        .await
}

/// Insert a new [`Template`] record into the database.
pub async fn insert_template(db: &Database, template: Template) -> Result<Template, OrmError> {
    template.save(db).await
}

/// Update an existing [`Template`] record.
pub async fn update_template(db: &Database, template: &Template) -> Result<(), OrmError> {
    template.update(db).await
}

/// Delete a [`Template`] by its internal primary key.
pub async fn delete_template_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    Template::objects().filter(q!(id = id))?.delete(db).await
}

// ---------------------------------------------------------------------------
// TemplateVersion Queries
// ---------------------------------------------------------------------------

/// Fetch a [`TemplateVersion`] by internal primary key.
pub async fn version_by_id(db: &Database, id: i64) -> Result<Option<TemplateVersion>, OrmError> {
    TemplateVersion::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
}

/// Fetch a [`TemplateVersion`] by public UUID.
pub async fn version_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<TemplateVersion>, OrmError> {
    TemplateVersion::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a [`TemplateVersion`] by public UUID and parent template internal ID.
pub async fn version_by_public_id_and_template(
    db: &Database,
    public_id: &str,
    template_id: i64,
) -> Result<Option<TemplateVersion>, OrmError> {
    TemplateVersion::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(template_id = template_id))?
        .first(db)
        .await
}

/// Fetch a [`TemplateVersion`] by semver string and parent template internal ID.
pub async fn version_by_semver_and_template(
    db: &Database,
    version_str: &str,
    template_id: i64,
) -> Result<Option<TemplateVersion>, OrmError> {
    TemplateVersion::objects()
        .filter(q!(template_id = template_id))?
        .filter(q!(version = version_str.to_owned()))?
        .first(db)
        .await
}

/// List all versions for a template ordered by creation date descending (`-created_at`).
pub async fn versions_for_template(
    db: &Database,
    template_id: i64,
) -> Result<Vec<TemplateVersion>, OrmError> {
    TemplateVersion::objects()
        .filter(q!(template_id = template_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List versions for a template with optional limit and offset.
pub async fn list_template_versions_query(
    db: &Database,
    template_id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<TemplateVersion>, i64), OrmError> {
    let mut qs = TemplateVersion::objects().filter(q!(template_id = template_id))?;
    let total = qs.clone().count(db).await?;
    qs = qs.order_by("-created_at")?;
    if let Some(l) = limit {
        qs = qs.limit(l);
    }
    if let Some(o) = offset {
        qs = qs.offset(o);
    }
    let rows = qs.all(db).await?;
    Ok((rows, total))
}

/// Fetch the latest version for a template.
pub async fn latest_version_for_template(
    db: &Database,
    template_id: i64,
) -> Result<Option<TemplateVersion>, OrmError> {
    TemplateVersion::objects()
        .filter(q!(template_id = template_id))?
        .order_by("-created_at")?
        .first(db)
        .await
}

/// Count total versions for a given template.
pub async fn count_versions_for_template(db: &Database, template_id: i64) -> Result<i64, OrmError> {
    TemplateVersion::objects()
        .filter(q!(template_id = template_id))?
        .count(db)
        .await
}

/// Insert a new [`TemplateVersion`] record.
pub async fn insert_version(
    db: &Database,
    version: TemplateVersion,
) -> Result<TemplateVersion, OrmError> {
    version.save(db).await
}

/// Update an existing [`TemplateVersion`] record.
pub async fn update_version(db: &Database, version: &TemplateVersion) -> Result<(), OrmError> {
    version.update(db).await
}

/// Delete a [`TemplateVersion`] by its internal primary key.
pub async fn delete_version_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    TemplateVersion::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}

// ---------------------------------------------------------------------------
// SellerAccount Queries
// ---------------------------------------------------------------------------

/// Fetch a [`SellerAccount`] by organization internal primary key.
pub async fn seller_account_by_org_id(
    db: &Database,
    organization_id: i64,
) -> Result<Option<SellerAccount>, OrmError> {
    SellerAccount::objects()
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a [`SellerAccount`] by Stripe connected account ID (`acct_...`).
pub async fn seller_account_by_stripe_id(
    db: &Database,
    stripe_account_id: &str,
) -> Result<Option<SellerAccount>, OrmError> {
    SellerAccount::objects()
        .filter(q!(stripe_account_id = stripe_account_id.to_owned()))?
        .first(db)
        .await
}

/// Insert a new [`SellerAccount`] record.
pub async fn insert_seller_account(
    db: &Database,
    account: SellerAccount,
) -> Result<SellerAccount, OrmError> {
    account.save(db).await
}

/// Update an existing [`SellerAccount`] record.
pub async fn update_seller_account(db: &Database, account: &SellerAccount) -> Result<(), OrmError> {
    account.update(db).await
}

// ---------------------------------------------------------------------------
// TemplatePurchase Queries
// ---------------------------------------------------------------------------

/// Fetch a [`TemplatePurchase`] by its internal primary key.
pub async fn purchase_by_id(db: &Database, id: i64) -> Result<Option<TemplatePurchase>, OrmError> {
    TemplatePurchase::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
}

/// Fetch a [`TemplatePurchase`] by its external public UUID v4.
pub async fn purchase_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<TemplatePurchase>, OrmError> {
    TemplatePurchase::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a [`TemplatePurchase`] by idempotency key.
pub async fn purchase_by_idempotency_key(
    db: &Database,
    idempotency_key: &str,
) -> Result<Option<TemplatePurchase>, OrmError> {
    TemplatePurchase::objects()
        .filter(q!(idempotency_key = idempotency_key.to_owned()))?
        .first(db)
        .await
}

/// Fetch an active succeeded purchase for a buyer organization and template.
pub async fn succeeded_purchase_for_buyer_and_template(
    db: &Database,
    buyer_organization_id: i64,
    template_id: i64,
) -> Result<Option<TemplatePurchase>, OrmError> {
    TemplatePurchase::objects()
        .filter(q!(buyer_organization_id = buyer_organization_id))?
        .filter(q!(template_id = template_id))?
        .filter(q!(status = "succeeded".to_string()))?
        .first(db)
        .await
}

/// List all purchases made by a buyer organization, ordered by `-created_at`.
pub async fn purchases_for_buyer_org(
    db: &Database,
    buyer_organization_id: i64,
) -> Result<Vec<TemplatePurchase>, OrmError> {
    TemplatePurchase::objects()
        .filter(q!(buyer_organization_id = buyer_organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List purchases for a buyer organization using cursor-based pagination.
pub async fn list_purchases_cursor(
    db: &Database,
    buyer_organization_id: i64,
    cursor: Option<&str>,
    limit: i64,
) -> Result<(Vec<TemplatePurchase>, Option<String>), OrmError> {
    let mut qs =
        TemplatePurchase::objects().filter(q!(buyer_organization_id = buyer_organization_id))?;
    qs = crate::apps::common::pagination::apply_datetime_cursor(qs, cursor, "created_at", true)?;
    qs = qs.order_by("-created_at")?.limit(limit + 1);
    let mut rows = qs.all(db).await?;
    let has_next = rows.len() > limit as usize;
    if has_next {
        rows.truncate(limit as usize);
    }
    let next_cursor = rows.last().and_then(|last| {
        crate::apps::common::pagination::encode_datetime_cursor(has_next, last.id, last.created_at)
    });
    Ok((rows, next_cursor))
}

/// Insert a new [`TemplatePurchase`] record.
pub async fn insert_purchase(
    db: &Database,
    purchase: TemplatePurchase,
) -> Result<TemplatePurchase, OrmError> {
    purchase.save(db).await
}

/// Update an existing [`TemplatePurchase`] record.
pub async fn update_purchase(db: &Database, purchase: &TemplatePurchase) -> Result<(), OrmError> {
    purchase.update(db).await
}

// ---------------------------------------------------------------------------
// TemplateReview Queries
// ---------------------------------------------------------------------------

/// Fetch a [`TemplateReview`] by internal primary key.
pub async fn review_by_id(db: &Database, id: i64) -> Result<Option<TemplateReview>, OrmError> {
    TemplateReview::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
}

/// Fetch a [`TemplateReview`] by public UUID.
pub async fn review_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<TemplateReview>, OrmError> {
    TemplateReview::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a [`TemplateReview`] by template ID and buyer organization ID.
pub async fn review_by_template_and_buyer_org(
    db: &Database,
    template_id: i64,
    buyer_organization_id: i64,
) -> Result<Option<TemplateReview>, OrmError> {
    TemplateReview::objects()
        .filter(q!(template_id = template_id))?
        .filter(q!(buyer_organization_id = buyer_organization_id))?
        .first(db)
        .await
}

/// List all published reviews for a template, newest first.
pub async fn published_reviews_for_template(
    db: &Database,
    template_id: i64,
) -> Result<Vec<TemplateReview>, OrmError> {
    TemplateReview::objects()
        .filter(q!(template_id = template_id))?
        .filter(q!(status = "published".to_string()))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all reviews for a template (including hidden/archived, for staff/author views).
pub async fn all_reviews_for_template(
    db: &Database,
    template_id: i64,
) -> Result<Vec<TemplateReview>, OrmError> {
    TemplateReview::objects()
        .filter(q!(template_id = template_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List reviews for a template with optional limit and offset.
pub async fn list_template_reviews_query(
    db: &Database,
    template_id: i64,
    include_unmoderated: bool,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(Vec<TemplateReview>, i64), OrmError> {
    let mut qs = TemplateReview::objects().filter(q!(template_id = template_id))?;
    if !include_unmoderated {
        qs = qs.filter(q!(status = "published".to_string()))?;
    }
    let total = qs.clone().count(db).await?;
    qs = qs.order_by("-created_at")?;
    if let Some(l) = limit {
        qs = qs.limit(l);
    }
    if let Some(o) = offset {
        qs = qs.offset(o);
    }
    let rows = qs.all(db).await?;
    Ok((rows, total))
}

/// Insert a new [`TemplateReview`] record.
pub async fn insert_review(
    db: &Database,
    review: TemplateReview,
) -> Result<TemplateReview, OrmError> {
    review.save(db).await
}

/// Update an existing [`TemplateReview`] record.
pub async fn update_review(db: &Database, review: &TemplateReview) -> Result<(), OrmError> {
    review.update(db).await
}

/// Delete a [`TemplateReview`] by internal primary key.
pub async fn delete_review_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    TemplateReview::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}

/// Computes the published review count and star sum for a template.
pub async fn published_reviews_aggregate_for_template(
    db: &Database,
    template_id: i64,
) -> Result<(i64, i64), OrmError> {
    let reviews = TemplateReview::objects()
        .filter(q!(template_id = template_id))?
        .filter(q!(status = "published".to_string()))?
        .all(db)
        .await?;

    let count = reviews.len() as i64;
    let sum: i64 = reviews.iter().map(|r| r.rating).sum();
    Ok((count, sum))
}

/// Computes the marketplace-wide global average rating in milli-stars across all published reviews.
pub async fn marketplace_global_rating_mean_milli(db: &Database) -> Result<i64, OrmError> {
    let published = TemplateReview::objects()
        .filter(q!(status = "published".to_string()))?
        .all(db)
        .await?;

    if published.is_empty() {
        return Ok(super::services::DEFAULT_GLOBAL_MEAN_MILLI);
    }

    let count = published.len() as i64;
    let sum: i64 = published.iter().map(|r| r.rating).sum();
    let mean = (sum * 1000 + count / 2) / count;
    Ok(mean)
}

// ---------------------------------------------------------------------------
// ReviewReport Queries
// ---------------------------------------------------------------------------

/// Fetch a [`ReviewReport`] by internal primary key.
pub async fn review_report_by_id(db: &Database, id: i64) -> Result<Option<ReviewReport>, OrmError> {
    ReviewReport::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a [`ReviewReport`] by public UUID.
pub async fn review_report_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<ReviewReport>, OrmError> {
    ReviewReport::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// List all reports filed for a specific review.
pub async fn reports_for_review(
    db: &Database,
    review_id: i64,
) -> Result<Vec<ReviewReport>, OrmError> {
    ReviewReport::objects()
        .filter(q!(review_id = review_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// Insert a new [`ReviewReport`] record.
pub async fn insert_review_report(
    db: &Database,
    report: ReviewReport,
) -> Result<ReviewReport, OrmError> {
    report.save(db).await
}

/// Update an existing [`ReviewReport`] record.
pub async fn update_review_report(db: &Database, report: &ReviewReport) -> Result<(), OrmError> {
    report.update(db).await
}

// ---------------------------------------------------------------------------
// Install Analytics & Verification Queries
// ---------------------------------------------------------------------------

/// Checks if an install event deduplication record exists for the given template, actor hash, and date bucket.
/// Deletes install deduplication rows created before `cutoff`, returning how many were removed.
///
/// Backs the `purge_install_dedup` recurring task. These rows are write-once and read only
/// within their daily bucket, so without a purge the table grows by one row per unique
/// installer per template per day forever.
pub async fn delete_install_dedup_before(
    db: &Database,
    cutoff: chrono::DateTime<chrono::Utc>,
) -> Result<u64, OrmError> {
    TemplateInstallDedup::objects()
        .filter(q!(created_at__lt = cutoff))?
        .delete(db)
        .await
}

pub async fn install_dedup_exists(
    db: &Database,
    template_id: i64,
    actor_hash: &str,
    date_bucket: &str,
) -> Result<bool, OrmError> {
    TemplateInstallDedup::objects()
        .filter(q!(template_id = template_id))?
        .filter(q!(actor_hash = actor_hash.to_owned()))?
        .filter(q!(date_bucket = date_bucket.to_owned()))?
        .exists(db)
        .await
}

/// Insert a new [`TemplateInstallDedup`] record.
pub async fn insert_install_dedup(
    db: &Database,
    dedup: TemplateInstallDedup,
) -> Result<TemplateInstallDedup, OrmError> {
    dedup.save(db).await
}

/// Checks if a verified installation record exists for a template and buyer organization.
pub async fn verified_install_exists(
    db: &Database,
    template_id: i64,
    buyer_organization_id: i64,
) -> Result<bool, OrmError> {
    TemplateInstall::objects()
        .filter(q!(template_id = template_id))?
        .filter(q!(buyer_organization_id = buyer_organization_id))?
        .exists(db)
        .await
}

/// Fetch a verified installation record for a template and buyer organization.
pub async fn verified_install_by_template_and_buyer_org(
    db: &Database,
    template_id: i64,
    buyer_organization_id: i64,
) -> Result<Option<TemplateInstall>, OrmError> {
    TemplateInstall::objects()
        .filter(q!(template_id = template_id))?
        .filter(q!(buyer_organization_id = buyer_organization_id))?
        .first(db)
        .await
}

/// Records an install as a single atomic unit: the deduplication row, the template counter,
/// the optional version counter, and the optional verified-install row.
///
/// These must commit together. The dedup row is what makes an install un-repeatable, so a
/// partial commit that stores it without moving the counters loses the install permanently —
/// the retry sees the dedup row, returns early, and the count never catches up.
///
/// # Why this bypasses the model helpers
///
/// The `Model` derive generates `save(&self, db: &Database)` and `update(&self, db: &Database)`,
/// both hardcoded to `&Database`. A transaction hands the closure a `&mut Conn`, which is not a
/// `&Database`, so neither helper can be called inside one. The `QuerySet` write paths
/// (`bulk_create`, `update`) are generic over `DbExecutor` and are the supported way to write
/// transactionally. This is a framework constraint, not a preference.
///
/// Counters use `SetExpr::FieldOp`, so the increment happens in the database. Reading the row
/// and writing back `count + 1` would drop increments whenever two installs race.
pub async fn record_install_atomically(
    db: &Database,
    dedup: TemplateInstallDedup,
    template_id: i64,
    version_id: Option<i64>,
    verified_install_actor: Option<(i64, i64)>,
) -> Result<(), OrmError> {
    use djangors_db::DbExecutor;
    use djangors_orm::expr::{ArithOp, SetExpr, Value};
    use djangors_orm::QuerySet;

    db.transaction_conn(|conn| {
        Box::pin(async move {
            QuerySet::<TemplateInstallDedup>::bulk_create(conn.conn(), &[dedup]).await?;

            let increment = || {
                vec![(
                    "install_count",
                    SetExpr::FieldOp {
                        field: "install_count",
                        op: ArithOp::Add,
                        operand: Value::I64(1),
                    },
                )]
            };

            Template::objects()
                .filter(q!(id = template_id))?
                .update(conn.conn(), increment())
                .await?;

            if let Some(ver_id) = version_id {
                TemplateVersion::objects()
                    .filter(q!(id = ver_id))?
                    .update(conn.conn(), increment())
                    .await?;
            }

            if let Some((buyer_org_id, user_id)) = verified_install_actor {
                // Checked inside the transaction so a concurrent install cannot slip a second
                // verified row past the check between here and the insert.
                let already = TemplateInstall::objects()
                    .filter(q!(template_id = template_id))?
                    .filter(q!(buyer_organization_id = buyer_org_id))?
                    .exists(conn.conn())
                    .await?;

                if !already {
                    let install = TemplateInstall {
                        id: 0,
                        public_id: uuid::Uuid::new_v4().to_string(),
                        template_id: djangors_orm::ForeignKey::new(template_id),
                        template_version_id: None,
                        buyer_organization_id: djangors_orm::ForeignKey::new(buyer_org_id),
                        installed_by_user_id: user_id,
                        created_at: chrono::Utc::now(),
                    };
                    QuerySet::<TemplateInstall>::bulk_create(conn.conn(), &[install]).await?;
                }
            }

            Ok::<(), OrmError>(())
        })
    })
    .await
    .map_err(|e| OrmError::InvalidQuery(e.to_string()))
}

/// Insert a new [`TemplateInstall`] record.
pub async fn insert_template_install(
    db: &Database,
    install: TemplateInstall,
) -> Result<TemplateInstall, OrmError> {
    install.save(db).await
}

// ---------------------------------------------------------------------------
// Cross-App Projections
// ---------------------------------------------------------------------------

/// Look up an organization summary by its internal primary key.
pub async fn organization_summary_by_id(
    db: &Database,
    org_id: i64,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let found = crate::apps::organizations::models::Organization::objects()
        .filter(q!(id = org_id))?
        .first(db)
        .await?;
    Ok(found.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
    }))
}

/// Look up a user profile public ID by internal auth user ID.
pub async fn user_public_id_by_id(db: &Database, user_id: i64) -> Result<Option<String>, OrmError> {
    let found = crate::apps::accounts::models::UserProfile::objects()
        .filter(q!(user_id = user_id))?
        .first(db)
        .await?;
    Ok(found.map(|p| p.public_id))
}

/// Look up multiple organization summaries by internal primary keys in one batch.
pub async fn organizations_by_ids(
    db: &Database,
    org_ids: &[i64],
) -> Result<std::collections::HashMap<i64, OrganizationSummary>, OrmError> {
    if org_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let orgs = crate::apps::organizations::models::Organization::objects()
        .filter(q!(id__in = org_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(orgs.len());
    for org in orgs {
        map.insert(
            org.id,
            OrganizationSummary {
                id: org.id,
                public_id: org.public_id,
            },
        );
    }
    Ok(map)
}

/// Look up multiple templates by internal primary keys in one batch.
pub async fn templates_by_ids(
    db: &Database,
    template_ids: &[i64],
) -> Result<std::collections::HashMap<i64, Template>, OrmError> {
    if template_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let templates = Template::objects()
        .filter(q!(id__in = template_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(templates.len());
    for t in templates {
        map.insert(t.id, t);
    }
    Ok(map)
}

/// Look up multiple template versions by internal primary keys in one batch.
pub async fn versions_by_ids(
    db: &Database,
    version_ids: &[i64],
) -> Result<std::collections::HashMap<i64, TemplateVersion>, OrmError> {
    if version_ids.is_empty() {
        return Ok(std::collections::HashMap::new());
    }
    let versions = TemplateVersion::objects()
        .filter(q!(id__in = version_ids.to_vec()))?
        .all(db)
        .await?;
    let mut map = std::collections::HashMap::with_capacity(versions.len());
    for v in versions {
        map.insert(v.id, v);
    }
    Ok(map)
}
