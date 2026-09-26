import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/garment_details_page.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

// Matches the shape GarmentUploadHelper.startAddClothingFlow actually
// constructs for a not-yet-saved garment (no id) — GarmentDetailsPage now
// requires initialGarment, so add-mode tests need a stand-in for "nothing
// has been picked/entered yet" rather than the page's own default.
const _draftGarment = Garment(
  name: '',
  category: GarmentCategory.top,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
);

void main() {
  setUp(() {
    setUpFakeAuth();
    // GarmentService's closet-analysis cache is SharedPreferences-backed
    // and process-wide — without this, a garment id reused across tests
    // could inherit another test's cached result.
    SharedPreferences.setMockInitialValues({});
  });

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
      await pumpApp(
        tester,
        const GarmentDetailsPage(initialGarment: _draftGarment),
      );
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
      await pumpApp(
        tester,
        const GarmentDetailsPage(initialGarment: _draftGarment),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Blue Oxford Shirt');
      await tester.pump();

      expect(find.text('Add to Closet'), findsOneWidget);
    });
  });

  // The Uwearis AI card only shows once the garment is actually in the
  // closet (closet-analysis needs a real garment id) — Add mode has no
  // insight card at all.
  testWidgets('add mode has no Uwearis AI analysis card', (tester) async {
    await runWithEmptyCloset(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const GarmentDetailsPage(
          initialGarment: _draftGarment,
          initialAnalysisData: {'name': 'Tee', 'category': 'Top'},
        ),
      );
      await tester.pump();

      expect(find.text('Analyze with AI'), findsNothing);
    });
  });

  testWidgets('edit mode: closet-analysis card starts as a prompt + Analyze '
      'button, then shows the versatility result', (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/closet-analysis')) {
        return jsonResponse(
          envelope({
            'versatility': {'level': 8, 'label': 'Versatile'},
            'outfit_ideas': <Object?>[],
            'similar_garments': <Object?>[],
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
      );
      await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
      await tester.pump();
      await tester.pump();

      // No analysis until the user asks for it — a one-line prompt and the
      // "Analyze with AI" pill, no result yet.
      expect(
        find.text('How well this piece works with your closet.'),
        findsOneWidget,
      );
      expect(find.text('Analyze with AI'), findsOneWidget);
      expect(find.text('Versatile'), findsNothing);

      await tester.tap(find.text('Analyze with AI'));
      await tester.pump();
      await tester.pump();

      expect(find.text('LEVEL 8'), findsOneWidget);
      expect(find.text('Versatile'), findsOneWidget);
    }, () => client);
  });

  testWidgets(
    'edit mode: tapping an outfit-idea garment opens the garment detail '
    'dialog',
    (tester) async {
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          return jsonResponse(
            envelope({
              'versatility': {'level': 8, 'label': 'Versatile'},
              'outfit_ideas': [
                {
                  'title': 'Rugged Workwear Layering',
                  'garments': [
                    {
                      'garment_id': 109,
                      'category': 'Bottom',
                      'name': 'Wide Tapered Denim Pants',
                      'image_url': '',
                      'is_target': false,
                    },
                  ],
                },
              ],
              'similar_garments': <Object?>[],
            }),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/garments/109')) {
          return jsonResponse(
            envelope({
              'id': 109,
              'category': 'Bottom',
              'name': 'Wide Tapered Denim Pants',
              'sub_category': 'Jeans',
              'image_url': '',
              'is_favorite': false,
              'is_deleted': false,
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
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();

        // The outfit idea's title isn't shown — just its garment thumbnails,
        // separated from other ideas by a divider (see _buildResult).
        expect(find.text('Rugged Workwear Layering'), findsNothing);
        final thumbFinder = find.byWidgetPredicate(
          (w) => w is GarmentImage && w.garmentId == 109,
        );
        expect(thumbFinder, findsOneWidget);

        await tester.tap(thumbFinder);
        await tester.pump();
        await tester.pump();

        expect(find.text('Wide Tapered Denim Pants'), findsOneWidget);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: multiple outfit ideas show no title and are separated by '
    'a divider',
    (tester) async {
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          return jsonResponse(
            envelope({
              'versatility': {'level': 8, 'label': 'Versatile'},
              'outfit_ideas': [
                {
                  'title': 'Rugged Workwear Layering',
                  'garments': [
                    {
                      'garment_id': 109,
                      'category': 'Bottom',
                      'name': 'Wide Tapered Denim Pants',
                      'image_url': '',
                      'is_target': false,
                    },
                  ],
                },
                {
                  'title': 'Clean Casual',
                  'garments': [
                    {
                      'garment_id': 205,
                      'category': 'Top',
                      'name': 'White Tee',
                      'image_url': '',
                      'is_target': false,
                    },
                  ],
                },
              ],
              'similar_garments': <Object?>[],
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
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        final dividersBefore = find.byType(AppDivider).evaluate().length;

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Rugged Workwear Layering'), findsNothing);
        expect(find.text('Clean Casual'), findsNothing);
        expect(
          find.byWidgetPredicate((w) => w is GarmentImage && w.garmentId == 109),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) => w is GarmentImage && w.garmentId == 205),
          findsOneWidget,
        );
        // Exactly one new divider — the one separator between the two ideas.
        expect(find.byType(AppDivider).evaluate().length, dividersBefore + 1);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: tapping a similar-in-closet garment opens the garment '
    'detail dialog',
    (tester) async {
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          return jsonResponse(
            envelope({
              'versatility': {'level': 8, 'label': 'Versatile'},
              'outfit_ideas': <Object?>[],
              'similar_garments': [
                {
                  'garment_id': 106,
                  'name': 'Plaid Flannel Shirt',
                  'category': 'Top',
                  'image_url': '',
                },
              ],
            }),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/garments/106')) {
          return jsonResponse(
            envelope({
              'id': 106,
              'category': 'Top',
              'name': 'Plaid Flannel Shirt',
              'sub_category': 'Shirt',
              'image_url': '',
              'is_favorite': false,
              'is_deleted': false,
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
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();

        await tester.tap(
          find.byWidgetPredicate((w) => w is GarmentImage && w.garmentId == 106),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Plaid Flannel Shirt'), findsOneWidget);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: revisiting the same garment restores the previous '
    'closet-analysis result — including after a simulated app restart — '
    'without a new network call, and never expires on its own',
    (tester) async {
      var closetAnalysisCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          closetAnalysisCalls++;
          return jsonResponse(
            envelope({
              'versatility': {'level': 8, 'label': 'Versatile'},
              'outfit_ideas': <Object?>[],
              'similar_garments': <Object?>[],
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        // A garment id unique to this test, so it can't collide with a
        // cache entry another test happened to leave behind on the
        // GarmentService singleton.
        final garment = Garment(
          id: 900109,
          name: 'Cache Restore Test Jacket',
          category: GarmentCategory.outer,
          subCategory: 'Jacket',
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
        );

        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();

        expect(find.text('LEVEL 8'), findsOneWidget);
        expect(closetAnalysisCalls, 1);

        // Simulate leaving and coming back: `pumpApp` mounts a brand new
        // widget tree, so this is a fresh GarmentDetailsPage State for the
        // same garment — GarmentService's cache lives outside that State.
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        expect(find.text('LEVEL 8'), findsOneWidget);
        expect(find.text('Analyze with AI'), findsNothing);
        expect(closetAnalysisCalls, 1);

        // No TTL: rewrite the persisted entry's own analyzed_at far into
        // the past and confirm a third visit still reads it from cache
        // rather than treating it as stale.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('closet_analysis_900109')!;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded['analyzed_at'] = DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String();
        await prefs.setString('closet_analysis_900109', jsonEncode(decoded));

        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        expect(find.text('LEVEL 8'), findsOneWidget);
        expect(find.text('Analyze with AI'), findsNothing);
        expect(closetAnalysisCalls, 1);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: the header refresh action only appears once a result '
    'exists, not while showing the initial prompt',
    (tester) async {
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          return jsonResponse(
            envelope({
              'versatility': {'level': 8, 'label': 'Versatile'},
              'outfit_ideas': <Object?>[],
              'similar_garments': <Object?>[],
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
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.refresh), findsNothing);

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.refresh), findsOneWidget);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: tapping refresh keeps showing the old result while it '
    'runs, then replaces it (and the persisted cache) with the new one',
    (tester) async {
      var call = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          call++;
          if (call == 2) {
            // A beat so the test can observe the old result still showing
            // while the refresh is in flight, rather than it resolving
            // within the same pump as the tap.
            await Future.delayed(const Duration(milliseconds: 50));
          }
          return jsonResponse(
            envelope({
              'versatility': {
                'level': call == 1 ? 8 : 3,
                'label': call == 1 ? 'Versatile' : 'Limited',
              },
              'outfit_ideas': <Object?>[],
              'similar_garments': <Object?>[],
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        final garment = Garment(
          id: 502,
          name: 'Refresh Success Test Jacket',
          category: GarmentCategory.outer,
          subCategory: 'Jacket',
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();
        expect(find.text('LEVEL 8'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.refresh));
        // Mid-flight: the old result is still on screen — refresh
        // regenerates, it never deletes first.
        await tester.pump();
        expect(find.text('LEVEL 8'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('LEVEL 3'), findsOneWidget);
        expect(find.text('LEVEL 8'), findsNothing);
        expect(find.text('Limited'), findsOneWidget);

        final cached = await GarmentService().cachedClosetAnalysis(502);
        expect(cached!.versatility.level, 3);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: a failed refresh keeps the old result and its cache, and '
    'shows a brief error instead of replacing the card',
    (tester) async {
      var call = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          call++;
          if (call == 1) {
            return jsonResponse(
              envelope({
                'versatility': {'level': 8, 'label': 'Versatile'},
                'outfit_ideas': <Object?>[],
                'similar_garments': <Object?>[],
              }),
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'boom',
              'data': null,
              'error_code': 'AI_GENERATION_FAILED',
            }),
            500,
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        final garment = Garment(
          id: 503,
          name: 'Refresh Failure Test Jacket',
          category: GarmentCategory.outer,
          subCategory: 'Jacket',
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();
        expect(find.text('LEVEL 8'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pump();
        await tester.pump();

        // The old result is still the whole card — not replaced by the
        // full-body error state that a first-run failure would show.
        expect(find.text('LEVEL 8'), findsOneWidget);
        expect(find.text('Versatile'), findsOneWidget);
        expect(
          find.text("Couldn't analyze — please try again."),
          findsOneWidget,
        );
        // Still available to try again.
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        final cached = await GarmentService().cachedClosetAnalysis(503);
        expect(cached!.versatility.level, 8);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: a GARMENT_NOT_FOUND closet-analysis failure shows a '
    'specific message and a retry button',
    (tester) async {
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'not found',
              'data': null,
              'error_code': 'GARMENT_NOT_FOUND',
            }),
            404,
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
        );
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Analyze with AI'));
        await tester.pump();
        await tester.pump();

        expect(
          find.text('This item could no longer be found in your closet.'),
          findsOneWidget,
        );
        expect(find.text('Analyze Again'), findsOneWidget);
      }, () => client);
    },
  );
}
