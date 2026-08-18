import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/sections',
}) {
  router.get('$prefix', SectionViews.list);
  router.post('$prefix', SectionViews.create);
}
