//! Role-based permissions, organization context, and authorization policies for `webhosting`.

pub use crate::apps::accounts::permissions::{require_authenticated, CurrentOrganizationId};
pub use crate::apps::organizations::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};
