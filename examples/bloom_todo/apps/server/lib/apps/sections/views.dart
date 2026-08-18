import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_todo_core/core.dart';

class SectionViews {
  static final List<Section> _inMemorySections = [
    Section(
      id: 'sec_1',
      projectId: 'prj_1',
      name: 'To Do',
      position: 0,
      createdAt: DateTime.now(),
    ),
    Section(
      id: 'sec_2',
      projectId: 'prj_1',
      name: 'In Progress',
      position: 1,
      createdAt: DateTime.now(),
    ),
    Section(
      id: 'sec_3',
      projectId: 'prj_1',
      name: 'Done',
      position: 2,
      createdAt: DateTime.now(),
    ),
  ];

  static Future<BloomResponse> list(BloomRequest req) async {
    final projectId = req.queryParams['projectId'];
    var results = _inMemorySections;
    if (projectId != null) {
      results = results.where((s) => s.projectId == projectId).toList();
    }
    return BloomResponse.json(results.map((s) => s.toJson()).toList());
  }

  static Future<BloomResponse> create(BloomRequest req) async {
    final body = await req.json();
    final section = Section(
      id: 'sec_${DateTime.now().millisecondsSinceEpoch}',
      projectId: body['projectId'] as String,
      name: body['name'] as String,
      position: _inMemorySections.length,
      createdAt: DateTime.now().toUtc(),
    );
    _inMemorySections.add(section);
    return BloomResponse.json(section.toJson(), statusCode: 201);
  }
}
