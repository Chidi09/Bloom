import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/labels',
}) {
  router.get('$prefix', LabelViews.list);
  router.post('$prefix', LabelViews.create);
}
