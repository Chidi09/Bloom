// lib/app/boot.dart
import 'package:bloom_framework/bloom.dart';

/// AppBootstrapper executes during the `Bloom.boot()` sequence
/// before the widget tree mounts. Use this to register DI services and initialize storage.
class AppBootstrapper extends BloomBootstrapper {
  const AppBootstrapper();

  @override
  Future<void> onBoot(BloomContainer container) async {
    logger.info('Initializing application dependencies...');

    // Example DI registration:
    // container.provideSingleton<AuthService>(() => AuthService());
  }
}
