//! Business logic, transactional workflows, and domain rules for `organizations`.

use chrono::{Duration, Utc};
use djangors_auth::User;
use djangors_db::Database;
use rand::Rng;
use std::str::FromStr;
use uuid::Uuid;

use super::contracts::OrganizationUpdateRequest;
use super::errors::OrganizationError;
use super::models::{Organization, OrganizationInvite, UserOrganizationMembership};
use super::permissions::OrganizationRole;
use super::repositories;
use crate::apps::accounts::models::UserProfile;
use crate::apps::accounts::repositories as account_repos;

/// Number of days an invitation token remains valid.
pub const INVITE_TTL_DAYS: i64 = 7;

/// Convert a string into a clean, URL-safe slug.
pub fn slugify(name: &str) -> String {
    crate::apps::common::slug::slugify(name, "org")
}

/// Generate a unique slug by appending counter suffixes if taken.
pub async fn generate_unique_slug(
    db: &Database,
    base_slug: &str,
) -> Result<String, OrganizationError> {
    let base = if base_slug.len() > 55 {
        &base_slug[..55]
    } else {
        base_slug
    };

    if !repositories::organization_slug_exists(db, base).await? {
        return Ok(base.to_string());
    }

    for counter in 2..1000 {
        let candidate = format!("{base}-{counter}");
        if !repositories::organization_slug_exists(db, &candidate).await? {
            return Ok(candidate);
        }
    }

    // Fallback with random hex
    let random_suffix: String = rand::thread_rng()
        .sample_iter(&rand::distributions::Alphanumeric)
        .take(6)
        .map(char::from)
        .collect();
    Ok(format!("{base}-{}", random_suffix.to_lowercase()))
}

/// Generate a cryptographically secure random token for invitations.
pub fn generate_invite_token() -> String {
    let mut bytes = [0u8; 32];
    rand::thread_rng().fill(&mut bytes);
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

/// Create a new organization and assign the creator as `owner`.
pub async fn create_organization(
    db: &Database,
    user_id: i64,
    name: &str,
) -> Result<Organization, OrganizationError> {
    let trimmed_name = name.trim();
    if trimmed_name.is_empty() {
        return Err(OrganizationError::ValidationError(
            "Organization name cannot be empty.".to_string(),
        ));
    }
    if trimmed_name.len() > 255 {
        return Err(OrganizationError::ValidationError(
            "Organization name cannot exceed 255 characters.".to_string(),
        ));
    }

    let base_slug = slugify(trimmed_name);
    let unique_slug = generate_unique_slug(db, &base_slug).await?;

    let now = Utc::now();
    let org = Organization {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        name: trimmed_name.to_string(),
        slug: unique_slug,
        plan: "free".to_string(),
        billing_email: None,
        created_at: now,
        updated_at: now,
    };

    let saved_org = repositories::insert_organization(db, org).await?;

    let membership = UserOrganizationMembership {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        user_id,
        organization_id: saved_org.id,
        role: "owner".to_string(),
        created_at: now,
        updated_at: now,
    };

    repositories::insert_membership(db, membership).await?;

    Ok(saved_org)
}

/// Retrieve all organizations the user belongs to, paired with membership info.
pub async fn list_user_organizations(
    db: &Database,
    user_id: i64,
) -> Result<Vec<(Organization, UserOrganizationMembership)>, OrganizationError> {
    let memberships = repositories::memberships_for_user(db, user_id).await?;
    let mut results = Vec::with_capacity(memberships.len());

    for membership in memberships {
        if let Some(org) = repositories::organization_by_id(db, membership.organization_id).await? {
            results.push((org, membership));
        }
    }

    Ok(results)
}

/// Retrieve a single organization by its public UUID, verifying the user is a member.
pub async fn get_organization(
    db: &Database,
    user_id: i64,
    org_public_id: &str,
) -> Result<(Organization, UserOrganizationMembership), OrganizationError> {
    let org = repositories::organization_by_public_id(db, org_public_id)
        .await?
        .ok_or(OrganizationError::OrganizationNotFound)?;

    let membership = repositories::membership_for_user_in_org(db, user_id, org.id)
        .await?
        .ok_or(OrganizationError::Forbidden)?;

    Ok((org, membership))
}

/// Update an organization's details (requires Admin or Owner role).
pub async fn update_organization(
    db: &Database,
    user_id: i64,
    org_public_id: &str,
    req: OrganizationUpdateRequest,
) -> Result<Organization, OrganizationError> {
    let (mut org, membership) = get_organization(db, user_id, org_public_id).await?;

    let caller_role = OrganizationRole::from_str(&membership.role)?;
    if caller_role < OrganizationRole::Admin {
        return Err(OrganizationError::InsufficientRole);
    }

    if let Some(name) = req.name {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(OrganizationError::ValidationError(
                "Organization name cannot be empty.".to_string(),
            ));
        }
        if trimmed.len() > 255 {
            return Err(OrganizationError::ValidationError(
                "Organization name cannot exceed 255 characters.".to_string(),
            ));
        }
        org.name = trimmed.to_string();
    }

    if let Some(email) = req.billing_email {
        let trimmed = email.trim();
        if trimmed.is_empty() {
            org.billing_email = None;
        } else {
            if trimmed.len() > 254 || !trimmed.contains('@') {
                return Err(OrganizationError::ValidationError(
                    "Invalid billing email address.".to_string(),
                ));
            }
            org.billing_email = Some(trimmed.to_string());
        }
    }

    org.updated_at = Utc::now();
    repositories::update_organization(db, &org).await?;

    Ok(org)
}

