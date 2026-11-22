import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/temperature_coverage.dart';
import 'package:uwearis/features/widgets/outfit/temperature_coverage_card.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

const _coverage = TemperatureCoverage(
  temperatureOffsetC: 0,
  usableOutfitCount: 50,
  enoughCount: 3,
  bands: [
    TemperatureBand(
      minC: null,
      maxC: 12,
      outfitCount: 1,
      status: TemperatureCoverageStatus.few,
    ),
    TemperatureBand(
      minC: 18,
      maxC: 21,
      outfitCount: 42,
      status: TemperatureCoverageStatus.enough,
    ),
    TemperatureBand(
      minC: 33,
      maxC: null,
      outfitCount: 0,
      status: TemperatureCoverageStatus.none,
    ),
  ],
);

void main() {
  group('enlarged text', () {
    setUpAll(loadAppFont);
    for (final c in layoutCases) {
      testWidgets('stays readable at ${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c, height: 2000);
        await pumpApp(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: TemperatureCoverageCard(coverage: _coverage),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final isEn = c.locale.languageCode == 'en';
        for (final label in [
          isEn ? 'Below 12°C' : '12°C 以下',
          isEn ? '18–21°C' : '18~21°C',
          isEn ? '33°C and above' : '33°C 以上',
        ]) {
          expect(isTruncated(tester, find.text(label)), isFalse);
          expectNoBrokenWords(tester, find.text(label));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
