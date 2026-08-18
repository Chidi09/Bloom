import 'package:bloom_framework/bloom_server.dart';
import 'views.dart';

void registerUrls(
  BloomApiRouter router, {
  String prefix = '/api/auth',
}) {
  router.post('$prefix/signup', AuthViews.signup);
  router.post('$prefix/login', AuthViews.login);
  router.post('$prefix/refresh', AuthViews.refresh);
  router.post('$prefix/logout', AuthViews.logout);
  router.get('$prefix/me', AuthViews.me);
}
