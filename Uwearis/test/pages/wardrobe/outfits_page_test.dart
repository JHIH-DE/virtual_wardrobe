import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/style_profile_provider.dart';
import 'package:uwearis/core/providers/style_taste_provider.dart';
import 'package:uwearis/core/providers/temperature_coverage_provider.dart';
import 'package:uwearis/data/temperature_coverage.dart';
import 'package:uwearis/data/style_profile.dart';
import 'package:uwearis/data/style_taste.dart';
import 'package:uwearis/core/utils/user_acknowledgement.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/features/pages/wardrobe/outfits_page.dart';
import 'package:uwearis/features/widgets/outfit/outfit_insights_sheet.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

class _SeededStyleTasteNotifier extends StyleTasteProfileNotifier {
  @override
  Future<StyleTasteProfile> build() async =>
      const StyleTasteProfile(status: 'ready', summary: '', preferences: []);
}

class _EmptyStyleProfileNotifier extends StyleProfileNotifier {
  @override
  Future<List<StyleProfileItem>> build() async => const [];
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets('no outfits shows the "no outfits" empty state, centered, with a '
      'Create Outfit action that opens the create-outfit flow', (tester) async {
    await pumpApp(
      tester,
      const OutfitsPage(),
      overrides: [
        outfitsProvider.overrideWith(
          () => SeededOutfitsNotifier([], refreshReseeds: true),
        ),
        garmentsProvider.overrideWith(
          () => SeededGarmentsNotifier([], refreshReseeds: true),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No outfits yet'), findsOneWidget);
    expect(
      find.text('Combine pieces from your closet into a complete look.'),
      findsOneWidget,
    );
    expect(find.text('Create Outfit'), findsOneWidget);

    await tester.tap(find.text('Create Outfit'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Match a Look'), findsOneWidget);
  });

  group('Outfit Insights button', () {
    Future<void> pumpWithOutfits(
      WidgetTester tester,
      List<Outfit> outfits,
    ) async {
      await pumpApp(
        tester,
        const OutfitsPage(),
        overrides: [
          outfitsProvider.overrideWith(() => SeededOutfitsNotifier(outfits)),
          garmentsProvider.overrideWith(() => SeededGarmentsNotifier([])),
          styleTasteProfileProvider.overrideWith(_SeededStyleTasteNotifier.new),
          styleProfileProvider.overrideWith(_EmptyStyleProfileNotifier.new),
          temperatureCoverageProvider.overrideWith(
            (ref) async => const TemperatureCoverage(
              temperatureOffsetC: 0,
              usableOutfitCount: 0,
              enoughCount: 3,
              bands: [],
            ),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('is hidden when the user has no outfits', (tester) async {
      await pumpWithOutfits(tester, const []);
      expect(find.byTooltip('Outfit Insights'), findsNothing);
    });

    testWidgets('opens Outfit Insights as a sheet over the Outfits tab', (
      tester,
    ) async {
      await pumpWithOutfits(tester, [
        Outfit(id: 1, imageUrl: '', garmentIds: const [1]),
      ]);

      await tester.tap(find.byTooltip('Outfit Insights'));
      await tester.pumpAndSettle();

      expect(find.byType(OutfitInsightsSheetContent), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(OutfitsPage), findsOneWidget);
    });

    testWidgets('declining AI consent keeps Outfit Insights closed', (
      tester,
    ) async {
      UserAcknowledgement.debugGrantedOverride = false;
      addTearDown(() => UserAcknowledgement.debugGrantedOverride = true);
      await pumpWithOutfits(tester, [
        Outfit(id: 1, imageUrl: '', garmentIds: const [1]),
      ]);

      await tester.tap(find.byTooltip('Outfit Insights'));
      await tester.pumpAndSettle();
      expect(find.text('How AI Features Use Your Data'), findsOneWidget);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
      expect(find.byType(OutfitInsightsSheetContent), findsNothing);
      expect(find.byType(OutfitsPage), findsOneWidget);
    });
  });
}
