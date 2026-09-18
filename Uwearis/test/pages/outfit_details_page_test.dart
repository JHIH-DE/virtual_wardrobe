import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/outfit_details_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_icon_button.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';
import 'package:uwearis/features/widgets/common/images/refreshable_network_image.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

Outfit _outfit({
  List<String> style = const [],
  String? name,
  List<int> garmentIds = const [],
  int groupId = 3,
}) {
  return Outfit(
    id: 1,
    groupId: groupId,
    name: name,
    imageUrl: 'https://img.example/1.png',
    style: style,
    garmentIds: garmentIds,
  );
}

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // _loadGroupOutfits (post-frame) is the only initState fetch while the
  // seed outfit carries no garment ids; it swallows failures, so any
  // benign error response keeps the seed version showing.
  http.Client stubClient() =>
      MockClient((_) async => jsonResponse(envelope({'items': []})));

  testWidgets('untagged outfit shows the "My Collection" fallback', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();

      expect(find.text('My Collection'), findsOneWidget);
      expect(find.byType(CategoryTag), findsNothing);
    }, stubClient);
  });

  testWidgets('style tags render as CategoryTag chips (title-cased)', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(style: ['smart_casual', 'street'])),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Smart Casual'), findsOneWidget);
      expect(find.text('Street'), findsOneWidget);
      expect(find.byType(CategoryTag), findsNWidgets(2));
    }, stubClient);
  });

  testWidgets('the page title falls back to the first tag word', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(name: 'Weekend Look')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Weekend Look'), findsOneWidget);
    }, stubClient);
  });

  // Regression: _loadGarments used to await every garment id in one
  // Future.wait, so a single 404 (e.g. a deleted garment) rejected the
  // whole batch and silently blanked out every *other* garment on the
  // outfit too. Each id now resolves independently.
  testWidgets('one garment failing to load does not blank out the rest', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/garments/1')) {
        return jsonResponse(envelope({}), status: 404);
      }
      if (request.url.path.endsWith('/garments/2')) {
        return jsonResponse(
          envelope({
            'id': 2,
            'name': 'Denim Jacket',
            'category': 'Outer',
            'sub_category': '',
            'upload_url': '',
            'object_name': '',
            'image_url': '',
          }),
        );
      }
      return jsonResponse(envelope({'items': []}));
    });

    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(garmentIds: [1, 2])),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Denim Jacket'), findsOneWidget);
    }, () => client);
  });

  testWidgets(
    'a soft-deleted garment shows a warning badge that clears once restored',
    (tester) async {
      var isDeleted = true;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/garments/60') &&
            request.method == 'GET') {
          return jsonResponse(
            envelope({
              'id': 60,
              'name': 'Old Sneakers',
              'category': 'Shoes',
              'sub_category': '',
              'upload_url': '',
              'object_name': '',
              'image_url': '',
              'is_deleted': isDeleted,
            }),
          );
        }
        if (request.url.path.endsWith('/garments/60') &&
            request.method == 'PATCH') {
          isDeleted = false;
          return jsonResponse(
            envelope({
              'id': 60,
              'name': 'Old Sneakers',
              'category': 'Shoes',
              'sub_category': '',
              'upload_url': '',
              'object_name': '',
              'image_url': '',
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
          OutfitDetailsPage(outfit: _outfit(garmentIds: [60], groupId: 704)),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Old Sneakers'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);

        await tester.tap(find.text('Old Sneakers'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('This item has been removed from your closet.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Add Back to Closet'));
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.error), findsNothing);
      }, () => client);
    },
  );

  // Regression: initState and _loadGroupOutfits (once it resolves) each
  // called _loadGarments independently, with no coordination — for the
  // common case where _loadGroupOutfits resolves to the same version
  // that's already showing, this re-fetched the same garments a second
  // time, flipping the garment section back to a spinner in between
  // (visible as a flash) for no reason.
  testWidgets(
    "_loadGroupOutfits resolving to the outfit's already-loaded version "
    "does not re-fetch its garments",
    (tester) async {
      // A garment id not used by any other test in this file — GarmentService
      // is a process-wide singleton with its own cache, so reusing an id
      // another test already fetched would hide a real double-fetch behind
      // that cache hit instead of exercising the network. OutfitService is
      // now the same kind of singleton for getGroupOutfits, so this test
      // also uses a group id (701) no other test's outfits mock a real
      // response for — otherwise a later test could be served this test's
      // cached group instead of hitting its own mock.
      var garmentRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/701')) {
          return jsonResponse(
            envelope({
              'outfits': [
                {
                  'id': 1,
                  'group_id': 701,
                  'image_url': 'https://img.example/1.png',
                  'garment_ids': [42],
                },
              ],
            }),
          );
        }
        if (request.url.path.endsWith('/garments/42')) {
          garmentRequests++;
          return jsonResponse(
            envelope({
              'id': 42,
              'name': 'Wool Scarf',
              'category': 'Accessory',
              'sub_category': '',
              'upload_url': '',
              'object_name': '',
              'image_url': '',
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(outfit: _outfit(garmentIds: [42], groupId: 701)),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Wool Scarf'), findsOneWidget);
        expect(garmentRequests, 1);
      }, () => client);
    },
  );

  testWidgets(
    'tapping the outfit photo opens it full-screen; tapping again closes it',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
        await tester.pump();
        await tester.pump();

        bool isBlackScaffold(Widget w) =>
            w is Scaffold && w.backgroundColor == Colors.black;
        expect(find.byWidgetPredicate(isBlackScaffold), findsNothing);

        await tester.tap(find.byType(RefreshableNetworkImage).first);
        // Not pumpAndSettle — CachedNetworkImage's placeholder spinner
        // animates indefinitely while the (blocked-in-tests) network fetch
        // never resolves.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byWidgetPredicate(isBlackScaffold), findsOneWidget);

        await tester.tapAt(const Offset(50, 50));
        await tester.pump();
        // A little past the 200ms transition — the route's post-animation
        // teardown lands a frame after the animation itself completes.
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byWidgetPredicate(isBlackScaffold), findsNothing);
      }, stubClient);
    },
  );

  testWidgets('the pill reads "New Version" with only a single version', (
    tester,
  ) async {
    useTallSurface(tester);

    // Single version: the seed outfit's own group has no siblings.
    await http.runWithClient(() async {
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();

      expect(find.text('New Version'), findsOneWidget);
    }, stubClient);
  });

  testWidgets('the pill shrinks to a bare "+" once a sibling version exists', (
    tester,
  ) async {
    useTallSurface(tester);
    // A group id no other test's outfits mock a real getGroupOutfits
    // response for — see the "does not re-fetch its garments" test above on
    // why that matters now that OutfitService caches per group id.
    const groupId = 702;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/$groupId')) {
        return jsonResponse(
          envelope({
            'outfits': [
              {
                'id': 1,
                'group_id': groupId,
                'image_url': 'https://img.example/1.png',
              },
              {
                'id': 2,
                'group_id': groupId,
                'image_url': 'https://img.example/2.png',
              },
            ],
          }),
        );
      }
      return jsonResponse(envelope({'items': []}));
    });

    await http.runWithClient(() async {
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(groupId: groupId)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('New Version'), findsNothing);
      // Also an unrelated AccentIconButton on this page (the tag-edit
      // pill) — narrow to the "+" one specifically.
      expect(find.widgetWithIcon(AccentIconButton, Icons.add), findsOneWidget);
      expect(find.byType(AccentPillButton), findsNothing);
    }, () => client);
  });

  // Regression: tapping "+ New Version" once the group already has
  // _maxVersions versions used to just open OutfitEditPage like any other
  // tap — the cap is enforced client-side, so nothing stopped one more.
  testWidgets(
    '"+ New Version" past the version cap explains the limit instead of '
    'opening the picker',
    (tester) async {
      // A group id no other test's outfits mock a real getGroupOutfits
      // response for — see the "does not re-fetch its garments" test above
      // on why that matters now that OutfitService caches per group id.
      const groupId = 703;
      // Matches _maxVersions in outfit_details_page.dart — keep in sync if
      // that constant changes.
      const maxVersions = 10;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/$groupId')) {
          return jsonResponse(
            envelope({
              'outfits': [
                for (var id = 1; id <= maxVersions; id++)
                  {
                    'id': id,
                    'group_id': groupId,
                    'image_url': 'https://img.example/$id.png',
                  },
              ],
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(outfit: _outfit(groupId: groupId)),
        );
        await tester.pump();
        await tester.pump();

        // maxVersions versions are already loaded, so the pill has swapped
        // for a bare "+" AccentIconButton — narrow past the page's other
        // one (the tag-edit pill).
        await tester.tap(find.widgetWithIcon(AccentIconButton, Icons.add));
        await tester.pump();
        await tester.pump();

        expect(find.text('Version limit reached'), findsOneWidget);
        expect(
          find.text(
            'You can keep up to 10 versions for each outfit. Delete a '
            'version to create a new one.',
          ),
          findsOneWidget,
        );
        // Dismiss, then confirm the picker never opened underneath.
        await tester.tap(find.text('OK'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Add Version'), findsNothing);
      }, () => client);
    },
  );
}
