import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/create_outfit_page.dart';
import 'package:uwearis/features/pages/outfit_details_page.dart';
import 'package:uwearis/features/pages/select_garment_page.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

/// Fixed closet so tests don't hit the network.
class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._items);
  final List<Garment> _items;

  @override
  Future<List<Garment>> build() async => _items;

  @override
  Future<void> refresh() async => state = AsyncData(_items);
}

Garment _garment({
  required int id,
  required GarmentCategory category,
  String name = 'Item',
  String subCategory = '',
}) {
  return Garment(
    id: id,
    garmentId: id,
    name: name,
    category: category,
    subCategory: subCategory,
    uploadUrl: '',
    objectName: '',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth();
  });

  final closet = [
    _garment(id: 1, category: GarmentCategory.top, name: 'Tee'),
    _garment(id: 2, category: GarmentCategory.bottom, name: 'Jeans'),
    _garment(id: 3, category: GarmentCategory.shoes, name: 'Sneakers'),
  ];

  List<Override> closetOverride([List<Garment>? pool]) => [
    garmentsProvider.overrideWith(() => _FakeGarments(pool ?? closet)),
  ];

  // A viewport tall enough that the whole ListView is laid out at once, so
  // slots/customization below the first screenful are in the tree.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'create mode shows the Match a Look app-bar icon and an empty Your Outfit row',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: closetOverride(),
      );
      await tester.pump();

      expect(find.byTooltip('Match a Look'), findsOneWidget);
      expect(find.text('Reference Look'), findsNothing);
      expect(find.text('OUTFIT ITEMS'), findsOneWidget);
      expect(find.text('Add Garment'), findsOneWidget);

      expect(
        find.widgetWithText(BottomActionButton, 'Create Outfit'),
        findsNothing,
      );
    },
  );

  testWidgets('Create Outfit stays hidden while Shoes are still missing', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      CreateOutfitPage(
        initialGarments: [closet[0], closet[1]], // Top + Bottom, no Shoes
      ),
      overrides: closetOverride(),
    );
    await tester.pump();
    expect(
      find.widgetWithText(BottomActionButton, 'Create Outfit'),
      findsNothing,
    );
  });

  testWidgets('Create Outfit appears once Top, Bottom and Shoes are all set', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      CreateOutfitPage(initialGarments: [closet[0], closet[1], closet[2]]),
      overrides: closetOverride(),
    );
    await tester.pump();
    expect(
      find.widgetWithText(BottomActionButton, 'Create Outfit'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Create Outfit renders exactly the picks, with no AI fill-in step',
    (tester) async {
      useTallSurface(tester);
      final requests = <http.Request>[];
      // Fail every call so the flow stops right after the render request.
      final client = MockClient((request) async {
        requests.add(request);
        return jsonResponse(envelope(null), status: 500);
      });

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          CreateOutfitPage(initialGarments: [closet[0], closet[1], closet[2]]),
          overrides: closetOverride(),
        );
        await tester.pump();
        await tester.tap(
          find.widgetWithText(BottomActionButton, 'Create Outfit'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
      }, () => client);

      expect(requests, isNotEmpty);
      expect(
        requests.where((r) => r.url.path.endsWith('/outfit/advice')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'a manually added garment is locked by default; removing it clears the lock',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: closetOverride(),
      );
      await tester.pump();

      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tee'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock), findsNothing);
    },
  );

  testWidgets('tapping the lock badge toggles it', (tester) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      const CreateOutfitPage(),
      overrides: closetOverride(),
    );
    await tester.pump();

    await tester.tap(find.text('Add Garment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tee'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);

    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pump();
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets(
    'the Complete with AI pill is enabled with zero garments picked',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: closetOverride(),
      );
      await tester.pump();

      final pill = tester.widget<AccentPillButton>(
        find.widgetWithText(AccentPillButton, 'Finish with AI'),
      );
      expect(pill.enabled, isTrue);
    },
  );

  testWidgets(
    "the Finish Outfit card's temperature defaults to today's high/low average",
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: [
          ...closetOverride(),
          weatherProvider.overrideWith(_FakeWeather.new),
        ],
      );
      await tester.pumpAndSettle();

      // High 28 / low 18 → 23, not the current reading (30).
      expect(find.text('23°C'), findsOneWidget);
      expect(find.text('30°C'), findsNothing);
    },
  );

  testWidgets(
    'the Finish Outfit card holds the temperature + style knobs, no occasion',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: closetOverride(),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6)); // weather lookup settles
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(find.text('OCCASION'), findsNothing);
      expect(find.text('TEMPERATURE'), findsOneWidget);
      expect(find.text('20°C'), findsOneWidget); // fallback default
      expect(find.text('STYLE'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      final finish = find.widgetWithText(AccentPillButton, 'Finish with AI');
      expect(finish, findsOneWidget);
      expect(
        tester.getCenter(finish).dy,
        closeTo(tester.getCenter(find.text('Auto-Complete')).dy, 4),
      );
      expect(
        tester.getCenter(find.text('STYLE')).dy,
        closeTo(tester.getCenter(find.text('TEMPERATURE')).dy, 1),
      );

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('21°C'), findsOneWidget);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Streetwear'));
      await tester.pumpAndSettle();
      expect(find.text('Streetwear'), findsOneWidget);
      expect(find.text('Auto'), findsNothing);
      expect(find.text('21°C'), findsOneWidget);
    },
  );

  testWidgets(
    'Finish with AI applies the AI picks; a later run excludes them',
    (tester) async {
      useTallSurface(tester);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return jsonResponse(
          envelope({
            'outfit_name': 'AI Pick',
            'selected_garment_ids': [1, 2, 3],
            'items': [
              {'garment_id': 1, 'role': 'top', 'order': 0, 'reason': null},
              {'garment_id': 2, 'role': 'bottom', 'order': 1, 'reason': null},
              {'garment_id': 3, 'role': 'shoes', 'order': 2, 'reason': null},
            ],
            'styling_tips': null,
            'reasoning': null,
          }),
        );
      });

      // Plain pumps after the tap: _completeWithAi's LoadingOverlay spinner
      // animates forever, so pumpAndSettle would time out.
      Future<void> runFinishWithAi() async {
        await tester.tap(
          find.widgetWithText(AccentPillButton, 'Finish with AI'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
      }

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          const CreateOutfitPage(),
          overrides: closetOverride(),
        );
        await tester.pump();

        await runFinishWithAi();

        expect(
          find.widgetWithText(BottomActionButton, 'Create Outfit'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.lock_open), findsNWidgets(3));
        expect(requests, hasLength(1));
        final firstBody =
            jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(firstBody['exclude_garment_ids'], <int>[]);
        // "Auto" style leaves it to the backend.
        expect(firstBody.containsKey('style'), isFalse);
        expect(firstBody.containsKey('occasion'), isFalse);

        // A second run asks the AI to avoid repeating the first run's picks.
        await runFinishWithAi();
        expect(requests, hasLength(2));
        expect(
          jsonDecode(requests[1].body)['exclude_garment_ids'],
          unorderedEquals([1, 2, 3]),
        );
      }, () => client);
    },
  );

  testWidgets(
    'Finish with AI never replaces a locked garment, even when it suggests '
    'another piece for the same slot',
    (tester) async {
      useTallSurface(tester);
      final wardrobe = [
        _garment(
          id: 1,
          category: GarmentCategory.top,
          name: 'Tee',
          subCategory: 'T-shirt',
        ),
        _garment(
          id: 2,
          category: GarmentCategory.top,
          name: 'Polo',
          subCategory: 'Polo shirt',
        ),
        _garment(id: 3, category: GarmentCategory.bottom, name: 'Jeans'),
        _garment(id: 4, category: GarmentCategory.bottom, name: 'Chinos'),
        _garment(id: 5, category: GarmentCategory.shoes, name: 'Sneakers'),
      ];
      final client = MockClient(
        (request) async => jsonResponse(
          envelope({
            'selected_garment_ids': [1, 2, 3, 4, 5],
            'items': <Object?>[],
          }),
        ),
      );

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          const CreateOutfitPage(),
          overrides: closetOverride(wardrobe),
        );
        await tester.pump();
        // Manual picks are locked.
        for (final name in ['Tee', 'Jeans']) {
          await tester.tap(find.text('Add Garment'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(name));
          await tester.pumpAndSettle();
        }
        expect(find.byIcon(Icons.lock), findsNWidgets(2));

        await tester.tap(
          find.widgetWithText(AccentPillButton, 'Finish with AI'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(find.text('Tee'), findsOneWidget);
        expect(find.text('Jeans'), findsOneWidget);
        expect(find.text('Polo'), findsNothing);
        expect(find.text('Chinos'), findsNothing);
        expect(find.text('Sneakers'), findsOneWidget);
        expect(find.byIcon(Icons.lock), findsNWidgets(2));
      }, () => client);
    },
  );

  testWidgets('Finish with AI surfaces an error when the request fails', (
    tester,
  ) async {
    useTallSurface(tester);
    final client = MockClient(
      (request) async => jsonResponse(envelope(null), status: 500),
    );

    await http.runWithClient(() async {
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: closetOverride(),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(AccentPillButton, 'Finish with AI'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(
        find.text("Couldn't complete your outfit with AI — please try again."),
        findsOneWidget,
      );
    }, () => client);
  });

  testWidgets(
    'Add garment picker drops a full category and an already-worn accessory type',
    (tester) async {
      useTallSurface(tester);
      final wardrobe = [
        _garment(id: 1, category: GarmentCategory.top, name: 'Tee'),
        _garment(id: 2, category: GarmentCategory.bottom, name: 'Jeans'),
        _garment(id: 3, category: GarmentCategory.bottom, name: 'Chinos'),
        _garment(
          id: 4,
          category: GarmentCategory.accessory,
          name: 'Ray-Bans',
          subCategory: 'Sunglasses',
        ),
        _garment(
          id: 5,
          category: GarmentCategory.accessory,
          name: 'Wayfarers',
          subCategory: 'Sunglasses',
        ),
        _garment(
          id: 6,
          category: GarmentCategory.accessory,
          name: 'Beanie',
          subCategory: 'Beanie',
        ),
      ];
      await pumpApp(
        tester,
        CreateOutfitPage(
          // Wearing the Jeans (fills Bottom) and the Ray-Bans (sunglasses).
          initialGarments: [wardrobe[1], wardrobe[3]],
        ),
        overrides: closetOverride(wardrobe),
      );
      await tester.pump();

      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();

      // Bottom slot is full → no Bottom tab, no other trousers offered.
      expect(find.text('Bottom'), findsNothing);
      expect(find.text('Chinos'), findsNothing);
      // Top is still open.
      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Tee'), findsOneWidget);

      // On the Accessory tab: sunglasses are hidden, a fresh type isn't.
      await tester.tap(find.text('Accessory'));
      await tester.pumpAndSettle();
      expect(find.text('Beanie'), findsOneWidget);
      expect(find.text('Wayfarers'), findsNothing);
      expect(find.text('Ray-Bans'), findsNothing);
    },
  );

  testWidgets(
    'Add garment picker hides a base-layer alternative for the worn top '
    '(Polo shirt while wearing a T-shirt) the same way it hides an '
    'already-worn accessory type, but a genuine mid-layer piece still shows '
    'and stacks',
    (tester) async {
      useTallSurface(tester);
      final wardrobe = [
        _garment(
          id: 1,
          category: GarmentCategory.top,
          name: 'Tee',
          subCategory: 'T-shirt',
        ),
        _garment(
          id: 2,
          category: GarmentCategory.top,
          name: 'Polo',
          subCategory: 'Polo shirt',
        ),
        _garment(
          id: 3,
          category: GarmentCategory.top,
          name: 'Cardi',
          subCategory: 'Cardigan',
        ),
      ];
      await pumpApp(
        tester,
        CreateOutfitPage(initialGarments: [wardrobe[0]]),
        overrides: closetOverride(wardrobe),
      );
      await tester.pump();

      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();
      expect(find.text('Polo'), findsNothing);
      expect(find.text('Cardi'), findsOneWidget);

      await tester.tap(find.text('Cardi'));
      await tester.pumpAndSettle();

      // A cardigan is a real mid layer — it stacks alongside the base top
      // rather than replacing it.
      expect(find.text('Tee'), findsOneWidget);
      expect(find.text('Cardi'), findsOneWidget);
      expect(find.text('Top · T-shirt'), findsOneWidget);
      expect(find.text('Top · Cardigan'), findsOneWidget);
    },
  );

  testWidgets(
    'swapping the worn top directly still offers its base-layer alternative, '
    'and picking it replaces the top rather than adding a mid layer',
    (tester) async {
      useTallSurface(tester);
      final wardrobe = [
        _garment(
          id: 1,
          category: GarmentCategory.top,
          name: 'Tee',
          subCategory: 'T-shirt',
        ),
        _garment(
          id: 2,
          category: GarmentCategory.top,
          name: 'Polo',
          subCategory: 'Polo shirt',
        ),
      ];
      await pumpApp(
        tester,
        CreateOutfitPage(initialGarments: [wardrobe[0]]),
        overrides: closetOverride(wardrobe),
      );
      await tester.pump();

      // Tapping the Top row itself (swap flow) re-admits its own
      // alternative, unlike the generic "Add garment" picker above.
      await tester.tap(find.text('Tee'));
      await tester.pumpAndSettle();
      expect(find.text('Polo'), findsOneWidget);

      await tester.tap(find.text('Polo'));
      await tester.pumpAndSettle();

      expect(find.text('Tee'), findsNothing);
      expect(find.text('Polo'), findsOneWidget);
      expect(find.text('Top · Polo shirt'), findsOneWidget);
    },
  );

  testWidgets(
    'the Background field opens a sheet of backgrounds; picking one closes '
    'it and updates the field',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        const CreateOutfitPage(),
        overrides: closetOverride(),
      );
      await tester.pump();
      expect(find.text('BACKGROUND'), findsOneWidget);
      expect(find.text('(OPTIONAL)'), findsNothing);
      expect(
        tester.getTopLeft(find.text('BACKGROUND')).dy,
        greaterThan(tester.getTopLeft(find.text('OUTFIT ITEMS')).dy),
      );
      expect(find.byType(AppDivider), findsWidgets);
      expect(find.text('Fitting Room'), findsOneWidget);
      expect(find.text('Choose a background'), findsNothing);
      // Name only — no thumbnail in the field itself.
      expect(
        find.image(const AssetImage('assets/images/fitting_room.png')),
        findsNothing,
      );

      await tester.ensureVisible(find.text('Fitting Room'));
      await tester.tap(find.text('Fitting Room'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a background'), findsOneWidget);
      // Only the current background carries the checkmark.
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Tokyo Street'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a background'), findsNothing);
      expect(find.text('Tokyo Street'), findsOneWidget);
      expect(find.text('Fitting Room'), findsNothing);
    },
  );

  testWidgets(
    'an accessory survives the round trip through Create Outfit and back',
    (tester) async {
      useTallSurface(tester);
      final wardrobe = [
        ...closet,
        _garment(
          id: 4,
          category: GarmentCategory.accessory,
          name: 'Ray-Bans',
          subCategory: 'Sunglasses',
        ),
      ];
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path.endsWith('/outfit')) {
          return jsonResponse(envelope({'group_id': 42}));
        }
        if (request.method == 'POST' && path.endsWith('/generate')) {
          return jsonResponse(
            envelope({
              'outfit_id': 99,
              'group_id': 42,
              'result_image_url': 'https://img.example/outfit.png',
              'garment_ids': [1, 2, 3, 4],
            }),
          );
        }
        if (request.method == 'GET' && path.endsWith('/outfit/42')) {
          return jsonResponse(
            envelope({
              'outfits': [
                {
                  'outfit_id': 99,
                  'group_id': 42,
                  'result_image_url': 'https://img.example/outfit.png',
                  'garment_ids': [1, 2, 3, 4],
                },
              ],
              'cover_outfit_id': 99,
              'name': null,
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          CreateOutfitPage(
            initialGarments: wardrobe,
          ), // Top+Bottom+Shoes+Ray-Bans
          overrides: closetOverride(wardrobe),
        );
        await tester.pump();
        expect(find.text('Ray-Bans'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(BottomActionButton, 'Create Outfit'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        // Now on OutfitDetailsPage — back out and choose Save. Plain pumps:
        // the page's loading spinner animates forever.
        expect(find.byType(OutfitDetailsPage), findsOneWidget);
        await tester.tap(find.byType(ActionDiscButton).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.widgetWithText(ElevatedButton, 'Save'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // Unrelated: the "Outfit saved" toast overflows under the test
        // font's wider metrics.
        tester.takeException();

        // The accessory picked before "Create Outfit" must survive.
        expect(find.byType(CreateOutfitPage), findsOneWidget);
        expect(find.text('Ray-Bans'), findsOneWidget);

        // Drain the toast's auto-dismiss timer before teardown.
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
    },
  );

  group('tops (up to two, no fixed top / mid layer)', () {
    final tee = _garment(
      id: 11,
      category: GarmentCategory.top,
      name: 'Tee',
      subCategory: 'T-shirt',
    );
    final hoodie = _garment(
      id: 12,
      category: GarmentCategory.top,
      name: 'Hoodie',
      subCategory: 'Hoodie',
    );
    final cardi = _garment(
      id: 13,
      category: GarmentCategory.top,
      name: 'Cardi',
      subCategory: 'Cardigan',
    );
    final polo = _garment(
      id: 14,
      category: GarmentCategory.top,
      name: 'Polo',
      subCategory: 'Polo shirt',
    );
    final jeans = _garment(
      id: 15,
      category: GarmentCategory.bottom,
      name: 'Jeans',
    );
    final boots = _garment(
      id: 16,
      category: GarmentCategory.shoes,
      name: 'Boots',
    );

    Finder rowOf(String name) => find
        .ancestor(of: find.text(name), matching: find.byType(GestureDetector))
        .first;

    Future<void> removeRow(WidgetTester tester, String name) async {
      await tester.tap(
        find.descendant(of: rowOf(name), matching: find.byIcon(Icons.close)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('removing the first of two tops still counts the other as '
        'the Top, so Create Version appears', (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        CreateOutfitPage(
          initialGarments: [hoodie, tee, jeans, boots],
          targetGroupId: 7,
        ),
        overrides: closetOverride([hoodie, tee, jeans, boots]),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bottomActionButton-hidden')),
        findsOneWidget,
      );

      await removeRow(tester, 'Hoodie');

      expect(find.text('Hoodie'), findsNothing);
      expect(find.text('Top · T-shirt'), findsOneWidget);
      expect(
        find.widgetWithText(BottomActionButton, 'Create Version'),
        findsOneWidget,
      );

      // With no top left, Top is missing again.
      await removeRow(tester, 'Tee');
      expect(
        find.byKey(const ValueKey('bottomActionButton-hidden')),
        findsOneWidget,
      );
    });

    testWidgets('after removing a top, Add Garment offers tops again', (
      tester,
    ) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        CreateOutfitPage(initialGarments: [hoodie, tee]),
        overrides: closetOverride([hoodie, tee, cardi, jeans]),
      );
      await tester.pump();

      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();
      expect(find.text('Jeans'), findsOneWidget);
      expect(find.text('Cardi'), findsNothing, reason: 'two tops is the cap');
      Navigator.of(tester.element(find.byType(SelectGarmentPage))).pop();
      await tester.pumpAndSettle();

      await removeRow(tester, 'Hoodie');
      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardi'));
      await tester.pumpAndSettle();

      expect(find.text('Top · T-shirt'), findsOneWidget);
      expect(find.text('Top · Cardigan'), findsOneWidget);
    });

    testWidgets('swapping the second top replaces only that one', (
      tester,
    ) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        CreateOutfitPage(initialGarments: [tee, cardi]),
        overrides: closetOverride([tee, cardi, hoodie]),
      );
      await tester.pump();

      await tester.tap(find.text('Cardi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoodie'));
      await tester.pumpAndSettle();

      expect(find.text('Cardi'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Tee')).dy,
        lessThan(tester.getTopLeft(find.text('Hoodie')).dy),
        reason: 'the swap keeps the row in place',
      );
    });

    testWidgets('Match a Look\'s top replaces the interchangeable worn top, '
        'keeps the other, and leaves with the reference look', (tester) async {
      useTallSurface(tester);
      final photo = (await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('match_look');
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 4, 4),
          Paint()..color = const Color(0xFF888888),
        );
        final image = await recorder.endRecording().toImage(4, 4);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${dir.path}/look.png');
        await file.writeAsBytes(png!.buffer.asUint8List());
        return file.path;
      }))!;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/reference/init-upload')) {
          return jsonResponse(
            envelope({
              'upload_url': 'https://storage.example/look.jpg',
              'object_name': 'look.jpg',
            }),
          );
        }
        if (path.endsWith('/look.jpg')) return http.Response('', 200);
        if (path.endsWith('/match')) {
          return jsonResponse(
            envelope({
              'reference_id': 1,
              'roles': [
                {
                  'role': 'top',
                  'match_status': 'strong_match',
                  'selected_garment_id': polo.id,
                },
              ],
              'garments': [
                {
                  'id': polo.id,
                  'garment_id': polo.id,
                  'name': polo.name,
                  'category': 'Top',
                  'sub_category': polo.subCategory,
                },
              ],
            }),
          );
        }
        return jsonResponse(envelope(<String, dynamic>{}));
      });

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          CreateOutfitPage(
            initialGarments: [tee, cardi, jeans, boots],
            initialMatchALookImagePath: photo,
          ),
          overrides: closetOverride([tee, cardi, polo, jeans, boots]),
        );
        // The photo is read off the fake clock.
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }

        expect(find.text('Tee'), findsNothing);
        expect(find.text('Top · Polo shirt'), findsOneWidget);
        expect(find.text('Top · Cardigan'), findsOneWidget);
        expect(find.text('1 pieces matched'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove Reference Look'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Polo'), findsNothing);
        expect(find.text('Top · Cardigan'), findsOneWidget);
      }, () => client);
    });
  });

  group('version mode (Outfit Details\' Add Version)', () {
    testWidgets('starts from the source version and only offers Create '
        'Version once something changed', (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        CreateOutfitPage(
          initialGarments: [closet[0], closet[1], closet[2]],
          targetGroupId: 40,
          initialBackgroundId: 7,
        ),
        overrides: closetOverride(),
      );
      await tester.pump();

      expect(find.text('Add Version'), findsOneWidget);
      expect(find.byTooltip('Match a Look'), findsOneWidget);
      expect(find.text('Tokyo Street'), findsOneWidget);
      expect(
        find.widgetWithText(BottomActionButton, 'Create Version'),
        findsNothing,
      );

      await tester.ensureVisible(find.text('Tokyo Street'));
      await tester.tap(find.text('Tokyo Street'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paris Street'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(BottomActionButton, 'Create Version'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(BottomActionButton, 'Create Outfit'),
        findsNothing,
      );
    });

    testWidgets('renders into the target group and pops the new version '
        'instead of opening it as a new outfit', (tester) async {
      useTallSurface(tester);
      final generateBodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/generate')) {
          generateBodies.add({
            'path': request.url.path,
            ...jsonDecode(request.body) as Map<String, dynamic>,
          });
          return jsonResponse(
            envelope({
              'outfit_id': 77,
              'group_id': 40,
              'result_image_url': '',
              'garment_ids': [1, 2, 3],
            }),
          );
        }
        return jsonResponse(envelope(null), status: 404);
      });

      Outfit? popped;
      await http.runWithClient(() async {
        await pumpApp(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.push<Outfit>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateOutfitPage(
                        initialGarments: [closet[0], closet[1], closet[2]],
                        targetGroupId: 40,
                        initialBackgroundId: 7,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          overrides: closetOverride(),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Tokyo Street'));
        await tester.tap(find.text('Tokyo Street'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paris Street'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(BottomActionButton, 'Create Version'),
        );
        await tester.pumpAndSettle();
      }, () => client);

      expect(generateBodies, hasLength(1));
      expect(generateBodies.single['path'], endsWith('/outfit/40/generate'));
      expect(generateBodies.single['garment_ids'], [1, 2, 3]);
      expect(generateBodies.single['background_id'], 6);
      expect(find.byType(CreateOutfitPage), findsNothing);
      expect(find.byType(OutfitDetailsPage), findsNothing);
      expect(popped?.id, 77);
      expect(popped?.groupId, 40);
    });
  });
}

class _FakeWeather extends WeatherNotifier {
  @override
  Future<WeatherData> build() async => WeatherData(
    location: 'Test City',
    temp: 30,
    high: 28,
    low: 18,
    condition: 'Clear',
    weeklyCodes: const [0],
    weeklyHighs: const [28],
    weeklyLows: const [18],
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );
}
