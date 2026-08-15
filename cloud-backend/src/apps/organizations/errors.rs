//! Application errors and HTTP status mappings for the `organizations` app.

use djangors_core::{DjangorsError, StatusCode};

/// Domain error conditions that can arise during organization operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OrganizationError {
    /// Organization name is already in use or taken.
    NameTaken,
    /// Organization slug is already in use.
    SlugTaken,
    /// Organization was not found by public ID or slug.
    OrganizationNotFound,
    /// Membership record was not found for user and organization.
    MembershipNotFound,
    /// User is already a member of the organization.
    AlreadyMember,
    /// Invite token does not exist.
    InviteNotFound,
    /// Invite token has expired or has already been accepted.
    InviteExpired,
    /// Operation would leave the organization without any owner.
    CannotRemoveLastOwner,
    /// Cannot delete organization because it still contains active projects or resources.
    OrganizationNotEmpty,
    /// Caller lacks the necessary role for this operation.
    InsufficientRole,
    /// Specified role string is invalid.
    InvalidRole,
    /// Request validation failed.
    ValidationError(String),
    /// Caller is unauthenticated.
    Unauthorized,
    /// Caller is forbidden from performing this action.
    Forbidden,
    /// Underlying database error.
    Database(String),
}

impl std::fmt::Display for OrganizationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NameTaken => write!(f, "An organization with this name already exists."),
            Self::SlugTaken => write!(f, "An organization with this slug already exists."),
            Self::OrganizationNotFound => write!(f, "Organization was not found."),
            Self::MembershipNotFound => write!(f, "Membership was not found."),
            Self::AlreadyMember => write!(f, "User is already a member of this organization."),
            Self::InviteNotFound => write!(f, "Invitation was not found."),
            Self::InviteExpired => write!(f, "Invitation has expired or has already been used."),
            Self::CannotRemoveLastOwner => {
                write!(
                    f,
                    "Cannot remove or demote the last owner of an organization."
                )
            }
            Self::OrganizationNotEmpty => {
                write!(
                    f,
                    "Cannot delete organization containing active projects or apps."
                )
            }
            Self::InsufficientRole => {
                write!(
                    f,
                    "You do not have sufficient permissions to perform this action."
                )
            }
            Self::InvalidRole => write!(f, "Invalid organization role specified."),
            Self::ValidationError(msg) => write!(f, "Validation error: {msg}"),
            Self::Unauthorized => write!(
                f,
                "Authentication credentials were not provided or are invalid."
            ),
            Self::Forbidden => write!(f, "You do not have permission to access this resource."),
            Self::Database(msg) => write!(f, "Database error: {msg}"),
        }
    }
}

impl std::error::Error for OrganizationError {}

impl From<OrganizationError> for DjangorsError {
    fn from(error: OrganizationError) -> Self {
        match error {
            OrganizationError::NameTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "name_taken",
                "An organization with this name already exists.",
            ),
            OrganizationError::SlugTaken => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "slug_taken",
                "An organization with this slug already exists.",
            ),
            OrganizationError::OrganizationNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "organization_not_found",
                "Organization was not found.",
            ),
            OrganizationError::MembershipNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "membership_not_found",
                "Membership was not found.",
            ),
            OrganizationError::AlreadyMember => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "already_member",
                "User is already a member of this organization.",
            ),
            OrganizationError::InviteNotFound => DjangorsError::api(
                StatusCode::NOT_FOUND,
                "invite_not_found",
                "Invitation was not found.",
            ),
            OrganizationError::InviteExpired => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invite_expired",
                "Invitation has expired or has already been used.",
            ),
            OrganizationError::CannotRemoveLastOwner => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "cannot_remove_last_owner",
                "Cannot remove or demote the last owner of an organization.",
            ),
            OrganizationError::OrganizationNotEmpty => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "organization_not_empty",
                "Cannot delete organization containing active projects or apps.",
            ),
            OrganizationError::InsufficientRole => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "insufficient_role",
                "You do not have sufficient permissions to perform this action.",
            ),
            OrganizationError::InvalidRole => DjangorsError::api(
                StatusCode::BAD_REQUEST,
                "invalid_role",
                "Invalid organization role specified.",
            ),
            OrganizationError::ValidationError(msg) => {
                DjangorsError::api(StatusCode::BAD_REQUEST, "validation_error", msg)
            }
            OrganizationError::Unauthorized => DjangorsError::api(
                StatusCode::UNAUTHORIZED,
                "invalid_credentials",
                "Authentication credentials were not provided or are invalid.",
            ),
            OrganizationError::Forbidden => DjangorsError::api(
                StatusCode::FORBIDDEN,
                "permission_denied",
                "You do not have permission to perform this action.",
            ),
            OrganizationError::Database(msg) => {
                DjangorsError::api(StatusCode::INTERNAL_SERVER_ERROR, "database_error", msg)
            }
        }
    }
}

impl From<djangors_orm::OrmError> for OrganizationError {
    fn from(err: djangors_orm::OrmError) -> Self {
        OrganizationError::Database(err.to_string())
    }
}
