// lib/features/auth/controllers/${featureName}_controller.dart
import 'package:bloom_framework/bloom.dart';

class AuthController extends BloomController {
  final count = signal(0);
  late final isEven = computed(() => count.value.isEven);

  void increment() => count.value++;
  void decrement() => count.value--;
  void reset() => count.value = 0;

  @override
  void onInit() {
    super.onInit();
    logger.info('AuthController initialized');
  }
}
