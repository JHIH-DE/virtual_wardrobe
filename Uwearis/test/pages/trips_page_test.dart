import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/trips_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/widget_harness.dart';

class _FakeTrips extends TripsNotifier {
  _FakeTrips(this._items);
  final List<Trip> _items;

  @override
  Future<List<Trip>> build() async => _items;
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets(
    'no trips shows the "no trips planned" empty state, centered, with a '
    'Plan a Trip action that opens the new-trip dialog',
    (tester) async {
      await pumpApp(
        tester,
        const TripsPage(),
        overrides: [tripsProvider.overrideWith(() => _FakeTrips([]))],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No trips planned yet'), findsOneWidget);
      expect(
        find.text(
          'Plan a trip and let Uwearis help you pack and pick outfits.',
        ),
        findsOneWidget,
      );
      expect(find.text('Plan a Trip'), findsOneWidget);

      await tester.tap(find.text('Plan a Trip'));
      await tester.pumpAndSettle();

      // TripCreateDialog's own field.
      expect(find.text('Trip Name'), findsOneWidget);
    },
  );
}
