# 06. Bloom Data & Offline Architecture

## 1. Differentiated Infrastructure

While routing and state management can wrap proven ecosystem solutions (`go_router`, `signals`), **server-state orchestration and offline caching** represent a genuine gap in the Flutter ecosystem.

Bloom Data introduces a dedicated, high-performance runtime for:
* Asynchronous query management
* Normalized and key-based caching
* Mutation queues with optimistic updates
* Automatic cache invalidation
* Offline-first persistence and synchronization

```text
┌─────────────────────────────────────────────────────────────┐
│                         UI Request                          │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
                    In Memory Cache Hit?
                    /                  \
                 YES                    NO
                 /                        \
      Return Instant Data        Persistent Cache Hit?
      (Check if Stale)           /                   \
            │                  YES                    NO
            │                  /                        \
            │          Return Stale Data        Dispatch Network Request
            │                  │                        │
            └──────────┬───────┴────────────────────────┘
                       │
                       ▼
          Background Network Revalidation
                       │
                       ▼
          Update Cache & Notify Listeners
                       │
                       ▼
          Persist to Local Storage
```

---

## 2. The Query API

Queries encapsulate asynchronous read operations and expose reactive signals for loading, data, and error states:

```dart
import 'package:bloom_framework/bloom.dart';
import '../models/user.dart';
import '../services/user_api.dart';

class UserProfileController extends BloomController {
  final String userId;
  UserProfileController(this.userId);

  late final userQuery = query<User>(
    key: ['users', userId],
    fetch: () => inject<UserApi>().getUser(userId),
    staleTime: const Duration(minutes: 5),
    cacheTime: const Duration(hours: 24),
  );
}
```

### 2.1 Query States
* `data`: The most recently resolved data payload
* `status`: `QueryStatus.idle | .loading | .success | .error`
* `isFetching`: Boolean indicating active background fetch
* `isStale`: Boolean indicating data has exceeded `staleTime`
* `isOffline`: Boolean indicating device is disconnected
* `error`: Error payload if fetch failed

### 2.2 Using Queries in Widgets

```dart
class UserProfileScreen extends StatelessWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final controller = inject<UserProfileController>();
    final query = controller.userQuery.watch(context);

    if (query.isLoading && query.data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.hasError && query.data == null) {
      return Center(child: Text('Error: ${query.error}'));
    }

    final user = query.data!;
    return Column(
      children: [
        if (query.isFetching) const LinearProgressIndicator(),
        Text('Name: ${user.name}'),
        Text('Email: ${user.email}'),
      ],
    );
  }
}
```

---

## 3. The Mutation API & Optimistic Updates

Mutations represent state-modifying operations (POST, PUT, DELETE, PATCH):

```dart
final updateUserMutation = mutation<User, UpdateUserParams>(
  mutate: (params) => inject<UserApi>().updateUser(params),
  
  // 1. Optimistic Update (Immediate UI response)
  onMutate: (params) async {
    // Cancel outgoing queries for this key
    await BloomData.cancelQueries(['users', params.id]);

    // Snapshot previous value for rollback
    final previousUser = BloomData.getQueryData<User>(['users', params.id]);

    // Optimistically set new data
    BloomData.setQueryData<User>(
      ['users', params.id],
      (old) => old?.copyWith(name: params.name),
    );

    return {'previousUser': previousUser};
  },

  // 2. Rollback on Error
  onError: (err, params, context) {
    if (context?['previousUser'] != null) {
      BloomData.setQueryData(['users', params.id], context!['previousUser']);
    }
  },

  // 3. Invalidate / Revalidate on Success
  onSuccess: (data, params, context) {
    BloomData.invalidateQueries(['users', params.id]);
    BloomData.invalidateQueries(['users', 'list']);
  },
);
```

---

## 4. Cache Invalidation Engine

Bloom Data avoids manual screen-refresh coordination. When data changes, simple declarative keys trigger automated updates across all active listeners:

```dart
// Invalidate exact record
BloomData.invalidateQueries(['users', userId]);

// Invalidate all queries matching prefix ['users', ...]
BloomData.invalidateQueries(['users']);

// Mark stale without immediate network refetch
BloomData.markStale(['products']);
```

---

## 5. Offline Architecture & Sync Queue

```text
Offline Mode Detected
         ↓
Serve cached data immediately (Stale-while-revalidate)
         ↓
User performs mutation (e.g. create post)
         ↓
Optimistic UI update applied
         ↓
Mutation appended to persistent Offline Queue (SQLite / Key-Value)
         ↓
Network Connectivity Restored
         ↓
Offline Queue Replayed Sequentially
         ↓
Server Conflict Resolution Applied (Last-Write-Wins / Custom Policy)
         ↓
Queries Invalidated & Synchronized
```

---

## 6. Repository & Networking Conventions

Bloom structures data access into clean, testable repositories:

```dart
// lib/repositories/user_repository.dart
import 'package:bloom_framework/bloom.dart';
import '../models/user.dart';

abstract class UserRepository {
  Future<User> get(String id);
  Future<List<User>> list();
  Future<User> update(User user);
}

class RemoteUserRepository implements UserRepository {
  final BloomHttpClient http = inject();

  @override
  Future<User> get(String id) async {
    final response = await http.get('/users/$id');
    return User.fromJson(response.data);
  }

  @override
  Future<List<User>> list() async {
    final response = await http.get('/users');
    return (response.data as List).map((j) => User.fromJson(j)).toList();
  }

  @override
  Future<User> update(User user) async {
    final response = await http.put('/users/${user.id}', data: user.toJson());
    return User.fromJson(response.data);
  }
}
```
