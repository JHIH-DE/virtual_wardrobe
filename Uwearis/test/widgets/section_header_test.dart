import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/section_header.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUpAll(loadAppFont);

  for (final c in layoutCases) {
    testWidgets('${describeCase(c)}: title and subtitle fit, unbroken', (
      tester,
    ) async {
      applyLayoutCase(tester, c);
      late AppLocalizations l10n;
      await pumpApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(30),
            child: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context);
                return SectionHeader(
                  title: l10n.temperatureAdjustmentTitle,
                  subtitle: l10n.virtualModelSectionSubtitle,
                );
              },
            ),
          ),
        ),
      );

      final header = find.byType(SectionHeader);
      final title = find.text(l10n.temperatureAdjustmentTitle);
      final subtitle = find.text(l10n.virtualModelSectionSubtitle);
      expectWithin(tester, title, header);
      expectWithin(tester, subtitle, header);
      expectNoBrokenWords(tester, title);
      expectNoBrokenWords(tester, subtitle);
      expect(
        tester.getRect(subtitle).top,
        greaterThanOrEqualTo(tester.getRect(title).bottom),
      );
    });
  }

  testWidgets('without a subtitle it is just the title', (tester) async {
    await pumpApp(tester, const Scaffold(body: SectionHeader(title: 'Title')));
    expect(find.text('Title'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });
}
