# 21. Offline Mutation Queue & Synchronization

Bloom provides a resilient offline mutation queue (`OfflineMutationQueue`) that enables applications to capture user actions while offline and replay them sequentially when network connectivity resumes.

---

## 🏗️ Architecture

```text
       Offline Mutation Queue
                 │
  ┌──────────────┴──────────────┐
  │                             │
User Action (Offline)    Network Restored
  │                             │
Enqueue Mutation         Replay Sequentially
  │                             │
Persist to Storage       Conflict Resolution
                         (Last-Write-Wins / Discard)
```

---

## 📥 Enqueuing an Offline Mutation

When an operation fails due to network unavailability or when the device is known to be offline, enqueue the mutation:

```dart
final queue = OfflineMutationQueue(storage: secureStorage);

await queue.enqueue(
  action: 'create_order',
  payload: {
    'item_id': 'item_123',
    'quantity': 2,
    'timestamp': DateTime.now().toIso8601String(),
  },
);

print('Pending mutations in queue: ${queue.pendingCount}');
```

---

## 🔁 Replaying Pending Mutations

When the device regains network connectivity, trigger sequential queue replay:

```dart
await queue.replay((mutation) async {
  if (mutation.action == 'create_order') {
    final res = await http.post('/api/orders', body: mutation.payload);
    return res.statusCode == 200 || res.statusCode == 201;
  }
  return false;
});
```

* Successfully replayed mutations are automatically removed from the persistent queue.
* Replay order is strictly FIFO (First-In, First-Out) by default.

---

## ⚔️ Conflict Resolution Policies

`ConflictPolicy` defines behavior when a queued mutation encounters a server collision:

| Policy | Behavior |
| :--- | :--- |
| `ConflictPolicy.lastWriteWins` | The queued client modification overrides existing server data. |
| `ConflictPolicy.serverWins` | Discards the client mutation and accepts the current server state. |
| `ConflictPolicy.merge` | Invokes a custom conflict resolver function to merge payload diffs. |
