//! Database access and QuerySet operations for the `organizations` app.

use chrono::{DateTime, Utc};
use djangors_db::Database;
use djangors_orm::expr::IntoSetExpr;
use djangors_orm::{q, Model, OrmError};

use super::models::{Organization, OrganizationInvite, UserOrganizationMembership};

// =========================================================================
// Organization Queries
// =========================================================================

/// Fetch an `Organization` by its internal primary key.
pub async fn organization_by_id(db: &Database, id: i64) -> Result<Option<Organization>, OrmError> {
    Organization::objects().filter(q!(id = id))?.first(db).await
}

/// Fetch an `Organization` by its external public UUID identifier.
pub async fn organization_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<Organization>, OrmError> {
    Organization::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch an `Organization` by unique slug.
pub async fn organization_by_slug(
    db: &Database,
    slug: &str,
) -> Result<Option<Organization>, OrmError> {
    Organization::objects()
        .filter(q!(slug = slug.to_owned()))?
        .first(db)
        .await
}

/// Check if an organization with the given slug exists.
pub async fn organization_slug_exists(db: &Database, slug: &str) -> Result<bool, OrmError> {
    Organization::objects()
        .filter(q!(slug = slug.to_owned()))?
        .exists(db)
        .await
}

/// Insert a new `Organization`.
pub async fn insert_organization(
    db: &Database,
    org: Organization,
) -> Result<Organization, OrmError> {
    org.save(db).await
}

/// Update an existing `Organization`.
pub async fn update_organization(db: &Database, org: &Organization) -> Result<(), OrmError> {
    org.update(db).await
}

/// Delete an `Organization` by internal primary key.
pub async fn delete_organization_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    Organization::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}

// =========================================================================
// Membership Queries
// =========================================================================

/// Fetch a `UserOrganizationMembership` by internal primary key.
pub async fn membership_by_id(
    db: &Database,
    id: i64,
) -> Result<Option<UserOrganizationMembership>, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(id = id))?
        .first(db)
        .await
}

/// Fetch a `UserOrganizationMembership` by public UUID identifier.
pub async fn membership_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<UserOrganizationMembership>, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch a `UserOrganizationMembership` for a specific user and organization.
pub async fn membership_for_user_in_org(
    db: &Database,
    user_id: i64,
    organization_id: i64,
) -> Result<Option<UserOrganizationMembership>, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(user_id = user_id))?
        .filter(q!(organization_id = organization_id))?
        .first(db)
        .await
}

/// Fetch all memberships for a user.
pub async fn memberships_for_user(
    db: &Database,
    user_id: i64,
) -> Result<Vec<UserOrganizationMembership>, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(user_id = user_id))?
        .all(db)
        .await
}

/// Fetch all memberships in an organization.
pub async fn memberships_for_org(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<UserOrganizationMembership>, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// Count how many members hold the `owner` role in an organization.
pub async fn count_owners_in_org(db: &Database, organization_id: i64) -> Result<i64, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(organization_id = organization_id))?
        .filter(q!(role = "owner".to_string()))?
        .count(db)
        .await
}

/// Insert a new membership row.
pub async fn insert_membership(
    db: &Database,
    membership: UserOrganizationMembership,
) -> Result<UserOrganizationMembership, OrmError> {
    membership.save(db).await
}

/// Update a member's role by primary key.
pub async fn update_membership_role(db: &Database, id: i64, role: &str) -> Result<u64, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(id = id))?
        .update(
            db,
            vec![
                ("role", role.to_string().into_set_expr()),
                ("updated_at", Utc::now().into_set_expr()),
            ],
        )
        .await
}

/// Delete a membership by primary key.
pub async fn delete_membership_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    UserOrganizationMembership::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}

// =========================================================================
// Invite Queries
// =========================================================================

/// Fetch an `OrganizationInvite` by secret token.
pub async fn invite_by_token(
    db: &Database,
    token: &str,
) -> Result<Option<OrganizationInvite>, OrmError> {
    OrganizationInvite::objects()
        .filter(q!(token = token.to_owned()))?
        .first(db)
        .await
}

/// Fetch an `OrganizationInvite` by public UUID identifier.
pub async fn invite_by_public_id(
    db: &Database,
    public_id: &str,
) -> Result<Option<OrganizationInvite>, OrmError> {
    OrganizationInvite::objects()
        .filter(q!(public_id = public_id.to_owned()))?
        .first(db)
        .await
}

/// Fetch outstanding invites for an organization.
pub async fn invites_for_org(
    db: &Database,
    organization_id: i64,
) -> Result<Vec<OrganizationInvite>, OrmError> {
    OrganizationInvite::objects()
        .filter(q!(organization_id = organization_id))?
        .all(db)
        .await
}

/// Insert a new `OrganizationInvite`.
pub async fn insert_invite(
    db: &Database,
    invite: OrganizationInvite,
) -> Result<OrganizationInvite, OrmError> {
    invite.save(db).await
}

/// Mark an invite as accepted.
pub async fn update_invite_accepted(
    db: &Database,
    id: i64,
    accepted_at: DateTime<Utc>,
) -> Result<u64, OrmError> {
    OrganizationInvite::objects()
        .filter(q!(id = id))?
        .update(db, vec![("accepted_at", accepted_at.into_set_expr())])
        .await
}

/// Delete an invite by primary key.
pub async fn delete_invite_by_id(db: &Database, id: i64) -> Result<u64, OrmError> {
    OrganizationInvite::objects()
        .filter(q!(id = id))?
        .delete(db)
        .await
}
