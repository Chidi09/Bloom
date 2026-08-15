//! HTTP view handlers for the `events` domain app.

use djangors_core::{DjangorsError, PathParams, Request, Response, StatusCode};
use djangors_db::Database;
use djangors_orm::Model;
use djangors_rest::Scoped;

use super::errors::EventError;
use super::models::EventLog;
use super::permissions::CurrentOrganizationId;
use super::repositories;
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

/// Interval between heartbeat frames on an idle event stream.
///
/// Reverse proxies close idle upstream connections well before this: nginx defaults
/// `proxy_read_timeout` to 60s and AWS ALB defaults its idle timeout to 60s. Emitting every
/// 25s keeps at least two frames inside the tightest of those windows, so a single dropped
/// frame does not cost the connection.
const HEARTBEAT_INTERVAL_SECS: u64 = 25;

/// GET `/api/v1/events/stream` — Live event stream for the active organization (SSE).
///
/// # Delivery semantics
///
/// This is a **liveness** channel, not a durable log. It is backed by Redis pub/sub, which is
/// fire-and-forget: events published while a client is disconnected are never replayed, and
/// there is no acknowledgement. A client that needs completeness must reconcile against
/// `GET /events`, which reads the durable table. Do not treat this stream as a system of
/// record.
///
/// Each frame carries the same JSON shape `GET /events` returns, so one parsed type serves
/// both. Heartbeat frames carry `"event_type": "heartbeat"` and may be ignored.
pub async fn stream_events(
    req: Request,
    _params: PathParams,
) -> Result<djangors_core::sse::StreamingResponse, DjangorsError> {
    use futures_util::StreamExt;

    // Authenticate and resolve the tenant BEFORE opening any subscription, so an
    // unauthenticated request never reaches Redis.
    require_authenticated(&req).await?;
    let db = get_db(&req)?;
    let organization_id = current_organization_id(&req)?;

    let organization_public_id = repositories::organization_public_id(db, organization_id)
        .await
        .map_err(EventError::from)?
        .ok_or(EventError::OrganizationRequired)?;

    let bus = req.require_state::<crate::infra::events::EventBus>()?;

    let events = bus
        .subscribe_for_organization(organization_public_id)
        .await
        .map_err(|e| DjangorsError::Internal(format!("event stream unavailable: {e}")))?;

    let heartbeat = tokio_stream::wrappers::IntervalStream::new(tokio::time::interval(
        std::time::Duration::from_secs(HEARTBEAT_INTERVAL_SECS),
    ))
    .map(|_| serde_json::json!({ "event_type": "heartbeat" }).to_string());

    // `select` polls both and ends only when both end. The heartbeat never ends, so the
    // stream stays open until the client disconnects, at which point the response body is
    // dropped -- which drops the Redis subscription with it, releasing the connection.
    Ok(djangors_core::sse::StreamingResponse::sse(
        futures_util::stream::select(events, heartbeat),
    ))
}
