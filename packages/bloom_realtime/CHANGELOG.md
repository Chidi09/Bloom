# 0.2.1

- **Fixed: `bloom_realtime` could not be installed alongside `bloom_server` or
  `bloom_seo`.** It depended on `bloom_js_native ^0.2.0` while both of those require
  `bloom_js_native ^0.3.0`; the two ranges are disjoint, so any app combining
  `bloom_realtime` with the rest of the Bloom server stack failed with "version solving
  failed". The constraint is now `^0.3.0`, matching the 0.3.6 that this package's
  `dependency_overrides` already built and tested against. Resolving `bloom_realtime`
  on its own always succeeded, which is why the break went unnoticed.

# 0.2.0

- **`BloomRealtimeCluster` Multi-Isolate Engine**: Added native multi-core cluster orchestrator scaling WebSocket throughput to 78,000+ msgs/sec via kernel-level port sharing (`shared: true`) and peer-to-peer `SendPort` inter-isolate mesh pub/sub routing.
- **Zero-Allocation Broadcast Loop**: Refactored `_channelSubscribers` to direct connection pointer sets, eliminating 50,000 intermediate map lookups and heap list allocations during high-frequency message fan-outs.
- **High-Performance `BloomChannelHub.upgrade`**: Added production WebSocket upgrader with default `CompressionOptions.compressionOff` to eliminate zlib CPU overhead on small JSON packets.
- **Binary Frame Streaming**: Added `msg.encodeBytes()` and `asBinary: true` support to `RealtimeMessage`, `BloomChannelHub.broadcast`, and `BloomRealtimeCluster.broadcast`.
- **Streamlined Protocol Parsing**: Enhanced `RealtimeMessage.tryParse` to decode both UTF-8 `List<int>` / `Uint8List` binary frames and JSON strings.
- **Memory Footprint**: Optimized server memory consumption down to 3.70 MB RSS under 1,000 concurrent active WebSocket connections.

# 0.1.0

- Initial release of `bloom_realtime`.
- Server-side `BloomChannelHub` for in-memory channel subscriptions and broadcasts.
- Automatic dead/closed WebSocket connection cleanup and lifecycle pruning.
- Server-side `BloomPresenceTracker` for join/leave presence tracking.
- Shared JSON wire protocol `RealtimeMessage` (`subscribe`, `unsubscribe`, `broadcast`, `presence_join`, `presence_leave`, `presence_state`, `error`, `ping`, `pong`).
- Client-side `BloomRealtimeClient` with automatic exponential backoff reconnection.
- Client-side query invalidation bridge (`bindQueryInvalidation`, `invalidateQueryOnBroadcast`) integrated with `BloomData.invalidateQueries`.
- Server-side extension and helpers on `BloomWebSocketServer` and `BloomApiRouter`.
