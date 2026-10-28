import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/create_outfit_page.dart';
import 'package:uwearis/features/pages/garment_details_page.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/cards/uwearis_insight_card.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/common/section_title.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';
import 'package:uwearis/features/widgets/garment/garment_outfit_ideas_card.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

// What GarmentUploadHelper.startAddClothingFlow builds for an unsaved
// garment (no id).
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
    // The closet-analysis cache is persisted and process-wide.
    SharedPreferences.setMockInitialValues({});
  });

  // Add mode doesn't fetch in initState, but garmentsProvider is still
  // watched; serve an empty closet instead of hitting a real socket.
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

  // Fixed pumps, not pumpAndSettle(): the sheet's loading spinner never
  // settles.
  Future<void> openAnalysisSheet(WidgetTester tester) async {
    await tester.tap(find.text('View Match'));
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
      // View Match sits in the image's bottom-left corner.
      final image = tester.getRect(find.byType(GarmentImage));
      final pill = tester.getRect(
        find.descendant(
          of: find.widgetWithText(AccentPillButton, 'View Match'),
          matching: find.byType(TextButton),
        ),
      );
      // Bottom-left, with the favorite heart's 12pt inset (image frame
      // border aside).
      expect(pill.left - image.left, closeTo(11, 0.5));
      expect(image.bottom - pill.bottom, closeTo(11, 0.5));
      expect(find.text('Add to Closet'), findsNothing);
      expect(
        find.byKey(const ValueKey('bottomActionButton-hidden')),
        findsOneWidget,
      );
    });
  });

  testWidgets('add mode: the divider above Category stays, with an even '
      'gap on both sides — no extra section gap stacked above it', (
    tester,
  ) async {
    await runWithEmptyCloset(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const GarmentDetailsPage(initialGarment: _draftGarment),
      );
      await tester.pump();

      final image = tester.getRect(find.byType(GarmentImage));
      final category = tester.getRect(find.text('CATEGORY'));
      final divider = tester
          .widgetList<Divider>(find.byType(Divider))
          .map((d) => tester.getRect(find.byWidget(d)))
          .singleWhere((r) => r.top > image.bottom && r.top < category.top);

      // +1 for the image frame's border.
      expect(
        divider.top - image.bottom,
        closeTo(AppDimens.cardHeaderGap + 1, 0.01),
      );
      expect(category.top - divider.bottom, AppDimens.cardHeaderGap);
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

    testWidgets('edit mode has no Save button; picking from the bottom sheet '
        'updates the field and saves it right away', (tester) async {
      final patches = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await openPage(tester);
        expect(find.text('Save'), findsNothing);

        await pick(tester, 'Relaxed', 'Oversized');

        expect(find.text('Oversized'), findsOneWidget);
        expect(find.text('Relaxed'), findsNothing);
        expect(patches.single['fit'], 'Oversized');
        expect(find.text('Save'), findsNothing);
      }, () => _garmentBackend(bottom, patches));
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

  // Before the garment exists, the analysis runs against the form fields
  // (GarmentService.closetAnalysis with a null garmentId).
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

      expect(find.text('View Match'), findsOneWidget);
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
                // save flow's retargeting is exercised.
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

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        expect(previewCalls, 1);
        await closeAnalysisSheet(tester);

        await tester.enterText(
          find.byType(TextField).first,
          'Preview Cache Tee',
        );
        await tester.pump();
        // The upload spinner never settles, and the upload does real file
        // I/O, so give it real time between pumps.
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

        // The preview result must already be cached under the real id.
        await pumpApp(tester, GarmentDetailsPage(initialGarment: saved!));
        await tester.pump();
        await tester.pump();

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        expect(perGarmentAnalysisCalls, 0);
      }, () => client);
    },
  );

  testWidgets('edit mode: the View Match button opens the Closet Match sheet, '
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

      // No analysis until asked.
      expect(find.text('View Match'), findsOneWidget);
      expect(find.byType(UwearisInsightCard), findsNothing);
      expect(
        find.text('How well this piece works with your closet.'),
        findsNothing,
      );

      await openAnalysisSheet(tester);

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
      expect(find.text('View Match'), findsOneWidget);
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
            matching: find.byType(GarmentOutfitIdeasCard),
          ),
          findsNWidgets(2),
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is GarmentImage && w.garmentId == 109,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is GarmentImage && w.garmentId == 205,
          ),
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

  testWidgets('edit mode: an outfit idea\'s Try It On button opens Add Outfit '
      'pre-filled with that idea\'s garments, skipping any since deleted', (
    tester,
  ) async {
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

      final addOutfit = tester.widget<CreateOutfitPage>(
        find.byType(CreateOutfitPage),
      );
      expect(addOutfit.initialGarments.map((g) => g.id), [501, 109]);
    }, () => client);
  });

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
          find.byWidgetPredicate(
            (w) => w is GarmentImage && w.garmentId == 106,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Plaid Flannel Shirt'), findsOneWidget);
      }, () => client);
    },
  );

  testWidgets('edit mode: revisiting the same garment restores the previous '
      'closet-analysis result — including after a simulated app restart — '
      'without a new network call, and never expires on its own', (
    tester,
  ) async {
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
      // Unique id so it can't hit another test's cache entry.
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

      // A fresh page State; the cache lives in GarmentService.
      await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
      await tester.pump();
      await tester.pump();

      await openAnalysisSheet(tester);
      expect(find.text('8/10'), findsOneWidget);
      expect(closetAnalysisCalls, 1);
      await closeAnalysisSheet(tester);

      // No TTL: a 30-day-old entry is still served from cache.
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
  });

  testWidgets('edit mode: the refresh action only appears once a result '
      'exists, not while showing the initial prompt', (tester) async {
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
  });

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
            // Lets the test see the old result while the refresh is in flight.
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
        // Re-analyze is the sheet's top-left action, mirroring the X.
        expect(find.text('Analyze Again'), findsNothing);
        final sheet = tester.getRect(find.byType(BottomSheet));
        expect(
          tester.getCenter(find.byIcon(Icons.refresh)),
          tester
              .getCenter(find.byIcon(Icons.close))
              .translate(-(sheet.width - 2 * (20 + ActionDisc.size / 2)), 0),
        );

        await tester.tap(find.byIcon(Icons.refresh));
        // Mid-flight the old result stays under the LoadingOverlay.
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

        // The old result stays, not the first-run error state.
        expect(find.text('8/10'), findsOneWidget);
        expect(find.text('Versatile'), findsOneWidget);
        expect(
          find.text("Couldn't analyze — please try again."),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        final cached = await GarmentService().cachedClosetAnalysis(503);
        expect(cached!.versatility.level, 8);
      }, () => client);
    },
  );

  testWidgets('edit mode: a GARMENT_NOT_FOUND closet-analysis failure shows a '
      'specific message and a retry button', (tester) async {
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
  });

  group('edit mode auto-save', () {
    const shirt = Garment(
      id: 9401,
      name: 'Oxford Shirt',
      category: GarmentCategory.top,
      subCategory: 'Shirt',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
      brand: 'Uniqlo',
      fit: 'Regular',
      silhouette: 'Boxy',
      sleeveLength: 'Long',
    );

    late List<Map<String, dynamic>> patches;
    setUp(() => patches = []);

    // Pushes the page over a placeholder home so popping is observable.
    Future<void> pushPage(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const GarmentDetailsPage(initialGarment: shirt),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> pump500(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    final backButton = find.ancestor(
      of: find.byIcon(Icons.arrow_back_ios_new_rounded),
      matching: find.byType(ActionDiscButton),
    );

    testWidgets('switching category saves once, with the attributes the new '
        'category drops already cleared', (tester) async {
      await http.runWithClient(() async {
        await pushPage(tester);

        await tester.tap(find.text('Top'));
        await pump500(tester);
        await tester.tap(find.text('Bottom').last);
        await pump500(tester);

        expect(patches, hasLength(1));
        expect(patches.single['category'], 'Bottom');
        // Boxy isn't a Bottom silhouette; bottoms have no sleeve length.
        expect(patches.single['silhouette'], isNull);
        expect(patches.single.containsKey('sleeve_length'), isFalse);
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('typing waits for a pause; clearing brand actually clears it', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await pushPage(tester);

        await tester.enterText(find.text('Uniqlo'), '');
        await tester.pump(const Duration(milliseconds: 500));
        expect(patches, isEmpty);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(patches, hasLength(1));
        expect(patches.single.containsKey('brand'), isTrue);
        expect(patches.single['brand'], isNull);
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('an emptied Product Type flags itself and keeps the saved '
        'value in the PATCH', (tester) async {
      await http.runWithClient(() async {
        await pushPage(tester);

        await tester.enterText(find.text('Shirt'), '');
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(find.text('Please enter product type'), findsOneWidget);
        expect(patches.single['sub_category'], 'Shirt');
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('rename goes through the same auto-save and updates the '
        'heading', (tester) async {
      await http.runWithClient(() async {
        await pushPage(tester);

        await tester.tap(find.byIcon(Icons.more_vert));
        await pump500(tester);
        await tester.tap(find.text('Rename'));
        await pump500(tester);
        await tester.enterText(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(TextField),
          ),
          'Blue Oxford',
        );
        await tester.pump();
        await tester.tap(
          find.descendant(of: find.byType(Dialog), matching: find.text('Save')),
        );
        await pump500(tester);

        expect(patches.single['name'], 'Blue Oxford');
        expect(find.text('Blue Oxford'), findsOneWidget);
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('back while a typed change is still waiting saves it, then '
        'pops', (tester) async {
      await http.runWithClient(() async {
        await pushPage(tester);

        await tester.enterText(find.text('Uniqlo'), 'Muji');
        await tester.pump();
        await tester.tap(backButton);
        await pump500(tester);

        expect(patches.single['brand'], 'Muji');
        expect(find.byType(GarmentDetailsPage), findsNothing);
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('a failed save offers Retry; leaving while it still fails '
        'asks before discarding', (tester) async {
      await http.runWithClient(() async {
        await pushPage(tester);

        await tester.tap(find.text('Regular'));
        await pump500(tester);
        await tester.tap(find.text('Slim').last);
        await pump500(tester);
        expect(
          find.text("Couldn't save this item. Please try again."),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await pump500(tester);

        await tester.tap(backButton);
        await pump500(tester);
        expect(find.text('You have unsaved changes'), findsOneWidget);
        await tester.tap(find.text("Don't Save"));
        await pump500(tester);
        expect(find.byType(GarmentDetailsPage), findsNothing);
      }, () => _garmentBackend(shirt, patches, fail: true));
    });
  });

  group('favorite', () {
    const saved = Garment(
      id: 7001,
      name: 'Oxford Shirt',
      category: GarmentCategory.top,
      subCategory: 'Shirt',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
    );

    testWidgets('the heart sits in the image\'s bottom-right corner and '
        'toggles is_favorite', (tester) async {
      final patches = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, const GarmentDetailsPage(initialGarment: saved));
        await tester.pump();

        final heart = find.byIcon(Icons.favorite_border);
        final image = tester.getRect(find.byType(GarmentImage));
        final disc = tester.getRect(
          find.ancestor(of: heart, matching: find.byType(DecoratedBox)).first,
        );
        expect(image.right - disc.right, closeTo(11, 0.5));
        expect(image.bottom - disc.bottom, closeTo(11, 0.5));

        await tester.tap(heart);
        await tester.pump();
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(patches, [
          {'is_favorite': true},
        ]);

        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pump();
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(patches.last, {'is_favorite': false});
      }, () => _garmentBackend(saved, patches));
    });

    testWidgets('a failed toggle reverts the heart and says so', (
      tester,
    ) async {
      final patches = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, const GarmentDetailsPage(initialGarment: saved));
        await tester.pump();

        await tester.tap(find.byIcon(Icons.favorite_border));
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(
          find.text(
            AppLocalizations.of(
              tester.element(find.byType(GarmentDetailsPage)),
            ).failedToUpdateFavorite,
          ),
          findsOneWidget,
        );
      }, () => _garmentBackend(saved, patches, fail: true));
    });

    testWidgets('add mode has no heart', (tester) async {
      await runWithEmptyCloset(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          const GarmentDetailsPage(initialGarment: _draftGarment),
        );
        await tester.pump();

        expect(find.byIcon(Icons.favorite_border), findsNothing);
        expect(find.byIcon(Icons.favorite), findsNothing);
      });
    });
  });

  testWidgets('tapping the garment photo opens it full-screen with pinch '
      'zoom on a light backdrop; tapping again closes it', (tester) async {
    const withPhoto = Garment(
      id: 7002,
      name: 'Oxford Shirt',
      category: GarmentCategory.top,
      subCategory: 'Shirt',
      uploadUrl: '',
      objectName: '',
      imageUrl: 'https://example.com/shirt.png',
    );
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const GarmentDetailsPage(initialGarment: withPhoto),
      );
      await tester.pump();

      await tester.tap(find.byType(GarmentImage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final viewer = find.byType(InteractiveViewer);
      expect(viewer, findsOneWidget);
      expect(
        tester
            .widget<Scaffold>(
              find.ancestor(of: viewer, matching: find.byType(Scaffold)).first,
            )
            .backgroundColor,
        AppColors.surface,
      );
      expect(
        tester
            .widget<GarmentImage>(
              find.descendant(of: viewer, matching: find.byType(GarmentImage)),
            )
            .url,
        'https://example.com/shirt.png',
      );

      await tester.tap(viewer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(InteractiveViewer), findsNothing);
    }, () => _garmentBackend(withPhoto, []));
  });
}

/// Records every garment PATCH body and answers with [garment] (or a 500
/// when [fail]); every other request gets an empty list.
MockClient _garmentBackend(
  Garment garment,
  List<Map<String, dynamic>> patches, {
  bool fail = false,
}) {
  return MockClient((request) async {
    if (request.method == 'PATCH') {
      patches.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (fail) return jsonResponse({'success': false}, status: 500);
      return jsonResponse(
        envelope({
          'id': garment.id,
          'name': garment.name,
          'category': garment.category.apiValue,
          'sub_category': garment.subCategory,
          'upload_url': '',
          'object_name': '',
          'image_url': '',
        }),
      );
    }
    return jsonResponse(envelope({'items': []}));
  });
}
