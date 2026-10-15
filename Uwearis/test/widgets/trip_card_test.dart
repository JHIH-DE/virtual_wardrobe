import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/trip/trip_card.dart';

import '../helpers/widget_harness.dart';

void main() {
  final trip = Trip(
    id: '7',
    name: 'Kyoto Autumn',
    activities: const [],
    legs: [
      TripLeg(
        location: LocationResult(
          name: 'Kyoto',
          latitude: 35,
          longitude: 135,
          timezone: 'Asia/Tokyo',
        ),
        dateRange: DateTimeRange(
          start: DateTime(2026, 11, 1),
          end: DateTime(2026, 11, 4),
        ),
      ),
    ],
  );

  testWidgets('the "⋮" is a CircleIconButton inset like Trip Details\' '
      'and tapping it opens the trip menu', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TripCard(
            trip: trip,
            onTap: () {},
            onNameChanged: (_) {},
            onDelete: () {},
          ),
        ),
      ),
    );

    final button = find.widgetWithIcon(CircleIconButton, Icons.more_vert);
    expect(button, findsOneWidget);

    final disc = tester.getRect(
      find.descendant(of: button, matching: find.byType(DecoratedBox)).first,
    );
    final card = tester.getRect(find.byType(TripCard));
    expect(card.right - disc.right, 17);
    // Centred on the title.
    expect(disc.center.dy, tester.getCenter(find.text('Kyoto Autumn')).dy);
    expect(disc.top - card.top, 17);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Edit Name'), findsOneWidget);
    expect(find.text('Delete Trip'), findsOneWidget);
  });
}
