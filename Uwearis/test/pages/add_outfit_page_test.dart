import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/add_outfit_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

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

  // preloadedGarments short-circuits the initState network fetch, so the
  // page renders without any HTTP mocking.
  final closet = [
    _garment(id: 1, category: GarmentCategory.top, name: 'Tee'),
    _garment(id: 2, category: GarmentCategory.bottom, name: 'Jeans'),
    _garment(id: 3, category: GarmentCategory.shoes, name: 'Sneakers'),
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
    await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
    await tester.pump();

    expect(find.text('Match a Look'), findsOneWidget);
    expect(find.text('YOUR OUTFIT'), findsOneWidget);
    // Nothing picked yet — only the "Add Garment" row is in the list.
    expect(find.text('Add Garment'), findsOneWidget);

    // Fewer than two garments, so the Create Outfit bar is gated off
    // (hidden, not greyed) — see BottomActionButton._isUnavailable.
    expect(find.text('Create Outfit'), findsNothing);
    expect(
      find.byKey(const ValueKey('bottomActionButton-hidden')),
      findsOneWidget,
    );
  });

  testWidgets('Create Outfit stays hidden until the checklist is complete', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        preloadedGarments: closet,
        initialGarments: [closet[0], closet[1]], // Top + Bottom, no Shoes
      ),
    );
    await tester.pump();
    expect(find.text('Create Outfit'), findsNothing);
  });

  testWidgets('Create Outfit appears once Top, Bottom and Shoes are all set', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        preloadedGarments: closet,
        initialGarments: [closet[0], closet[1], closet[2]],
      ),
    );
    await tester.pump();
    expect(find.text('Create Outfit'), findsOneWidget);
  });

  testWidgets('the core checklist shows Top/Bottom/Shoes progress', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        preloadedGarments: closet,
        initialGarments: [closet[0]], // just the top
      ),
    );
    await tester.pump();

    expect(find.text('Bottom'), findsOneWidget); // checklist only
    expect(find.text('Shoes'), findsOneWidget);
    // Top satisfied, Bottom + Shoes still open.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
  });

  testWidgets(
    'a manually added garment is locked by default; removing it clears the lock',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
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
    await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
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

  testWidgets('the Complete with AI pill is enabled with zero garments picked', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
    await tester.pump();

    final pill = tester.widget<AccentPillButton>(find.byType(AccentPillButton));
    expect(pill.enabled, isTrue);
  });

  testWidgets(
    'the context row opens a settings sheet to adjust occasion and temperature',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
      await tester.pump();

      // No weather in tests — the row starts showing just the occasion.
      await tester.tap(find.text('Casual'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6)); // weather lookup timeout
      await tester.pumpAndSettle();

      expect(find.text('Outfit context'), findsOneWidget);
      expect(find.text('20°C'), findsOneWidget); // fallback default

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('21°C'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Outfit context'), findsNothing);

      // The row itself now reflects the adjusted temperature.
      expect(find.text('Casual · 21°C'), findsOneWidget);
    },
  );

  testWidgets(
    'Complete with AI shows the intro dialog once, applies the recommended '
    'garments, then skips the dialog on a later tap',
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

      await http.runWithClient(() async {
        await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
        await tester.pump();

        await tester.tap(find.byType(AccentPillButton));
        await tester.pump();
        // Fast-forward past the (best-effort, unmocked-in-tests) weather
        // lookup's own timeout so the dialog's build isn't left waiting on
        // it — geolocator has no mock handler registered here, so it hangs
        // rather than throwing, same as flutter_secure_storage.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.text('Complete your outfit'), findsOneWidget);

        // Confirming calls _completeWithAi, which does its own best-effort
        // weather lookup before the (mocked) recommendation request. Plain
        // (not pumpAndSettle) pumps here: the in-flight LoadingOverlay's
        // spinner animates forever, which would make pumpAndSettle time out
        // regardless of the async work underneath.
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Complete with AI'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
        expect(find.text('Complete your outfit'), findsNothing);

        // The recommended garments are now in place, unlocked, and the
        // Top/Bottom/Shoes checklist is satisfied.
        expect(find.text('Create Outfit'), findsOneWidget);
        expect(find.byIcon(Icons.lock_open), findsNWidgets(3));
        expect(requests, hasLength(1));
        expect(
          jsonDecode(requests.single.body)['exclude_garment_ids'],
          <int>[],
        );

        // Second tap: the intro dialog doesn't reappear, and this run asks
        // the AI to avoid repeating the first run's (unlocked) picks.
        await tester.tap(find.byType(AccentPillButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
        expect(find.text('Complete your outfit'), findsNothing);
        expect(requests, hasLength(2));
        expect(
          jsonDecode(requests[1].body)['exclude_garment_ids'],
          unorderedEquals([1, 2, 3]),
        );
      }, () => client);
    },
  );

  testWidgets('Complete with AI surfaces a SnackBar when the request fails', (
    tester,
  ) async {
    useTallSurface(tester);
    final client = MockClient(
      (request) async => jsonResponse(envelope(null), status: 500),
    );

    await http.runWithClient(() async {
      await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
      await tester.pump();

      await tester.tap(find.byType(AccentPillButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Complete your outfit'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Complete with AI'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Complete your outfit'), findsNothing);
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
          preloadedGarments: wardrobe,
          // Wearing the Jeans (fills Bottom) and the Ray-Bans (sunglasses).
          initialGarments: [wardrobe[1], wardrobe[3]],
        ),
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

  testWidgets('selectOnly mode drops Match a Look and uses the edit copy', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        preloadedGarments: closet,
        initialGarments: [closet.first],
        selectOnly: true,
      ),
    );
    await tester.pump();

    expect(find.text('Match a Look'), findsNothing);
    expect(
      find.text("Choose which suitcase items make up this day's outfit."),
      findsOneWidget,
    );
    // Confirm stays hidden until the selection actually changes.
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets(
    'create mode shows a collapsed Background section; tapping it opens the picker',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(tester, AddOutfitPage(preloadedGarments: closet));
      await tester.pump();
      // Its own "BACKGROUND" header, not the selectOnly/edit flow's combined
      // "Accessories & Background" panel.
      expect(find.text('Accessories & Background'), findsNothing);
      expect(find.text('BACKGROUND'), findsOneWidget);
      expect(find.text('(OPTIONAL)'), findsNothing);

      AnimatedCrossFade crossFade() =>
          tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(crossFade().crossFadeState, CrossFadeState.showSecond);

      await tester.tap(find.text('BACKGROUND'));
      await tester.pumpAndSettle();
      expect(crossFade().crossFadeState, CrossFadeState.showFirst);

      await tester.tap(find.text('BACKGROUND'));
      await tester.pumpAndSettle();
      expect(crossFade().crossFadeState, CrossFadeState.showSecond);
    },
  );

  testWidgets('selectOnly customization block drops the Background section', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      AddOutfitPage(
        preloadedGarments: closet,
        initialGarments: [closet.first],
        selectOnly: true,
      ),
    );
    await tester.pump();
    expect(find.text('BACKGROUND'), findsNothing);
  });

  testWidgets(
    'existingOutfit ("Create Another Version") uses the same layout as the '
    'plain New Outfit create flow',
    (tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        AddOutfitPage(
          existingOutfit: Outfit(id: 1, imageUrl: ''),
          initialGarments: closet,
          preloadedGarments: closet,
        ),
      );
      await tester.pump();

      // Markers of the create flow's vertical-list body — none of these
      // exist in the older per-category slot layout ([_buildSlotFlowBody]).
      expect(find.text('YOUR OUTFIT'), findsOneWidget);
      expect(find.byType(AccentPillButton), findsOneWidget);
      expect(find.text('Add Garment'), findsOneWidget);
      expect(find.text('BACKGROUND'), findsOneWidget);
      // The slot flow's per-category rows (FieldLabel renders uppercased)
      // are gone.
      expect(find.text('MID LAYER'), findsNothing);
    },
  );

  testWidgets(
    'existingOutfit keeps its own Create Outfit readiness rule even though '
    'it now shares the create flow layout',
    (tester) async {
      useTallSurface(tester);
      // A one-piece counts for both Top and Bottom under the plain create
      // flow's readiness check (_coreComplete/_createFlowReady), but
      // existingOutfit deliberately keeps its own older rule (_hasCoreSlots,
      // which checks _outfit.bottom directly) — see the comments on
      // _showsBottomActionButton/_buildBottomBar. Top and Bottom both being
      // real closet categories (even though neither is actually picked)
      // triggers the difference between the two rules.
      final onePieceCloset = [
        _garment(id: 10, category: GarmentCategory.top, name: 'Shirt'),
        _garment(id: 11, category: GarmentCategory.bottom, name: 'Jeans'),
        _garment(id: 12, category: GarmentCategory.onePiece, name: 'Dress'),
        _garment(id: 13, category: GarmentCategory.shoes, name: 'Heels'),
      ];
      await pumpApp(
        tester,
        AddOutfitPage(
          existingOutfit: Outfit(id: 1, imageUrl: ''),
          initialGarments: [onePieceCloset[2], onePieceCloset[3]],
          preloadedGarments: onePieceCloset,
        ),
      );
      await tester.pump();

      expect(find.text('Create Outfit'), findsNothing);
    },
  );
}
