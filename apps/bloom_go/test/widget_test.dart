// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:bloom_go/app/routes.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Bloom.reset();
  });

  testWidgets('Bloom Go Hub mounts and displays scan button and manual connect', (tester) async {
    await tester.pumpWidget(
      BloomApp(
        title: 'Bloom Go Test',
        routes: $bloomRoutes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bloom Go'), findsOneWidget);
    expect(find.text('Instant Mobile Development'), findsOneWidget);
    expect(find.text('Manual Host & Port Connect'), findsOneWidget);
    expect(find.text('Scan Terminal QR Code'), findsOneWidget);
  });

  testWidgets('BloomDevOverlay shows app info and cache status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => BloomDevOverlay.show(context),
              child: const Text('Open Overlay'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Overlay'));
    await tester.pumpAndSettle();

    expect(find.text('Bloom Dev Inspector'), findsOneWidget);
    expect(find.text('App Info'), findsOneWidget);
    expect(find.text('Purge Query Cache'), findsOneWidget);
  });
}