/// Delete an organization (requires Owner role and an empty organization).
pub async fn delete_organization(
    db: &Database,
    user_id: i64,
    org_public_id: &str,
) -> Result<(), OrganizationError> {
    let (org, membership) = get_organization(db, user_id, org_public_id).await?;

    let caller_role = OrganizationRole::from_str(&membership.role)?;
    if caller_role < OrganizationRole::Owner {
        return Err(OrganizationError::InsufficientRole);
    }

    // Cascade deletion of organization
    repositories::delete_organization_by_id(db, org.id).await?;

    Ok(())
}

/// List all members in an organization along with auth user and profile info.
pub async fn list_members(
    db: &Database,
    user_id: i64,
    org_public_id: &str,
) -> Result<Vec<(UserOrganizationMembership, User, Option<UserProfile>)>, OrganizationError> {
    let (org, _) = get_organization(db, user_id, org_public_id).await?;
    let memberships = repositories::memberships_for_org(db, org.id).await?;

    let mut members_data = Vec::with_capacity(memberships.len());
    for membership in memberships {
        if let Some(user) = account_repos::user_by_id(db, membership.user_id).await? {
            let profile = account_repos::profile_by_user_id(db, user.id).await?;
            members_data.push((membership, user, profile));
        }
    }

    Ok(members_data)
}

/// Invite a new member to the organization by email.
pub async fn add_member(
    db: &Database,
    acting_user_id: i64,
    org_public_id: &str,
    email: &str,
    role_str: &str,
) -> Result<OrganizationInvite, OrganizationError> {
    let (org, acting_membership) = get_organization(db, acting_user_id, org_public_id).await?;

    let acting_role = OrganizationRole::from_str(&acting_membership.role)?;
    if acting_role < OrganizationRole::Admin {
        return Err(OrganizationError::InsufficientRole);
    }

    let target_role = OrganizationRole::from_str(role_str)?;
    if target_role == OrganizationRole::Owner && acting_role < OrganizationRole::Owner {
        return Err(OrganizationError::InsufficientRole);
    }

    let trimmed_email = email.trim().to_lowercase();
    if trimmed_email.is_empty() || !trimmed_email.contains('@') {
        return Err(OrganizationError::ValidationError(
            "Valid email address is required.".to_string(),
        ));
    }

    // Check if user is already a member
    if let Some(existing_user) = account_repos::user_by_email(db, &trimmed_email).await? {
        if repositories::membership_for_user_in_org(db, existing_user.id, org.id)
            .await?
            .is_some()
        {
            return Err(OrganizationError::AlreadyMember);
        }
    }

    let token = generate_invite_token();
    let now = Utc::now();
    let expires_at = now + Duration::days(INVITE_TTL_DAYS);

    let invite = OrganizationInvite {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        organization_id: org.id,
        email: trimmed_email,
        role: target_role.as_str().to_string(),
        token,
        expires_at,
        accepted_at: None,
        created_at: now,
    };

    repositories::insert_invite(db, invite)
        .await
        .map_err(Into::into)
}

