use bloom_cloud_backend::infra::events::{event_belongs_to_organization, EVENT_CHANNEL};
use serde_json::json;

const ORG_A: &str = "11111111-1111-1111-1111-111111111111";
const ORG_B: &str = "22222222-2222-2222-2222-222222222222";

#[test]
fn test_event_channel_name_matches_the_documented_channel() {
    // docs/infrastructure.md section 3 names this channel. A rename here silently detaches
    // every publisher from every subscriber, with nothing failing.
    assert_eq!(EVENT_CHANNEL, "bloomcloud:events");
}

#[test]
fn test_event_is_delivered_only_to_its_owning_organization() {
    let event = json!({
        "id": "e1",
        "event_type": "build.started",
        "organization_id": ORG_A,
    });

    assert!(event_belongs_to_organization(&event, ORG_A));
    assert!(!event_belongs_to_organization(&event, ORG_B));
}

#[test]
fn test_unattributable_events_are_delivered_to_nobody() {
    // The channel carries every tenant's events, so this predicate is the entire tenant
    // boundary for the stream. A payload we cannot attribute must be dropped, never
    // broadcast -- failing open here would be a cross-tenant leak.
    let no_org = json!({ "id": "e1", "event_type": "build.started" });
    assert!(!event_belongs_to_organization(&no_org, ORG_A));
    assert!(!event_belongs_to_organization(&no_org, ORG_B));

    let null_org = json!({ "organization_id": serde_json::Value::Null });
    assert!(!event_belongs_to_organization(&null_org, ORG_A));

    // A non-string organization_id must not be coerced into a match.
    let numeric_org = json!({ "organization_id": 11111111 });
    assert!(!event_belongs_to_organization(&numeric_org, ORG_A));

    let empty = json!({});
    assert!(!event_belongs_to_organization(&empty, ORG_A));
}

#[test]
fn test_organization_match_is_exact_not_prefix() {
    // Public ids are UUIDs, but a prefix match would still be wrong, and cheap to get wrong
    // with a `starts_with`.
    let event = json!({ "organization_id": ORG_A });
    assert!(!event_belongs_to_organization(&event, &ORG_A[..8]));
    assert!(!event_belongs_to_organization(
        &event,
        &format!("{ORG_A}-suffix")
    ));
}
