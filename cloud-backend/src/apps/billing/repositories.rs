//! Database queries and QuerySets for the `billing` domain app.

use chrono::{DateTime, Utc};
use djangors_db::Database;
use djangors_orm::{q, Model, OrmError};

use super::models::{Invoice, Plan, Subscription, UsageRecord};

// ---------------------------------------------------------------------------
// Plan queries
// ---------------------------------------------------------------------------

/// Fetch a `Plan` by its internal primary key.
pub async fn plan_by_id(db: &Database, id: i64) -> Result<Option<Plan>, OrmError> {
    Plan::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Plan` by its external public UUID.
pub async fn plan_by_public_id(db: &Database, public_id: &str) -> Result<Option<Plan>, OrmError> {
    Plan::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `Plan` by tier name (e.g. `free`, `pro`, `enterprise`).
pub async fn plan_by_name(db: &Database, name: &str) -> Result<Option<Plan>, OrmError> {
    Plan::objects()
        .filter(q!(name = name.to_owned()))?
        .first(db)
        .await
}

/// List all active plans available for subscription.
pub async fn active_plans(db: &Database) -> Result<Vec<Plan>, OrmError> {
    Plan::objects()
        .filter(q!(active = true))?
        .order_by("id")?
        .all(db)
        .await
}

/// Insert a new `Plan` record.
pub async fn insert_plan(db: &Database, plan: Plan) -> Result<Plan, OrmError> {
    plan.save(db).await
}

/// Update an existing `Plan` record.
pub async fn update_plan(db: &Database, plan: &Plan) -> Result<(), OrmError> {
    plan.update(db).await
}

// ---------------------------------------------------------------------------
// Subscription queries
// ---------------------------------------------------------------------------

/// Fetch a `Subscription` by internal primary key.
pub async fn subscription_by_id(db: &Database, id: i64) -> Result<Option<Subscription>, OrmError> {
    Subscription::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch a `Subscription` by external public UUID.
pub async fn subscription_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Subscription>, OrmError> {
    Subscription::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch the active 1:1 `Subscription` for an organization.
pub async fn subscription_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Option<Subscription>, OrmError> {
    Subscription::objects()
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch a subscription by its generic provider customer reference.
pub async fn subscription_by_provider_customer_id(
    db: &Database,
    customer_id: &str,
) -> Result<Option<Subscription>, OrmError> {
    Subscription::objects()
        .filter(q!(stripe_customer_id = customer_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a subscription by its generic provider subscription/transaction reference.
pub async fn subscription_by_provider_subscription_id(
    db: &Database,
    sub_id: &str,
) -> Result<Option<Subscription>, OrmError> {
    Subscription::objects()
        .filter(q!(stripe_subscription_id = sub_id.to_owned()))?
        .first(db)
        .await
}

/// Insert a new `Subscription` record.
pub async fn insert_subscription(
    db: &Database,
    sub: Subscription,
) -> Result<Subscription, OrmError> {
    sub.save(db).await
}

/// Update an existing `Subscription` record.
pub async fn update_subscription(db: &Database, sub: &Subscription) -> Result<(), OrmError> {
    sub.update(db).await
}

// ---------------------------------------------------------------------------
// UsageRecord queries
// ---------------------------------------------------------------------------

/// Insert a new `UsageRecord`.
pub async fn insert_usage_record(
    db: &Database,
    record: UsageRecord,
) -> Result<UsageRecord, OrmError> {
    record.save(db).await
}

/// List usage records for an organization and metric, newest first.
pub async fn usage_records_for_org(
    db: &Database,
    organization_id: i64,
    metric: &str,
) -> Result<Vec<UsageRecord>, OrmError> {
    UsageRecord::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(metric = metric.to_owned()))?
        .order_by("-recorded_at")?
        .all(db)
        .await
}

/// Sum metric values for an organization recorded on or after a given timestamp.
pub async fn total_usage_for_org_metric_since(
    db: &Database,
    organization_id: i64,
    metric: &str,
    since: DateTime<Utc>,
) -> Result<i64, OrmError> {
    let records = UsageRecord::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(metric = metric.to_owned()))?
        .filter(q!(recorded_at__gte = since))?
        .all(db)
        .await?;

    let sum = records
        .iter()
        .map(|r| r.value)
        .fold(0_i64, |acc, v| acc.saturating_add(v));
    Ok(sum)
}

// ---------------------------------------------------------------------------
// Invoice queries
// ---------------------------------------------------------------------------

/// Fetch an `Invoice` by its internal primary key.
pub async fn invoice_by_id(db: &Database, id: i64) -> Result<Option<Invoice>, OrmError> {
    Invoice::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch an `Invoice` by its external public UUID.
pub async fn invoice_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Invoice>, OrmError> {
    Invoice::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch an `Invoice` by public UUID within a specific organization.
pub async fn invoice_by_public_id_and_org(
    db: &Database,
    public_id: &str,
    organization_id: i64,
) -> Result<Option<Invoice>, OrmError> {
    Invoice::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch an invoice by its generic provider invoice reference.
pub async fn invoice_by_provider_invoice_id(
    db: &Database,
    provider_invoice_id: &str,
) -> Result<Option<Invoice>, OrmError> {
    Invoice::objects()
        .filter(q!(stripe_invoice_id = provider_invoice_id.to_owned()))?
        .first(db)
        .await
}

/// List all invoices for an organization, newest first.
pub async fn invoices_for_organization(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<Invoice>, OrmError> {
    Invoice::objects()
        .filter(q!(organization_id = organization_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// List all invoices for a specific subscription.
pub async fn invoices_for_subscription(
    db: &Database,
    subscription_id: i64,
) -> Result<Vec<Invoice>, OrmError> {
    Invoice::objects()
        .filter(q!(subscription_id = subscription_id))?
        .order_by("-created_at")?
        .all(db)
        .await
}

/// Insert a new `Invoice` record.
pub async fn insert_invoice(db: &Database, invoice: Invoice) -> Result<Invoice, OrmError> {
    invoice.save(db).await
}

/// Update an existing `Invoice` record.
pub async fn update_invoice(db: &Database, invoice: &Invoice) -> Result<(), OrmError> {
    invoice.update(db).await
}

// ---------------------------------------------------------------------------
// External entity summaries (Organizations & Users) via public ORM models
// ---------------------------------------------------------------------------

/// Projected summary for an organization entity from the `organizations` app.
#[derive(Debug, Clone)]
pub struct OrganizationSummary {
    /// Internal primary key.
    pub id: i64,
    /// External public UUID.
    pub public_id: String,
    /// Organization name.
    pub name: String,
}

/// Look up an organization summary by its internal primary key.
pub async fn organization_summary_by_id(
    db: &Database,
    organization_id: i64,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let found = crate::apps::organizations::models::Organization::objects()
        .filter(q!(id = organization_id))?
        .first(db)
        .await?;
    Ok(found.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
        name: o.name,
    }))
}

/// Look up an organization summary by its external public UUID.
pub async fn organization_summary_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<OrganizationSummary>, OrmError> {
    let found = crate::apps::organizations::models::Organization::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await?;
    Ok(found.map(|o| OrganizationSummary {
        id: o.id,
        public_id: o.public_id,
        name: o.name,
    }))
}

/// Projected summary for a user entity from the `accounts` app.
#[derive(Debug, Clone)]
pub struct UserSummary {
    /// Internal primary key.
    pub id: i64,
    /// User email address.
    pub email: String,
}

/// Look up a user summary by internal primary key.
pub async fn user_summary_by_id(
    db: &Database,
    user_id: i64,
) -> Result<Option<UserSummary>, OrmError> {
    // The email lives on djangors_auth::User (table `auth_user`), not on the accounts app's
    // UserProfile, which carries only profile fields.
    let found = djangors_auth::User::objects()
        .filter(q!(id = user_id))?
        .first(db)
        .await?;
    Ok(found.map(|u| UserSummary {
        id: u.id,
        email: u.email,
    }))
}
