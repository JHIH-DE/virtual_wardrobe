import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/core/providers/sub_category_provider.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/core/services/outfit_service.dart';
import 'package:uwearis/data/bag_details.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/garment_sub_category.dart';
import 'package:uwearis/features/pages/wardrobe/create_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/garment_details_page.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/common/fields/app_text_field.dart';
import 'package:uwearis/features/widgets/common/fields/picker_field.dart';
import 'package:uwearis/features/widgets/common/fields/labeled_field.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/common/section_title.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';
import 'package:uwearis/features/widgets/garment/garment_outfit_ideas_card.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/mock_http.dart';
import '../../helpers/text_scale_harness.dart';
import '../../helpers/widget_harness.dart';

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

      // Add mode's toolbar title is always shown, not faded in on scroll.
      expect(
        find.ancestor(
          of: find.text('Add Clothing'),
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
      );
      expect(find.text('Add Clothing'), findsOneWidget);
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('Do you own this item?'), findsOneWidget);
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

  testWidgets('add mode: the divider above Name stays, with an even '
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
      final name = tester.getRect(find.text('NAME'));
      final divider = tester
          .widgetList<Divider>(find.byType(Divider))
          .map((d) => tester.getRect(find.byWidget(d)))
          .singleWhere((r) => r.top > image.bottom && r.top < name.top);

      // +1 for the image frame's border.
      expect(
        divider.top - image.bottom,
        closeTo(AppDimens.cardHeaderGap + 1, 0.01),
      );
      expect(name.top - divider.bottom, AppDimens.cardHeaderGap);
    });
  });

  testWidgets(
    'add mode: ownership defaults to owned and can switch to Not yet',
    (tester) async {
      await runWithEmptyCloset(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          const GarmentDetailsPage(initialGarment: _draftGarment),
        );
        await tester.pump();

        bool? groupValue() => tester
            .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
            .groupValue;
        expect(groupValue(), isTrue);
        await tester.tap(find.text('Not yet'));
        await tester.pump();
        expect(groupValue(), isFalse);
      });
    },
  );

  group('add mode: ownership options', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      testWidgets('${describeCase(c)}: side by side when both fit, '
          'stacked otherwise, never cut', (tester) async {
        await runWithEmptyCloset(() async {
          applyLayoutCase(tester, c, height: 2400);
          await pumpApp(
            tester,
            const GarmentDetailsPage(initialGarment: _draftGarment),
          );
          await tester.pump();

          final radios = find.byType(Radio<bool>);
          final labels = find.descendant(
            of: find.byType(RadioGroup<bool>),
            matching: find.byType(Text),
          );
          expect(labels, findsNWidgets(2));
          for (var i = 0; i < 2; i++) {
            expect(renderedLineCount(tester, labels.at(i)), 1);
            expectNoBrokenWords(tester, labels.at(i));
          }
          final sideBySide =
              tester.getTopLeft(radios.at(0)).dy ==
              tester.getTopLeft(radios.at(1)).dy;
          if (c.width == 390 && c.scale == 1.0) expect(sideBySide, isTrue);
          if (!sideBySide) {
            expect(
              tester.getTopLeft(radios.at(1)).dy,
              greaterThan(tester.getBottomLeft(radios.at(0)).dy - 0.5),
            );
          }
        });
      });
    }
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
              'closure': 'Button',
              'crop_length': '',
            },
          ),
        );
        await tester.pump();

        expect(find.text('Regular'), findsOneWidget);
        expect(find.text('Boxy'), findsOneWidget);
        expect(find.text('Long Sleeve'), findsOneWidget);
        expect(find.text('Buttons'), findsOneWidget);
        expect(find.text('LENGTH'), findsNothing);
      });
    });

    group('AI-detected brand', () {
      final brandField = find.byWidgetPredicate(
        (w) =>
            w is AppTextField &&
            w.hint == 'What is the brand of this clothing?',
      );
      String brandText(WidgetTester tester) =>
          tester.widget<AppTextField>(brandField).controller!.text;

      Future<void> pumpWithAnalysis(
        WidgetTester tester,
        Map<String, dynamic> analysis, {
        Garment garment = _draftGarment,
      }) async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          GarmentDetailsPage(
            initialGarment: garment,
            initialAnalysisData: {
              'name': 'TNF Check Shirt',
              'category': 'Top',
              ...analysis,
            },
          ),
        );
        await tester.pump();
      }

      testWidgets('add mode fills an empty brand field', (tester) async {
        await runWithEmptyCloset(() async {
          await pumpWithAnalysis(tester, {'brand': '  The North Face '});
          expect(brandText(tester), 'The North Face');
        });
      });

      testWidgets('a null brand leaves the field empty', (tester) async {
        await runWithEmptyCloset(() async {
          await pumpWithAnalysis(tester, {'brand': null});
          expect(brandText(tester), '');
        });
      });

      testWidgets('an AI brand past 100 code points is cut to fit', (
        tester,
      ) async {
        await runWithEmptyCloset(() async {
          await pumpWithAnalysis(tester, {'brand': 'B' * 130});
          expect(brandText(tester), 'B' * 100);
        });
      });

      testWidgets('never replaces a brand already in the field', (
        tester,
      ) async {
        await runWithEmptyCloset(() async {
          await pumpWithAnalysis(tester, {
            'brand': 'The North Face',
          }, garment: _draftGarment.copyWith(brand: 'Uniqlo'));
          expect(brandText(tester), 'Uniqlo');
        });
      });

      testWidgets('the brand field stops at 100 characters', (tester) async {
        await runWithEmptyCloset(() async {
          await pumpWithAnalysis(tester, {});
          await tester.enterText(
            find.descendant(
              of: brandField,
              matching: find.byType(EditableText),
            ),
            'x' * 120,
          );
          await tester.pump();
          expect(brandText(tester).length, 100);
        });
      });

      // The backend counts code points: 👍🏽 is one character on screen but
      // two code points, so 60 of them would be 120.
      testWidgets('the brand field caps code points, not on-screen '
          'characters, and never splits one', (tester) async {
        await runWithEmptyCloset(() async {
          await pumpWithAnalysis(tester, {});
          await tester.enterText(
            find.descendant(
              of: brandField,
              matching: find.byType(EditableText),
            ),
            '👍🏽' * 60,
          );
          await tester.pump();
          expect(brandText(tester), '👍🏽' * 50);
          expect(brandText(tester).runes.length, 100);
        });
      });
    });

    testWidgets('closure shows only on an Outer, saves right away, and is '
        'dropped when the category changes', (tester) async {
      const jacket = Garment(
        id: 9302,
        name: 'Denim Jacket',
        category: GarmentCategory.outer,
        subCategory: 'Denim jacket',
        uploadUrl: '',
        objectName: '',
        imageUrl: '',
        sleeveLength: 'Long',
        closure: 'Zipper',
      );
      final patches = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, const GarmentDetailsPage(initialGarment: jacket));
        await tester.pump();
        await tester.pump();
        expect(find.text('CLOSURE'), findsOneWidget);

        await pick(tester, 'Zipper', 'Buttons');
        expect(find.text('Buttons'), findsOneWidget);
        expect(patches.last['closure'], 'Button');

        await pick(tester, 'Outer', 'Top');
        expect(find.text('CLOSURE'), findsNothing);
        expect(patches.last.containsKey('closure'), isFalse);
      }, () => _garmentBackend(jacket, patches));
    });

    group('bag fields', () {
      const sacoche = Garment(
        id: 288,
        name: 'PORTER Sacoche',
        category: GarmentCategory.accessory,
        subCategory: 'Bag',
        uploadUrl: '',
        objectName: '',
        imageUrl: '',
        bagDetails: BagDetails(
          bagType: BagType.sacoche,
          strapWidthClass: StrapWidthClass.thin,
        ),
      );

      Future<void> openBag(WidgetTester tester, Garment garment) async {
        useTallSurface(tester);
        await pumpApp(tester, GarmentDetailsPage(initialGarment: garment));
        await tester.pump();
        await tester.pump();
      }

      testWidgets('show the stored values', (tester) async {
        await runWithEmptyCloset(() async {
          await openBag(tester, sacoche);

          expect(find.text('BAG TYPE'), findsOneWidget);
          expect(find.text('Sacoche'), findsOneWidget);
          expect(find.text('Thin'), findsOneWidget);
          // Removed fields.
          expect(find.text('WAYS TO CARRY'), findsNothing);
          expect(find.text('USUAL CARRY'), findsNothing);
          expect(find.text('STRAP'), findsNothing);
          expect(find.text('TOP HANDLE'), findsNothing);
          expect(find.text('STRAP WIDTH (CM)'), findsNothing);
        });
      });

      testWidgets('a pick saves the whole bag_details right away', (
        tester,
      ) async {
        final patches = <Map<String, dynamic>>[];
        await http.runWithClient(() async {
          await openBag(tester, sacoche);

          await pick(tester, 'Thin', 'Wide');
          expect(patches.last['bag_details'], {
            'bag_type': 'sacoche',
            'body_width_cm': null,
            'strap_width_class': 'wide',
          });

          await pick(tester, 'Sacoche', 'Tote');
          expect(patches.last['bag_details']['bag_type'], 'tote');
        }, () => _garmentBackend(sacoche, patches));
      });

      testWidgets('the width saves after typing; an out-of-range value is '
          'flagged and not sent', (tester) async {
        final patches = <Map<String, dynamic>>[];
        await http.runWithClient(() async {
          await openBag(tester, sacoche);
          final width = find.widgetWithText(
            AppTextField,
            'Measure the body, without the strap',
          );

          await tester.enterText(width, '25');
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
          expect(patches.last['bag_details']['body_width_cm'], 25.0);

          await tester.enterText(width, '250');
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
          expect(find.text('Enter a width from 3 to 150 cm'), findsOneWidget);
          // The invalid value keeps the last saved one.
          expect(patches.last['bag_details']['body_width_cm'], isNull);
        }, () => _garmentBackend(sacoche, patches));
      });

      testWidgets(
        'leaving the bag category hides them and stops sending them',
        (tester) async {
          final patches = <Map<String, dynamic>>[];
          await http.runWithClient(() async {
            await openBag(tester, sacoche);

            await pick(tester, 'Accessory', 'Top');
            expect(find.text('BAG TYPE'), findsNothing);
            expect(patches.last.containsKey('bag_details'), isFalse);
          }, () => _garmentBackend(sacoche, patches));
        },
      );

      testWidgets('a legacy bag with nothing filled in sends no bag_details', (
        tester,
      ) async {
        final legacy = sacoche.copyWith(clearBagDetails: true);
        final patches = <Map<String, dynamic>>[];
        await http.runWithClient(() async {
          await openBag(tester, legacy);
          expect(find.text('BAG TYPE'), findsOneWidget);

          await tester.enterText(
            find.widgetWithText(
              AppTextField,
              "What is the brand of this clothing?",
            ),
            'PORTER',
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }, () => _garmentBackend(legacy, patches));
        expect(patches, isNotEmpty);
        expect(patches.where((p) => p.containsKey('bag_details')), isEmpty);
      });

      testWidgets('add mode pre-fills them from AI metadata', (tester) async {
        await runWithEmptyCloset(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            const GarmentDetailsPage(
              initialGarment: _draftGarment,
              initialAnalysisData: {
                'name': 'PORTER Sacoche',
                'category': 'Accessory',
                'sub_category': 'Bag',
                'bag_details': {
                  'bag_type': 'sacoche',
                  'body_width_cm': null,
                  'strap_width_class': 'thin',
                },
              },
            ),
          );
          await tester.pump();

          expect(find.text('Sacoche'), findsOneWidget);
          expect(find.text('Thin'), findsOneWidget);
        });
      });
    });
  });

  group('add mode: form values', () {
    Finder addToCloset() => find.text('Add to Closet');

    Future<void> openDraft(WidgetTester tester, Garment draft) async {
      useTallSurface(tester);
      await pumpApp(tester, GarmentDetailsPage(initialGarment: draft));
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

    /// The text field showing [text] now, still found after its text changes.
    Finder textFieldShowing(WidgetTester tester, String text) {
      final element = find
          .byWidgetPredicate(
            (w) => w is TextField && w.controller?.text == text,
          )
          .evaluate()
          .single;
      return find.byElementPredicate((e) => identical(e, element));
    }

    const bottomDraft = Garment(
      name: 'Wide Pants',
      category: GarmentCategory.bottom,
      subCategory: 'Trousers',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
      fit: 'Relaxed',
      silhouette: 'Tapered',
      cropLength: 'Nine-length',
      brand: 'Uniqlo',
      price: 1990,
    );

    testWidgets('a text field edit shows Add to Closet; typing the starting '
        'text back hides it again', (tester) async {
      await runWithEmptyCloset(() async {
        await openDraft(tester, bottomDraft);
        expect(addToCloset(), findsNothing);

        for (final (start, changed) in [
          ('Wide Pants', 'Wide Pants 2'),
          ('Uniqlo', 'Uniqlo U'),
          ('1990.0', '2490'),
        ]) {
          final field = textFieldShowing(tester, start);
          await tester.enterText(field, changed);
          await tester.pump();
          expect(addToCloset(), findsOneWidget, reason: changed);
          await tester.enterText(field, start);
          await tester.pump();
          expect(addToCloset(), findsNothing, reason: start);
        }
        // Whitespace is a change to the field as typed.
        final name = textFieldShowing(tester, 'Wide Pants');
        await tester.enterText(name, 'Wide Pants ');
        await tester.pump();
        expect(addToCloset(), findsOneWidget);
      });
    });

    testWidgets('an attribute pick shows Add to Closet; picking the starting '
        'value back hides it again', (tester) async {
      await runWithEmptyCloset(() async {
        await openDraft(tester, bottomDraft);

        await pick(tester, 'Relaxed', 'Oversized');
        expect(addToCloset(), findsOneWidget);
        await pick(tester, 'Oversized', 'Relaxed');
        expect(addToCloset(), findsNothing);

        await pick(tester, 'Tapered', 'Straight');
        expect(addToCloset(), findsOneWidget);
        await pick(tester, 'Straight', 'Tapered');
        expect(addToCloset(), findsNothing);
      });
    });

    testWidgets('a category round trip that drops nothing ends unmodified', (
      tester,
    ) async {
      await runWithEmptyCloset(() async {
        await openDraft(
          tester,
          const Garment(
            name: 'Tee',
            category: GarmentCategory.top,
            subCategory: '',
            uploadUrl: '',
            objectName: '',
            imageUrl: '',
            fit: 'Slim',
          ),
        );
        await pick(tester, 'Top', 'Bottom');
        expect(addToCloset(), findsOneWidget);
        await pick(tester, 'Bottom', 'Top');
        expect(addToCloset(), findsNothing);
      });
    });

    testWidgets('a category round trip that drops an attribute stays '
        'modified', (tester) async {
      await runWithEmptyCloset(() async {
        await openDraft(tester, bottomDraft);
        // Tops have no crop length and Tapered isn't a Top silhouette.
        await pick(tester, 'Bottom', 'Top');
        await pick(tester, 'Top', 'Bottom');
        expect(addToCloset(), findsOneWidget);
      });
    });

    testWidgets('bag type and body width count as edits, and undoing them '
        'counts as unmodified', (tester) async {
      await runWithEmptyCloset(() async {
        await openDraft(
          tester,
          const Garment(
            name: 'PORTER Sacoche',
            category: GarmentCategory.accessory,
            subCategory: 'Bag',
            uploadUrl: '',
            objectName: '',
            imageUrl: '',
            bagDetails: BagDetails(
              bagType: BagType.sacoche,
              strapWidthClass: StrapWidthClass.thin,
            ),
          ),
        );
        expect(addToCloset(), findsNothing);

        await pick(tester, 'Thin', 'Wide');
        expect(addToCloset(), findsOneWidget);
        await pick(tester, 'Wide', 'Thin');
        expect(addToCloset(), findsNothing);

        final width = find.widgetWithText(
          AppTextField,
          'Measure the body, without the strap',
        );
        final widthField = find.descendant(
          of: width,
          matching: find.byType(TextField),
        );
        final element = widthField.evaluate().single;
        final stable = find.byElementPredicate((e) => identical(e, element));
        await tester.enterText(stable, '25');
        await tester.pump();
        expect(addToCloset(), findsOneWidget);
        await tester.enterText(stable, '');
        await tester.pump();
        expect(addToCloset(), findsNothing);
      });
    });

    testWidgets(
      'AI metadata reaches the preview and the saved garment with '
      'the same attributes; only the upload sends an unset crop length as ""',
      (tester) async {
        // Real file I/O never completes inside testWidgets' fake-async zone.
        final tempDir = Directory.systemTemp.createTempSync('garment_photo');
        final photo = File('${tempDir.path}/photo.jpg')
          ..writeAsBytesSync(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
              '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
            ),
          );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        Map<String, dynamic>? preview;
        Map<String, dynamic>? complete;
        final client = MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/closet-analysis')) {
            preview = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse(
              envelope({
                'versatility': {'level': 6, 'label': 'Versatile'},
                'outfit_ideas': <Object?>[],
                'similar_garments': <Object?>[],
              }),
            );
          }
          if (request.method == 'POST' &&
              path.endsWith('/garments/init-upload')) {
            return jsonResponse(
              envelope({
                'upload_url': 'https://example.com/upload-b6',
                'object_name': 'obj-b6',
              }),
            );
          }
          if (request.method == 'PUT') return http.Response('', 200);
          if (request.method == 'POST' && path.endsWith('/garments/complete')) {
            complete = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse(
              envelope({
                'id': 700601,
                'category': 'Outer',
                'name': 'Coach Jacket',
                'sub_category': 'Jacket',
                'image_url': 'https://cdn.example.com/700601.jpg',
              }),
            );
          }
          return jsonResponse(envelope({'items': []}));
        });

        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.push<Garment>(
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
                          'name': 'Coach Jacket',
                          'category': 'Outer',
                          'sub_category': 'Jacket',
                          'fit': 'Regular',
                          'silhouette': 'Boxy',
                          'sleeve_length': 'Long',
                          'closure': 'Button',
                          'material': 'nylon',
                        },
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          // Surrounding spaces are trimmed in both requests.
          await tester.enterText(
            textFieldShowing(tester, 'Coach Jacket'),
            '  Coach Jacket  ',
          );
          await tester.pump();

          await openAnalysisSheet(tester);
          await closeAnalysisSheet(tester);

          await tester.tap(addToCloset());
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          await tester.pump(const Duration(milliseconds: 500));
        }, () => client);

        expect(preview, {
          'name': 'Coach Jacket',
          'category': 'Outer',
          'sub_category': 'Jacket',
          'style': null,
          'brand': null,
          'color': null,
          'fit': 'Regular',
          'silhouette': 'Boxy',
          'sleeve_length': 'Long',
          'closure': 'Button',
          'crop_length': null,
          'material': 'nylon',
        });

        expect(complete, isNotNull);
        final metadata = complete!['metadata'] as Map<String, dynamic>;
        expect(complete!['name'], 'Coach Jacket');
        expect(complete!['category'], 'Outer');
        expect(complete!['sub_category'], 'Jacket');
        expect(complete!.containsKey('style'), isFalse);
        expect(complete!['object_name'], 'obj-b6');
        expect(complete!['brand'], isNull);
        expect(complete!['color'], isNull);
        expect(complete!['price'], isNull);
        expect(complete!['purchase_date'], isNull);
        expect(complete!['is_owned'], isTrue);
        expect(metadata, {
          'name': 'Coach Jacket',
          'category': 'Outer',
          'sub_category': 'Jacket',
          'material': 'nylon',
          'style': null,
          'fit': 'Regular',
          'silhouette': 'Boxy',
          'sleeve_length': 'Long',
          'closure': 'Button',
          'crop_length': '',
          'bag_details': null,
        });
        for (final key in ['fit', 'silhouette', 'sleeve_length', 'closure']) {
          expect(metadata[key], preview![key], reason: key);
        }
      },
    );
  });

  group('product type', () {
    final catalog = SubCategoryCatalog(const {
      GarmentCategory.top: [
        SubCategoryOption(value: 'T-shirt', label: 'Tee (label)'),
        SubCategoryOption(value: 'Button-up shirt', label: 'Shirt (label)'),
        SubCategoryOption(
          value: 'Shirts',
          label: 'Shirts (label)',
          styles: [
            SubCategoryOption(value: 'Overshirt', label: 'Overshirt (label)'),
            SubCategoryOption(value: 'Oxford shirt', label: 'Oxford (label)'),
          ],
        ),
        SubCategoryOption(value: 'Other', label: 'Other (label)'),
      ],
      GarmentCategory.outer: [
        SubCategoryOption(value: 'Jacket', label: 'Jacket (label)'),
        SubCategoryOption(value: 'Button-up shirt', label: 'Shirt (label)'),
        SubCategoryOption(value: 'Other', label: 'Other (label)'),
      ],
      GarmentCategory.accessory: [
        SubCategoryOption(value: 'Cap', label: 'Cap (label)'),
        SubCategoryOption(value: 'Tote bag', label: 'Tote (label)'),
        SubCategoryOption(value: 'Other', label: 'Other (label)'),
      ],
    });

    Garment garment(GarmentCategory category, String sub, {String? style}) =>
        Garment(
          id: 9501,
          name: 'Item',
          category: category,
          subCategory: sub,
          style: style,
          uploadUrl: '',
          objectName: '',
          imageUrl: '',
        );

    Future<void> open(
      WidgetTester tester,
      Garment g, {
      Object? loadError,
    }) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        GarmentDetailsPage(initialGarment: g),
        overrides: [
          subCategoryCatalogProvider.overrideWith((ref, _) async {
            if (loadError != null) throw loadError;
            return catalog;
          }),
        ],
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> pickFrom(
      WidgetTester tester,
      String field,
      String option,
    ) async {
      await tester.tap(find.text(field));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(option).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('shows the label, offers the category\'s list and saves the '
        'value', (tester) async {
      final patches = <Map<String, dynamic>>[];
      final shirt = garment(GarmentCategory.top, 'Button-up shirt');
      await http.runWithClient(() async {
        await open(tester, shirt);
        expect(find.text('Shirt (label)'), findsOneWidget);

        await tester.tap(find.text('Shirt (label)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Jacket (label)'), findsNothing);
        await tester.tap(find.text('Tee (label)').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Tee (label)'), findsOneWidget);
        expect(patches.last['sub_category'], 'T-shirt');
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('the Style field shows only for a product type with styles, '
        'saves a pick, and clears when the type changes', (tester) async {
      final patches = <Map<String, dynamic>>[];
      final shirt = garment(GarmentCategory.top, 'Shirts', style: 'Overshirt');
      await http.runWithClient(() async {
        await open(tester, shirt);
        expect(find.text('STYLE'), findsOneWidget);
        expect(find.text('Overshirt (label)'), findsOneWidget);

        await pickFrom(tester, 'Overshirt (label)', 'Oxford (label)');
        expect(patches.last['style'], 'Oxford shirt');
        expect(patches.last['sub_category'], 'Shirts');

        await pickFrom(tester, 'Shirts (label)', 'Tee (label)');
        expect(find.text('STYLE'), findsNothing);
        expect(patches.last['sub_category'], 'T-shirt');
        expect(patches.last.containsKey('style'), isTrue);
        expect(patches.last['style'], isNull);
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('picking None in Style clears only the L3', (tester) async {
      final patches = <Map<String, dynamic>>[];
      final shirt = garment(GarmentCategory.top, 'Shirts', style: 'Overshirt');
      await http.runWithClient(() async {
        await open(tester, shirt);

        await pickFrom(tester, 'Overshirt (label)', 'None');
        expect(find.text('STYLE'), findsOneWidget);
        expect(patches.last['sub_category'], 'Shirts');
        expect(patches.last.containsKey('style'), isTrue);
        expect(patches.last['style'], isNull);
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('a category change keeps a value both lists have; any other '
        'is flagged and the saved value is sent until one is picked', (
      tester,
    ) async {
      final patches = <Map<String, dynamic>>[];
      final shirt = garment(GarmentCategory.top, 'Button-up shirt');
      await http.runWithClient(() async {
        await open(tester, shirt);

        await pickFrom(tester, 'Top', 'Outer');
        expect(find.text('Shirt (label)'), findsOneWidget);
        expect(patches.last['sub_category'], 'Button-up shirt');

        await pickFrom(tester, 'Outer', 'Accessory');
        expect(find.text('Shirt (label)'), findsNothing);
        expect(find.text('Please choose a product type'), findsOneWidget);
        expect(patches.last['sub_category'], 'Button-up shirt');

        await pickFrom(tester, 'Not selected', 'Cap (label)');
        expect(find.text('Please choose a product type'), findsNothing);
        expect(patches.last['sub_category'], 'Cap');
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('while the lists are unknown a category change keeps the '
        'value', (tester) async {
      final patches = <Map<String, dynamic>>[];
      final shirt = garment(GarmentCategory.top, 'Button-up shirt');
      await http.runWithClient(() async {
        await open(tester, shirt, loadError: Exception('down'));

        await pickFrom(tester, 'Top', 'Outer');
        expect(find.text('Button-up shirt'), findsOneWidget);
        expect(patches.last['sub_category'], 'Button-up shirt');
      }, () => _garmentBackend(shirt, patches));
    });

    testWidgets('an unrelated edit keeps an empty legacy value as is', (
      tester,
    ) async {
      final patches = <Map<String, dynamic>>[];
      final legacy = garment(GarmentCategory.top, '');
      await http.runWithClient(() async {
        await open(tester, legacy);
        await pickFrom(tester, 'Top', 'Outer');
        expect(patches.last['sub_category'], '');
      }, () => _garmentBackend(legacy, patches));
    });

    testWidgets('a value from before the lists shows as stored', (
      tester,
    ) async {
      await runWithEmptyCloset(() async {
        await open(tester, garment(GarmentCategory.top, 'Denim shirt'));
        expect(find.text('Denim shirt'), findsOneWidget);
      });
    });

    testWidgets('picking a bag reveals the bag fields', (tester) async {
      final patches = <Map<String, dynamic>>[];
      final cap = garment(GarmentCategory.accessory, 'Cap');
      await http.runWithClient(() async {
        await open(tester, cap);
        expect(find.text('BAG TYPE'), findsNothing);

        await pickFrom(tester, 'Cap (label)', 'Tote (label)');
        expect(find.text('BAG TYPE'), findsOneWidget);
      }, () => _garmentBackend(cap, patches));
    });

    testWidgets('add mode requires one before Add to Closet', (tester) async {
      await runWithEmptyCloset(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          const GarmentDetailsPage(
            initialGarment: _draftGarment,
            initialAnalysisData: {'name': 'Tee', 'category': 'Top'},
          ),
          overrides: [
            subCategoryCatalogProvider.overrideWith((ref, _) async => catalog),
          ],
        );
        await tester.pump();

        await tester.tap(find.text('Add to Closet'));
        await tester.pump();
        expect(find.text('Please choose a product type'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.widgetWithText(LabeledField, "PRODUCT TYPE"),
            matching: find.byType(PickerField),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Tee (label)').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Please choose a product type'), findsNothing);
      });
    });

    testWidgets('a value the gender-filtered picker lacks keeps its label '
        '(from the full lists) and stays', (tester) async {
      final menu = SubCategoryCatalog(const {
        GarmentCategory.bottom: [
          SubCategoryOption(value: 'Jeans', label: 'Jeans (label)'),
          SubCategoryOption(value: 'Other', label: 'Other (label)'),
        ],
      });
      final full = SubCategoryCatalog(const {
        GarmentCategory.bottom: [
          SubCategoryOption(value: 'Jeans', label: 'Jeans (label)'),
          SubCategoryOption(value: 'Mini skirt', label: 'Skirt (label)'),
          SubCategoryOption(value: 'Other', label: 'Other (label)'),
        ],
      });
      final patches = <Map<String, dynamic>>[];
      final skirt = garment(GarmentCategory.bottom, 'Mini skirt');
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          GarmentDetailsPage(initialGarment: skirt),
          overrides: [
            subCategoryCatalogProvider.overrideWith(
              (ref, key) async => key.allGenders ? full : menu,
            ),
          ],
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Skirt (label)'), findsOneWidget);

        await tester.tap(find.text('Skirt (label)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Skirt (label)'),
          ),
          findsNothing,
        );
        // Dismissed: nothing changes.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Skirt (label)'), findsOneWidget);
      }, () => _garmentBackend(skirt, patches));
      expect(patches, isEmpty);
    });

    testWidgets('a list that fails to load says so and offers a retry', (
      tester,
    ) async {
      await runWithEmptyCloset(() async {
        await open(
          tester,
          garment(GarmentCategory.top, 'T-shirt'),
          loadError: Exception('down'),
        );
        // Falls back to the stored value.
        expect(find.text('T-shirt'), findsOneWidget);

        await tester.tap(find.text('T-shirt'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text("Couldn't load the product types. Please try again."),
          findsOneWidget,
        );
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

  group('Closet Match sheet', () {
    Garment savedGarment(int id) => Garment(
      id: id,
      name: 'Black Leather Moc Toe Work Boots',
      category: GarmentCategory.shoes,
      subCategory: 'Boots',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
    );

    Map<String, dynamic> analysisJson({
      int level = 8,
      List<Map<String, dynamic>> ideaGarments = const [],
    }) => {
      'versatility': {'level': level, 'label': 'Versatile'},
      'outfit_ideas': [
        if (ideaGarments.isNotEmpty)
          {'title': 'Idea', 'garments': ideaGarments},
      ],
      'similar_garments': <Object?>[],
    };

    testWidgets('the versatility bar fills one segment per level, of 10', (
      tester,
    ) async {
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          return jsonResponse(envelope(analysisJson(level: 3)));
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          GarmentDetailsPage(initialGarment: savedGarment(7701)),
        );
        await tester.pump();
        await tester.pump();
        await openAnalysisSheet(tester);

        Finder segments(Color color) => find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints == const BoxConstraints.tightFor(height: 8) &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == color,
        );
        expect(find.text('3/10'), findsOneWidget);
        expect(segments(AppColors.accent), findsNWidgets(3));
        expect(segments(AppColors.borderSubtle), findsNWidgets(7));
      }, () => client);
    });

    testWidgets('closing the sheet mid-run does not cancel the analysis: '
        'reopening shows its result without a second run', (tester) async {
      final reply = Completer<http.Response>();
      var runs = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          runs++;
          return reply.future;
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          GarmentDetailsPage(initialGarment: savedGarment(7702)),
        );
        await tester.pump();
        await tester.pump();

        await openAnalysisSheet(tester);
        expect(find.byType(LoadingOverlay), findsOneWidget);

        await closeAnalysisSheet(tester);
        expect(find.byType(BottomSheet), findsNothing);

        reply.complete(jsonResponse(envelope(analysisJson())));
        await tester.pump();
        await tester.pump();

        await openAnalysisSheet(tester);
        expect(find.text('8/10'), findsOneWidget);
        expect(find.byType(LoadingOverlay), findsNothing);
        expect(runs, 1);
      }, () => client);
    });

    testWidgets('an idea garment whose signed URL already expired is '
        're-signed before showing, and the fresh URL is written back to the '
        'persisted result', (tester) async {
      const expired =
          'https://storage.example/g.png'
          '?X-Goog-Date=20200101T000000Z&X-Goog-Expires=60';
      const fresh = 'https://img.example/fresh-7731.png';
      final garmentReads = <Uri>[];
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/closet-analysis')) {
          return jsonResponse(
            envelope(
              analysisJson(
                ideaGarments: [
                  {
                    'garment_id': 7731,
                    'category': 'Bottom',
                    'name': 'Wide Tapered Denim Pants',
                    'image_url': expired,
                    'is_target': false,
                  },
                ],
              ),
            ),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/garments/7731')) {
          garmentReads.add(request.url);
          return jsonResponse(
            envelope({
              'id': 7731,
              'category': 'Bottom',
              'name': 'Wide Tapered Denim Pants',
              'sub_category': 'Jeans',
              'image_url': fresh,
              'is_favorite': false,
              'is_deleted': false,
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          GarmentDetailsPage(initialGarment: savedGarment(7703)),
        );
        await tester.pump();
        await tester.pump();
        await openAnalysisSheet(tester);
        await tester.pump();
        await tester.pump();

        expect(garmentReads, isNotEmpty);
        expect(garmentReads.first.queryParameters['include_deleted'], 'true');
        expect(
          find.byWidgetPredicate(
            (w) => w is GarmentImage && w.garmentId == 7731 && w.url == fresh,
          ),
          findsOneWidget,
        );
        final persisted = await GarmentService().cachedClosetAnalysis(7703);
        expect(persisted!.outfitIdeas.single.garments.single.imageUrl, fresh);
      }, () => client);
    });
  });

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
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Blue Oxford'),
          ),
          findsOneWidget,
        );
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
        await tester.tap(find.byKey(AppDialog.dismissButtonKey));
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

  group('edit mode ownership', () {
    const notYet = Garment(
      id: 9501,
      name: 'Wishlist Bomber',
      category: GarmentCategory.outer,
      subCategory: 'Bomber jacket',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
      isOwned: false,
    );

    testWidgets('an owned garment doesn\'t ask', (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          GarmentDetailsPage(initialGarment: notYet.copyWith(isOwned: true)),
        );
        await tester.pump();
        expect(find.text('Do you own this item?'), findsNothing);
      }, () => _garmentBackend(notYet, []));
    });

    testWidgets('a Not-yet garment asks below the image, saves the answer at '
        'once, and keeps asking', (tester) async {
      final patches = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, const GarmentDetailsPage(initialGarment: notYet));
        await tester.pump();

        final question = find.text('Do you own this item?');
        expect(question, findsOneWidget);
        expect(
          tester.getTopLeft(question).dy,
          greaterThan(tester.getBottomLeft(find.byType(GarmentImage)).dy),
        );

        await tester.tap(find.text('Yes, I own it'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(patches, hasLength(1));
        expect(patches.single['is_owned'], isTrue);
        expect(question, findsOneWidget);
      }, () => _garmentBackend(notYet, patches));
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
  group('Re-analyze Cancel', () {
    const imageUrl = 'https://example.com/garment.png';
    const pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    Map<String, dynamic> garmentJson(int id) => {
      'id': id,
      'garment_id': id,
      'name': 'Plain Tee',
      'category': 'Top',
      'sub_category': 'Tee',
      'image_url': imageUrl,
    };

    /// Each analyze-instant call waits on its own gate, so a test decides
    /// the order replies land in.
    MockClient gatedClient({
      required int id,
      required List<Completer<String>> gates,
      required List<http.Request> patches,
    }) {
      return MockClient((request) async {
        final path = request.url.path;
        if (request.url.toString() == imageUrl) {
          return http.Response.bytes(pngHeader, 200);
        }
        if (path.endsWith('/analyze-instant')) {
          final gate = Completer<String>();
          gates.add(gate);
          final subCategory = await gate.future;
          return jsonResponse(
            envelope({
              'metadata': {'category': 'Top', 'sub_category': subCategory},
            }),
          );
        }
        if (request.method == 'PATCH') {
          patches.add(request);
          return jsonResponse(envelope(garmentJson(id)));
        }
        if (path.endsWith('/garments/$id')) {
          return jsonResponse(envelope(garmentJson(id)));
        }
        return jsonResponse(envelope({'items': []}));
      });
    }

    Future<void> openPage(WidgetTester tester, int id) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        GarmentDetailsPage(
          initialGarment: Garment(
            id: id,
            name: 'Plain Tee',
            category: GarmentCategory.top,
            subCategory: 'Tee',
            uploadUrl: '',
            objectName: '',
            imageUrl: '',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> startReanalysis(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Re-analyze'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Re-analyze'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Finder overlay() => find.byType(LoadingOverlay);

    testWidgets('Cancel closes the overlay; a reply landing afterwards '
        'leaves the form untouched and saves nothing', (tester) async {
      final gates = <Completer<String>>[];
      final patches = <http.Request>[];
      await http.runWithClient(() async {
        await openPage(tester, 7701);
        await startReanalysis(tester);
        expect(overlay(), findsOneWidget);
        expect(gates, hasLength(1));

        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(overlay(), findsNothing);

        gates.single.complete('Late Hoodie');
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('Late Hoodie'), findsNothing);
        expect(find.text('Tee'), findsOneWidget);
        expect(find.text('Details Updated'), findsNothing);
        expect(patches, isEmpty);
      }, () => gatedClient(id: 7701, gates: gates, patches: patches));
    });

    testWidgets('a cancelled run that lands after a newer one can\'t '
        'overwrite it', (tester) async {
      final gates = <Completer<String>>[];
      final patches = <http.Request>[];
      await http.runWithClient(() async {
        await openPage(tester, 7702);
        await startReanalysis(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // Restartable at once, without waiting for the cancelled request.
        await startReanalysis(tester);
        expect(gates, hasLength(2));

        gates[1].complete('Fresh Polo');
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(overlay(), findsNothing);
        expect(find.text('Fresh Polo'), findsOneWidget);
        expect(patches, hasLength(1));

        gates[0].complete('Stale Hoodie');
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Stale Hoodie'), findsNothing);
        expect(find.text('Fresh Polo'), findsOneWidget);
        expect(patches, hasLength(1));
        expect(jsonDecode(patches.single.body)['sub_category'], 'Fresh Polo');
      }, () => gatedClient(id: 7702, gates: gates, patches: patches));
    });
  });

  group('Used in Outfits', () {
    const garmentId = 7801;
    const garment = Garment(
      id: garmentId,
      name: 'Plain Tee',
      category: GarmentCategory.top,
      subCategory: 'T-Shirt',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
    );

    // Outfits on the fake backend, as `GET by-garments` would return them.
    late List<Map<String, dynamic>> outfits;

    Map<String, dynamic> outfitJson(int outfitId, int groupId) => {
      'outfit_id': outfitId,
      'group_id': groupId,
      'group_type': 'general',
      'status': 'completed',
      'name': null,
      'garment_ids': [garmentId, 8],
      'result_image_url': 'https://example.com/$outfitId.jpg',
      'season': <String>[],
      'style': <String>[],
      'is_favorite': false,
    };

    MockClient outfitBackend() => MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'POST' && path.endsWith('/outfit/by-garments')) {
        return jsonResponse(envelope(outfits));
      }
      if (request.method == 'POST' && path.endsWith('/40/generate')) {
        final created = outfitJson(900, 40);
        outfits.add(created);
        return jsonResponse(envelope(created));
      }
      if (request.method == 'DELETE' && path.endsWith('/outfit/40')) {
        outfits.removeWhere((o) => o['group_id'] == 40);
        return jsonResponse(envelope(null));
      }
      return jsonResponse(envelope({'items': []}));
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    setUp(() => outfits = []);

    testWidgets('the count follows outfits created and deleted while the '
        'page is open: 0 → 1 → 0', (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          const GarmentDetailsPage(initialGarment: garment),
        );
        await settle(tester);
        expect(find.text('Used in Outfits'), findsNothing);

        // E.g. Closet Match's outfit idea → Create Outfit, pushed over this page.
        await OutfitService().generateOutfit(
          garmentIds: [garmentId, 8],
          groupId: 40,
        );
        await settle(tester);
        expect(find.text('Used in Outfits'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);

        await OutfitService().deleteGroup(40);
        await settle(tester);
        expect(find.text('Used in Outfits'), findsNothing);
      }, outfitBackend);
    });

    testWidgets('the count goes from 1 to 2 when another outfit uses it', (
      tester,
    ) async {
      outfits.add(outfitJson(800, 30));
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          const GarmentDetailsPage(initialGarment: garment),
        );
        await settle(tester);
        expect(find.text('1'), findsOneWidget);

        await OutfitService().generateOutfit(
          garmentIds: [garmentId, 8],
          groupId: 40,
        );
        await settle(tester);
        expect(find.text('2'), findsOneWidget);
      }, outfitBackend);
    });
  });
  // F4: an optimistic favorite racing a garmentsProvider refresh that read
  // the server before the PATCH committed.
  group('favorite vs. a closet refresh', () {
    const id = 7101;
    const garment = Garment(
      id: id,
      name: 'Oxford Shirt',
      category: GarmentCategory.top,
      subCategory: 'Shirt',
      uploadUrl: '',
      objectName: '',
      imageUrl: '',
    );

    late bool serverFavorite;
    late bool holdList;
    late bool holdPatch;
    late bool patchFails;
    late List<Completer<void>> listGates;
    late List<Completer<void>> patchGates;

    Map<String, dynamic> garmentJson(bool fav) => {
      'id': id,
      'name': garment.name,
      'category': garment.category.apiValue,
      'sub_category': garment.subCategory,
      'image_url': '',
      'is_favorite': fav,
    };

    setUp(() {
      serverFavorite = false;
      holdList = false;
      holdPatch = false;
      patchFails = false;
      listGates = [];
      patchGates = [];
    });

    /// `GET /garments` answers with the server's favorite when the request
    /// *arrives*; a PATCH commits only once released.
    MockClient backend() => MockClient((request) async {
      if (request.method == 'PATCH') {
        final value =
            (jsonDecode(request.body) as Map<String, dynamic>)['is_favorite']
                as bool;
        if (holdPatch) {
          final gate = Completer<void>();
          patchGates.add(gate);
          await gate.future;
        }
        if (patchFails) return jsonResponse({'success': false}, status: 500);
        serverFavorite = value;
        return jsonResponse(envelope(garmentJson(value)));
      }
      if (request.url.path.endsWith('/garments')) {
        final snapshot = garmentJson(serverFavorite);
        if (holdList) {
          final gate = Completer<void>();
          listGates.add(gate);
          await gate.future;
        }
        return jsonResponse(
          envelope({
            'items': [snapshot],
            'total': 1,
            'page': 1,
            'size': 100,
          }),
        );
      }
      return jsonResponse(envelope({'items': []}));
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    late ProviderContainer container;

    Future<void> open(WidgetTester tester, {bool favorite = false}) async {
      serverFavorite = favorite;
      useTallSurface(tester);
      await pumpApp(
        tester,
        GarmentDetailsPage(
          initialGarment: garment.copyWith(isFavorite: favorite),
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(GarmentDetailsPage)),
      );
      container.listen(garmentsProvider, (_, _) {});
      await settle(tester);
    }

    bool? providerFavorite() => container
        .read(garmentsProvider)
        .value
        ?.singleWhere((g) => g.id == id)
        .isFavorite;

    /// Taps the heart with its PATCH held, then starts a refresh that reads
    /// the server before that PATCH commits.
    Future<({Future<void> done})> tapThenRefresh(
      WidgetTester tester, {
      required IconData heart,
    }) async {
      holdPatch = true;
      await tester.tap(find.byIcon(heart));
      await settle(tester);
      holdList = true;
      final refresh = container.read(garmentsProvider.notifier).refresh();
      await settle(tester);
      return (done: refresh);
    }

    Future<void> release(
      WidgetTester tester,
      List<Completer<void>> gates,
    ) async {
      for (final gate in [...gates]) {
        gate.complete();
      }
      gates.clear();
      await settle(tester);
    }

    testWidgets('favorite → stale refresh answers → PATCH succeeds: the '
        'closet ends favorited', (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        final refresh = (await tapThenRefresh(
          tester,
          heart: Icons.favorite_border,
        )).done;

        await release(tester, listGates); // stale: not favorite
        await refresh;
        await release(tester, patchGates); // PATCH commits

        expect(providerFavorite(), isTrue);
        expect(find.byIcon(Icons.favorite), findsOneWidget);
      }, backend);
    });

    testWidgets('unfavorite → stale refresh answers → PATCH succeeds: the '
        'closet ends unfavorited', (tester) async {
      await http.runWithClient(() async {
        await open(tester, favorite: true);
        final refresh = (await tapThenRefresh(
          tester,
          heart: Icons.favorite,
        )).done;

        await release(tester, listGates); // stale: still favorite
        await refresh;
        await release(tester, patchGates);

        expect(providerFavorite(), isFalse);
      }, backend);
    });

    testWidgets('PATCH succeeds before the stale refresh answers: the '
        'closet still ends favorited', (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        final refresh = (await tapThenRefresh(
          tester,
          heart: Icons.favorite_border,
        )).done;

        await release(tester, patchGates); // commits first
        await release(tester, listGates); // then the stale reply lands
        await refresh;

        expect(providerFavorite(), isTrue);
      }, backend);
    });

    testWidgets('a failed PATCH rolls back the closet and the heart', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await open(tester);
        patchFails = true;
        await tester.tap(find.byIcon(Icons.favorite_border));
        await settle(tester);

        expect(providerFavorite(), isFalse);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      }, backend);
    });

    testWidgets("a failed PATCH's rollback doesn't undo a newer favorite "
        'written meanwhile (another screen)', (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        holdPatch = true;
        patchFails = true;
        await tester.tap(find.byIcon(Icons.favorite_border)); // held; fails
        await settle(tester);

        // Another screen favorites it too, and its own request succeeded:
        // the newer write. Our rollback (to unfavorited) must not undo it.
        container
            .read(garmentsProvider.notifier)
            .updateFavoriteOptimistically(id, isFavorite: true);
        await release(tester, patchGates); // our favorite's PATCH fails

        expect(providerFavorite(), isTrue);
      }, backend);
    });
  });

  // P2-1 batch 2: the confirm dialogs now come from showConfirmDialog. Each
  // keeps its texts and destructive style; cancelling sends nothing.
  group('confirm dialogs', () {
    const id = 7301;

    /// Records DELETEs and analysis calls; everything else is a plain read.
    MockClient recordingClient(List<http.Request> requests) {
      return MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') return jsonResponse(envelope(null));
        if (request.url.path.endsWith('/garments/$id')) {
          return jsonResponse(
            envelope({
              'id': id,
              'name': 'Plain Tee',
              'category': 'Top',
              'sub_category': 'Tee',
              'image_url': '',
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });
    }

    Future<void> openMenuItem(WidgetTester tester, String label) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> openPage(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const GarmentDetailsPage(
          initialGarment: Garment(
            id: id,
            name: 'Plain Tee',
            category: GarmentCategory.top,
            subCategory: 'Tee',
            uploadUrl: '',
            objectName: '',
            imageUrl: '',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    AppDialog dialog(WidgetTester tester) =>
        tester.widget<AppDialog>(find.byType(AppDialog));

    testWidgets('Delete Garment: destructive; Cancel deletes nothing, Delete '
        'deletes it', (tester) async {
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await openPage(tester);
        await openMenuItem(tester, 'Delete Garment');

        expect(dialog(tester).title, 'Delete Garment');
        expect(
          dialog(tester).body,
          'Are you sure you want to delete this garment?',
        );
        expect(dialog(tester).primaryLabel, 'Delete');
        expect(dialog(tester).destructive, isTrue);
        await tester.tap(find.byKey(AppDialog.dismissButtonKey));
        await tester.pump(const Duration(milliseconds: 500));
        expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
        expect(find.byType(GarmentDetailsPage), findsOneWidget);

        await openMenuItem(tester, 'Delete Garment');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
        await tester.pump();
        await tester.pump();
        final deletes = requests.where((r) => r.method == 'DELETE');
        expect(deletes.single.url.path, endsWith('/garments/$id'));
      }, () => recordingClient(requests));
    });

    testWidgets('Re-analyze: a plain (not destructive) confirm; Cancel '
        'analyzes nothing', (tester) async {
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await openPage(tester);
        await openMenuItem(tester, 'Re-analyze');

        expect(dialog(tester).title, 'Re-analyze This Item?');
        expect(dialog(tester).primaryLabel, 'Re-analyze');
        expect(dialog(tester).destructive, isFalse);
        final before = requests.length;
        await tester.tap(find.byKey(AppDialog.dismissButtonKey));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          requests
              .skip(before)
              .where((r) => r.url.path.endsWith('/analyze-instant')),
          isEmpty,
        );
        expect(requests.skip(before), isEmpty, reason: 'nothing at all');
      }, () => recordingClient(requests));
    });
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
