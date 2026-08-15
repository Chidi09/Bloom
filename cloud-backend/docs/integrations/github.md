# Integration spec — GitHub / GitLab / Bitbucket

Bloom Cloud connects to Git providers to receive webhooks and list repositories.

---

## 1. GitHub

### Connection method

GitHub App installation. The app requests:

- Read repository metadata
- Read repository contents
- Read webhooks
- Push event subscription
- Pull request event subscription

### Webhook payload verification

Verify `X-Hub-Signature-256` using the GitHub App webhook secret.

```rust
let signature = req.header("X-Hub-Signature-256").unwrap();
let payload = req.body_bytes().await?;
let expected = hmac_sha256(webhook_secret, payload);
constant_time_eq(signature, expected);
```

### Events handled

- `push` — trigger build for default branch or matching branch deploy policy.
- `pull_request` — `opened`, `synchronize`, `reopened` — trigger preview build for web.
- `ping` — respond 200.

### Repository listing

Use GitHub App installation token to call `GET /installations/{id}/repositories`.

---

## 2. GitLab

### Connection method

GitLab OAuth application or group access token.

### Webhook verification

Verify `X-Gitlab-Token` or `X-Gitlab-Signature`.

### Events

- `Push Hook`
- `Merge Request Hook`

---

## 3. Bitbucket

### Connection method

Bitbucket OAuth consumer or app password.

### Webhook verification

Bitbucket does not sign webhooks natively in older versions; use IP allowlist and delivery ID deduplication.

### Events

- `repo:push`
- `pullrequest:created`, `pullrequest:updated`

---

## 4. Common webhook handling

1. Parse provider and delivery ID.
2. Verify signature (provider-specific).
3. Deduplicate by delivery ID.
4. Emit `git.push` or `git.pull_request` event.
5. Optionally enqueue `process_git_push` task to evaluate branch policies and create build.

---

## 5. Branch deploy policies

Policies are stored per app (Phase 6):

```json
{
  "branch_policies": [
    { "pattern": "main", "environment": "production", "auto_deploy": false },
    { "pattern": "staging", "environment": "staging", "auto_deploy": true },
    { "pattern": "feature/*", "environment": "development", "preview": true }
  ]
}
```

---

## 6. Notes

- Webhook endpoints are unauthenticated by route but signature-verified.
- Git provider tokens are encrypted at rest.
- Delivery IDs are cached for 24 hours to prevent duplicate builds.
