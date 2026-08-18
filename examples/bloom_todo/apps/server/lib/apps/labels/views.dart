import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_todo_core/core.dart';

class LabelViews {
  static final List<Label> _inMemoryLabels = [
    Label(
      id: 'lbl_1',
      workspaceId: 'ws_1',
      name: 'urgent',
      colorHex: '#EF4444',
      position: 0,
      createdAt: DateTime.now(),
    ),
    Label(
      id: 'lbl_2',
      workspaceId: 'ws_1',
      name: 'backend',
      colorHex: '#6366F1',
      position: 1,
      createdAt: DateTime.now(),
    ),
    Label(
      id: 'lbl_3',
      workspaceId: 'ws_1',
      name: 'frontend',
      colorHex: '#10B981',
      position: 2,
      createdAt: DateTime.now(),
    ),
  ];

  static Future<BloomResponse> list(BloomRequest req) async {
    return BloomResponse.json(_inMemoryLabels.map((l) => l.toJson()).toList());
  }

  static Future<BloomResponse> create(BloomRequest req) async {
    final body = await req.json();
    final label = Label(
      id: 'lbl_${DateTime.now().millisecondsSinceEpoch}',
      workspaceId: body['workspaceId'] as String? ?? 'ws_1',
      name: body['name'] as String,
      colorHex: body['colorHex'] as String? ?? '#6366F1',
      position: _inMemoryLabels.length,
      createdAt: DateTime.now().toUtc(),
    );
    _inMemoryLabels.add(label);
    return BloomResponse.json(label.toJson(), statusCode: 201);
  }
}
