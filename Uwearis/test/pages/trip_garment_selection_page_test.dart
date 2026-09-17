import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/trip_garment_selection_page.dart';
import 'package:uwearis/features/widgets/common/fields/number_stepper.dart';
import 'package:uwearis/features/widgets/garment/garment_card.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

Garment _garment(int id, GarmentCategory category) => Garment(
  id: id,
  garmentId: id,
  name: 'Item $id',
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
);

void main() {
  setUp(setUpFakeAuth);

  http.Client noAdviceClient() =>
      MockClient((request) async => jsonResponse(envelope({}), status: 404));

  testWidgets(
    'the quantity stepper only shows for a selected Sock, defaults to 1, '
    'and incrementing it does not deselect the card',
    (tester) async {
      await http.runWithClient(() async {
        final socks = [_garment(1, GarmentCategory.socks)];
        await pumpApp(
          tester,
          TripGarmentSelectionPage(
            tripId: 7,
            garments: socks,
            initiallySelectedIds: const {1},
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(NumberStepper), findsOneWidget);
        expect(find.text('1'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump();
        expect(find.text('2'), findsOneWidget);

        // Still selected — the stepper doesn't fall through to
        // GarmentCard's own onTap underneath it.
        final card = tester.widget<GarmentCard>(find.byType(GarmentCard));
        expect(card.isSelected, isTrue);
      }, noAdviceClient);
    },
  );

  double opacityOf(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets(
    'the stepper opens fully revealed on a fresh unselected→selected tap, '
    'but not on a later remount of an already-selected sock (e.g. switching '
    'category tabs away and back)',
    (tester) async {
      await http.runWithClient(() async {
        final garments = [
          _garment(1, GarmentCategory.socks),
          _garment(2, GarmentCategory.top),
        ];
        await pumpApp(
          tester,
          TripGarmentSelectionPage(
            tripId: 7,
            garments: garments,
            initiallySelectedIds: const {},
          ),
        );
        await tester.pump();
        await tester.pump();

        // Switch to the Socks tab and tap to select — a genuinely fresh
        // selection, so the stepper should appear fully revealed.
        await tester.tap(find.text('Socks'));
        await tester.pump();
        await tester.tap(find.byType(GarmentCard));
        await tester.pump();

        expect(find.byType(NumberStepper), findsOneWidget);
        expect(opacityOf(tester), 1);

        // Switch away to Top, then back to Socks — the sock card remounts
        // (its whole tab's SliverGrid is rebuilt), but it was already
        // selected, not freshly selected, so the stepper must not reveal.
        await tester.tap(find.text('Top'));
        await tester.pump();
        await tester.tap(find.text('Socks'));
        await tester.pump();

        expect(find.byType(NumberStepper), findsOneWidget);
        expect(opacityOf(tester), 0.6);
      }, noAdviceClient);
    },
  );

  testWidgets(
    'no stepper for a selected non-sock category',
    (tester) async {
      await http.runWithClient(() async {
        final garments = [
          _garment(1, GarmentCategory.socks),
          _garment(2, GarmentCategory.top),
        ];
        await pumpApp(
          tester,
          TripGarmentSelectionPage(
            tripId: 7,
            garments: garments,
            initiallySelectedIds: const {2}, // Top selected, sock isn't
          ),
        );
        await tester.pump();
        await tester.pump();

        // Default tab is Top (first in category order) — its selected card
        // shouldn't get a quantity stepper.
        expect(find.byType(NumberStepper), findsNothing);
      }, noAdviceClient);
    },
  );
}
