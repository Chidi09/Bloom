import 'package:bloom_todo_config/config.dart';

/// Centralised, env-driven configuration for the server.
abstract final class Settings {
  static String get databaseUrl => 'sqlite:///tmp/bloom_todo_dev.db';

  static String get jwtSecret => 'bloom_todo_jwt_secret_dev_key';

  static int get jwtExpiryHours => 24;

  static String? get redisUrl => null;

  static String get sendgridApiKey => '';

  static String get fcmServerKey => '';

  static String get appUrl => Env.appUrl;

  static String get sentryDsn => Env.sentryDsn;

  static String get stripeSecretKey => '';
}
