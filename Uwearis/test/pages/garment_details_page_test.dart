import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/add_outfit_page.dart';
import 'package:uwearis/features/pages/garment_details_page.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/common/buttons/action_button.dart';
import 'package:uwearis/features/widgets/common/cards/app_card_shell.dart';
import 'package:uwearis/features/widgets/common/cards/uwearis_insight_card.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/common/section_title.dart';
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

  // The closet analysis lives in a page sheet opened from the page's
  // Closet Match button. Fixed-duration pumps rather than pumpAndSettle() — the
  // sheet's loading state is an indeterminate spinner that never settles.
  Future<void> openAnalysisSheet(
    WidgetTester tester, {
    String label = 'View Closet Match',
  }) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> closeAnalysisSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
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

  group('garment attributes (fit / silhouette / sleeve / crop length)', () {
    const bottom = Garment(
      id: 9301,
      name: 'Wide Pants',
      category: GarmentCategory.bottom,
      subCategory: 'Trousers',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
      fit: 'Relaxed',
      silhouette: 'Tapered',
      sleeveLength: '',
      cropLength: 'Nine-length',
    );

    Future<void> openPage(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(tester, const GarmentDetailsPage(initialGarment: bottom));
      await tester.pump();
      await tester.pump();
    }

    Future<void> pick(WidgetTester tester, String field, String option) async {
      await tester.tap(find.text(field));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(option).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('shows only the fields the category supports', (tester) async {
      await runWithEmptyCloset(() async {
        await openPage(tester);

        expect(find.text('Relaxed'), findsOneWidget);
        expect(find.text('Tapered'), findsOneWidget);
        expect(find.text('Nine-length'), findsOneWidget);
        expect(find.text('SLEEVE LENGTH'), findsNothing);
        expect(find.byType(Slider), findsNothing);
      });
    });

    testWidgets('picking from the bottom sheet updates the field and marks '
        'the form modified', (tester) async {
      await runWithEmptyCloset(() async {
        await openPage(tester);
        expect(
          find.byKey(const ValueKey('bottomActionButton-hidden')),
          findsOneWidget,
        );

        await pick(tester, 'Relaxed', 'Oversized');

        expect(find.text('Oversized'), findsOneWidget);
        expect(find.text('Relaxed'), findsNothing);
        expect(
          find.byKey(const ValueKey('bottomActionButton-visible')),
          findsOneWidget,
        );
      });
    });

    testWidgets('switching category drops values the new category rejects', (
      tester,
    ) async {
      await runWithEmptyCloset(() async {
        await openPage(tester);

        await pick(tester, 'Bottom', 'Top');

        // Fit carries over; Tapered isn't a Top silhouette; tops have no
        // crop length but do have a sleeve length.
        expect(find.text('Relaxed'), findsOneWidget);
        expect(find.text('Tapered'), findsNothing);
        expect(find.text('Nine-length'), findsNothing);
        expect(find.text('SLEEVE LENGTH'), findsOneWidget);
      });
    });

    testWidgets('a long option list (Bottom silhouettes) shows every option '
        'at once on a phone-sized screen, without scrolling', (tester) async {
      await runWithEmptyCloset(() async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpApp(tester, const GarmentDetailsPage(initialGarment: bottom));
        await tester.pump();
        await tester.pump();

        await tester.ensureVisible(find.text('Tapered'));
        await tester.pump();
        await tester.tap(find.text('Tapered'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        final sheet = tester.getRect(find.byType(BottomSheet));
        for (final option in [
          'Straight',
          'Tapered',
          'Balloon',
          'Jogger',
          'Flared',
          'Pencil',
          'A-line',
          'Pleated',
        ]) {
          final row = tester.getRect(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.widgetWithText(ListTile, option),
            ),
          );
          expect(row.bottom, lessThanOrEqualTo(sheet.bottom), reason: option);
        }
        final sheetPosition = tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Scrollable),
              ),
            )
            .position;
        expect(sheetPosition.maxScrollExtent, 0);

        await tester.tap(find.text('Pleated'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Pleated'), findsOneWidget);
        expect(find.text('Tapered'), findsNothing);
      });
    });

    testWidgets('add mode pre-fills the attributes from AI metadata', (
      tester,
    ) async {
      await runWithEmptyCloset(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          const GarmentDetailsPage(
            initialGarment: _draftGarment,
            initialAnalysisData: {
              'name': 'Coach Jacket',
              'category': 'Outer',
              'sub_category': 'Jacket',
              'fit': 'Regular',
              'silhouette': 'Boxy',
              'sleeve_length': 'Long',
              'crop_length': '',
            },
          ),
        );
        await tester.pump();

        expect(find.text('Regular'), findsOneWidget);
        expect(find.text('Boxy'), findsOneWidget);
        expect(find.text('Long Sleeve'), findsOneWidget);
        expect(find.text('LENGTH'), findsNothing);
      });
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

  // Add mode shows the same Closet Match button as edit mode — tapping it
  // before the garment is ever saved runs a preview analysis
  // against the current form fields instead of a real garment id (see
  // GarmentService.closetAnalysis's null-garmentId mode).
  testWidgets('add mode: Uwearis AI analysis card runs a preview analysis', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/closet-analysis') &&
          (jsonDecode(request.body) as Map<String, dynamic>)['garment_id'] ==
              null) {
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
      await pumpApp(
        tester,
        const GarmentDetailsPage(
          initialGarment: _draftGarment,
          initialAnalysisData: {'name': 'Tee', 'category': 'Top'},
        ),
      );
      await tester.pump();

      expect(find.text('View Closet Match'), findsOneWidget);
      expect(find.text('Versatile'), findsNothing);

      await openAnalysisSheet(tester);

      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('Versatile'), findsOneWidget);
    }, () => client);
  });

  testWidgets('add mode: outfit ideas have no Try It On button — the '
      'garment isn\'t in the closet yet', (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/closet-analysis')) {
        return jsonResponse(
          envelope({
            'versatility': {'level': 8, 'label': 'Versatile'},
            'outfit_ideas': [
              {
                'title': 'Idea',
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
      return jsonResponse(envelope({'items': []}));
    });

    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const GarmentDetailsPage(
          initialGarment: _draftGarment,
          initialAnalysisData: {'name': 'Tee', 'category': 'Top'},
        ),
      );
      await tester.pump();

      await openAnalysisSheet(tester);

      expect(find.text('Outfit 1'), findsOneWidget);
      expect(find.text('Try It On'), findsNothing);
    }, () => client);
  });

  testWidgets(
    'a preview analysis run before Add to Closet carries over into the '
    'real per-garment cache, so reopening it shows the result without '
    're-analyzing',
    (tester) async {
      // Real file I/O never completes inside testWidgets' fake-async zone.
      final tempDir = Directory.systemTemp.createTempSync('garment_photo');
      // A real (1×1 PNG) image, since the page's photo preview decodes it.
      final photo = File('${tempDir.path}/photo.jpg')
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
            '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          ),
        );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      var previewCalls = 0;
      var perGarmentAnalysisCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path.endsWith('/closet-analysis')) {
          final garmentId =
              (jsonDecode(request.body) as Map<String, dynamic>)['garment_id'];
          if (garmentId == null) {
            previewCalls++;
            return jsonResponse(
              envelope({
                'versatility': {'level': 8, 'label': 'Versatile'},
                // Includes a target entry (sentinel id 0, no image) so the
                // save flow's retargeting is actually exercised, not just
                // the no-outfit-ideas easy case.
                'outfit_ideas': [
                  {
                    'title': 'Preview Idea',
                    'garments': [
                      {
                        'garment_id': 0,
                        'category': 'Top',
                        'name': 'Preview Cache Tee',
                        'image_url': '',
                        'is_target': true,
                      },
                    ],
                  },
                ],
                'similar_garments': <Object?>[],
              }),
            );
          }
          perGarmentAnalysisCalls++;
          return jsonResponse(
            envelope({
              'versatility': {'level': 2, 'label': 'Very Limited'},
              'outfit_ideas': <Object?>[],
              'similar_garments': <Object?>[],
            }),
          );
        }
        if (request.method == 'POST' &&
            path.endsWith('/garments/init-upload')) {
          return jsonResponse(
            envelope({
              'upload_url': 'https://example.com/upload',
              'object_name': 'obj-700501',
              'public_url': '',
            }),
          );
        }
        if (request.method == 'PUT' &&
            request.url.toString() == 'https://example.com/upload') {
          return http.Response('', 200);
        }
        if (request.method == 'POST' && path.endsWith('/garments/complete')) {
          return jsonResponse(
            envelope({
              'id': 700501,
              'category': 'Top',
              'name': 'Preview Cache Tee',
              'sub_category': 'T-Shirt',
              'image_url': 'https://cdn.example.com/700501.jpg',
              'is_favorite': false,
              'is_deleted': false,
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        Garment? saved;
        await pumpApp(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<Garment>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GarmentDetailsPage(
                        initialGarment: Garment(
                          name: '',
                          category: GarmentCategory.top,
                          subCategory: '',
                          uploadUrl: '',
                          objectName: '',
                          imageUrl: photo.path,
                        ),
                        initialAnalysisData: const {
                          'name': 'Preview Cache Tee',
                          'category': 'Top',
                          'sub_category': 'T-Shirt',
                        },
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Run the preview analysis before ever saving, then close the sheet
        // to get back to the form.
        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        expect(previewCalls, 1);
        await closeAnalysisSheet(tester);

        // Make sure Add to Closet is actually enabled, then save.
        await tester.enterText(
          find.byType(TextField).first,
          'Preview Cache Tee',
        );
        await tester.pump();
        // Same reasoning as above — the bottom button shows its own
        // indeterminate spinner (isLoading: _uploading) while the
        // init-upload/PUT/complete/cache chain runs.
        // The upload reads the photo with real file I/O, so give it real
        // time between pumps.
        await tester.tap(find.text('Add to Closet'));
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(GarmentDetailsPage), findsNothing);
        expect(saved?.id, 700501);

        // Reopen the now-real garment — the preview result must already be
        // cached under its real id, with no fresh per-garment analysis call.
        await pumpApp(tester, GarmentDetailsPage(initialGarment: saved!));
        await tester.pump();
        await tester.pump();

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        expect(perGarmentAnalysisCalls, 0);
      }, () => client);
    },
  );

  testWidgets('edit mode: the Closet Match button opens the analysis sheet, '
      'which runs it and shows the versatility result', (tester) async {
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

      // No analysis until the user asks for it — just the tinted View
      // Closet Match button under the photo, no Uwearis AI card or result.
      expect(find.text('View Closet Match'), findsOneWidget);
      expect(
        tester
            .widget<ActionButton>(find.byType(ActionButton))
            .variant,
        ActionButtonVariant.tinted,
      );
      expect(find.byType(UwearisInsightCard), findsNothing);
      expect(
        find.text('How well this piece works with your closet.'),
        findsNothing,
      );

      await openAnalysisSheet(tester);

      // The sheet itself is titled just "Closet Match".
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Closet Match'),
        ),
        findsOneWidget,
      );
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('Versatile'), findsOneWidget);

      await closeAnalysisSheet(tester);
      expect(find.text('8/10'), findsNothing);
      expect(find.text('View Closet Match'), findsOneWidget);
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

        await openAnalysisSheet(tester);

        // Ideas are titled by number, not by the backend's own idea title.
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
    'edit mode: each outfit idea gets its own card titled Outfit 1, Outfit 2, '
    '… with a "+" between its garments',
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
                    {
                      'garment_id': 110,
                      'category': 'Outer',
                      'name': 'Waxed Canvas Jacket',
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

        await openAnalysisSheet(tester);

        // Numbered titles, not the backend's own idea titles.
        expect(find.text('Rugged Workwear Layering'), findsNothing);
        expect(find.text('Clean Casual'), findsNothing);
        expect(find.text('Outfit 1'), findsOneWidget);
        expect(find.text('Outfit 2'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(AppCardShell),
          ),
          findsNWidgets(2),
        );
        expect(
          find.byWidgetPredicate((w) => w is GarmentImage && w.garmentId == 109),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) => w is GarmentImage && w.garmentId == 205),
          findsOneWidget,
        );
        // Outfit thumbnails sit borderless inside their card.
        final thumbFrame = tester.widget<Container>(
          find
              .ancestor(
                of: find.byWidgetPredicate(
                  (w) => w is GarmentImage && w.garmentId == 109,
                ),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((thumbFrame.decoration! as BoxDecoration).border, isNull);

        // One "+" — between Outfit 1's two garments; Outfit 2 has just one.
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byIcon(Icons.add),
          ),
          findsOneWidget,
        );
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: an outfit idea\'s Try It On button opens Add Outfit '
    'pre-filled with that idea\'s garments, skipping any since deleted',
    (tester) async {
      Map<String, Object?> garmentJson(int id, {bool deleted = false}) => {
        'id': id,
        'category': 'Bottom',
        'name': 'Garment $id',
        'sub_category': 'Jeans',
        'image_url': '',
        'is_favorite': false,
        'is_deleted': deleted,
      };
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path.endsWith('/closet-analysis')) {
          return jsonResponse(
            envelope({
              'versatility': {'level': 8, 'label': 'Versatile'},
              'outfit_ideas': [
                {
                  'title': 'Idea',
                  'garments': [
                    for (final id in [501, 109, 110])
                      {
                        'garment_id': id,
                        'category': 'Bottom',
                        'name': 'Garment $id',
                        'image_url': '',
                        'is_target': id == 501,
                      },
                  ],
                },
              ],
              'similar_garments': <Object?>[],
            }),
          );
        }
        if (request.method == 'GET' && path.endsWith('/garments')) {
          return jsonResponse(
            envelope({
              'items': [
                garmentJson(501),
                garmentJson(109),
                garmentJson(110, deleted: true),
              ],
              'total': 3,
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

        await openAnalysisSheet(tester);

        // Inside the outfit card only the analyzed garment (501) is framed,
        // in borderStrong; the others are borderless.
        Border? frameBorder(int id) {
          final frame = tester.widget<Container>(
            find
                .ancestor(
                  of: find.descendant(
                    of: find.byType(BottomSheet),
                    matching: find.byWidgetPredicate(
                      (w) => w is GarmentImage && w.garmentId == id,
                    ),
                  ),
                  matching: find.byType(Container),
                )
                .first,
          );
          return (frame.decoration! as BoxDecoration).border as Border?;
        }

        expect(frameBorder(501)!.top.color, AppColors.borderStrong);
        expect(frameBorder(109), isNull);

        // The button sits level with its card's "Outfit 1" title.
        expect(
          tester.getCenter(find.text('Try It On')).dy,
          tester.getCenter(find.text('Outfit 1')).dy,
        );

        await tester.tap(find.text('Try It On'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final addOutfit = tester.widget<AddOutfitPage>(
          find.byType(AddOutfitPage),
        );
        expect(addOutfit.initialGarments.map((g) => g.id), [501, 109]);
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

        await openAnalysisSheet(tester);

        // Section headings are SectionTitles in normal case.
        expect(
          find.widgetWithText(SectionTitle, 'Similar in Your Closet'),
          findsOneWidget,
        );

        // A divider separates Similar in Your Closet from what's above it.
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(AppDivider),
          ),
          findsOneWidget,
        );

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

        await openAnalysisSheet(tester);

        expect(find.text('8/10'), findsOneWidget);
        expect(closetAnalysisCalls, 1);
        await closeAnalysisSheet(tester);

        // Simulate leaving and coming back: `pumpApp` mounts a brand new
        // widget tree, so this is a fresh GarmentDetailsPage State for the
        // same garment — GarmentService's cache lives outside that State.
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        expect(closetAnalysisCalls, 1);
        await closeAnalysisSheet(tester);

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

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        expect(closetAnalysisCalls, 1);
        await closeAnalysisSheet(tester);
      }, () => client);
    },
  );

  testWidgets(
    'edit mode: the refresh action only appears once a result '
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

        await openAnalysisSheet(tester);

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

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        // Re-analyze is the sheet's top-left action now, mirroring the X —
        // no separate button below the result.
        expect(find.text('Analyze Again'), findsNothing);
        final sheet = tester.getRect(find.byType(BottomSheet));
        expect(
          tester.getCenter(find.byIcon(Icons.refresh)),
          tester.getCenter(find.byIcon(Icons.close)).translate(
            -(sheet.width - 2 * (16 + 18)),
            0,
          ),
        );

        await tester.tap(find.byIcon(Icons.refresh));
        // Mid-flight: the old result is still there, under the sheet's
        // LoadingOverlay — refresh regenerates, it never deletes first.
        await tester.pump();
        expect(find.text('8/10'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(LoadingOverlay),
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(LoadingOverlay), findsNothing);
        expect(find.text('3/10'), findsOneWidget);
        expect(find.text('8/10'), findsNothing);
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

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pump();
        await tester.pump();

        // The old result is still the whole card — not replaced by the
        // full-body error state that a first-run failure would show.
        expect(find.text('8/10'), findsOneWidget);
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

        await openAnalysisSheet(tester);

        expect(
          find.text('This item could no longer be found in your closet.'),
          findsOneWidget,
        );
        expect(find.text('Analyze Again'), findsOneWidget);
      }, () => client);
    },
  );
}
