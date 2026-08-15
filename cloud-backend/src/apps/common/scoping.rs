//! Shared organization-scoping helper for Bloom Cloud models.

use djangors_core::error::DjangorsError;
use djangors_core::request::Request;
use djangors_core::StatusCode;
use djangors_orm::expr::{UnresolvedCompare, UnresolvedExpr, Value};
use djangors_orm::{FromRow, Model, QuerySet};

/// Marker inserted by [`OrganizationResolutionLayer`] when the organization lookup or membership
/// check failed due to a database/server error (not a lack of credentials or membership).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OrganizationResolutionFailed;

/// Filters `qs` to rows where `field` (e.g. `"organization_id"`) matches the current request's
/// resolved, membership-verified organization ID.
///
/// Reads [`crate::apps::accounts::CurrentOrganizationId`] from the request extensions.
/// Returns 403 with code `organization_required` when no organization is selected or resolved on the request.
pub fn organization_scope<M>(
    req: &Request,
    qs: QuerySet<M>,
    field: &str,
) -> Result<QuerySet<M>, DjangorsError>
where
    M: Model + FromRow,
{
    if req.ext::<OrganizationResolutionFailed>().is_some() {
        return Err(DjangorsError::Internal(
            "Organization resolution failed due to an internal error.".to_string(),
        ));
    }

    let org_id = req
        .ext::<crate::apps::accounts::CurrentOrganizationId>()
        .ok_or_else(|| {
            DjangorsError::api(
                StatusCode::FORBIDDEN,
                "organization_required",
                "No organization selected.",
            )
        })?
        .0;

    let static_field: &'static str = match field {
        "organization_id" => "organization_id",
        "organization" => "organization",
        other => Box::leak(other.to_string().into_boxed_str()),
    };

    qs.filter(UnresolvedExpr::And(vec![UnresolvedCompare {
        field: static_field,
        value: Value::I64(org_id),
    }]))
    .map_err(|e| DjangorsError::Internal(e.to_string()))
}
