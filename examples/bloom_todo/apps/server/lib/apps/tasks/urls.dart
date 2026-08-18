import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/tasks',
}) {
  router.get('$prefix', TaskViews.list);
  router.post('$prefix', TaskViews.create);
  router.get('$prefix/today', TaskViews.today);
  router.get('$prefix/upcoming', TaskViews.upcoming);
  router.post('$prefix/bulk-complete', TaskViews.bulkComplete);
  router.get('$prefix/:id', (req) => TaskViews.getById(req, req.params['id']!));
  router.patch('$prefix/:id', (req) => TaskViews.update(req, req.params['id']!));
  router.post('$prefix/:id/complete', (req) => TaskViews.complete(req, req.params['id']!));
  router.post('$prefix/:id/move', (req) => TaskViews.move(req, req.params['id']!));
}
