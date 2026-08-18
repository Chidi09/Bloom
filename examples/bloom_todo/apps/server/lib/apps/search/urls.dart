import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/search',
}) {
  router.get('$prefix', SearchViews.search);
}
