//! Request-extraction helpers shared by every domain app's view layer.
//!
//! Each app previously carried its own byte-identical copies of these two functions. They are
//! about the request envelope rather than any one domain, so they live here once: a change to
//! how the active organization is resolved, or to the error a missing one produces, should not
//! need fifteen edits to take effect uniformly.

use djangors_core::{DjangorsError, Request, StatusCode};
use djangors_db::Database;

use crate::apps::accounts::permissions::CurrentOrganizationId;

/// Retrieve the database handle from request state.
pub fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Retrieve the active organization ID from request extensions.
///
/// The extension is set by the organization-resolution layer. Its absence means the caller
/// never selected an organization, which is a 403 rather than a 404: the route exists, but
/// nothing about it can be answered without knowing the tenant.
pub fn get_org_id(req: &Request) -> Result<i64, DjangorsError> {
    req.ext::<CurrentOrganizationId>()
        .map(|ext| ext.0)
        .ok_or_else(|| {
            DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            )
        })
}
