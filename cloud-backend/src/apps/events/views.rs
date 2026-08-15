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
///
/// Uses `CursorPagination` because the event log is an append-heavy, unbounded stream
/// of system events where stable keyset pagination under concurrent inserts is required
/// and count queries over large datasets should be avoided.
pub async fn list_events(req: Request, _params: PathParams) -> Result<Response, DjangorsError> {
    require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let organization_id = current_organization_id(&req)?;
    let qs = EventLog::scope(&req, EventLog::objects())?;

    // CursorPagination strategy with default 100 rows clamped to max 100
    let pagination = djangors_rest::pagination::CursorPagination {
        page_size: djangors_rest::pagination::REST_PER_PAGE,
        max_page_size: Some(100),
    };
    // Deliberately no COUNT. CursorPagination::slice ignores `total` entirely, and the whole
    // point of keyset paging on an append-only log is to avoid scanning the organization's
    // full history on every request -- which is the scaling problem this endpoint had. Use
    // page_size, which the framework documents as the cursor path's size source.
    // Fully qualified: CursorPagination has both a `page_size` field and a `page_size` trait
    // method, and the field shadows the method on a plain call.
    let limit = djangors_rest::pagination::Pagination::page_size(&pagination, &req);

    let (events, next_cursor) = services::list_events_cursor(
        db,
        qs,
        &services::EventListFilters {
            event_type: req.query("event_type"),
            project_id: req.query("project_id"),
            app_id: req.query("app_id"),
        },
        organization_id,
        req.query("cursor"),
        limit,
    )
    .await
    .map_err(DjangorsError::from)?;

    let results: Vec<serde_json::Value> = events
        .into_iter()
        .map(|resp| serde_json::to_value(resp).unwrap_or(serde_json::Value::Null))
        .collect();

    // `count` is omitted rather than fabricated: computing it costs the scan this endpoint
    // exists to avoid, and inventing a number would be worse than not reporting one. This is
    // the conventional cursor-pagination response shape.
    Response::json(
        StatusCode::OK,
        &serde_json::json!({
            "results": results,
            "next_cursor": next_cursor,
            "previous_cursor": serde_json::Value::Null,
        }),
    )
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
