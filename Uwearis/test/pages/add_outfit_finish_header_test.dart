import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/add_outfit_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/common/cards/app_card_shell.dart';
import 'package:uwearis/features/widgets/common/section_title.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/add_outfit_harness.dart';
import '../helpers/fake_auth.dart';
import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

class _EmptyCloset extends GarmentsNotifier {
  @override
  Future<List<Garment>> build() async => const [];
}

void main() {
  setUpAll(loadAppFont);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth();
  });

  // Create Outfit's Auto-Complete card: a SectionTitle + collapse toggle
  // header over a temperature stepper tile and a style tile, with the
  // Finish with AI pill centered at the bottom.
  for (final c in layoutCases) {
    testWidgets('the Auto-Complete card lays out at ${describeCase(c)}', (
      tester,
    ) async {
      applyLayoutCase(tester, c, height: 3000);
      await pumpApp(
        tester,
        const AddOutfitPage(),
        overrides: [garmentsProvider.overrideWith(_EmptyCloset.new)],
      );
      await tester.pump();
      await expandFinishOutfit(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AddOutfitPage)),
      );
      final pill = find.widgetWithText(AccentPillButton, l10n.finishWithAi);
      final pillLabel = find.descendant(
        of: pill,
        matching: find.text(l10n.finishWithAi),
      );

      expect(isTruncated(tester, pillLabel), isFalse);

      final card = find
          .ancestor(of: pill, matching: find.byType(AppCardShell))
          .first;
      final pillRect = tester.getRect(
        find.descendant(of: pill, matching: find.byType(TextButton)),
      );
      expect(
        pillRect.center.dx,
        closeTo(tester.getRect(card).center.dx, 0.5),
        reason: 'pill is centered in the card',
      );
      expect(
        pillRect.top,
        greaterThanOrEqualTo(tester.getRect(find.text(l10n.styleAuto)).bottom),
        reason: 'pill sits below the tiles',
      );

      // The temperature reads at full size inside its tile — not clipped
      // past the tile edge, not scaled down to fit.
      final value = find.text('20°C');
      final tile = find
          .ancestor(of: value, matching: find.byType(Material))
          .first;
      expectWithin(tester, value, tile);
      expect(
        tester.getRect(value).width,
        closeTo(tester.renderObject<RenderBox>(value).size.width, 0.5),
      );
      final styleValue = find.text(l10n.styleAuto);
      expectWithin(
        tester,
        styleValue,
        find.ancestor(of: styleValue, matching: find.byType(Material)).first,
      );
      expect(isTruncated(tester, styleValue), isFalse);
    });
  }

  testWidgets(
    'the card starts collapsed; the toggle reveals and hides temperature and style',
    (tester) async {
      applyLayoutCase(tester, layoutCases.first, height: 3000);
      await pumpApp(
        tester,
        const AddOutfitPage(),
        overrides: [garmentsProvider.overrideWith(_EmptyCloset.new)],
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AddOutfitPage)),
      );
      final toggle = find.descendant(
        of: find.ancestor(
          of: find.widgetWithText(SectionTitle, l10n.finishOutfit),
          matching: find.byType(Stack),
        ),
        matching: find.byType(CircleIconButton),
      );
      expect(find.text('20°C'), findsNothing);
      expect(find.text(l10n.styleAuto), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(
        find.widgetWithText(AccentPillButton, l10n.finishWithAi),
        findsOneWidget,
      );

      await tester.tap(toggle.first);
      await tester.pump();
      expect(find.text('20°C'), findsOneWidget);
      expect(find.text(l10n.styleAuto), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      await tester.tap(toggle.first);
      await tester.pump();
      expect(find.text('20°C'), findsNothing);
      expect(find.text(l10n.styleAuto), findsNothing);
    },
  );
}
