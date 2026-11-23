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
      key: 'freezing',
      label: '零下',
      minC: null,
      maxC: 0,
      outfitCount: 1,
      status: TemperatureCoverageStatus.few,
    ),
    TemperatureBand(
      key: 'chilly',
      label: 'Chilly',
      minC: 10,
      maxC: 15,
      outfitCount: 42,
      status: TemperatureCoverageStatus.enough,
    ),
    TemperatureBand(
      key: 'hot',
      minC: 29,
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
          '零下',
          'Chilly',
          isEn ? 'Below 0°C' : '0°C 以下',
          isEn ? '10–15°C' : '10~15°C',
          isEn ? '29°C and above' : '29°C 以上',
        ]) {
          expect(isTruncated(tester, find.text(label)), isFalse);
          expectNoBrokenWords(tester, find.text(label));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a band without a backend label shows its range alone', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: TemperatureCoverageCard(coverage: _coverage)),
    );
    await tester.pumpAndSettle();

    final hotRow = find.byKey(const ValueKey('hot'));
    expect(
      find.descendant(of: hotRow, matching: find.byType(Text)),
      findsNWidgets(2), // range + count
    );
    expect(
      find.descendant(of: hotRow, matching: find.text('29°C and above')),
      findsOneWidget,
    );
  });
}
