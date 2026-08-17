# bloom_realtime

A lightweight, real-time pub/sub, presence, and live query invalidation layer for Bloom server and client applications.

`bloom_realtime` bridges server-side state changes (e.g. database mutations, background jobs) to connected client apps over WebSockets, with built-in channels, presence tracking, exponential backoff reconnection, and direct integration with `BloomData` / `BloomQuery`.

> **Note on Architecture**: The server hub `BloomChannelHub` is an in-memory, single-process implementation. If your Bloom API server is horizontally scaled across multiple instances or processes, broadcast events remain local to each process unless coordinated via an external broker (such as Redis pub/sub).

---

## Features

- **Server-Side Pub/Sub Hub (`BloomChannelHub`)**: In-process registry managing WebSocket subscriptions by channel name, broadcast fanout, and guaranteed dead-socket cleanup.
- **Presence Tracking (`BloomPresenceTracker`)**: Realtime join/leave tracking with initial state snapshots and departure events on socket disconnect.
- **Reliable Client (`BloomRealtimeClient`)**: Auto-reconnecting client with exponential backoff, jitter, keep-alive pings, and automatic resubscription.
- **Query Cache Invalidation Bridge (`RealtimeQueryBridge`)**: Connects realtime broadcasts to `BloomData.invalidateQueries(...)`, automatically triggering background revalidation of UI queries (`BloomQuery`).
- **Standardized Wire Protocol (`RealtimeMessage`)**: Structured JSON envelopes for subscriptions, broadcasts, presence, and heartbeats.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_framework:
    path: ../bloom_framework
  bloom_security:
    path: ../bloom_security
  bloom_realtime:
    path: ../bloom_realtime
```

---

## Full Worked Example 1: Server Broadcast & Client `BloomQuery` Live Invalidation

### Server (`server.dart`)

```dart
import 'dart:io';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  final router = BloomApiRouter();
  final hub = BloomChannelHub();

  // In-memory mock database
  final todos = <Map<String, dynamic>>[
    {'id': 1, 'listId': '42', 'title': 'Buy groceries', 'completed': false},
  ];

  // REST API: GET todos for a list
  router.get('/api/lists/:id/todos', (req) async {
    final listId = req.params['id']!;
    final listTodos = todos.where((t) => t['listId'] == listId).toList();
    return BloomResponse.json({'todos': listTodos});
  });

  // REST API: POST create todo -> triggers realtime broadcast to channel
  router.post('/api/lists/:id/todos', (req) async {
    final listId = req.params['id']!;
    final body = await req.json();
    final newTodo = {
      'id': todos.length + 1,
      'listId': listId,
      'title': body['title'],
      'completed': false,
    };
    todos.add(newTodo);

    // Broadcast change to everyone listening to this list's channel
    hub.broadcast('lists:$listId', {
      'action': 'todo_created',
      'todo': newTodo,
    });

    return BloomResponse.json(newTodo, statusCode: 201);
  });

  // Serve HTTP and WebSocket upgrades using BloomWebSocketServer
  final wsServer = BloomWebSocketServer(apiRouter: router);
  wsServer.register('/ws/realtime', (socket, httpRequest) {
    hub.registerConnection(socket);
  });

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  server.listen(wsServer.handleIoRequest);
  print('Bloom Realtime Server running on http://localhost:8080');
}
```

### Client (`client.dart`)

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:bloom_framework/bloom_data.dart';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  // 1. Initialize Realtime Client
  final realtime = BloomRealtimeClient(
    uri: Uri.parse('ws://localhost:8080/ws/realtime'),
  );
  await realtime.connect();

  const listId = '42';
  final queryKey = ['lists', listId, 'todos'];

  // 2. Wire the realtime channel directly to invalidate the query on broadcasts
  realtime.invalidateQueriesOnBroadcast(
    channel: 'lists:$listId',
    key: queryKey,
  );

  // 3. Define the cached BloomQuery
  final todosQuery = query<List<dynamic>>(
    key: queryKey,
    fetch: () async {
      final res = await http.get(Uri.parse('http://localhost:8080/api/lists/$listId/todos'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['todos'] as List<dynamic>;
    },
  );

  // Print UI state whenever data updates
  print('Initial fetch status: ${todosQuery.status.value}');
  await Future.delayed(const Duration(milliseconds: 200));
  print('Todos in list: ${todosQuery.data.value}');

  // When any client posts a new todo, the server broadcasts to 'lists:42',
  // which automatically triggers BloomData.invalidateQueries(['lists', '42', 'todos']),
  // causing todosQuery to refetch and update UI without polling!
}
```

---

## Full Worked Example 2: Presence Tracking (Join / Leave / State)

### Server (`presence_server.dart`)

```dart
import 'dart:io';
import 'package:bloom_security/bloom_security.dart';
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  final hub = BloomChannelHub();
  final presence = BloomPresenceTracker(hub: hub);

  final wsServer = BloomWebSocketServer();
  wsServer.register('/ws/presence', (socket, request) {
    presence.attachProtocolHandler(socket);
  });

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
  server.listen(wsServer.handleIoRequest);
  print('Presence server running on ws://localhost:8081/ws/presence');
}
```

### Client (`presence_client.dart`)

```dart
import 'package:bloom_realtime/bloom_realtime.dart';

void main() async {
  final client = BloomRealtimeClient(
    uri: Uri.parse('ws://localhost:8081/ws/presence'),
  );
  await client.connect();

  const roomId = 'room-alpha';

  // Join channel presence with user profile metadata
  final presenceStream = client.joinPresence(roomId, {
    'userId': 'user_123',
    'username': 'Alice',
    'avatar': 'https://example.com/avatar.png',
  });

  // Listen to live presence updates (users entering/leaving the room)
  presenceStream.listen((users) {
    print('Users currently in $roomId:');
    for (final u in users) {
      final info = u['info'] as Map<String, dynamic>;
      print('- ${info['username']} (${u['connectionId']})');
    }
  });

  // Broadcast an ephemeral user event to the room (e.g. typing indicator)
  client.broadcast(roomId, {
    'type': 'typing',
    'username': 'Alice',
  });

  // To leave presence
  // client.leavePresence(roomId);
}
```
