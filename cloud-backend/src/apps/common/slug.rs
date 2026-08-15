//! Shared URL slug generation.
//!
//! Five apps each carried their own `slugify`, and they had already drifted apart: most
//! matched on `is_ascii_alphanumeric` while marketplace used the Unicode `is_alphanumeric`,
//! so the same name produced different slugs depending on which app you asked. Worse, the
//! Unicode variant then sliced with `&trimmed[..60]`, which panics when a multi-byte
//! character straddles byte 60 — a request-killing panic reachable from any user-supplied
//! template name.

/// Maximum slug length in bytes.
///
/// Slugs are ASCII-only, so bytes and characters coincide and truncation cannot split a
/// character.
pub const MAX_SLUG_LEN: usize = 60;

/// Converts `name` into a URL-safe ASCII slug, falling back to `fallback` when nothing
/// usable survives.
///
/// Non-ASCII characters are dropped rather than transliterated. Slugs appear in URLs and are
/// compared for uniqueness, so a predictable ASCII subset is worth more here than preserving
/// the original script; callers that need the original keep it in the record's `name`.
///
/// Runs of separators collapse into a single `-`, and leading and trailing dashes are
/// trimmed. `fallback` should be the domain noun (`"app"`, `"project"`, `"template"`).
pub fn slugify(name: &str, fallback: &str) -> String {
    let mut slug = String::with_capacity(name.len());
    let mut last_was_dash = true;

    for c in name.chars() {
        if c.is_ascii_alphanumeric() {
            slug.push(c.to_ascii_lowercase());
            last_was_dash = false;
        } else if !last_was_dash {
            slug.push('-');
            last_was_dash = true;
        }
    }

    let trimmed = slug.trim_matches('-');

    if trimmed.is_empty() {
        return fallback.to_string();
    }

    if trimmed.len() > MAX_SLUG_LEN {
        // Safe to slice: every retained character is ASCII, so byte MAX_SLUG_LEN is always a
        // character boundary. Trim again in case the cut landed on a dash.
        return trimmed[..MAX_SLUG_LEN].trim_matches('-').to_string();
    }

    trimmed.to_string()
}
