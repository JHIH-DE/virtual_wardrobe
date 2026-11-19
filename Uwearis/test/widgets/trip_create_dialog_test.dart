import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/common/location_picker_page.dart';
import 'package:uwearis/features/widgets/trip/trip_create_dialog.dart';

import '../helpers/widget_harness.dart';

void main() {
  ElevatedButton createButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets(
    'Create starts disabled (greyed out), and stays disabled with only a '
    'name and no location yet',
    (tester) async {
      await pumpApp(tester, const TripCreateDialog());
      await tester.pump();

      expect(createButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Kyoto Autumn');
      await tester.pump();

      // A name alone isn't enough — still needs a location.
      expect(createButton(tester).onPressed, isNull);
    },
  );

  testWidgets('"Add Destination" sits in the itinerary card under the '
      'Itinerary & Dates label and opens the location picker', (tester) async {
    await pumpApp(tester, const TripCreateDialog());
    await tester.pump();

    final add = find.text('Add Destination');
    expect(add, findsOneWidget);
    expect(
      tester.getCenter(add).dy,
      greaterThan(tester.getCenter(find.text('ITINERARY & DATES')).dy),
    );

    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.byType(LocationPickerPage), findsOneWidget);
  });
}
