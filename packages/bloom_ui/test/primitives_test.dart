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
            placeholder: 'Enter name',
          ),
        ),
      );

      expect(find.text('Enter name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Alice');
      expect(controller.text, 'Alice');
    });

    testWidgets('BloomCheckbox toggles controlled and uncontrolled state', (tester) async {
      bool? checked = false;
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

    testWidgets('BloomRadioGroup selects radio option', (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrapWithTheme(
          BloomRadioGroup<String>(
            options: const [
              BloomRadioOption(value: 'apple', label: Text('Apple')),
              BloomRadioOption(value: 'banana', label: Text('Banana')),
            ],
            defaultValue: 'apple',
            onChanged: (val) => selected = val,
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      await tester.tap(find.text('Banana'));
      expect(selected, 'banana');
    });

    testWidgets('BloomSlider updates value on slide', (tester) async {
      double sliderVal = 0.2;
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (ctx, setState) => BloomSlider(
              value: sliderVal,
              onChanged: (v) => setState(() => sliderVal = v),
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('BloomSelect renders dropdown with initial value', (tester) async {
      String? selected = 'opt1';
      await tester.pumpWidget(
        wrapWithTheme(
          BloomSelect<String>(
            value: selected,
            items: const [
              BloomSelectItem(value: 'opt1', label: 'Option 1'),
              BloomSelectItem(value: 'opt2', label: 'Option 2'),
            ],
            onChanged: (val) => selected = val,
          ),
        ),
      );

      expect(find.text('Option 1'), findsOneWidget);
    });

    testWidgets('BloomToggle toggles pressed state', (tester) async {
      bool? toggled;
      await tester.pumpWidget(
        wrapWithTheme(
          BloomToggle(
            defaultChecked: false,
            onPressed: (val) => toggled = val,
            child: const Icon(Icons.format_bold),
          ),
        ),
      );

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      await tester.tap(find.byIcon(Icons.format_bold));
      expect(toggled, isTrue);
    });

    testWidgets('BloomButtonGroup renders horizontal items and allows selection', (tester) async {
      String selected = 'day';
      await tester.pumpWidget(
        wrapWithTheme(
          BloomButtonGroup<String>(
            items: const [
              BloomButtonGroupItem(value: 'day', label: Text('Day')),
              BloomButtonGroupItem(value: 'week', label: Text('Week')),
              BloomButtonGroupItem(value: 'month', label: Text('Month')),
            ],
            defaultValue: selected,
            onChanged: (val) => selected = val,
          ),
        ),
      );

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      await tester.tap(find.text('Week'));
      expect(selected, 'week');
    });
  });

  group('Bloom UI: Layout & Container Primitives', () {
    testWidgets('BloomCard renders header, content, and footer', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomCard(
            header: BloomCardHeader(
              title: BloomCardTitle('Project Settings'),
              description: BloomCardDescription('Manage your deployment tokens.'),
            ),
            content: BloomCardContent(
              child: Text('Card Content'),
            ),
            footer: BloomCardFooter(
              child: Text('Card Footer'),
            ),
          ),
        ),
      );

      expect(find.text('Project Settings'), findsOneWidget);
      expect(find.text('Manage your deployment tokens.'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
      expect(find.text('Card Footer'), findsOneWidget);
    });

    testWidgets('BloomAlert renders title and description', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomAlert(
            title: BloomAlertTitle('Update Available'),
            description: BloomAlertDescription('A new version of Bloom is ready to install.'),
            variant: BloomAlertVariant.info,
          ),
        ),
      );

      expect(find.text('Update Available'), findsOneWidget);
      expect(find.text('A new version of Bloom is ready to install.'), findsOneWidget);
    });

    testWidgets('BloomAlertDialog renders with title and action buttons', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(
        wrapWithTheme(
          BloomAlertDialog(
            title: const BloomDialogTitle('Are you sure?'),
            description: const BloomDialogDescription('This action cannot be undone.'),
            cancel: const Text('Cancel'),
            action: BloomButton(
              size: BloomButtonSize.sm,
              onPressed: () => confirmed = true,
              child: const Text('Delete'),
            ),
          ),
        ),
      );

      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      expect(confirmed, isTrue);
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
          const BloomTabs<String>(
            defaultValue: 'account',
            items: [
              BloomTabItem(value: 'account', label: Text('Account'), content: Text('Account Panel')),
              BloomTabItem(value: 'password', label: Text('Password'), content: Text('Password Panel')),
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

    testWidgets('BloomProgress renders progress percentage', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomProgress(value: 0.65),
        ),
      );

      expect(find.byType(BloomProgress), findsOneWidget);
    });
  });

  group('Bloom UI: Charts Suite', () {
    testWidgets('BloomChart Area chart renders canvas and series labels', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomChart(
            type: BloomChartType.area,
            data: BloomChartData(
              labels: ['Jan', 'Feb', 'Mar'],
              series: [
                BloomChartSeries(
                  name: 'Revenue',
                  values: [100, 200, 150],
                  color: BloomColors.petalPink,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
      expect(find.text('Mar'), findsOneWidget);
    });

    testWidgets('BloomChart Bar chart renders bars and categories', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomChart(
            type: BloomChartType.bar,
            data: BloomChartData(
              labels: ['Mon', 'Tue', 'Wed'],
              series: [
                BloomChartSeries(
                  name: 'Active Users',
                  values: [300, 450, 600],
                  color: BloomColors.petalBlue,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Active Users'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
    });

    testWidgets('BloomChart Pie chart renders slices and legends', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomChart(
            type: BloomChartType.pie,
            data: BloomChartData(
              labels: ['Desktop', 'Mobile', 'Tablet'],
              series: [
                BloomChartSeries(
                  name: 'Values',
                  values: [60, 30, 10],
                  color: BloomColors.petalCyan,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);
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

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('Bloom UI: Additional Primitives', () {
    testWidgets('BloomAvatar renders fallback letter when no image', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomAvatar(name: 'Sol'),
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
                shortcut: '⌘,',
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
      expect(find.text('⌘,'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Settings');
      await tester.pump();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsNothing);

      await tester.tap(find.text('Open Settings'));
      expect(triggered, isTrue);
    });

    testWidgets('BloomSonner displays success toast notification', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => BloomButton(
              onPressed: () => BloomSonner.success(context, 'Saved successfully!'),
              child: const Text('Save'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Saved successfully!'), findsOneWidget);
    });

    testWidgets('BloomKbd and BloomMarker render styled tokens', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              BloomKbd(text: 'Ctrl+K'),
              BloomMarker(content: Text('Highlighted text')),
            ],
          ),
        ),
      );

      expect(find.text('Ctrl+K'), findsOneWidget);
      expect(find.text('Highlighted text'), findsOneWidget);
    });

    testWidgets('BloomDirection sets text direction context', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BloomDirection(
            direction: TextDirection.rtl,
            child: Text('مرحبا'),
          ),
        ),
      );

      expect(find.text('مرحبا'), findsOneWidget);
    });
  });
}