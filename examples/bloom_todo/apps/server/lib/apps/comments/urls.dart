import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/comments',
}) {
  router.get('$prefix', CommentViews.list);
  router.post('$prefix', CommentViews.create);
}
