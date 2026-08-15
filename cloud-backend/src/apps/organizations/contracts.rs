//! Request and response data contracts for the `organizations` app.

use serde::{Deserialize, Serialize};

/// Payload to create a new organization.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct OrganizationCreateRequest {
    /// Desired name for the organization.
    pub name: String,
}

/// Payload for partial update of an organization.
#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
#[serde(default)]
pub struct OrganizationUpdateRequest {
    /// Optional updated name.
    pub name: Option<String>,
    /// Optional updated billing email address.
    pub billing_email: Option<String>,
}

/// Organization details serialized for API responses.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OrganizationResponse {
    /// Public UUID identifier.
    pub id: String,
    /// Organization display name.
    pub name: String,
    /// URL-safe slug.
    pub slug: String,
    /// Plan tier.
    pub plan: String,
    /// Requesting user's membership role in this organization.
    pub role: String,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}

/// Membership representation returned in membership lists.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MembershipResponse {
    /// Public UUID identifier for the membership row.
    pub id: String,
    /// Public UUID identifier for the member user.
    pub user_id: String,
    /// User's email address.
    pub email: String,
    /// User's unique username.
    pub username: String,
    /// Assigned role in this organization.
    pub role: String,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}

/// Payload to invite a new member to an organization.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct InviteRequest {
    /// Email of the user to invite.
    pub email: String,
    /// Desired role for the invitee (`owner`, `admin`, `developer`, `release_manager`, `viewer`).
    pub role: String,
}

/// Outbound invitation representation.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InviteResponse {
    /// Public UUID identifier of the invitation.
    pub id: String,
    /// Invitee email address.
    pub email: String,
    /// Assigned role upon accepting.
    pub role: String,
    /// Secret invitation token.
    pub token: String,
    /// ISO-8601 expiration timestamp.
    pub expires_at: String,
    /// ISO-8601 creation timestamp.
    pub created_at: String,
}

/// Payload to accept an outstanding invitation.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct AcceptInviteRequest {
    /// Secret invitation token.
    pub token: String,
}

/// Payload to change a member's role.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct ChangeRoleRequest {
    /// Target role to set.
    pub role: String,
}
