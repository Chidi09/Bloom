use bloom_cloud_backend::apps::common::slug::{slugify, MAX_SLUG_LEN};

#[test]
fn test_basic_slugification() {
    assert_eq!(
        slugify("My Awesome Project", "project"),
        "my-awesome-project"
    );
    assert_eq!(
        slugify("Bloom Engine v2.0!", "project"),
        "bloom-engine-v2-0"
    );
    assert_eq!(
        slugify("  --spaces-and-dashes--  ", "project"),
        "spaces-and-dashes"
    );
    assert_eq!(slugify("123-numbers", "project"), "123-numbers");
}

#[test]
fn test_fallback_is_used_only_when_nothing_survives() {
    assert_eq!(slugify("", "project"), "project");
    assert_eq!(slugify("!!!", "template"), "template");
    assert_eq!(slugify("   ", "env"), "env");
    // A single usable character is enough that the fallback must NOT be used.
    assert_eq!(slugify("!a!", "env"), "a");
}

#[test]
fn test_multibyte_name_does_not_panic_at_the_truncation_boundary() {
    // Regression: marketplace's copy matched Unicode alphanumerics and then sliced with
    // &trimmed[..60]. A name whose multi-byte character straddles byte 60 panicked inside
    // the request handler -- reachable from any user-supplied template name.
    let straddling = format!("{}\u{e9}{}", "a".repeat(59), "b".repeat(40));
    let slug = slugify(&straddling, "template");

    assert!(slug.len() <= MAX_SLUG_LEN);
    assert!(slug.is_char_boundary(slug.len()));
    // The non-ASCII character is dropped rather than transliterated.
    assert!(slug.is_ascii());
}

#[test]
fn test_non_ascii_is_dropped_consistently() {
    // Previously this differed by app: ASCII-only matchers dropped the accent while the
    // Unicode matcher kept it, so the same name produced two different slugs.
    assert_eq!(slugify("caf\u{e9} bar", "project"), "caf-bar");
    assert_eq!(slugify("\u{4e2d}\u{6587}", "project"), "project");
}

#[test]
fn test_truncation_trims_a_trailing_dash() {
    // Cutting at MAX_SLUG_LEN can land immediately after a separator; the result must not
    // end in a dash.
    let name = format!("{} tail", "a".repeat(MAX_SLUG_LEN - 1));
    let slug = slugify(&name, "project");

    assert!(slug.len() <= MAX_SLUG_LEN);
    assert!(!slug.ends_with('-'));
    assert!(!slug.starts_with('-'));
}

#[test]
fn test_separator_runs_collapse() {
    assert_eq!(slugify("a___b   c...d", "project"), "a-b-c-d");
}
