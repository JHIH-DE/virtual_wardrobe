import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/add_outfit_page.dart';
import 'package:uwearis/features/pages/outfit_details_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

/// garmentsProvider seeded with a fixed closet — the page reads it directly,
/// so every test overrides it instead of hitting the network.
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

  /// Overrides garmentsProvider with [pool] (default [closet]) — pass to
  /// `pumpApp`'s `overrides:`.
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

  testWidgets('create mode shows Match a Look and an empty Your Outfit row', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(tester, const AddOutfitPage(), overrides: closetOverride());
    await tester.pump();

    expect(find.text('Match a Look'), findsOneWidget);
    expect(find.text('YOUR OUTFIT'), findsOneWidget);
    // Nothing picked yet — only the "Add Garment" row is in the list.
    expect(find.text('Add Garment'), findsOneWidget);

    // Create Outfit is always shown now — missing core slots get filled by
    // Finish Outfit before the render (see _startTryOn).
    expect(
      find.widgetWithText(BottomActionButton, 'Create Outfit'),
      findsOneWidget,
    );
  });

  testWidgets('Create Outfit shows even when the checklist is incomplete', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        initialGarments: [closet[0], closet[1]], // Top + Bottom, no Shoes
      ),
      overrides: closetOverride(),
    );
    await tester.pump();
    expect(
      find.widgetWithText(BottomActionButton, 'Create Outfit'),
      findsOneWidget,
    );
  });

  testWidgets('Create Outfit appears once Top, Bottom and Shoes are all set', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(initialGarments: [closet[0], closet[1], closet[2]]),
      overrides: closetOverride(),
    );
    await tester.pump();
    expect(
      find.widgetWithText(BottomActionButton, 'Create Outfit'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Create Outfit with a missing core slot runs Finish Outfit before rendering',
    (tester) async {
      useTallSurface(tester);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/outfit/advice')) {
          return jsonResponse(
            envelope({
              'outfit_name': 'AI Pick',
              'selected_garment_ids': [1, 2, 3],
              'items': const [
                {'garment_id': 1, 'role': 'top', 'order': 0, 'reason': null},
                {'garment_id': 2, 'role': 'bottom', 'order': 1, 'reason': null},
                {'garment_id': 3, 'role': 'shoes', 'order': 2, 'reason': null},
              ],
              'styling_tips': null,
              'reasoning': null,
            }),
          );
        }
        // The try-on generate call that follows — fail it so the flow stops
        // after the Finish Outfit step (this test only asserts the ordering).
        return jsonResponse(envelope(null), status: 500);
      });

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          AddOutfitPage(
            initialGarments: [closet[0], closet[1]], // Top + Bottom, no Shoes
          ),
          overrides: closetOverride(),
        );
        await tester.pump();

        await tester.tap(
          find.widgetWithText(BottomActionButton, 'Create Outfit'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 6)); // weather timeout
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(
          requests.any((r) => r.url.path.endsWith('/outfit/advice')),
          isTrue,
        );
      }, () => client);
    },
  );

  testWidgets(
    'a manually added garment is locked by default; removing it clears the lock',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(tester, const AddOutfitPage(), overrides: closetOverride());
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
    await pumpApp(tester, const AddOutfitPage(), overrides: closetOverride());
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
      await pumpApp(tester, const AddOutfitPage(), overrides: closetOverride());
      await tester.pump();

      final pill = tester.widget<AccentPillButton>(
        find.byType(AccentPillButton),
      );
      expect(pill.enabled, isTrue);
    },
  );

  testWidgets(
    'the Finish Outfit dialog holds the occasion + temperature knobs',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(tester, const AddOutfitPage(), overrides: closetOverride());
      await tester.pump();
      await tester.pump(const Duration(seconds: 6)); // weather lookup settles
      await tester.pumpAndSettle();

      // No occasion/temperature UI on the page itself anymore.
      expect(find.text('Occasion'), findsNothing);

      await tester.tap(find.byType(AccentPillButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      // The dialog: explainer, occasion row, temperature stepper, CTA.
      expect(
        find.text('Let AI complete your selected pieces.'),
        findsOneWidget,
      );
      expect(find.text('Occasion'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('20°C'), findsOneWidget); // fallback default
      expect(
        find.widgetWithText(ElevatedButton, 'Finish with AI'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('21°C'), findsOneWidget);

      // Occasion picked via the shared bottom sheet, dialog stays open.
      await tester.tap(find.text('Occasion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('21°C'), findsOneWidget);
    },
  );

  testWidgets(
    'Finish Outfit dialog applies the AI picks; a later run excludes them',
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

      // Open the Finish Outfit dialog and confirm with "Finish with AI".
      // Plain pumps after confirm: _completeWithAi's LoadingOverlay spinner
      // animates forever, so pumpAndSettle would time out.
      Future<void> runFinishWithAi() async {
        await tester.tap(find.byType(AccentPillButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Finish with AI'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
      }

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          const AddOutfitPage(),
          overrides: closetOverride(),
        );
        await tester.pump();

        await runFinishWithAi();

        // The recommended garments are now in place, unlocked, and the
        // Create Outfit gate is satisfied.
        expect(
          find.widgetWithText(BottomActionButton, 'Create Outfit'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.lock_open), findsNWidgets(3));
        expect(requests, hasLength(1));
        expect(
          jsonDecode(requests.single.body)['exclude_garment_ids'],
          <int>[],
        );

        // A second run: the dialog shows again (no first-use gating), and
        // this run asks the AI to avoid repeating the first run's picks.
        await runFinishWithAi();
        expect(requests, hasLength(2));
        expect(
          jsonDecode(requests[1].body)['exclude_garment_ids'],
          unorderedEquals([1, 2, 3]),
        );
      }, () => client);
    },
  );

  testWidgets('Finish Outfit surfaces a SnackBar when the request fails', (
    tester,
  ) async {
    useTallSurface(tester);
    final client = MockClient(
      (request) async => jsonResponse(envelope(null), status: 500),
    );

    await http.runWithClient(() async {
      await pumpApp(tester, const AddOutfitPage(), overrides: closetOverride());
      await tester.pump();

      await tester.tap(find.byType(AccentPillButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ElevatedButton, 'Finish with AI'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Finish with AI'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(
        find.widgetWithText(ElevatedButton, 'Finish with AI'),
        findsNothing,
      );
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
        AddOutfitPage(
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
        _garment(id: 1, category: GarmentCategory.top, name: 'Tee', subCategory: 'T-shirt'),
        _garment(id: 2, category: GarmentCategory.top, name: 'Polo', subCategory: 'Polo shirt'),
        _garment(id: 3, category: GarmentCategory.top, name: 'Cardi', subCategory: 'Cardigan'),
      ];
      await pumpApp(
        tester,
        AddOutfitPage(initialGarments: [wardrobe[0]]),
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
        _garment(id: 1, category: GarmentCategory.top, name: 'Tee', subCategory: 'T-shirt'),
        _garment(id: 2, category: GarmentCategory.top, name: 'Polo', subCategory: 'Polo shirt'),
      ];
      await pumpApp(
        tester,
        AddOutfitPage(initialGarments: [wardrobe[0]]),
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
    'shows a collapsed Background section; tapping it opens the picker',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(tester, const AddOutfitPage(), overrides: closetOverride());
      await tester.pump();
      expect(find.text('BACKGROUND'), findsOneWidget);
      expect(find.text('(OPTIONAL)'), findsNothing);

      AnimatedCrossFade crossFade() => tester.widget<AnimatedCrossFade>(
        find.byKey(const ValueKey('backgroundSection')),
      );
      expect(crossFade().crossFadeState, CrossFadeState.showSecond);

      await tester.tap(find.text('BACKGROUND'));
      await tester.pumpAndSettle();
      expect(crossFade().crossFadeState, CrossFadeState.showFirst);

      await tester.tap(find.text('BACKGROUND'));
      await tester.pumpAndSettle();
      expect(crossFade().crossFadeState, CrossFadeState.showSecond);
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
          AddOutfitPage(initialGarments: wardrobe), // Top+Bottom+Shoes+Ray-Bans
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

        // Now on OutfitDetailsPage — back out and choose Save, same as the
        // reported repro (create → save → return to Add Outfit). Plain
        // pumps, not pumpAndSettle: the page's own loading spinner (while
        // it resolves garments/saved-status) animates forever.
        expect(find.byType(OutfitDetailsPage), findsOneWidget);
        await tester.tap(find.byType(IconButton).first);
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
        // Unrelated to this test: the post-save "Outfit saved" toast
        // (showFeedbackOverlay) overflows its fixed-width box under the
        // test font's wider metrics — not something this fix touches.
        tester.takeException();

        // Back on Add Outfit — the accessory picked before "Create Outfit"
        // must still be there, exactly like the core Top/Bottom/Shoes slots.
        expect(find.byType(AddOutfitPage), findsOneWidget);
        expect(find.text('Ray-Bans'), findsOneWidget);

        // Drain showFeedbackOverlay's auto-dismiss timer so it doesn't trip
        // the "pending timer after dispose" check at test teardown.
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
    },
  );
}
