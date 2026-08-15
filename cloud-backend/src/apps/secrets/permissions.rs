//! Role permissions and authorization helpers for the `secrets` domain app.

pub use crate::apps::accounts::permissions::require_authenticated;
pub use crate::apps::accounts::CurrentOrganizationId;
pub use crate::apps::organizations::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};
