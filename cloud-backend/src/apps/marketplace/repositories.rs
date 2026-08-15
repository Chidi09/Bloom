//! Database queries and persistence operations for the `marketplace` app.

use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{SellerAccount, Template, TemplatePurchase, TemplateVersion};

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
