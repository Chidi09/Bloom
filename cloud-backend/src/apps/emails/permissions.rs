//! Role-based permissions and authorization policies for the `emails` app.

use djangors_auth::User;

pub use crate::apps::accounts::permissions::{require_authenticated, CurrentOrganizationId};
pub use crate::apps::organizations::permissions::{
    CurrentOrganizationPublicId, CurrentOrganizationRole, OrganizationPermission, OrganizationRole,
};

use super::errors::EmailsError;

/// Verify that the authenticated user possesses staff or superuser privileges.
pub fn require_staff(user: &User) -> Result<(), EmailsError> {
    if user.is_staff || user.is_superuser {
        Ok(())
    } else {
        Err(EmailsError::StaffRequired)
    }
}
