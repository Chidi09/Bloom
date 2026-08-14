# 43. Bloom v1.0 Cookbook: End-to-End Recipes

Practical, production-ready recipes for building full-stack workflows with Bloom.

---

## 🍳 Recipe 1: Authenticated CRUD with Offline Persistence

A complete user notes feature with Supabase backend, local caching, and offline sync.

### Step 1: Note Model
```dart
// lib/models/note.dart
class Note {
  final String id;
  final String content;
  final bool isSynced;

  const Note({required this.id, required this.content, this.isSynced = true});

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    isSynced: json['is_synced'] != false,
  );

  Map<String, dynamic> toJson() => {'id': id, 'content': content};
}
```

### Step 2: Note Controller with Optimistic Mutation
```dart
// lib/features/notes/notes_controller.dart
import 'package:bloom_framework/bloom.dart';
import '../../models/note.dart';

class NotesController extends BloomController {
  final BloomHttpClient http;
  late final notesQuery = BloomData.query<List<Note>>(
    queryKey: ['notes', 'list'],
    queryFn: () async {
      final res = await http.get<List<dynamic>>('/rest/v1/notes?select=*');
      return res.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    },
    staleTime: const Duration(minutes: 5),
  );

  late final addNoteMutation = BloomData.mutation<Note, String>(
    mutationFn: (text) async {
      final res = await http.post<Map<String, dynamic>>('/rest/v1/notes', body: {'content': text});
      return Note.fromJson(res);
    },
    onMutate: (text) {
      final prev = notesQuery.data.value ?? [];
      final tempNote = Note(id: 'temp_${DateTime.now().millisecondsSinceEpoch}', content: text, isSynced: false);
      notesQuery.setData([...prev, tempNote]);
      return {'rollback': prev};
    },
    onError: (err, text, context) {
      if (context?['rollback'] != null) {
        notesQuery.setData(context!['rollback'] as List<Note>);
      }
    },
    onSettled: (note, err, text, context) {
      BloomData.invalidateQueries(['notes']);
    },
  );

  NotesController(this.http);
}
```

---

## 🍳 Recipe 2: Rolling Out an Over-The-Air (OTA) Patch

### 1. Make Changes to Dart Code
Modify your UI or business logic (e.g. fix an incorrect calculation in `checkout_controller.dart`).

### 2. Verify Changes in Test Suite
```bash
bloom test
bloom analyze
```

### 3. Deploy Patch to Staging Channel
```bash
bloom deploy --patch --target=android --channel=staging --flavor=staging
```

### 4. Promote Patch to Production Channel
```bash
bloom deploy --patch --target=android --channel=production --flavor=production
```

Installed apps running on the Shorebird engine will download and stage the patch automatically on next launch!

---

## 🍳 Recipe 3: Adding a Native Plugin with Prebuild

### 1. Update `bloom.yaml`
```yaml
plugins:
  - secure-storage
  - camera
  - notifications:
      android_channel_id: order_updates
      importance: high
```

### 2. Synchronize Platform Manifests
```bash
bloom prebuild
```
Bloom automatically injects `CAMERA`, `POST_NOTIFICATIONS`, and `VIBRATE` permissions into `AndroidManifest.xml` and privacy descriptions into `Info.plist`.
