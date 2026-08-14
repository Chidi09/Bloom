# Integration spec — Shorebird

Shorebird is the native OTA patch provider for Bloom Cloud. Bloom does not build a competing OTA engine.

---

## 1. Authentication

Shorebird token or machine account credentials.

Stored in `credentials::Credential` with provider `shorebird`.

---

## 2. Commands

### Shorebird release

```bash
shorebird release {platform} --artifact {path}
```

Creates a Shorebird release for the native binary.

### Shorebird patch

```bash
shorebird patch {platform} --artifact {path}
```

Creates a Dart patch.

---

## 3. Worker flow

```text
Build artifact
   ↓
Determine if change is patch-eligible (CLI decides)
   ↓
Run `shorebird release` or `shorebird patch`
   ↓
Capture Shorebird release/patch ID
   ↓
Store ID on Bloom Release
   ↓
Emit `shorebird.release.created` or `shorebird.patch.created`
```

---

## 4. Bloom CLI commands

```bash
bloom release   # native binary release
bloom patch     # Dart patch
bloom deploy    # Bloom decides native binary vs Dart patch
```

The backend does not decide patch eligibility; it invokes the Shorebird CLI and records the result.

---

## 5. Data model

Add to `Release` metadata or a separate table:

| Field | Notes |
|-------|-------|
| `shorebird_release_id` | optional |
| `shorebird_patch_id` | optional |
| `shorebird_platform` | `android` / `ios` |

These are stored in `Release.rollout_status` JSON or a dedicated `shorebird_releases` child table (Phase 6).

---

## 6. Error handling

Capture Shorebird CLI stderr. Common issues:

- Patch eligibility failures (native code changed)
- Invalid Shorebird token
- App ID mismatch

---

## 7. Notes

- Shorebird CLI must be installed in build/deploy worker image.
- Keep Shorebird as the single source of truth for patch rollout.
- Bloom Cloud records the link between Shorebird IDs and Bloom Releases.
