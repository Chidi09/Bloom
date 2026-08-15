//! Shared keyset-pagination helpers.
//!
//! Cursor pagination needs the same two operations in every app that uses it: turn an opaque
//! cursor from the query string into a keyset predicate, and turn the last row of a page back
//! into a cursor. Both were written out inline per app, which is how two copies drift into
//! disagreeing about the timestamp format and silently skip rows at a page boundary.

use chrono::{DateTime, Utc};
use djangors_core::Request;
use djangors_orm::{FromRow, Model, OrmError, QuerySet};

/// Returns the `(limit, offset)` for the requested page.
///
/// `Pagination::slice` needs a row count up front, purely so `Paginator::offset` can clamp an
/// out-of-range page back into the valid range. Getting that count means an extra `COUNT`
/// before the real query — and the list repositories already return their own total, so a view
/// calling `slice` first issues two counts and a throwaway `SELECT ... LIMIT 0` on every
/// request.
///
/// This computes the window directly instead. Requesting a page past the end returns an empty
/// page rather than silently serving the last one, which is both the conventional behaviour
/// and easier for a client to detect. The authoritative total still comes back from the query
/// itself and goes into the envelope.
pub fn page_window(
    pagination: &impl djangors_rest::pagination::Pagination,
    req: &Request,
) -> (i64, i64) {
    let limit = pagination.page_size(req);
    let offset = (djangors_rest::pagination::requested_page(req) - 1).max(0) * limit;
    (limit, offset)
}

/// Applies a decoded cursor to `qs` as a keyset predicate over `(ordering_field, id)`.
///
/// A cursor that is absent, malformed, or carries an unparseable timestamp yields the queryset
/// unchanged, which serves the first page. That is deliberate: a bad cursor is a client error
/// that should not fail an otherwise valid list request, and returning page one is the
/// conventional recovery.
///
/// `descending` must match the queryset's ordering. Passing the wrong direction produces a
/// predicate that silently excludes the rows the caller wanted.
pub fn apply_datetime_cursor<T: Model + FromRow>(
    qs: QuerySet<T>,
    cursor: Option<&str>,
    ordering_field: &'static str,
    descending: bool,
) -> Result<QuerySet<T>, OrmError> {
    let Some(raw_cursor) = cursor else {
        return Ok(qs);
    };

    let Ok((cursor_pk, Some(value))) = djangors_core::pagination::decode_cursor(raw_cursor) else {
        return Ok(qs);
    };

    let Ok(parsed) = DateTime::parse_from_rfc3339(&value) else {
        return Ok(qs);
    };

    qs.after(
        ordering_field,
        djangors_orm::Value::DateTime(parsed.with_timezone(&Utc)),
        "id",
        cursor_pk,
        descending,
    )
}

/// Encodes the cursor pointing at the row after `last`, or `None` when the page is the last one.
///
/// `has_next` comes from fetching `limit + 1` rows: emitting a cursor without knowing another
/// row exists would hand the client a cursor onto an empty page.
pub fn encode_datetime_cursor(
    has_next: bool,
    last_id: i64,
    last_value: DateTime<Utc>,
) -> Option<String> {
    if !has_next {
        return None;
    }
    Some(djangors_core::pagination::encode_cursor(
        last_id,
        Some(&last_value.to_rfc3339()),
    ))
}
