import 'dart:async';
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
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
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

      // Always shown; with nothing picked, a tap lists every core item.
      await tester.tap(
        find.widgetWithText(BottomActionButton, 'Create Outfit'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Missing Items'), findsOneWidget);
      for (final label in ['Top', 'Bottom', 'Shoes']) {
        expect(find.widgetWithText(CategoryTag, label), findsOneWidget);
      }
    },
  );

  testWidgets('tapping Create Outfit without Shoes names only Shoes, and '
      'Add Garment opens the Shoes tab', (tester) async {
    useTallSurface(tester);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return jsonResponse(envelope(null), status: 500);
    });

    await http.runWithClient(() async {
      await pumpApp(
        tester,
        CreateOutfitPage(
          initialGarments: [closet[0], closet[1]], // Top + Bottom, no Shoes
        ),
        overrides: closetOverride(),
      );
      await tester.pump();

      await tester.tap(
        find.widgetWithText(BottomActionButton, 'Create Outfit'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Missing Items'), findsOneWidget);
      expect(find.widgetWithText(CategoryTag, 'Shoes'), findsOneWidget);
      expect(find.byType(CategoryTag), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Add Garment'),
        ),
      );
      await tester.pumpAndSettle();
      final picker = tester.widget<SelectGarmentPage>(
        find.byType(SelectGarmentPage),
      );
      expect(picker.category, GarmentCategory.shoes);
    }, () => client);

    expect(requests, isEmpty, reason: 'no render without the core items');
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
        find.widgetWithText(AccentPillButton, 'Go'),
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
      final finish = find.widgetWithText(AccentPillButton, 'Go');
      expect(finish, findsOneWidget);
      // Pill to the right of the title/description, all above the tiles.
      expect(find.text('AI Styling'), findsOneWidget);
      final description = find.text('Let AI complete your outfit.');
      expect(
        tester.getRect(description).bottom,
        lessThan(tester.getRect(find.text('TEMPERATURE')).top),
      );
      expect(
        tester.getRect(finish).left,
        greaterThan(tester.getRect(description).right),
      );
      expect(
        tester.getRect(finish).bottom,
        lessThan(tester.getRect(find.text('TEMPERATURE')).top),
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
        await tester.tap(find.widgetWithText(AccentPillButton, 'Go'));
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

        await tester.tap(find.widgetWithText(AccentPillButton, 'Go'));
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

      await tester.tap(find.widgetWithText(AccentPillButton, 'Go'));
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

  testWidgets('Stop Waiting asks first, then leaves; the render that lands '
      'afterwards is kept and refreshes Outfits', (tester) async {
    useTallSurface(tester);
    final pending = Completer<http.Response>();
    final deleted = <String>[];
    final outfitListFetches = <DateTime>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path.endsWith('/outfit')) {
        outfitListFetches.add(DateTime.now());
      }
      if (request.method == 'POST' && path.endsWith('/outfit')) {
        return jsonResponse(envelope({'group_id': 42}));
      }
      if (request.method == 'POST' && path.endsWith('/generate')) {
        return pending.future;
      }
      if (request.method == 'DELETE') {
        deleted.add(path);
        return jsonResponse(envelope(null));
      }
      return jsonResponse(envelope({'items': []}));
    });

    await http.runWithClient(() async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateOutfitPage(initialGarments: closet),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: closetOverride(closet),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(
        find.widgetWithText(BottomActionButton, 'Create Outfit'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      Finder dialogButton(String label) => find.descendant(
        of: find.byType(AppDialog),
        matching: find.text(label),
      );

      await tester.tap(find.text('Stop Waiting'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Stop Waiting?'), findsOneWidget);
      await tester.tap(dialogButton('Keep Waiting'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CreateOutfitPage), findsOneWidget);

      await tester.tap(find.text('Stop Waiting'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(dialogButton('Stop Waiting'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CreateOutfitPage), findsNothing);
      final fetchesBeforeLanding = outfitListFetches.length;

      pending.complete(
        jsonResponse(
          envelope({
            'outfit_id': 99,
            'group_id': 42,
            'result_image_url': 'https://img.example/outfit.png',
            'garment_ids': [1, 2, 3],
          }),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(deleted, isEmpty, reason: 'a finished render is never discarded');
      expect(outfitListFetches.length, greaterThan(fetchesBeforeLanding));
    }, () => client);
  });

  group('remaining try-ons', () {
    Map<String, dynamic> quota({int? limit = 10, int? remaining}) => {
      'limit': limit,
      'used': limit == null ? 3 : limit - (remaining ?? 0),
      'remaining': remaining,
      'resets_at': '2026-11-03T00:00:00+08:00',
    };

    /// Renders a version (it pops back on success, so the message shows on
    /// the host page). [quotaReply] null = never asked.
    Future<int> renderVersion(
      WidgetTester tester, {
      required bool succeed,
      http.Response Function()? quotaReply,
    }) async {
      useTallSurface(tester);
      var quotaReads = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/generation-quota')) {
          quotaReads++;
          return quotaReply!();
        }
        if (path.endsWith('/generate')) {
          return succeed
              ? jsonResponse(
                  envelope({
                    'outfit_id': 77,
                    'group_id': 40,
                    'result_image_url': '',
                    'garment_ids': [1, 2, 3],
                  }),
                )
              : jsonResponse({
                  'success': false,
                  'error_code': 'LOOK_GENERATION_FAILED',
                }, status: 500);
        }
        return jsonResponse(envelope(null), status: 404);
      });
      await http.runWithClient(() async {
        await pumpApp(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push<Outfit>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateOutfitPage(
                      initialGarments: [closet[0], closet[1], closet[2]],
                      targetGroupId: 40,
                      initialBackgroundId: 7,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          overrides: closetOverride(),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BottomActionButton),
            matching: find.textContaining('left'),
          ),
          findsNothing,
          reason: 'no count on the button',
        );
        // A version identical to its source isn't rendered.
        await tester.ensureVisible(find.text('Tokyo Street'));
        await tester.tap(find.text('Tokyo Street'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paris Street'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(BottomActionButton, 'Create Version'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }, () => client);
      return quotaReads;
    }

    testWidgets('a render that used a try-on is followed by the count left', (
      tester,
    ) async {
      final reads = await renderVersion(
        tester,
        succeed: true,
        quotaReply: () => jsonResponse(envelope(quota(remaining: 2))),
      );
      expect(reads, 1);
      expect(find.byType(CreateOutfitPage), findsNothing);
      expect(find.text('2 AI try-ons left today'), findsOneWidget);
    });

    testWidgets('the last one says so', (tester) async {
      await renderVersion(
        tester,
        succeed: true,
        quotaReply: () => jsonResponse(envelope(quota(remaining: 0))),
      );
      expect(find.text('That was your last AI try-on today'), findsOneWidget);
    });

    testWidgets('nothing after a failed render (nothing was used)', (
      tester,
    ) async {
      final reads = await renderVersion(tester, succeed: false);
      expect(reads, 0);
      expect(find.textContaining('AI try-on'), findsNothing);
    });

    testWidgets('nothing for an unlimited tier or when the count can\'t be '
        'read', (tester) async {
      for (final reply in [
        () => jsonResponse(envelope(quota(limit: null))),
        () => jsonResponse({'success': false, 'message': 'x'}, status: 503),
      ]) {
        await renderVersion(tester, succeed: true, quotaReply: reply);
        expect(find.textContaining('AI try-on'), findsNothing);
        expect(find.byType(CreateOutfitPage), findsNothing);
      }
    });
  });

  group('try-on', () {
    Future<void> openFromRoute(WidgetTester tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateOutfitPage(initialGarments: closet),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: closetOverride(closet),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Finder createButton() =>
        find.widgetWithText(BottomActionButton, 'Create Outfit');

    testWidgets('a rapid double tap sends one generate', (tester) async {
      useTallSurface(tester);
      final pending = Completer<http.Response>();
      var generates = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path.endsWith('/outfit')) {
          return jsonResponse(envelope({'group_id': 42}));
        }
        if (request.method == 'POST' && path.endsWith('/generate')) {
          generates++;
          return pending.future;
        }
        return jsonResponse(envelope({'items': []}));
      });
      await http.runWithClient(() async {
        await openFromRoute(tester);
        await tester.tap(createButton());
        await tester.tap(createButton(), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(generates, 1);
        pending.complete(jsonResponse(envelope(null), status: 500));
        await tester.pump(const Duration(seconds: 1));
      }, () => client);
    });

    testWidgets('a system back mid-render asks before leaving', (tester) async {
      useTallSurface(tester);
      final pending = Completer<http.Response>();
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path.endsWith('/outfit')) {
          return jsonResponse(envelope({'group_id': 42}));
        }
        if (request.method == 'POST' && path.endsWith('/generate')) {
          return pending.future;
        }
        return jsonResponse(envelope({'items': []}));
      });
      await http.runWithClient(() async {
        await openFromRoute(tester);
        await tester.tap(createButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Stop Waiting?'), findsOneWidget);
        expect(find.byType(CreateOutfitPage), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Keep Waiting'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CreateOutfitPage), findsOneWidget);

        pending.complete(jsonResponse(envelope(null), status: 500));
        await tester.pump(const Duration(seconds: 1));
      }, () => client);
    });

    testWidgets('iOS: the edge swipe is held mid-render (Stop Waiting is the '
        'way out) and works again once it is done', (tester) async {
      useTallSurface(tester);
      final pending = Completer<http.Response>();
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path.endsWith('/outfit')) {
          return jsonResponse(envelope({'group_id': 42}));
        }
        if (request.method == 'POST' && path.endsWith('/generate')) {
          return pending.future;
        }
        return jsonResponse(envelope({'items': []}));
      });
      await http.runWithClient(() async {
        await openFromRoute(tester);
        await tester.tap(createButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.dragFrom(const Offset(2, 600), const Offset(600, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CreateOutfitPage), findsOneWidget);
        expect(find.text('Stop Waiting?'), findsNothing);

        pending.complete(jsonResponse(envelope(null), status: 500));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('OK'));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.dragFrom(const Offset(2, 600), const Offset(600, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(CreateOutfitPage), findsNothing);
      }, () => client);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('when status can\'t be checked, Create Outfit again asks '
        'first and sends nothing if declined', (tester) async {
      useTallSurface(tester);
      var generates = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path.endsWith('/outfit')) {
          return jsonResponse(envelope({'group_id': 42}));
        }
        if (request.method == 'POST' && path.endsWith('/generate')) {
          generates++;
          throw TimeoutException('slow');
        }
        if (path.contains('/outfit/generations/')) {
          return jsonResponse({'success': false, 'message': 'x'}, status: 422);
        }
        if (path.endsWith('/outfit/42')) {
          return jsonResponse(
            envelope({'group_id': 42, 'outfits': <Object>[]}),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });
      await http.runWithClient(() async {
        await openFromRoute(tester);
        await tester.tap(createButton());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text(
            "We couldn't confirm whether this try-on finished. If it did, "
            'it will appear in Outfits.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('OK'));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(createButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Try Again?'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(generates, 1);
      }, () => client);
    });
  });

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

      await removeRow(tester, 'Hoodie');

      expect(find.text('Hoodie'), findsNothing);
      expect(find.text('Top · T-shirt'), findsOneWidget);
      expect(
        find.widgetWithText(BottomActionButton, 'Create Version'),
        findsOneWidget,
      );

      // With no top left, Top is missing again.
      await removeRow(tester, 'Tee');
      await tester.tap(
        find.widgetWithText(BottomActionButton, 'Create Version'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Missing Items'), findsOneWidget);
      expect(find.widgetWithText(CategoryTag, 'Top'), findsOneWidget);
      expect(find.byType(CategoryTag), findsOneWidget);
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
    testWidgets('starts from the source version and only creates a '
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

      // Unchanged: the tap explains instead of re-rendering the source.
      await tester.tap(
        find.widgetWithText(BottomActionButton, 'Create Version'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing Changed Yet'), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(AppDialog), matching: find.text('OK')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing Changed Yet'), findsNothing);

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
  group('Finish with AI Cancel', () {
    final pool = [
      ...closet,
      _garment(id: 4, category: GarmentCategory.top, name: 'Polo'),
    ];

    Map<String, dynamic> advice(int topId) => {
      'outfit_name': 'AI Pick',
      'selected_garment_ids': [topId, 2, 3],
      'items': [
        {'garment_id': topId, 'role': 'top', 'order': 0, 'reason': null},
        {'garment_id': 2, 'role': 'bottom', 'order': 1, 'reason': null},
        {'garment_id': 3, 'role': 'shoes', 'order': 2, 'reason': null},
      ],
      'styling_tips': null,
      'reasoning': null,
    };

    /// Each advice call waits on its own gate (completed with the top's
    /// id), so a test decides the order replies land in.
    MockClient gatedClient(List<Completer<int>> gates) {
      return MockClient((request) async {
        if (request.url.path.endsWith('/outfit/advice')) {
          final gate = Completer<int>();
          gates.add(gate);
          return jsonResponse(envelope(advice(await gate.future)));
        }
        return jsonResponse(envelope(null), status: 500);
      });
    }

    List<Override> overrides() => [
      ...closetOverride(pool),
      weatherProvider.overrideWith(_FakeWeather.new),
    ];

    Future<void> startFinishWithAi(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(AccentPillButton, 'Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> land(
      WidgetTester tester,
      Completer<int> gate,
      int topId,
    ) async {
      gate.complete(topId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Finder overlay() => find.byType(LoadingOverlay);

    testWidgets('Cancel closes the overlay; a reply landing afterwards '
        'fills nothing in', (tester) async {
      useTallSurface(tester);
      final gates = <Completer<int>>[];
      await http.runWithClient(() async {
        await pumpApp(tester, const CreateOutfitPage(), overrides: overrides());
        await tester.pump();

        await startFinishWithAi(tester);
        expect(overlay(), findsOneWidget);
        expect(gates, hasLength(1));

        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(overlay(), findsNothing);

        await land(tester, gates.single, 1);
        expect(find.text('Tee'), findsNothing);
        expect(find.byIcon(Icons.lock_open), findsNothing);
        expect(
          find.text(
            "Couldn't complete your outfit with AI — please try "
            'again.',
          ),
          findsNothing,
        );
      }, () => gatedClient(gates));
    });

    testWidgets('a cancelled run that lands after a newer one can\'t '
        'overwrite it', (tester) async {
      useTallSurface(tester);
      final gates = <Completer<int>>[];
      await http.runWithClient(() async {
        await pumpApp(tester, const CreateOutfitPage(), overrides: overrides());
        await tester.pump();

        await startFinishWithAi(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // Restartable at once, without waiting for the cancelled request.
        await startFinishWithAi(tester);
        expect(gates, hasLength(2));

        await land(tester, gates[1], 4);
        expect(overlay(), findsNothing);
        expect(find.text('Polo'), findsOneWidget);

        await land(tester, gates[0], 1);
        expect(find.text('Polo'), findsOneWidget);
        expect(find.text('Tee'), findsNothing);
      }, () => gatedClient(gates));
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
