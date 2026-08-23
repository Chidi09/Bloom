# 0.1.1 - 2026-08-23

- Migrated to an unnamed `library;` declaration. No public API changes.

# 0.1.0

- Initial release of `bloom_jobs`.
- In-memory background job queue (`BloomTaskQueue`) with atomic async task claiming (`claimNext`).
- Task registry (`BloomTaskRegistry`) for named task handlers.
- Worker loop (`BloomJobWorker`) with builder-style poll and recurring tick interval configuration.
- Recurring task scheduler (`BloomRecurringRegistry`, `BloomRecurringTask`) using duration intervals.
- Integrated with `BloomContainer` DI pattern.
