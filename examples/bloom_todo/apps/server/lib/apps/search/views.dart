import 'package:bloom_framework/bloom_server.dart';

class SearchViews {
  static Future<BloomResponse> search(BloomRequest req) async {
    final query = req.queryParams['q']?.toLowerCase() ?? '';

    // Returns mocked FTS matching results
    return BloomResponse.json({
      'query': query,
      'tasks': [
        {
          'id': 'tsk_1',
          'title': 'Review Bloom architecture blueprint',
          'match': 'architecture blueprint',
          'type': 'task',
        }
      ],
      'projects': [
        {
          'id': 'prj_1',
          'name': 'Bloom Framework',
          'match': 'Bloom',
          'type': 'project',
        }
      ],
    });
  }
}