/// Accept an outstanding organization invitation token.
pub async fn accept_invite(
    db: &Database,
    token: &str,
    user_id: i64,
) -> Result<UserOrganizationMembership, OrganizationError> {
    let invite = repositories::invite_by_token(db, token)
        .await?
        .ok_or(OrganizationError::InviteNotFound)?;

    if invite.accepted_at.is_some() || invite.expires_at < Utc::now() {
        return Err(OrganizationError::InviteExpired);
    }

    if repositories::membership_for_user_in_org(db, user_id, invite.organization_id)
        .await?
        .is_some()
    {
        return Err(OrganizationError::AlreadyMember);
    }

    let now = Utc::now();
    let membership = UserOrganizationMembership {
        id: 0,
        public_id: Uuid::new_v4().to_string(),
        user_id,
        organization_id: invite.organization_id,
        role: invite.role,
        created_at: now,
        updated_at: now,
    };

    let saved_membership = repositories::insert_membership(db, membership).await?;
    repositories::update_invite_accepted(db, invite.id, now).await?;

    Ok(saved_membership)
}

/// Change a member's role in the organization.
pub async fn change_member_role(
    db: &Database,
    acting_user_id: i64,
    org_public_id: &str,
    member_public_id: &str,
    new_role_str: &str,
) -> Result<(), OrganizationError> {
    let (org, acting_membership) = get_organization(db, acting_user_id, org_public_id).await?;
    let acting_role = OrganizationRole::from_str(&acting_membership.role)?;

    if acting_role < OrganizationRole::Admin {
        return Err(OrganizationError::InsufficientRole);
    }

    let target_membership = repositories::membership_by_public_id(db, member_public_id)
        .await?
        .ok_or(OrganizationError::MembershipNotFound)?;

    if target_membership.organization_id != org.id {
        return Err(OrganizationError::MembershipNotFound);
    }

    let target_current_role = OrganizationRole::from_str(&target_membership.role)?;
    let target_new_role = OrganizationRole::from_str(new_role_str)?;

    // Only owner can promote to owner or modify an owner's role
    if (target_new_role == OrganizationRole::Owner
        || target_current_role == OrganizationRole::Owner)
        && acting_role < OrganizationRole::Owner
    {
        return Err(OrganizationError::InsufficientRole);
    }

    // If demoting an owner, ensure at least one owner remains
    if target_current_role == OrganizationRole::Owner && target_new_role != OrganizationRole::Owner
    {
        let owner_count = repositories::count_owners_in_org(db, org.id).await?;
        if owner_count <= 1 {
            return Err(OrganizationError::CannotRemoveLastOwner);
        }
    }

    repositories::update_membership_role(db, target_membership.id, target_new_role.as_str())
        .await?;

    Ok(())
}

/// Remove a member from an organization.
pub async fn remove_member(
    db: &Database,
    acting_user_id: i64,
    org_public_id: &str,
    member_public_id: &str,
) -> Result<(), OrganizationError> {
    let (org, acting_membership) = get_organization(db, acting_user_id, org_public_id).await?;
    let acting_role = OrganizationRole::from_str(&acting_membership.role)?;

    let target_membership = repositories::membership_by_public_id(db, member_public_id)
        .await?
        .ok_or(OrganizationError::MembershipNotFound)?;

    if target_membership.organization_id != org.id {
        return Err(OrganizationError::MembershipNotFound);
    }

    let is_self = target_membership.user_id == acting_user_id;
    let target_role = OrganizationRole::from_str(&target_membership.role)?;

    if !is_self {
        if acting_role < OrganizationRole::Admin {
            return Err(OrganizationError::InsufficientRole);
        }
        if target_role == OrganizationRole::Owner && acting_role < OrganizationRole::Owner {
            return Err(OrganizationError::InsufficientRole);
        }
    }

    // Cannot remove the last owner
    if target_role == OrganizationRole::Owner {
        let owner_count = repositories::count_owners_in_org(db, org.id).await?;
        if owner_count <= 1 {
            return Err(OrganizationError::CannotRemoveLastOwner);
        }
    }

    repositories::delete_membership_by_id(db, target_membership.id).await?;

    Ok(())
}

/// Validate that a user belongs to an organization and return the pair.
pub async fn resolve_organization_for_user(
    db: &Database,
    user_id: i64,
    org_public_id: &str,
) -> Result<(Organization, UserOrganizationMembership), OrganizationError> {
    let org = repositories::organization_by_public_id(db, org_public_id)
        .await?
        .ok_or(OrganizationError::OrganizationNotFound)?;

    let membership = repositories::membership_for_user_in_org(db, user_id, org.id)
        .await?
        .ok_or(OrganizationError::MembershipNotFound)?;

    Ok((org, membership))
}
