import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/notifications',
}) {
  router.get('$prefix', NotificationViews.list);
  router.patch('$prefix/:id/read', (req) => NotificationViews.markRead(req, req.params['id']!));
  router.post('$prefix/read-all', NotificationViews.markAllRead);
}
