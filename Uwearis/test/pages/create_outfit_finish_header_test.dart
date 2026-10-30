import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/create_outfit_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/cards/app_card_shell.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

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

  // Create Outfit's AI Styling card: title and description with the Go pill
  // on their right, then a temperature stepper tile and a style tile.
  for (final c in layoutCases) {
    testWidgets('the AI Styling card stays readable '
        'at ${describeCase(c)}', (tester) async {
      applyLayoutCase(tester, c, height: 3000);
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: [garmentsProvider.overrideWith(_EmptyCloset.new)],
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CreateOutfitPage)),
      );
      final title = find.text(l10n.finishOutfit);
      final pill = find.widgetWithText(AccentPillButton, l10n.finishWithAi);
      final pillLabel = find.descendant(
        of: pill,
        matching: find.text(l10n.finishWithAi),
      );
      final card = find
          .ancestor(of: pill, matching: find.byType(AppCardShell))
          .first;

      expect(isTruncated(tester, pillLabel), isFalse);
      final description = find.text(l10n.finishOutfitDescription);
      expectNoBrokenWords(tester, title);
      expectNoBrokenWords(tester, description);
      expectWithin(tester, title, card);
      expectWithin(tester, description, card);
      expect(
        tester.getRect(description).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('20°C')).top),
      );
      expectWithin(tester, pill, card);
      expect(
        tester.getRect(pill).left,
        greaterThanOrEqualTo(tester.getRect(description).right),
      );
      expect(
        tester.getRect(pill).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('20°C')).top),
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
}
