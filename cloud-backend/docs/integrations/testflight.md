# Integration spec — TestFlight / App Store Connect

This document describes how Bloom Cloud uploads iOS builds to TestFlight and App Store via Apple's official tooling and APIs.

---

## 1. Authentication

Use App Store Connect API keys (JWT).

Required credentials:

- Issuer ID
- Key ID
- Team ID
- P8 private key

Stored in `credentials::Credential` with provider `apple`.

---

## 2. Upload flow

```text
Build IPA artifact
   ↓
Worker downloads credential
   ↓
Worker invokes `xcrun altool --upload-app` or Transporter (`iTMSTransporter`)
   ↓
Apple processes build
   ↓
Poll App Store Connect API for build status
   ↓
Assign internal testers group
   ↓
Optionally assign external testers group
   ↓
Notify team
```

---

## 3. Worker implementation

The deploy worker for iOS:

1. Download IPA from object storage.
2. Fetch decrypted Apple credential.
3. Generate a temporary JWT (signed with P8, expiring in 20 minutes).
4. Upload IPA via Transporter or `altool`.
5. Poll App Store Connect `/v1/builds?filter[app]=...&filter[version]=...` until `processingState = VALID`.
6. Assign beta groups via `/v1/betaGroups/{id}/builds`.
7. Update Bloom `Deployment` status to `ready`.

---

## 4. Platform API endpoints used

- `POST /v1/apps/{id}/builds` (indirect via upload)
- `GET /v1/builds` (poll)
- `POST /v1/betaGroups/{id}/builds`
- `GET /v1/betaAppReviewSubmissions` (external testing review status)

---

## 5. Status mapping

| Apple state | Bloom Deployment status | Event |
|-------------|------------------------|-------|
| upload in progress | `running` | `deployment.started` |
| processing | `processing` | `testflight.processing` |
| VALID | `ready` | `testflight.ready` |
| INVALID | `failed` | `deployment.failed` |
| external review approved | `live` | `deployment.completed` |

---

## 6. Error handling

Capture `altool` exit code and stderr. Map common errors:

- `ITMS-90189` — invalid provisioning profile
- `ITMS-90034` — missing entitlement
- `ITMS-90530` — invalid bundle identifier
- `ITMS-90713` — SDK version issue

Store raw error in `Deployment.error_message`.

---

## 7. App Store deployment

For App Store release:

1. Ensure build is `VALID`.
2. Create app store version `/v1/appStoreVersions`.
3. Set build relationship.
4. Submit for review `/v1/appStoreReviewSubmissions`.
5. Poll review status.
6. Release manually or automatically per app policy.

---

## 8. Notes

- Keep `altool` / Transporter installed in worker image.
- JWT must be regenerated per upload (Apple rejects reuse of an expired JWT).
- External TestFlight testing may trigger App Review; Bloom Cloud records the submission ID.
- Do not store Apple credentials in worker logs.
