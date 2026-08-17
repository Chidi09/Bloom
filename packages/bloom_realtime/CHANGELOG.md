# 0.1.0

- Initial release of `bloom_realtime`.
- Server-side `BloomChannelHub` for in-memory channel subscriptions and broadcasts.
- Automatic dead/closed WebSocket connection cleanup and lifecycle pruning.
- Server-side `BloomPresenceTracker` for join/leave presence tracking.
- Shared JSON wire protocol `RealtimeMessage` (`subscribe`, `unsubscribe`, `broadcast`, `presence_join`, `presence_leave`, `presence_state`, `error`, `ping`, `pong`).
- Client-side `BloomRealtimeClient` with automatic exponential backoff reconnection.
- Client-side query invalidation bridge (`bindQueryInvalidation`, `invalidateQueryOnBroadcast`) integrated with `BloomData.invalidateQueries`.
- Server-side extension and helpers on `BloomWebSocketServer` and `BloomApiRouter`.
