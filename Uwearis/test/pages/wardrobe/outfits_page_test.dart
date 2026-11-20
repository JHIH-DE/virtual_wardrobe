import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/features/pages/wardrobe/outfits_page.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

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
}
