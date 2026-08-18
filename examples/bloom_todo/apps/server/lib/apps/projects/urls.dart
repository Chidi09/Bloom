import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/projects',
}) {
  router.get('$prefix', ProjectViews.list);
  router.post('$prefix', ProjectViews.create);
  router.get('$prefix/:id', (req) => ProjectViews.getById(req, req.params['id']!));
  router.post('$prefix/:id/archive', (req) => ProjectViews.archive(req, req.params['id']!));
}
