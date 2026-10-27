import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/create_outfit_page.dart';
import 'package:uwearis/features/pages/outfit_details_page.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/carousel_dots_indicator.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';
import 'package:uwearis/features/widgets/common/images/refreshable_network_image.dart';
import 'package:uwearis/features/widgets/common/labeled_divider.dart';

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

class _FakeDailyOutfitNotifier extends DailyOutfitNotifier {
  _FakeDailyOutfitNotifier(this._outfits);
  final List<Outfit> _outfits;

  @override
  Future<List<Outfit>> build() async => _outfits;
}

class _FakeOutfitsNotifier extends OutfitsNotifier {
  _FakeOutfitsNotifier(this._outfits);
  final List<Outfit> _outfits;

  @override
  Future<List<Outfit>> build() async => _outfits;
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
      expect(
        tester
            .widgetList<CategoryTag>(find.byType(CategoryTag))
            .every((t) => t.variant == CategoryTagVariant.header),
        isTrue,
      );
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

  // One 404 (e.g. a deleted garment) must not reject the whole batch.
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

  // initState and _loadGroupOutfits both call _loadGarments; a second fetch
  // of the same set would flash the spinner.
  testWidgets(
    "_loadGroupOutfits resolving to the outfit's already-loaded version "
    "does not re-fetch its garments",
    (tester) async {
      // Garment and group (701) ids unique to this test: GarmentService and
      // OutfitService are caching singletons shared across tests.
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
        // Not pumpAndSettle — the image placeholder spinner never stops.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byWidgetPredicate(isBlackScaffold), findsOneWidget);

        await tester.tapAt(const Offset(50, 50));
        await tester.pump();
        // Route teardown lands a frame after the 200ms transition.
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byWidgetPredicate(isBlackScaffold), findsNothing);
      }, stubClient);
    },
  );

  testWidgets(
    'without "+ Add Version" or a counter, a gap still separates the photo '
    'from the garments divider',
    (tester) async {
      useTallSurface(tester);
      const groupId = 791;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/$groupId')) {
          return jsonResponse(
            envelope({
              'outfits': [
                {
                  'outfit_id': 1,
                  'group_id': groupId,
                  'result_image_url': 'https://img.example/1.png',
                  'garment_ids': [1],
                },
              ],
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        // An entry point that doesn't offer "+ Add Version", single version.
        await pumpApp(
          tester,
          OutfitDetailsPage(
            outfit: _outfit(groupId: groupId, garmentIds: [1]),
            showEditOutfitWhenSaved: false,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AccentPillButton), findsNothing);
        final photoBottom = tester.getBottomLeft(find.byType(PageView)).dy;
        final dividerTop = tester.getTopLeft(find.byType(LabeledDivider)).dy;
        expect(dividerTop - photoBottom, greaterThanOrEqualTo(16));
      }, () => client);
    },
  );

  testWidgets(
    'a new outfit offers Rename/Delete, Add Version and favorite once Saved',
    (tester) async {
      useTallSurface(tester);

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          OutfitDetailsPage(outfit: _outfit(), isNew: true),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Rename'), findsNothing);
        expect(find.text('Delete Outfit'), findsNothing);
        expect(find.text('Add Version'), findsNothing);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        await tester.tapAt(Offset.zero);
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text('Save'));
        // Past the "Outfit Saved" feedback overlay.
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Add Version'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Delete Outfit'), findsOneWidget);
      }, stubClient);
    },
  );

  testWidgets('the pill reads "Add Version" with only a single version', (
    tester,
  ) async {
    useTallSurface(tester);

    // Single version: the seed outfit's own group has no siblings.
    await http.runWithClient(() async {
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Add Version'), findsOneWidget);
    }, stubClient);
  });

  testWidgets(
    'the pill keeps reading "Add Version" once a sibling version '
    'exists, over the photo, with the Home-style dots + "n / total" counter below',
    (tester) async {
      useTallSurface(tester);
      // Unique group id: OutfitService caches per group.
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

        expect(
          find.widgetWithText(AccentPillButton, 'Add Version'),
          findsOneWidget,
        );
        expect(find.widgetWithIcon(CircleIconButton, Icons.add), findsNothing);
        expect(find.text('1 / 2'), findsOneWidget);
        final dots = tester.widget<CarouselDotsIndicator>(
          find.byType(CarouselDotsIndicator),
        );
        expect(dots.count, 2);
        expect(dots.currentIndex, 0);
        // The pill floats over the photo's bottom-left corner; the counter
        // stays on the row under the photo.
        final photo = tester.getRect(find.byType(PageView));
        final pill = tester.getRect(
          find.descendant(
            of: find.byType(AccentPillButton),
            matching: find.byType(TextButton),
          ),
        );
        expect(pill.left - photo.left, closeTo(12, 0.5));
        expect(photo.bottom - pill.bottom, closeTo(12, 0.5));
        expect(
          tester.getTopLeft(find.text('1 / 2')).dy,
          greaterThan(photo.bottom),
        );
      }, () => client);
    },
  );

  testWidgets('the dots still show without "+ Add Version"', (tester) async {
    useTallSurface(tester);
    const groupId = 790;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/$groupId')) {
        return jsonResponse(
          envelope({
            'outfits': [
              for (final id in [1, 2])
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
      // An entry point that doesn't offer "+ Add Version".
      await pumpApp(
        tester,
        OutfitDetailsPage(
          outfit: _outfit(groupId: groupId),
          showEditOutfitWhenSaved: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AccentPillButton), findsNothing);
      expect(find.byType(CarouselDotsIndicator), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    }, () => client);
  });

  // The version cap is enforced client-side only.
  testWidgets(
    '"+ Add Version" past the version cap explains the limit instead of '
    'opening the picker',
    (tester) async {
      // Unique group id: OutfitService caches per group.
      const groupId = 703;
      // Must match _maxVersions in outfit_details_page.dart.
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

        await tester.tap(find.widgetWithText(AccentPillButton, 'Add Version'));
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
        expect(find.byType(CreateOutfitPage), findsNothing);
      }, () => client);
    },
  );

  testWidgets(
    '"+ Add Version" opens Add Outfit in version mode, and the version it '
    'pops back is swiped into view',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, OutfitDetailsPage(outfit: _outfit(groupId: 704)));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.widgetWithText(AccentPillButton, 'Add Version'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final addOutfit = tester.widget<CreateOutfitPage>(
          find.byType(CreateOutfitPage),
        );
        expect(addOutfit.targetGroupId, 704);

        Navigator.of(tester.element(find.byType(CreateOutfitPage))).pop(
          Outfit(id: 2, groupId: 704, imageUrl: 'https://img.example/2.png'),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CreateOutfitPage), findsNothing);
        expect(find.text('2 / 2'), findsOneWidget);
        // Let the post-swipe outfitsProvider.refresh() settle before the
        // scope is torn down.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }, stubClient);
    },
  );

  group('edit tags sheet auto-saves on close', () {
    late List<Map<String, dynamic>> patches;
    late bool fail;

    setUp(() {
      patches = [];
      fail = false;
    });

    http.Client tagsClient() => MockClient((request) async {
      if (request.method == 'PATCH') {
        patches.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (fail) return jsonResponse({'success': false}, status: 500);
        return jsonResponse(envelope({'id': 1, 'group_id': 3}));
      }
      return jsonResponse(envelope({'items': []}));
    });

    // The page keeps an image-loading animation running, so pumpAndSettle
    // never settles — pump past the sheet/dialog transitions instead.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> openSheet(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(style: ['street'])),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.sell_outlined));
      await settle(tester);
    }

    Future<void> dismissSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
    }

    testWidgets('has no Save button; a changed selection is PATCHed once the '
        'sheet closes and shows right away', (tester) async {
      await http.runWithClient(() async {
        await openSheet(tester);
        expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);

        await tester.tap(find.text('Summer'));
        await tester.tap(find.text('Classic'));
        await settle(tester);
        expect(patches, isEmpty);

        await dismissSheet(tester);
        expect(patches, hasLength(1));
        expect(patches.single['season'], ['summer']);
        expect((patches.single['style'] as List).toSet(), {
          'street',
          'classic',
        });
        expect(find.text('Classic'), findsOneWidget);
      }, tagsClient);
    });

    // Today's Outfit reads dailyOutfitProvider, so an edit here must reach
    // it (and My Outfits) or that page keeps showing the old tags.
    testWidgets('a saved edit syncs the daily outfit and My Outfits', (
      tester,
    ) async {
      final seed = _outfit(style: ['street']);
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(outfit: seed),
          overrides: [
            dailyOutfitProvider.overrideWith(
              () => _FakeDailyOutfitNotifier([seed]),
            ),
            outfitsProvider.overrideWith(() => _FakeOutfitsNotifier([seed])),
          ],
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OutfitDetailsPage)),
        );
        container.listen(dailyOutfitProvider, (_, _) {});
        container.listen(outfitsProvider, (_, _) {});
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byIcon(Icons.sell_outlined));
        await settle(tester);

        await tester.tap(find.text('Summer'));
        await settle(tester);
        await dismissSheet(tester);

        final daily = container.read(dailyOutfitProvider).value!.single;
        final mine = container.read(outfitsProvider).value!.single;
        expect(daily.seasons, ['summer']);
        expect(daily.style, ['street']);
        expect(mine.seasons, ['summer']);
      }, tagsClient);
    });

    testWidgets('closing without a change sends nothing', (tester) async {
      await http.runWithClient(() async {
        await openSheet(tester);
        await tester.tap(find.text('Summer'));
        await tester.tap(find.text('Summer')); // toggled back off
        await settle(tester);
        await dismissSheet(tester);

        expect(patches, isEmpty);
      }, tagsClient);
    });

    testWidgets('a failed save rolls the tags back and offers Retry', (
      tester,
    ) async {
      fail = true;
      await http.runWithClient(() async {
        await openSheet(tester);
        await tester.tap(find.text('Classic'));
        await settle(tester);
        await dismissSheet(tester);

        expect(find.text('Retry'), findsOneWidget);
        // Rolled back behind the dialog — only the original tag remains.
        expect(find.byType(CategoryTag), findsOneWidget);

        fail = false;
        await tester.tap(find.text('Retry'));
        await settle(tester);

        expect(patches, hasLength(2));
        expect(find.text('Retry'), findsNothing);
        expect(find.byType(CategoryTag), findsNWidgets(2));
        // The tag button is usable again after the retry settles.
        final button = tester.widget<CircleIconButton>(
          find.ancestor(
            of: find.byIcon(Icons.sell_outlined),
            matching: find.byType(CircleIconButton),
          ),
        );
        expect(button.onPressed, isNotNull);
      }, tagsClient);
    });
  });

  // Regression: the heart only updated this page's own copy, so un-favoriting
  // an outfit here (opened from Outfits) left Home's / Today's Outfit's
  // daily copy still favorited.
  testWidgets('toggling favorite syncs the daily outfit and My Outfits', (
    tester,
  ) async {
    final favorited = Outfit(
      id: 1,
      groupId: 3,
      imageUrl: 'https://img.example/1.png',
      isFavorite: true,
    );
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        return jsonResponse(envelope({'outfit_id': 1, 'group_id': 3}));
      }
      return jsonResponse(envelope({'items': []}));
    });

    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: favorited),
        overrides: [
          dailyOutfitProvider.overrideWith(
            () => _FakeDailyOutfitNotifier([favorited]),
          ),
          outfitsProvider.overrideWith(() => _FakeOutfitsNotifier([favorited])),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OutfitDetailsPage)),
      );
      // Home keeps both alive in the real app.
      container.listen(dailyOutfitProvider, (_, _) {});
      container.listen(outfitsProvider, (_, _) {});
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(
        container.read(dailyOutfitProvider).value!.single.isFavorite,
        isFalse,
      );
      expect(container.read(outfitsProvider).value!.single.isFavorite, isFalse);
    }, () => client);
  });

  testWidgets('after deleting a version, the next one can be deleted right '
      'away, even while My Outfits is still re-fetching', (tester) async {
    useTallSurface(tester);
    // Unique group id: OutfitService caches per group.
    const groupId = 731;
    final listFetch = Completer<http.Response>();
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path.endsWith('/$groupId')) {
        return jsonResponse(
          envelope({
            'outfits': [
              for (final id in [1, 2, 3])
                {
                  'id': id,
                  'group_id': groupId,
                  'image_url': 'https://img.example/$id.png',
                },
            ],
          }),
        );
      }
      if (request.method == 'DELETE') return jsonResponse(envelope(null));
      // My Outfits' list re-fetch: never answers within this test.
      return listFetch.future;
    });

    await http.runWithClient(() async {
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(groupId: groupId)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);

      Opacity deleteItem() => tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Delete Version'),
              matching: find.byType(Opacity),
            )
            .first,
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Delete Version'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.pump();
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump(const Duration(milliseconds: 500));
      expect(deleteItem().opacity, 1);
    }, () => client);
    listFetch.complete(jsonResponse(envelope({'items': []})));
  });

  testWidgets('a second favorite tap while the first is in flight sends '
      'nothing; a failure rolls back to where it started', (tester) async {
    final patch = Completer<http.Response>();
    var patches = 0;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        patches++;
        return patch.future;
      }
      return jsonResponse(envelope({'items': []}));
    });

    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit(groupId: 741)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();
      expect(patches, 1);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      patch.complete(jsonResponse(envelope(null), status: 500));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(patches, 1);
    }, () => client);
  });
}
