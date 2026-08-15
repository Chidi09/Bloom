//! Persistence models for the `organizations` domain app.

use chrono::{DateTime, Utc};
use djangors_macros::Model;

/// An organization defines the tenancy, billing, and membership boundary for Bloom Cloud.
#[derive(Model, Debug, Clone)]
#[djangors(app = "organizations", table_name = "organizations_organization")]
pub struct Organization {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Human-readable organization name.
    #[djangors(max_length = 255)]
    pub name: String,

    /// Unique URL-safe slug identifier.
    #[djangors(max_length = 64, unique)]
    pub slug: String,

    /// Subscription tier plan: `free`, `pro`, `enterprise`.
    #[djangors(max_length = 32, default = "free")]
    pub plan: String,

    /// Optional email address for billing notifications and invoices.
    #[djangors(max_length = 254, nullable)]
    pub billing_email: Option<String>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

/// Links a user (`auth_user.id`) to an organization with a specific role.
#[derive(Model, Debug, Clone)]
#[djangors(
    app = "organizations",
    table_name = "organizations_userorganizationmembership"
)]
pub struct UserOrganizationMembership {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key pointing to `auth_user.id`.
    #[djangors(db_index)]
    pub user_id: i64,

    /// Foreign key pointing to `organizations_organization.id`.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Membership role: `owner`, `admin`, `developer`, `release_manager`, `viewer`.
    #[djangors(max_length = 32)]
    pub role: String,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,

    /// Last update timestamp.
    #[djangors(auto_now)]
    pub updated_at: DateTime<Utc>,
}

/// Outstanding invitation for a user to join an organization.
#[derive(Model, Debug, Clone)]
#[djangors(app = "organizations", table_name = "organizations_organizationinvite")]
pub struct OrganizationInvite {
    /// Internal primary key.
    #[djangors(primary_key, auto)]
    pub id: i64,

    /// External public UUID identifier (v4).
    #[djangors(max_length = 36)]
    pub public_id: String,

    /// Foreign key pointing to `organizations_organization.id`.
    #[djangors(db_index)]
    pub organization_id: i64,

    /// Email address of the invited user.
    #[djangors(max_length = 254)]
    pub email: String,

    /// Assigned role upon accepting the invite.
    #[djangors(max_length = 32)]
    pub role: String,

    /// Cryptographic invitation token.
    #[djangors(max_length = 128, unique)]
    pub token: String,

    /// Expiration timestamp after which the invite cannot be accepted.
    pub expires_at: DateTime<Utc>,

    /// Timestamp when the invite was accepted, if applicable.
    #[djangors(nullable)]
    pub accepted_at: Option<DateTime<Utc>>,

    /// Creation timestamp.
    #[djangors(auto_now_add)]
    pub created_at: DateTime<Utc>,
}
