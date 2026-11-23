import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/widgets/common/buttons/filter_button.dart';
import 'package:uwearis/features/widgets/outfit/outfit_tags_sheet.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  group('enlarged text', () {
    setUpAll(loadAppFont);
    for (final c in layoutCases) {
      for (final manual in [false, true]) {
        testWidgets('the tags sheet lays out at ${describeCase(c)}'
            '${manual ? ' (custom range)' : ''}', (tester) async {
          applyLayoutCase(tester, c);
          final outfit = Outfit(
            id: 1,
            imageUrl: '',
            style: const ['classic'],
            suitableTempMinC: manual ? null : 15,
            suitableTempMaxC: 21,
            suitableTempSource: manual
                ? OutfitTemperatureSource.manual
                : OutfitTemperatureSource.auto,
          );
          await pumpApp(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showOutfitTagsSheet(context, outfit),
                  child: const Text('open'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final isEn = c.locale.languageCode == 'en';
          final texts = [
            isEn ? 'Suitable Temperature' : '適合溫度',
            isEn ? 'Lowest' : '最低',
            isEn ? 'Highest' : '最高',
            manual ? (isEn ? 'No limit' : '不限') : '15°C',
            '21°C',
            if (manual) isEn ? 'Reset' : '重設',
          ];
          for (final text in texts) {
            final finder = find.text(text);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            expect(isTruncated(tester, finder), isFalse, reason: text);
            expectNoBrokenWords(tester, finder);
          }
        });
      }
    }
  });

  testWidgets('Reset does not make the temperature header taller', (
    tester,
  ) async {
    Future<double> headerHeight(OutfitTemperatureSource source) async {
      final outfit = Outfit(
        id: 1,
        imageUrl: '',
        suitableTempMinC: 15,
        suitableTempMaxC: 21,
        suitableTempSource: source,
      );
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOutfitTagsSheet(context, outfit),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final height = tester
          .getSize(find.byType(ChipSheetSectionHeader).first)
          .height;
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      return height;
    }

    final auto = await headerHeight(OutfitTemperatureSource.auto);
    final manual = await headerHeight(OutfitTemperatureSource.manual);
    expect(find.text('Reset'), findsNothing);
    expect(manual, auto);
  });
}
