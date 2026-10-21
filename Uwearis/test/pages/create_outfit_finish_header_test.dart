import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/create_outfit_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/section_title.dart';
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

  // Create Outfit's Auto-Complete card: a SectionTitle + Finish with AI
  // header over a temperature stepper tile and a style tile.
  for (final c in layoutCases) {
    testWidgets('the Auto-Complete title is never squeezed beside the AI pill '
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
      final title = find.descendant(
        of: find.widgetWithText(SectionTitle, l10n.finishOutfit),
        matching: find.text(l10n.finishOutfit),
      );
      final pill = find.widgetWithText(AccentPillButton, l10n.finishWithAi);
      final pillLabel = find.descendant(
        of: pill,
        matching: find.text(l10n.finishWithAi),
      );

      expect(isTruncated(tester, pillLabel), isFalse);

      // The title gets the header's full width, never just what the pill
      // leaves over.
      final header = find.ancestor(of: title, matching: find.byType(Wrap));
      expect(
        tester.renderObject<RenderBox>(title).constraints.maxWidth,
        closeTo(tester.getSize(header).width, 0.5),
      );

      final titleRect = tester.getRect(title);
      final pillRect = tester.getRect(
        find.descendant(of: pill, matching: find.byType(TextButton)),
      );
      final sameRow = pillRect.top < titleRect.bottom;
      if (sameRow) {
        expect(renderedLineCount(tester, title), 1);
      } else {
        expect(pillRect.top, greaterThanOrEqualTo(titleRect.bottom));
      }
      if (c.width == 390 && c.scale == 1.0) {
        expect(sameRow, isTrue, reason: 'roomy case keeps one header row');
      }

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
