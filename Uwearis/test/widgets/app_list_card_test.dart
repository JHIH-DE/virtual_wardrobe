import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_text_styles.dart';
import 'package:uwearis/features/widgets/common/cards/app_list_card.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUpAll(loadAppFont);

  testWidgets('disabled: ignores taps, hides the arrow and dims the content', (
    tester,
  ) async {
    var taps = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: AppListCard(
          enabled: false,
          onTap: () => taps++,
          showArrow: true,
          summary: 'Locked',
          child: const Text('Title'),
        ),
      ),
    );

    await tester.tap(find.text('Title'));
    expect(taps, 0);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
    expect(
      find.ancestor(of: find.text('Title'), matching: find.byType(Opacity)),
      findsOneWidget,
    );
  });

  // Settings' Temperature Preference row: title + summary + a trailing
  // status, the tightest AppListCard shape in the app.
  for (final c in layoutCases) {
    testWidgets('title, summary and status stay readable at '
        '${describeCase(c)}', (tester) async {
      applyLayoutCase(tester, c);
      final status = c.locale.languageCode == 'zh' ? '繁體中文' : 'English';
      late AppLocalizations l10n;
      await pumpApp(
        tester,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Builder(
                builder: (context) {
                  l10n = AppLocalizations.of(context);
                  return AppListCard(
                    onTap: () {},
                    leading: const SizedBox.square(
                      dimension: 40,
                      child: Icon(Icons.thermostat, size: 32),
                    ),
                    showArrow: true,
                    summary: l10n.styleTasteSummary,
                    status: status,
                    child: Text(
                      l10n.myOutfitProfileTitle,
                      style: AppTextStyle.bold16,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );

      final card = find.byType(AppListCard);
      final title = find.text(l10n.myOutfitProfileTitle);
      final summary = find.text(l10n.styleTasteSummary);
      final statusText = find.text(status);
      for (final part in [title, summary, statusText]) {
        expectWithin(tester, part, card);
      }
      expect(isTruncated(tester, summary), isFalse);
      expectNoBrokenWords(tester, title);
      expectNoBrokenWords(tester, summary);
      // A long word that can't fit beside the leading icon moves the icon
      // above the text rather than splitting the word.
      final icon = tester.getRect(find.byIcon(Icons.thermostat));
      if (icon.bottom <= tester.getRect(title).top) {
        expect(c.scale, greaterThan(1.0));
      }
      expect(renderedLineCount(tester, statusText), 1);

      final titleRect = tester.getRect(title);
      final statusRect = tester.getRect(statusText);
      if (c.scale == 1.0) {
        // Default size: the status trails the title on the same row.
        expect(statusRect.left, greaterThan(titleRect.right));
      } else {
        // Enlarged: the status moves under the title, so the title keeps
        // the row's full text width instead of a squeezed sliver.
        expect(statusRect.top, greaterThanOrEqualTo(titleRect.bottom));
        expect(
          tester.getSize(summary).width,
          lessThanOrEqualTo(
            tester.getSize(card).width - 2 * 16 - (4 + 20) + 0.5,
          ),
        );
        expect(
          tester.renderObject<RenderBox>(title).constraints.maxWidth,
          greaterThanOrEqualTo(_textColumnWidth(tester, card) - 0.5),
        );
      }
    });
  }
}

/// Width available to the card's text column: the card minus its 16px
/// padding, the 40px leading + 18px gap, and the 4px gap + 20px arrow.
double _textColumnWidth(WidgetTester tester, Finder card) =>
    tester.getSize(card).width - 2 * 16 - (40 + 18) - (4 + 20);
