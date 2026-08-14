# 38. Official Serverpod Full-Stack Dart Adapter

Bloom provides adapters for **Serverpod**, the server-side Dart framework, bridging real-time WebSocket event streams into fine-grained reactive Signals and delegate CRUD repositories.

---

## ⚡ 1. Client Setup & Reactive Streams (`BloomServerpodClient`)

`BloomServerpodClient` wraps Serverpod connection management and converts backend event streams into disposable reactive Signals (`BloomStreamSignal<T>`):

```dart
import 'package:bloom_framework/bloom.dart';

final client = BloomServerpodClient(
  serverUrl: 'https://api.bloom.dev',
  initialAuthKey: 'auth_key_jwt',
);

// Update authentication key
client.setAuthKey('new_session_token');
```

---

## 📡 Binding Serverpod Real-Time Streams to Signals

Convert any Serverpod streaming endpoint (e.g. chat messages, order updates, stock tickers) into a reactive signal:

```dart
// Controller binding
class ChatController extends BloomController {
  late final BloomStreamSignal<ChatMessage> latestMessage;

  @override
  void onInit() {
    super.onInit();
    final client = inject<BloomServerpodClient>();

    // Binds Serverpod WebSocket stream to a reactive signal
    latestMessage = client.signalFromStream<ChatMessage>(
      stream: serverpodClient.chat.messageStream,
      initialValue: ChatMessage(sender: 'System', text: 'Connected'),
    );
  }

  @override
  void onDispose() {
    // Explicitly cancels stream subscription to prevent memory leaks
    latestMessage.dispose();
    super.onDispose();
  }
}
```

---

## 🖼️ Consuming Stream Signals in UI

```dart
Watch((context) {
  final msg = chatController.latestMessage.value;
  return Text('[${msg.sender}] ${msg.text}');
})
```

---

## 📑 CRUD Repository Adapter (`BloomServerpodRepository`)

Bridges generated Serverpod client endpoint calls to standard `BloomCrudRepository<T, int>` conventions:

```dart
final articleRepo = BloomServerpodRepository<Article>(
  getAllDelegate: () => serverpodClient.article.getAllArticles(),
  getByIdDelegate: (id) => serverpodClient.article.getArticleById(id),
  insertDelegate: (article) => serverpodClient.article.createArticle(article),
  updateDelegate: (id, article) => serverpodClient.article.updateArticle(id, article),
  deleteDelegate: (id) => serverpodClient.article.deleteArticle(id),
);

// Interacts as standard BloomCrudRepository
final articles = await articleRepo.findAll();
```
