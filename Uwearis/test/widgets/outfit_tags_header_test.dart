import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';
import 'package:uwearis/features/widgets/outfit/outfit_tag_row.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

final _l10n = AppLocalizationsEn();

void main() {
  group('temperatureLabel', () {
    test('a closed range reads like the Home weather chip', () {
      expect(OutfitTagsHeader.temperatureLabel(_l10n, 15, 21), '15°C - 21°C');
    });

    test('open ends read "Below" / "and above"; both open is null', () {
      expect(OutfitTagsHeader.temperatureLabel(_l10n, null, 12), 'Below 12°C');
      expect(
        OutfitTagsHeader.temperatureLabel(_l10n, 29, null),
        '29°C and above',
      );
      expect(OutfitTagsHeader.temperatureLabel(_l10n, null, null), isNull);
    });
  });

  Widget header({List<String> style = const [], int? min, int? max}) =>
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutfitTagsHeader(
            style: style,
            temperatureMinC: min,
            temperatureMaxC: max,
            onEdit: () {},
          ),
        ),
      );

  testWidgets('shows the temperature chip before the style tags', (
    tester,
  ) async {
    await pumpApp(tester, header(style: ['classic'], min: 15, max: 21));

    final chip = tester.getRect(find.text('15°C - 21°C'));
    final tag = tester.getRect(find.text('Classic'));
    expect(chip.right, lessThan(tag.left));
    expect(find.text(_l10n.myCollection), findsNothing);
  });

  testWidgets('the temperature tag is exactly as tall as a style tag', (
    tester,
  ) async {
    await pumpApp(tester, header(style: ['classic'], min: 15, max: 21));

    final tags = find.byType(CategoryTag);
    expect(tags, findsNWidgets(2));
    expect(tester.getSize(tags.first).height, tester.getSize(tags.last).height);
    expect(
      find.descendant(
        of: tags.first,
        matching: find.byIcon(Icons.thermostat_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('temperature alone is enough to skip "My Collection"', (
    tester,
  ) async {
    await pumpApp(tester, header(min: 29));
    expect(find.text('29°C and above'), findsOneWidget);
    expect(find.text(_l10n.myCollection), findsNothing);
    expect(find.byType(OutfitTagRow), findsNothing);
  });

  testWidgets('no temperature and no style reads "My Collection"', (
    tester,
  ) async {
    await pumpApp(tester, header());
    expect(find.text(_l10n.myCollection), findsOneWidget);
    expect(find.byIcon(Icons.thermostat_rounded), findsNothing);
  });

  group('enlarged text', () {
    setUpAll(loadAppFont);
    for (final c in layoutCases) {
      testWidgets('temperature stays whole at ${describeCase(c)}', (
        tester,
      ) async {
        applyLayoutCase(tester, c);
        await pumpApp(
          tester,
          header(style: ['smart_casual', 'streetwear'], min: 15, max: 21),
        );
        await tester.pumpAndSettle();

        final label = find.text('15°C - 21°C');
        expect(tester.takeException(), isNull);
        expect(isTruncated(tester, label), isFalse);
        expectNoBrokenWords(tester, label);
      });
    }
  });
}
