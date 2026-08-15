# Integration spec — Google Play Developer API

Bloom Cloud uploads Android bundles (AAB/APK) to Google Play testing tracks and production.

---

## 1. Authentication

Google Play service-account JSON key.

Stored in `credentials::Credential` with provider `google_play`.

---

## 2. Upload and release flow

```text
Build AAB/APK artifact
   ↓
Worker downloads credential
   ↓
Create Google Play edit
   ↓
Upload bundle to Play Developer API
   ↓
Assign bundle to track (internal/closed/open/production)
   ↓
Set release notes, rollout fraction
   ↓
Commit edit
   ↓
Poll until live
   ↓
Update Bloom Deployment status
```

---

## 3. Worker implementation

Use the Google Play Android Developer API (v3) or `fastlane supply`.

API calls:

1. `POST /androidpublisher/v3/applications/{packageName}/edits`
2. `POST /androidpublisher/v3/applications/{packageName}/edits/{editId}/bundles` (upload AAB)
3. `POST /.../tracks/{track}` — assign version code and release configuration
4. `POST /.../edits/{editId}:commit`
5. Poll `GET /.../tracks/{track}` until release status is `completed` / `inProgress`.

---

## 4. Status mapping

| Play state | Bloom Deployment status | Event |
|------------|--------------------------|-------|
| edit created | `running` | `deployment.started` |
| upload committed | `processing` | `google_play.processing` |
| track live / in progress | `live` | `google_play.live` |
| edit failed | `failed` | `deployment.failed` |

---

## 5. Track targets

| Bloom target | Play track |
|--------------|------------|
| `internal` | `internal` |
| `closed` | `alpha` / `closedTesting` |
| `open` | `beta` / `openTesting` |
| `production` | `production` |

---

## 6. Rollout

Production deployments can specify a rollout fraction (0.0 - 1.0). Default 1.0 (full rollout).

---

## 7. Error handling

Common errors to capture:

- `apkNotificationMessageKeyUpgradeVersionConflict` — version code already exists
- `incompatibleAppVersion` — app signing mismatch
- `bundleRequiresReview` — bundle requires review
- Invalid keystore / signing identity mismatch

Store raw error in `Deployment.error_message`.

---

## 8. Notes

- Keep Google Play Developer API client in worker image.
- Service account needs `Release manager` or higher role.
- AAB strongly preferred over APK for Play Store; APK for sideload/internal dev.
