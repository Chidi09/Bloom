//! HTTP view handlers for the `events` domain app.

use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_orm::Model;
use djangors_rest::Scoped;

use super::errors::EventError;
use super::models::EventLog;
use super::permissions::CurrentOrganizationId;
use super::services;
use crate::apps::accounts::permissions::require_authenticated;

/// Retrieve the database handle from request state.
fn get_db(req: &Request) -> Result<&Database, DjangorsError> {
    req.require_state::<Database>()
}

/// Resolve the active organization's internal id from the request extensions.
fn current_organization_id(req: &Request) -> Result<i64, DjangorsError> {
    req.ext::<CurrentOrganizationId>()
        .map(|ext| ext.0)
        .ok_or_else(|| EventError::OrganizationRequired.into())
}

/// GET `/api/v1/events` — List events in the active organization, newest first.
///
/// Filterable with `event_type`, `project_id`, and `app_id` query params
/// (`project_id` and `app_id` are public UUIDs).
pub async fn list_events(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let organization_id = current_organization_id(&req)?;
    let qs = EventLog::scope(&req, EventLog::objects())?;

    let responses = services::list_events(
        db,
        qs,
        req.query("event_type"),
        req.query("project_id"),
        req.query("app_id"),
        organization_id,
    )
    .await
    .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &responses)
}

/// GET `/api/v1/events/{id}` — Retrieve a single event by public UUID.
pub async fn retrieve_event(req: Request, params: PathParams) -> Result<Response, DjangorsError> {
    require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let organization_id = current_organization_id(&req)?;
    let qs = EventLog::scope(&req, EventLog::objects())?;

    let event_id = params
        .get("id")
        .ok_or(EventError::ValidationError("Missing event id".to_string()))?;

    let response = services::get_event(db, qs, event_id, organization_id)
        .await
        .map_err(DjangorsError::from)?;

    Response::json(StatusCode::OK, &response)
}
