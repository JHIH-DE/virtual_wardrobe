import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/features/pages/garment_details_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUp(setUpFakeAuth);

  // Add mode (no initialGarment => no id) never fetches in initState, but
  // the outfit-potential card watches garmentsProvider, so give that an
  // empty closet rather than letting it hit a real socket.
  Future<void> runWithEmptyCloset(Future<void> Function() body) {
    return http.runWithClient(
      body,
      () => MockClient((_) async => jsonResponse(envelope({'items': []}))),
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('add mode: title, gated Add-to-Closet bar, empty color field', (
    tester,
  ) async {
    await runWithEmptyCloset(() async {
      useTallSurface(tester);
      await pumpApp(tester, const GarmentDetailsPage());
      await tester.pump();

      expect(find.text('New Clothing'), findsWidgets);
      expect(find.text('Select Color'), findsOneWidget);
      expect(find.text('Add to Closet'), findsNothing);
      expect(
        find.byKey(const ValueKey('bottomActionButton-hidden')),
        findsOneWidget,
      );
    });
  });

  testWidgets('editing the name reveals the Add-to-Closet bar', (tester) async {
    await runWithEmptyCloset(() async {
      useTallSurface(tester);
      await pumpApp(tester, const GarmentDetailsPage());
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Blue Oxford Shirt');
      await tester.pump();

      expect(find.text('Add to Closet'), findsOneWidget);
    });
  });

  testWidgets('renders the outfit potential card when versatility is supplied', (
    tester,
  ) async {
    await runWithEmptyCloset(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const GarmentDetailsPage(
          initialAnalysisData: {'name': 'Tee', 'category': 'Top'},
          initialVersatility: {
            'score': 82,
            'breakdown': [
              {
                'category': 'Bottom',
                'compatible_count': 4,
                'compatible_garment_ids': [1, 2],
              },
            ],
          },
        ),
      );
      await tester.pump();

      expect(find.text('Highly Versatile'), findsOneWidget);
      expect(find.textContaining('well with 4 items'), findsOneWidget);
    });
  });
}
