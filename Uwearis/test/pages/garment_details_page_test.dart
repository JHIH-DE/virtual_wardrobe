import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/garment.dart';
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

      expect(find.text('Add Clothing'), findsWidgets);
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

  testWidgets('closet-match card starts as a prompt + Analyze button', (
    tester,
  ) async {
    await runWithEmptyCloset(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const GarmentDetailsPage(
          initialAnalysisData: {'name': 'Tee', 'category': 'Top'},
        ),
      );
      await tester.pump();

      // No versatility until the user asks for it — a one-line prompt and
      // the "Analyze with AI" pill, no score ring.
      expect(
        find.text('See how well this piece works with your closet.'),
        findsOneWidget,
      );
      expect(find.text('Analyze with AI'), findsOneWidget);
      expect(find.text('Highly Versatile'), findsNothing);
    });
  });

  // Regression test for a 500 on Save: editing an existing garment and only
  // replacing its photo (no re-run of AI analysis) used to leave `_metaData`
  // null, so `completeUpload` sent `metadata: null` and the backend crashed
  // reading `metadata.thickness` on it. initState now seeds `_metaData` from
  // the garment's own already-saved metadata — this proves that seeding by
  // checking what "Analyze with AI" (which reads the same `_metaData`) sends.
  testWidgets(
    'editing an existing garment seeds Analyze-with-AI from its saved '
    'metadata',
    (tester) async {
      late http.Request scoreRequest;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/versatility-score')) {
          scoreRequest = request;
          return jsonResponse(
            envelope({
              'score': 80,
              'combination_count': 10,
              'skipped_reason': null,
              'breakdown': [],
              'message': null,
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        final garment = Garment(
          id: 501,
          name: 'Black Leather Moc Toe Work Boots',
          category: GarmentCategory.shoes,
          subCategory: 'Boots',
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
          metadata: const {
            'thickness': 4,
            'formality': 2,
            'material': 'Leather',
            'style': ['Workwear'],
            'fit': '',
            'crop_length': '',
            'description': 'Moc toe leather work boots',
          },
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();

        final body = jsonDecode(scoreRequest.body) as Map<String, dynamic>;
        final metadata = body['metadata'] as Map<String, dynamic>;
        expect(metadata['material'], 'Leather');
        expect(metadata['description'], 'Moc toe leather work boots');
      }, () => client);
    },
  );
}
