## 0.1.0

- Initial release of `bloom_auth_server`.
- **Password Hashing & Verification**: Strong, constant-time BCrypt hashing (`hashPassword`, `verifyPassword`, `dummyVerifyPassword`) with configurable cost factor and user-enumeration defense.
- **Session & Bearer Token Issuance**: Cryptographically signed Bearer JWT issuance (`issueSessionToken`, `verifySessionToken`) bound with expiration, user identity, and custom claims.
- **Sliding-Window Rate Limiting & Account Lockout**: In-memory rate limiting (`InMemoryRateLimiter`) and persistent-style lockout tracker (`InMemoryLockoutManager`, `AuthRateLimiter`) with fail-closed security semantics.
- **Password Reset Workflows**: Single-purpose, time-limited, HMAC-signed password reset tokens (`generatePasswordResetToken`, `verifyPasswordResetToken`) cryptographically bound to the user's current password hash to ensure instant invalidation upon password modification.
- **Bloom Server Middleware**: Drop-in `BloomAuthMiddleware` for `BloomApiRouter` supporting Bearer token extraction, claim hydration, role validation, and `BloomRequest` context extensions (`request.auth`, `request.authUserId`, `request.isAuthenticated`).
