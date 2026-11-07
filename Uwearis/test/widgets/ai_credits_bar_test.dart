import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/cards/ai_credits_bar.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/text_scale_harness.dart';

void main() {
  Widget harness(Widget bar, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(alignment: Alignment.topCenter, child: bar),
        ),
      ),
    );
  }

  testWidgets('shows the formatted balance', (tester) async {
    await tester.pumpWidget(harness(const AiCreditsBar(credits: 1250)));

    expect(find.text('AI Credits'), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
  });

  testWidgets('uses the header chip text color', (tester) async {
    await tester.pumpWidget(harness(const AiCreditsBar(credits: 850)));

    for (final text in ['AI Credits', '850']) {
      expect(
        tester.widget<Text>(find.text(text)).style?.color,
        AppColors.headerChipText,
      );
    }
  });

  group('text scale', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      testWidgets('stays readable at ${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c);
        await tester.pumpWidget(
          harness(const AiCreditsBar(credits: 10000), locale: c.locale),
        );

        final context = tester.element(find.byType(AiCreditsBar));
        final l10n = AppLocalizations.of(context);
        for (final text in [
          find.text(l10n.aiCreditsLabel),
          find.text('10,000'),
        ]) {
          expect(renderedLineCount(tester, text), 1);
          expectNoBrokenWords(tester, text);
          expectWithin(tester, text, find.byType(AiCreditsBar));
        }
      });
    }

    testWidgets('hugs one row at the default size', (tester) async {
      applyLayoutCase(tester, layoutCases.first);
      await tester.pumpWidget(harness(const AiCreditsBar(credits: 850)));

      final bar = tester.getRect(find.byType(AiCreditsBar));
      final label = tester.getRect(find.text('AI Credits'));
      final amount = tester.getRect(find.text('850'));
      expect(amount.center.dy, moreOrLessEquals(label.center.dy, epsilon: 1));
      expect(amount.left, greaterThanOrEqualTo(label.right));
      expect(bar.width, lessThan(342));
      expect(bar.height, 24);
    });

    testWidgets('keeps its width as the balance changes', (tester) async {
      applyLayoutCase(tester, layoutCases.first);
      await tester.pumpWidget(harness(const AiCreditsBar(credits: 850)));
      final atLowBalance = tester.getSize(find.byType(AiCreditsBar)).width;

      await tester.pumpWidget(harness(const AiCreditsBar(credits: 10000)));

      expect(tester.getSize(find.byType(AiCreditsBar)).width, atLowBalance);
    });

    testWidgets('stacks the amount under the label when they do not fit', (
      tester,
    ) async {
      applyLayoutCase(tester, (
        width: 320,
        scale: 2.0,
        locale: const Locale('en'),
      ));
      await tester.pumpWidget(
        harness(const SizedBox(width: 180, child: AiCreditsBar(credits: 850))),
      );

      final label = tester.getRect(find.text('AI Credits'));
      final amount = tester.getRect(find.text('850'));
      expect(amount.top, greaterThanOrEqualTo(label.bottom));
      expect(renderedLineCount(tester, find.text('AI Credits')), 1);
      expect(renderedLineCount(tester, find.text('850')), 1);
    });
  });
}
