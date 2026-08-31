# 0.2.1 - 2026-08-31

* Added lease recovery and ownership-token fencing for all task queue backends.

# 0.2.0 - 2026-08-25

### Added
* **Persistent, distributed job queue backends.** `BloomTaskQueue` is now an abstract base class with three implementations: `InMemoryTaskQueue` (unchanged, default), `RedisTaskQueue` (cross-process atomic claiming via a Lua script over a due-tasks sorted set), and `DatabaseTaskQueue` (SQL-backed via `bloom_db`, using `FOR UPDATE SKIP LOCKED` on Postgres and an atomic guarded `UPDATE` on SQLite). Jobs enqueued through either backend survive process restarts and can be claimed by any worker process sharing the same Redis/database, closing the previous in-memory-only limitation.

# 0.1.1 - 2026-08-23

- Migrated to an unnamed `library;` declaration. No public API changes.

# 0.1.0

- Initial release of `bloom_jobs`.
- In-memory background job queue (`BloomTaskQueue`) with atomic async task claiming (`claimNext`).
- Task registry (`BloomTaskRegistry`) for named task handlers.
- Worker loop (`BloomJobWorker`) with builder-style poll and recurring tick interval configuration.
- Recurring task scheduler (`BloomRecurringRegistry`, `BloomRecurringTask`) using duration intervals.
- Integrated with `BloomContainer` DI pattern.
