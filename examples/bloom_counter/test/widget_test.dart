// test/widget_test.dart
import 'package:bloom_framework/bloom_testing.dart';
import 'package:bloom_counter/routes/index.dart';

void main() {
  testWidgets('Index route mounts and shows welcome message', (WidgetTester tester) async {
    await tester.pumpBloomApp(
      home: const IndexRoute(),
    );

    expect(find.text('Welcome to Bloom'), findsOneWidget);
    expect(find.text('Clicks: 0'), findsOneWidget);
  });
}
