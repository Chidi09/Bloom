//! Serialization adapters for the `organizations` app.

use super::contracts::{InviteResponse, MembershipResponse, OrganizationResponse};
use super::models::{Organization, OrganizationInvite, UserOrganizationMembership};

/// Serializes an [`Organization`] entity with the caller's membership role.
pub fn serialize_organization(org: &Organization, role: &str) -> OrganizationResponse {
    OrganizationResponse {
        id: org.public_id.clone(),
        name: org.name.clone(),
        slug: org.slug.clone(),
        plan: org.plan.clone(),
        role: role.to_string(),
        created_at: org.created_at.to_rfc3339(),
    }
}

/// Serializes a [`UserOrganizationMembership`] entity along with associated user info.
pub fn serialize_membership(
    membership: &UserOrganizationMembership,
    user_public_id: &str,
    email: &str,
    username: &str,
) -> MembershipResponse {
    MembershipResponse {
        id: membership.public_id.clone(),
        user_id: user_public_id.to_string(),
        email: email.to_string(),
        username: username.to_string(),
        role: membership.role.clone(),
        created_at: membership.created_at.to_rfc3339(),
    }
}

/// Serializes an [`OrganizationInvite`] entity for API responses.
pub fn serialize_invite(invite: &OrganizationInvite) -> InviteResponse {
    InviteResponse {
        id: invite.public_id.clone(),
        email: invite.email.clone(),
        role: invite.role.clone(),
        token: invite.token.clone(),
        expires_at: invite.expires_at.to_rfc3339(),
        created_at: invite.created_at.to_rfc3339(),
    }
}
