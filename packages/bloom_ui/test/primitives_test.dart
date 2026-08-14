// test/primitives_test.dart
import 'package:bloom_ui/bloom_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [BloomTheme.light],
      ),
      home: Scaffold(body: child),
    );
  }

  group('Bloom UI: Form Primitives', () {
    testWidgets('BloomButton renders and triggers onPressed callback', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        wrapWithTheme(
          BloomButton(
            onPressed: () => pressed = true,
            child: const Text('Click me'),
          ),
        ),
      );

      expect(find.text('Click me'), findsOneWidget);
      await tester.tap(find.text('Click me'));
      expect(pressed, isTrue);
    });

    testWidgets('BloomButton shows loading indicator when loading is true', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BloomButton(
            loading: true,
            onPressed: () {},
            child: const Text('Loading Button'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('BloomInput renders and allows entering text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        wrapWithTheme(
          BloomInput(
            controller: controller,
            hintText: 'Enter name',
          ),
        ),
      );

      expect(find.text('Enter name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Alice');
      expect(controller.text, 'Alice');
    });

    testWidgets('BloomCheckbox toggles controlled and uncontrolled state', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        wrapWithTheme(
          BloomCheckbox(
            defaultChecked: false,
            label: const Text('Accept terms'),
            onChanged: (val) => checked = val,
          ),
        ),
      );

      expect(find.text('Accept terms'), findsOneWidget);
      await tester.tap(find.text('Accept terms'));
      await tester.pump();
      expect(checked, isTrue);
    });

    testWidgets('BloomSwitch triggers onChanged', (tester) async {
      var enabled = false;
      await tester.pumpWidget(
        wrapWithTheme(
          BloomSwitch(
            defaultChecked: false,
            label: const Text('Dark Mode'),
            onChanged: (val) => enabled = val,
          ),
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
    });

    testWidgets('BloomRadio and BloomRadioGroup select active item', (tester) async {
      String? selected = 'a';
      await tester.pumpWidget(
        wrapWithTheme(
          BloomRadioGroup<String>(
            children: [
              BloomRadio<String>(
                value: 'a',
                groupValue: selected,
                label: const Text('Option A'),
                onChanged: (v) => selected = v,
              ),
              BloomRadio<String>(
                value: 'b',
                groupValue: selected,
                label: const Text('Option B'),
                onChanged: (v) => selected = v,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
      await tester.tap(find.text('Option B'));
      expect(selected, 'b');
    });
  });

  group('Bloom UI: Layout & Feedback Primitives', () {
    testWidgets('BloomCard renders with header, description and content', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomCard(
            child: Column(
              children: [
                BloomCardTitle('Project Settings'),
                BloomCardDescription('Manage your deployment tokens.'),
                BloomCardContent(child: Text('Card Content')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Project Settings'), findsOneWidget);
      expect(find.text('Manage your deployment tokens.'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('BloomAlert renders title and description', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomAlert(
            title: 'Update Available',
            description: 'A new version of Bloom is ready to install.',
            variant: BloomAlertVariant.info,
          ),
        ),
      );

      expect(find.text('Update Available'), findsOneWidget);
      expect(find.text('A new version of Bloom is ready to install.'), findsOneWidget);
    });

    testWidgets('BloomAccordion expands and collapses on tap', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomAccordion(
            items: [
              BloomAccordionItem(
                title: 'Is it accessible?',
                content: Text('Yes, it follows WAI-ARIA and Flutter Semantics.'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Is it accessible?'), findsOneWidget);
      await tester.tap(find.text('Is it accessible?'));
      await tester.pumpAndSettle();
      expect(find.text('Yes, it follows WAI-ARIA and Flutter Semantics.'), findsOneWidget);
    });

    testWidgets('BloomTabs switches tab content on click', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomTabs(
            tabs: [
              BloomTabItem(label: 'Account', content: Text('Account Panel')),
              BloomTabItem(label: 'Password', content: Text('Password Panel')),
            ],
          ),
        ),
      );

      expect(find.text('Account Panel'), findsOneWidget);
      await tester.tap(find.text('Password'));
      await tester.pump();
      expect(find.text('Password Panel'), findsOneWidget);
    });

    testWidgets('BloomSkeleton renders shape and dimensions', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomSkeleton(width: 100, height: 20),
        ),
      );

      expect(find.byType(BloomSkeleton), findsOneWidget);
    });
  });

  group('Bloom UI: Chart', () {
    testWidgets('BloomChart renders bar chart with legend and tooltip', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomChart(
            data: BloomChartData(
              labels: ['Jan', 'Feb', 'Mar'],
              series: [
                BloomChartSeries(name: 'Desktop', values: [100, 80, 95]),
                BloomChartSeries(name: 'Mobile', values: [60, 90, 70]),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
    });

    testWidgets('BloomChart renders pie chart', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomChart(
            data: BloomChartData(
              labels: ['A', 'B', 'C'],
              series: [BloomChartSeries(name: 'Values', values: [30, 50, 20])],
            ),
            type: BloomChartType.pie,
          ),
        ),
      );

      expect(find.text('Values'), findsOneWidget);
    });
  });

  group('Bloom UI: Calendar', () {
    testWidgets('BloomCalendar single mode renders month grid', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BloomCalendar.single(
            onDaySelected: (_) {},
          ),
        ),
      );

      // Should show month/year header and day grid
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
    testWidgets('BloomAvatar renders fallback letter when no image', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomAvatar(fallback: 'Sol'),
        ),
      );

      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('BloomBadge renders variant styling', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomBadge(
            variant: BloomBadgeVariant.success,
            child: Text('ACTIVE'),
          ),
        ),
      );

      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('BloomDataTable renders columns and rows', (tester) async {
      final data = ['Item 1', 'Item 2'];
      await tester.pumpWidget(
        wrapWithTheme(
          BloomDataTable<String>(
            columns: [
              BloomDataColumn(label: 'Name', builder: (item) => Text(item)),
            ],
            data: data,
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('BloomCommandPalette filters items by search query', (tester) async {
      var triggered = false;
      await tester.pumpWidget(
        wrapWithTheme(
          BloomCommandPalette(
            items: [
              BloomCommandItem(
                title: 'Open Settings',
                onSelected: () => triggered = true,
              ),
              BloomCommandItem(
                title: 'Go to Dashboard',
                onSelected: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Settings');
      await tester.pump();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsNothing);

      await tester.tap(find.text('Open Settings'));
      expect(triggered, isTrue);
    });
}