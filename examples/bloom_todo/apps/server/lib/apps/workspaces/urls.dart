import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/workspaces',
}) {
  router.get('$prefix', WorkspaceViews.list);
  router.post('$prefix', WorkspaceViews.create);
  router.get('$prefix/:id', (req) => WorkspaceViews.getById(req, req.params['id']!));
  router.get('$prefix/:id/members', (req) => WorkspaceViews.members(req, req.params['id']!));
}
