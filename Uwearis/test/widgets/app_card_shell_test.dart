import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/common/cards/app_card_shell.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUpAll(loadAppFont);

  for (final c in layoutCases) {
    testWidgets('${describeCase(c)}: header fits beside its trailing action', (
      tester,
    ) async {
      applyLayoutCase(tester, c);
      late AppLocalizations l10n;
      await pumpApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context);
                return AppCardShell(
                  title: l10n.finishOutfit,
                  subtitle: l10n.finishOutfitDescription,
                  trailing: AccentPillButton(
                    label: l10n.finishWithAi,
                    onPressed: () {},
                  ),
                  child: const SizedBox(key: Key('body'), height: 40),
                );
              },
            ),
          ),
        ),
      );

      final card = find.byType(AppCardShell);
      final title = find.text(l10n.finishOutfit);
      final subtitle = find.text(l10n.finishOutfitDescription);
      final pill = find.byType(AccentPillButton);
      final body = find.byKey(const Key('body'));
      for (final f in [title, subtitle, pill, body]) {
        expectWithin(tester, f, card);
      }
      expectNoBrokenWords(tester, title);
      expectNoBrokenWords(tester, subtitle);
      expect(
        tester.getRect(subtitle).top,
        greaterThanOrEqualTo(tester.getRect(title).bottom),
      );
      expect(
        tester.getRect(pill).left,
        greaterThanOrEqualTo(tester.getRect(subtitle).right),
      );
      expect(
        tester.getRect(body).top,
        greaterThanOrEqualTo(tester.getRect(subtitle).bottom),
      );
      expect(
        tester.getRect(body).top,
        greaterThanOrEqualTo(tester.getRect(pill).bottom),
      );
    });
  }

  testWidgets('without a title it only wraps the child', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: AppCardShell(child: Text('Body'))),
    );
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('a title-only card has no body gap', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppCardShell(title: 'Title')));
    expect(find.text('Title'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  for (final c in layoutCases) {
    testWidgets('${describeCase(c)}: the action disc sits 12 from the top '
        'and right edges and the header keeps clear of it', (tester) async {
      applyLayoutCase(tester, c);
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppCardShell(
              padding: const EdgeInsets.all(20),
              title: 'Your Style Taste',
              subtitle: 'A visual summary of your style preferences.',
              actionIcon: Icons.info_outline,
              onAction: () => taps++,
              child: const SizedBox(height: 40),
            ),
          ),
        ),
      );

      final card = tester.getRect(find.byType(AppCardShell));
      final disc = tester.getRect(
        find.descendant(
          of: find.byType(CircleIconButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(disc.top - card.top, 12);
      expect(card.right - disc.right, 12);
      for (final text in [
        'Your Style Taste',
        'A visual summary of your style preferences.',
      ]) {
        expect(
          tester.getRect(find.text(text)).right,
          lessThanOrEqualTo(disc.left),
        );
      }

      await tester.tap(find.byIcon(Icons.info_outline));
      expect(taps, 1);
    });
  }
}
