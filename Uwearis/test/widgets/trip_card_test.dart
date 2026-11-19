import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
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
    expect(card.right - disc.right, 12);
    // Centred on the title.
    expect(disc.center.dy, tester.getCenter(find.text('Kyoto Autumn')).dy);
    expect(disc.top - card.top, 12);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Edit Name'), findsOneWidget);
    expect(find.text('Delete Trip'), findsOneWidget);
  });

  // P2-1 batch 3: Trip Card's delete confirm now comes from
  // showConfirmDialog; it stays destructive and only Delete deletes.
  testWidgets('Delete Trip: destructive; Cancel keeps it, Delete calls '
      'onDelete once', (tester) async {
    var deletes = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TripCard(
            trip: trip,
            onTap: () {},
            onNameChanged: (_) {},
            onDelete: () => deletes++,
          ),
        ),
      ),
    );
    Future<void> openDelete() async {
      await tester.tap(find.widgetWithIcon(CircleIconButton, Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Trip'));
      await tester.pumpAndSettle();
    }

    await openDelete();
    final dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, 'Delete Trip');
    expect(dialog.body, 'Are you sure you want to delete this trip?');
    expect(dialog.primaryLabel, 'Delete');
    expect(dialog.destructive, isTrue);
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await tester.pumpAndSettle();
    expect(deletes, 0);

    await openDelete();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
  });
}
