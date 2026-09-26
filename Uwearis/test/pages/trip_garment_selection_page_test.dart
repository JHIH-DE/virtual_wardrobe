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
    'a selected Sock renders as a plain GarmentCard — no quantity stepper '
    '(removed feature)',
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

        expect(find.byType(NumberStepper), findsNothing);
        final card = tester.widget<GarmentCard>(find.byType(GarmentCard));
        expect(card.isSelected, isTrue);
      }, noAdviceClient);
    },
  );

  testWidgets(
    'tapping an unselected garment card selects it (still works with the '
    'stepper removed)',
    (tester) async {
      await http.runWithClient(() async {
        final garments = [_garment(1, GarmentCategory.socks)];
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

        var card = tester.widget<GarmentCard>(find.byType(GarmentCard));
        expect(card.isSelected, isFalse);

        await tester.tap(find.byType(GarmentCard));
        await tester.pump();

        card = tester.widget<GarmentCard>(find.byType(GarmentCard));
        expect(card.isSelected, isTrue);
        expect(find.byType(NumberStepper), findsNothing);
      }, noAdviceClient);
    },
  );
}
