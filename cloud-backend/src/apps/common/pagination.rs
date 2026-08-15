//! Shared keyset-pagination helpers.
//!
//! Cursor pagination needs the same two operations in every app that uses it: turn an opaque
//! cursor from the query string into a keyset predicate, and turn the last row of a page back
//! into a cursor. Both were written out inline per app, which is how two copies drift into
//! disagreeing about the timestamp format and silently skip rows at a page boundary.

use chrono::{DateTime, Utc};
use djangors_orm::{FromRow, Model, OrmError, QuerySet};

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
