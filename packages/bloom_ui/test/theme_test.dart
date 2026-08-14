// test/theme_test.dart
import 'package:bloom_ui/bloom_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bloom UI: Design Tokens & ThemeExtension', () {
    test('Token values conform to design specification', () {
      expect(BloomColors.petalPurple, const Color(0xFF8B5CF6));
      expect(const BloomSpacing().s4, 16.0);
      expect(const BloomRadius().md, 8.0);
      expect(const BloomTypography().sans, 'Geist');
    });

    test('BloomColorScheme light and dark palettes initialize with correct contrasts', () {
      expect(BloomColorScheme.light.brightness, Brightness.light);
      expect(BloomColorScheme.dark.brightness, Brightness.dark);
      // Default is shadcn-neutral (near-black primary)
      expect(BloomColorScheme.light.primary, const Color(0xFF09090B));
      expect(BloomColorScheme.dark.primary, const Color(0xFFFAFAFA));
    });

    testWidgets('BloomBuildContext extension resolves active theme from tree', (tester) async {
      late BloomColorScheme colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [BloomTheme.light],
          ),
          home: Builder(
            builder: (context) {
              colors = context.bloomColors;
              return const SizedBox();
            },
          ),
        ),
      );

      // Default light primary is shadcn-neutral near-black
      expect(colors.primary, const Color(0xFF09090B));
      expect(colors.brightness, Brightness.light);
    });
  });
}
