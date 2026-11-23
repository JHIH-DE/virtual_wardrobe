import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/utils/user_acknowledgement.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/outfit_group.dart';
import 'package:uwearis/features/widgets/common/fields/number_stepper.dart';
import 'package:uwearis/features/pages/wardrobe/create_outfit_page.dart';
import 'package:uwearis/features/pages/wardrobe/outfit_details_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';
import 'package:uwearis/features/widgets/common/carousel_dots_indicator.dart';
import 'package:uwearis/features/widgets/common/images/refreshable_network_image.dart';
import 'package:uwearis/features/widgets/common/labeled_divider.dart';

import '../../helpers/points_fixture.dart';
import '../../helpers/fake_auth.dart';
import '../../helpers/mock_http.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

/// Secure storage whose reads wait on [hold] while it is set — a slow
/// keychain, as on a device.
class _SlowReadStorage extends TestFlutterSecureStoragePlatform {
  _SlowReadStorage(super.data);

  Completer<void>? hold;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final gate = hold;
    if (gate != null) await gate.future;
    return super.read(key: key, options: options);
  }
}

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

  testWidgets('a group passed in shows every version at once, on the tapped '
      'one, even if the group fetch fails', (tester) async {
    Outfit version(int id) =>
        Outfit(id: id, groupId: 3, imageUrl: 'https://img.example/$id.png');
    // The group fetch fails, so whatever shows came from the group passed in.
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(
          outfit: version(2),
          group: OutfitGroup(
            groupId: 3,
            name: 'Weekend',
            versions: [version(1), version(2), version(3)],
          ),
        ),
      );
      await tester.pump();
      final dots = tester.widget<CarouselDotsIndicator>(
        find.byType(CarouselDotsIndicator),
      );
      expect(dots.count, 3);
      expect(dots.currentIndex, 1);
      expect(find.text('Weekend'), findsWidgets);
    }, () => MockClient((_) async => http.Response('', 500)));
  });

  group('opened from a filtered list', () {
    Outfit version(int id) =>
        Outfit(id: id, groupId: 3, imageUrl: 'https://img.example/$id.png');
    final threeVersions = OutfitGroup(
      groupId: 3,
      versions: [version(1), version(2), version(3)],
    );
    http.Client failingClient() =>
        MockClient((_) async => http.Response('', 500));

    CarouselDotsIndicator? dots(WidgetTester tester) {
      final f = find.byType(CarouselDotsIndicator);
      return f.evaluate().isEmpty ? null : tester.widget(f);
    }

    testWidgets('shows only the matching versions until Clear Filter', (
      tester,
    ) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(
            outfit: version(3),
            group: threeVersions,
            versionFilter: (o) => o.id != 1,
          ),
        );
        await tester.pump();
        expect(dots(tester)!.count, 2);
        expect(dots(tester)!.currentIndex, 1);
        expect(find.textContaining('versions'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Clear Filter'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(dots(tester)!.count, 3);
        expect(dots(tester)!.currentIndex, 2, reason: 'stays on version 3');

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Clear Filter'), findsNothing);
      }, failingClient);
    });

    testWidgets('the tapped version always shows, even if it no longer '
        'matches', (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(
            outfit: version(2),
            group: threeVersions,
            versionFilter: (_) => false,
          ),
        );
        await tester.pump();
        expect(dots(tester), isNull);
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Clear Filter'), findsOneWidget);
      }, failingClient);
    });

    testWidgets('no Clear Filter when every version matches', (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(
            outfit: version(1),
            group: threeVersions,
            versionFilter: (_) => true,
          ),
        );
        await tester.pump();
        expect(dots(tester)!.count, 3);
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Clear Filter'), findsNothing);
      }, failingClient);
    });
  });

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

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Weekend Look'),
        ),
        findsOneWidget,
      );
    }, stubClient);
  });

  group('title comes from the group representative', () {
    // Opened on version 5; the group's versions come back out of id order
    // and without a group name, so the title is the representative's name.
    Future<void> pumpGroup(
      WidgetTester tester, {
      required int groupId,
      required int? coverOutfitId,
    }) async {
      Map<String, dynamic> version(int id) => {
        'outfit_id': id,
        'group_id': groupId,
        'name': 'Version $id',
        'result_image_url': 'https://img.example/$id.png',
      };
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/outfit/$groupId')) {
          return jsonResponse(
            envelope({
              'group_id': groupId,
              'name': null,
              'cover_outfit_id': coverOutfitId,
              'outfits': [version(5), version(2), version(9)],
            }),
          );
        }
        return jsonResponse(envelope({'items': []}));
      });
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(
            outfit: Outfit(
              id: 5,
              groupId: groupId,
              name: 'Version 5',
              imageUrl: 'https://img.example/5.png',
              style: const [],
              garmentIds: const [],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
      }, () => client);
    }

    Finder titled(String text) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(text));

    testWidgets('the cover version when it is in the group', (tester) async {
      await pumpGroup(tester, groupId: 801, coverOutfitId: 9);
      expect(titled('Version 9'), findsOneWidget);
    });

    testWidgets('the lowest id when the cover names no version', (
      tester,
    ) async {
      await pumpGroup(tester, groupId: 802, coverOutfitId: 77);
      expect(titled('Version 2'), findsOneWidget);
    });

    testWidgets('the lowest id when there is no cover', (tester) async {
      await pumpGroup(tester, groupId: 803, coverOutfitId: null);
      expect(titled('Version 2'), findsOneWidget);
    });
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

  testWidgets('when every garment fails to load, the section offers Retry', (
    tester,
  ) async {
    // Garment id 781 unique to this test: GarmentService caches garments.
    var garmentFails = true;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/garments/781')) {
        if (garmentFails) return jsonResponse(envelope({}), status: 404);
        return jsonResponse(
          envelope({
            'id': 781,
            'name': 'Wool Coat',
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
        OutfitDetailsPage(outfit: _outfit(garmentIds: [781])),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Failed to Load'), findsOneWidget);

      garmentFails = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Wool Coat'), findsOneWidget);
      expect(find.text('Failed to Load'), findsNothing);
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
    "a load for the same garments that's still in flight is not fetched "
    'again, and its result is shown',
    (tester) async {
      // Group (760) and garment (761) ids unique to this test: GarmentService
      // and OutfitService are caching singletons shared across tests.
      const groupId = 760;
      final garmentReply = Completer<http.Response>();
      var garmentRequests = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/$groupId')) {
          return jsonResponse(
            envelope({
              'outfits': [
                {
                  'id': 1,
                  'group_id': groupId,
                  'image_url': 'https://img.example/1.png',
                  'garment_ids': [761],
                },
              ],
            }),
          );
        }
        if (path.endsWith('/garments/761')) {
          garmentRequests++;
          return garmentReply.future;
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(
            outfit: _outfit(garmentIds: [761], groupId: groupId),
          ),
        );
        // _loadGroupOutfits lands while initState's load is still waiting.
        await tester.pump();
        await tester.pump();

        garmentReply.complete(
          jsonResponse(
            envelope({
              'id': 761,
              'name': 'Linen Shirt',
              'category': 'Top',
              'sub_category': '',
              'upload_url': '',
              'object_name': '',
              'image_url': '',
            }),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Linen Shirt'), findsOneWidget);
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
    '"+ Add Version" is greyed out at the version cap and opens nothing',
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

        final pill = find.widgetWithText(AccentPillButton, 'Add Version');
        expect(tester.widget<AccentPillButton>(pill).enabled, isFalse);

        await tester.tap(pill, warnIfMissed: false);
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

  testWidgets(
    'after "+ Add Version", a slower garment load for a version the swipe '
    'passed does not replace the new version\'s garments',
    (tester) async {
      useTallSurface(tester);
      // Group (750) and garment (751–754) ids unique to this test:
      // OutfitService and GarmentService are caching singletons.
      const groupId = 750;
      final passedVersionGarment = Completer<http.Response>();
      http.Response garment(int id) => jsonResponse(
        envelope({
          'id': id,
          'name': 'Garment $id',
          'category': 'Top',
          'sub_category': '',
          'upload_url': '',
          'object_name': '',
          'image_url': '',
        }),
      );
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/$groupId')) {
          return jsonResponse(
            envelope({
              'outfits': [
                for (final id in [1, 2, 3])
                  {
                    'id': id,
                    'group_id': groupId,
                    'image_url': 'https://img.example/$id.png',
                    'garment_ids': [750 + id],
                  },
              ],
            }),
          );
        }
        if (path.endsWith('/garments/752')) return passedVersionGarment.future;
        for (final id in [751, 753, 754]) {
          if (path.endsWith('/garments/$id')) return garment(id);
        }
        return jsonResponse(envelope({'items': []}));
      });

      await http.runWithClient(() async {
        await pumpApp(
          tester,
          OutfitDetailsPage(
            outfit: _outfit(groupId: groupId, garmentIds: [751]),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('1 / 3'), findsOneWidget);
        expect(find.text('Garment 751'), findsOneWidget);

        await tester.tap(find.widgetWithText(AccentPillButton, 'Add Version'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        Navigator.of(tester.element(find.byType(CreateOutfitPage))).pop(
          Outfit(
            id: 4,
            groupId: groupId,
            imageUrl: 'https://img.example/4.png',
            garmentIds: const [754],
          ),
        );
        // Frame by frame, as on a device, so the swipe passes every page.
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.text('4 / 4'), findsOneWidget);
        expect(find.text('Garment 754'), findsOneWidget);

        // Version 2's load, started as the animation passed it, lands last.
        passedVersionGarment.complete(garment(752));
        await tester.pump();
        await tester.pump();

        expect(find.text('Garment 754'), findsOneWidget);
        expect(find.text('Garment 752'), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }, () => client);
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
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        patches.add(body);
        if (fail) return jsonResponse({'success': false}, status: 500);
        final min = body['suitable_temp_min_c'];
        final max = body['suitable_temp_max_c'];
        final reset =
            body.containsKey('suitable_temp_min_c') &&
            min == null &&
            max == null;
        return jsonResponse(
          envelope({
            'id': 1,
            'group_id': 3,
            // Going back to automatic: the backend recalculates.
            'suitable_temp_min_c': reset ? 15 : min,
            'suitable_temp_max_c': reset ? 21 : max,
            'suitable_temp_source': reset || min == null && max == null
                ? 'auto'
                : 'manual',
          }),
        );
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

    Future<void> openSheet(WidgetTester tester, {Outfit? outfit}) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: outfit ?? _outfit(style: ['street'])),
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

    Finder stepperFor(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(NumberStepper),
    );

    Finder stepButton(String label, IconData icon) =>
        find.descendant(of: stepperFor(label), matching: find.byIcon(icon));

    Outfit withTemperature(
      int? min,
      int? max,
      OutfitTemperatureSource source,
    ) => _outfit(
      style: ['street'],
    ).copyWith(suitableTemperature: (minC: min, maxC: max, source: source));

    testWidgets('adjusting an automatic range PATCHes it as a manual one and '
        'the header shows it', (tester) async {
      await http.runWithClient(() async {
        await openSheet(
          tester,
          outfit: withTemperature(15, 21, OutfitTemperatureSource.auto),
        );
        expect(find.text('Reset'), findsNothing);

        await tester.tap(stepButton('Highest', Icons.add_circle_outline));
        await tester.tap(stepButton('Highest', Icons.add_circle_outline));
        await settle(tester);
        expect(find.text('Reset'), findsOneWidget);

        await dismissSheet(tester);
        expect(patches.single['suitable_temp_min_c'], 15);
        expect(patches.single['suitable_temp_max_c'], 23);
        expect(find.text('15°C - 23°C'), findsOneWidget);
      }, tagsClient);
    });

    testWidgets('a step past either end reads "No limit" and is sent as '
        'null', (tester) async {
      await http.runWithClient(() async {
        await openSheet(
          tester,
          outfit: withTemperature(25, 50, OutfitTemperatureSource.manual),
        );
        await tester.tap(stepButton('Highest', Icons.add_circle_outline));
        await settle(tester);
        expect(find.text('No limit'), findsOneWidget);
        // The other end can't open too: that would be "automatic".
        final lowerMin = tester.widget<NumberStepper>(stepperFor('Lowest'));
        expect(lowerMin.onDecrement, isNotNull);

        await dismissSheet(tester);
        expect(patches.single['suitable_temp_min_c'], 25);
        expect(patches.single.containsKey('suitable_temp_max_c'), isTrue);
        expect(patches.single['suitable_temp_max_c'], isNull);
        expect(find.text('25°C and above'), findsOneWidget);
      }, tagsClient);
    });

    testWidgets('the lowest can never reach the highest', (tester) async {
      await http.runWithClient(() async {
        await openSheet(
          tester,
          outfit: withTemperature(20, 21, OutfitTemperatureSource.manual),
        );
        final lowest = tester.widget<NumberStepper>(stepperFor('Lowest'));
        final highest = tester.widget<NumberStepper>(stepperFor('Highest'));
        expect(lowest.onIncrement, isNull);
        expect(highest.onDecrement, isNull);
      }, tagsClient);
    });

    testWidgets('Reset on a manual range sends two nulls and shows '
        'the recalculated range', (tester) async {
      await http.runWithClient(() async {
        await openSheet(
          tester,
          outfit: withTemperature(18, 27, OutfitTemperatureSource.manual),
        );
        expect(find.text('Reset'), findsOneWidget);

        await tester.tap(find.text('Reset'));
        await settle(tester);
        expect(find.byType(NumberStepper), findsNothing);
        expect(find.text('Reset'), findsNothing);

        await dismissSheet(tester);
        expect(patches.single.containsKey('suitable_temp_min_c'), isTrue);
        expect(patches.single['suitable_temp_min_c'], isNull);
        expect(patches.single['suitable_temp_max_c'], isNull);
        expect(find.text('15°C - 21°C'), findsOneWidget);
      }, tagsClient);
    });

    testWidgets('Set My Own after a reset keeps the manual range unsent', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await openSheet(
          tester,
          outfit: withTemperature(18, 27, OutfitTemperatureSource.manual),
        );
        await tester.tap(find.text('Reset'));
        await settle(tester);
        await tester.tap(find.text('Set My Own'));
        await settle(tester);
        await dismissSheet(tester);

        expect(patches, isEmpty);
      }, tagsClient);
    });

    testWidgets('has no Save button; a changed selection is PATCHed once the '
        'sheet closes and shows right away', (tester) async {
      await http.runWithClient(() async {
        await openSheet(tester);
        expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
        expect(find.text('Season'), findsNothing);
        expect(find.text('Summer'), findsNothing);

        await tester.tap(find.text('Classic'));
        await settle(tester);
        expect(patches, isEmpty);

        await dismissSheet(tester);
        expect(patches, hasLength(1));
        expect(patches.single.containsKey('season'), isFalse);
        expect(
          patches.single.containsKey('suitable_temp_min_c'),
          isFalse,
          reason: 'temperature untouched',
        );
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
      final seed = _outfit(style: ['street']).copyWith(
        suitableTemperature: (
          minC: 15,
          maxC: 21,
          source: OutfitTemperatureSource.auto,
        ),
      );
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          OutfitDetailsPage(outfit: seed),
          overrides: [
            dailyOutfitProvider.overrideWith(
              () => SeededDailyOutfitNotifier([seed]),
            ),
            outfitsProvider.overrideWith(() => SeededOutfitsNotifier([seed])),
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

        await tester.tap(stepButton('Lowest', Icons.add_circle_outline));
        await settle(tester);
        await dismissSheet(tester);

        final daily = container.read(dailyOutfitProvider).value!.single;
        final mine = outfitGroupCovers(
          container.read(outfitsProvider).value!,
        ).single;
        expect(daily.suitableTemperature, (
          minC: 16,
          maxC: 21,
          source: OutfitTemperatureSource.manual,
        ));
        expect(daily.style, ['street']);
        expect(mine.suitableTempMinC, 16);
      }, tagsClient);
    });

    testWidgets('closing without a change sends nothing', (tester) async {
      await http.runWithClient(() async {
        await openSheet(tester);
        await tester.tap(find.text('Classic'));
        await tester.tap(find.text('Classic')); // toggled back off
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
            () => SeededDailyOutfitNotifier([favorited]),
          ),
          outfitsProvider.overrideWith(
            () => SeededOutfitsNotifier([favorited]),
          ),
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
      expect(
        outfitGroupCovers(
          container.read(outfitsProvider).value!,
        ).single.isFavorite,
        isFalse,
      );
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

  group('regenerate', () {
    Future<int> regenerate(WidgetTester tester, {required bool succeed}) async {
      useTallSurface(tester);
      var quotaReads = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (isPointsSummaryPath(path)) {
          quotaReads++;
          return jsonResponse(envelope(pointsSummaryJson(balance: 3)));
        }
        if (path.endsWith('/regenerate')) {
          return succeed
              ? jsonResponse(
                  envelope({
                    'outfit_id': 1,
                    'group_id': 3,
                    'result_image_url': 'https://img.example/1b.png',
                    'garment_ids': <int>[],
                  }),
                )
              : jsonResponse({
                  'success': false,
                  'error_code': 'LOOK_GENERATION_FAILED',
                }, status: 500);
        }
        return jsonResponse(envelope({'items': []}));
      });
      await http.runWithClient(() async {
        await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byIcon(Icons.refresh).first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Regenerate').last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }, () => client);
      return quotaReads;
    }

    /// Records each regenerate's Idempotency-Key; [onRegenerate] answers it,
    /// [onStatus] answers `GET /outfit/generations/{key}`.
    MockClient recordingClient(
      List<String?> keys, {
      required Future<http.Response> Function() onRegenerate,
      Future<http.Response> Function()? onStatus,
    }) {
      return MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/regenerate')) {
          keys.add(request.headers['Idempotency-Key']);
          return onRegenerate();
        }
        if (path.contains('/outfit/generations/') && onStatus != null) {
          return onStatus();
        }
        if (isPointsSummaryPath(path)) {
          return jsonResponse(envelope(pointsSummaryJson(balance: 3)));
        }
        return jsonResponse(envelope({'items': []}));
      });
    }

    Map<String, dynamic> regenerated() => {
      'outfit_id': 1,
      'group_id': 3,
      'result_image_url': 'https://img.example/1b.png',
      'garment_ids': <int>[],
    };

    Future<void> openAndRegenerate(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.refresh).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Regenerate').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> pumpFor(WidgetTester tester, int seconds) async {
      for (var i = 0; i < seconds; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('mid-render: Stop Waiting is offered and a back asks first', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      final keys = <String?>[];
      await http.runWithClient(() async {
        await openAndRegenerate(tester);
        expect(find.text('Stop Waiting'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Stop Waiting?'), findsOneWidget);
        await tester.tap(find.text('Keep Waiting'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(OutfitDetailsPage), findsOneWidget);

        pending.complete(jsonResponse(envelope(regenerated())));
        await pumpFor(tester, 1);
      }, () => recordingClient(keys, onRegenerate: () => pending.future));
    });

    testWidgets('a lost reply is recovered by status, not by regenerating '
        'again', (tester) async {
      final keys = <String?>[];
      await http.runWithClient(
        () async {
          await openAndRegenerate(tester);
          // The balance shows for 4s once the status read finds the result.
          await pumpFor(tester, 2);
          expect(keys, hasLength(1));
          expect(find.text('3 points left'), findsOneWidget);
          await pumpFor(tester, 5);
        },
        () => recordingClient(
          keys,
          onRegenerate: () async => throw TimeoutException('slow'),
          onStatus: () async => jsonResponse(
            envelope({
              'status': 'succeeded',
              'outfit': {...regenerated(), 'group_type': 'general'},
            }),
          ),
        ),
      );
    });

    testWidgets('when status can\'t be checked: says so, then asks before '
        'regenerating again — as a new request', (tester) async {
      final keys = <String?>[];
      var timeOut = true;
      await http.runWithClient(
        () async {
          await openAndRegenerate(tester);
          await pumpFor(tester, 2);
          expect(
            find.text(
              "We couldn't confirm whether this try-on finished. If it did, "
              'it will appear in Outfits.',
            ),
            findsOneWidget,
          );
          await tester.tap(find.byKey(AppDialog.dismissButtonKey));
          await tester.pump(const Duration(milliseconds: 300));

          await tester.tap(find.byIcon(Icons.refresh).first);
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Try Again?'), findsOneWidget);
          await tester.tap(find.byKey(AppDialog.dismissButtonKey));
          await tester.pump(const Duration(milliseconds: 300));
          expect(keys, hasLength(1));

          timeOut = false;
          await tester.tap(find.byIcon(Icons.refresh).first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Retry'));
          await pumpFor(tester, 2);
          expect(keys, hasLength(2));
          expect(keys[1], isNot(keys[0]));
        },
        () => recordingClient(
          keys,
          onRegenerate: () async => timeOut
              ? throw TimeoutException('slow')
              : jsonResponse(envelope(regenerated())),
          onStatus: () async =>
              jsonResponse({'success': false, 'message': 'x'}, status: 422),
        ),
      );
    });

    // F3: one confirm flow at a time — a double tap used to stack two.
    group('one confirm at a time', () {
      final confirms = find.byType(AppDialog);
      final confirmTitle = find.text('Regenerate this image?');

      Future<void> openPage(WidgetTester tester) async {
        useTallSurface(tester);
        await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
        await tester.pump();
        await tester.pump();
      }

      /// Two taps inside one frame, before the first confirm is laid out.
      Future<void> doubleTap(WidgetTester tester) async {
        await tester.tap(find.byIcon(Icons.refresh).first);
        await tester.tap(find.byIcon(Icons.refresh).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> cancel(WidgetTester tester) async {
        await tester.tap(find.byKey(AppDialog.dismissButtonKey).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      testWidgets('a double tap opens one confirm; Cancel lets it open again', (
        tester,
      ) async {
        final keys = <String?>[];
        await http.runWithClient(
          () async {
            await openPage(tester);
            await doubleTap(tester);
            expect(confirms, findsOneWidget);

            await cancel(tester);
            expect(confirms, findsNothing);
            await tester.tap(find.byIcon(Icons.refresh).first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(confirmTitle, findsOneWidget);
            await cancel(tester);
            expect(confirms, findsNothing);
            expect(keys, isEmpty);
          },
          () => recordingClient(
            keys,
            onRegenerate: () async => jsonResponse(envelope(regenerated())),
          ),
        );
      });

      testWidgets('a double tap, then Regenerate: one request, and no '
          'confirm left behind', (tester) async {
        final keys = <String?>[];
        final pending = Completer<http.Response>();
        await http.runWithClient(() async {
          await openPage(tester);
          await doubleTap(tester);
          await tester.tap(find.text('Regenerate').last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(keys, hasLength(1));

          pending.complete(jsonResponse(envelope(regenerated())));
          await pumpFor(tester, 1);
          expect(confirms, findsNothing);
          expect(keys, hasLength(1));
          await pumpFor(tester, 5);
        }, () => recordingClient(keys, onRegenerate: () => pending.future));
      });

      testWidgets('a tap while the confirmed flow is still checking AI '
          'consent opens no second confirm and sends one request', (
        tester,
      ) async {
        // The real consent check: it reads the signed-in user id from the
        // keychain, which this storage holds on demand.
        final storage = _SlowReadStorage({
          'access_token': 'fake-access-token',
          'refresh_token': 'fake-refresh-token',
        });
        FlutterSecureStoragePlatform.instance = storage;
        AuthStorage.debugTrustStoredTokens();
        SharedPreferences.setMockInitialValues({
          'ai_consent_v1_unknown': '2026-11-20T00:00:00Z',
        });
        UserAcknowledgement.debugGrantedOverride = null;
        addTearDown(() => UserAcknowledgement.debugGrantedOverride = true);

        final keys = <String?>[];
        final pending = Completer<http.Response>();
        await http.runWithClient(() async {
          await openPage(tester);
          await tester.tap(find.byIcon(Icons.refresh).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(confirmTitle, findsOneWidget);

          final keychain = storage.hold = Completer<void>();
          await tester.tap(find.text('Regenerate').last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(
            find.byIcon(Icons.refresh).first,
            warnIfMissed: false,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final confirmsWhileChecking = confirms.evaluate().length;

          storage.hold = null;
          keychain.complete();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final requests = keys.length;
          pending.complete(jsonResponse(envelope(regenerated())));
          await pumpFor(tester, 1);
          final confirmsAfter = confirms.evaluate().length;
          while (find.byKey(AppDialog.dismissButtonKey).evaluate().isNotEmpty) {
            await cancel(tester);
          }
          await pumpFor(tester, 5);

          expect(
            {
              'confirms while checking': confirmsWhileChecking,
              'requests': requests,
              'confirms after': confirmsAfter,
              'requests at end': keys.length,
            },
            {
              'confirms while checking': 0,
              'requests': 1,
              'confirms after': 0,
              'requests at end': 1,
            },
          );
        }, () => recordingClient(keys, onRegenerate: () => pending.future));
      });

      testWidgets('after a failed regenerate, Regenerate opens again', (
        tester,
      ) async {
        final keys = <String?>[];
        await http.runWithClient(
          () async {
            await openPage(tester);
            await tester.tap(find.byIcon(Icons.refresh).first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.text('Regenerate').last);
            await pumpFor(tester, 1);
            expect(find.text('Failed to generate outfit'), findsOneWidget);
            await cancel(tester);
            expect(confirms, findsNothing);

            await tester.tap(find.byIcon(Icons.refresh).first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(confirmTitle, findsOneWidget);
            await cancel(tester);
            expect(keys, hasLength(1));
          },
          () => recordingClient(
            keys,
            onRegenerate: () async => jsonResponse({
              'success': false,
              'error_code': 'LOOK_GENERATION_FAILED',
            }, status: 500),
          ),
        );
      });

      testWidgets('a confirm removed by other navigation (the page stays) '
          'does not block the next tap', (tester) async {
        final keys = <String?>[];
        await http.runWithClient(
          () async {
            await openPage(tester);
            await tester.tap(find.byIcon(Icons.refresh).first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            final dialogRoute = ModalRoute.of(tester.element(confirmTitle))!;
            Navigator.of(
              tester.element(find.byType(OutfitDetailsPage)),
            ).removeRoute(dialogRoute);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(confirms, findsNothing);

            await tester.tap(find.byIcon(Icons.refresh).first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(confirmTitle, findsOneWidget);
            await cancel(tester);
            expect(keys, isEmpty);
          },
          () => recordingClient(
            keys,
            onRegenerate: () async => jsonResponse(envelope(regenerated())),
          ),
        );
      });

      testWidgets('signed out with the confirm open: no confirm, request or '
          'error left behind', (tester) async {
        final keys = <String?>[];
        await http.runWithClient(
          () async {
            await openPage(tester);
            await tester.tap(find.byIcon(Icons.refresh).first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(confirmTitle, findsOneWidget);

            final navigator = Navigator.of(
              tester.element(find.byType(OutfitDetailsPage)),
            );
            await clearSignedInSession();
            unawaited(
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('Signed out')),
                ),
                (_) => false,
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('Signed out'), findsOneWidget);
            expect(find.byType(OutfitDetailsPage), findsNothing);
            expect(confirms, findsNothing);
            expect(keys, isEmpty);
          },
          () => recordingClient(
            keys,
            onRegenerate: () async => jsonResponse(envelope(regenerated())),
          ),
        );
      });
    });

    testWidgets('a successful regenerate re-reads the balance and shows it', (
      tester,
    ) async {
      expect(await regenerate(tester, succeed: true), greaterThan(0));
      expect(find.text('3 points left'), findsOneWidget);
    });

    testWidgets('a failed regenerate shows no balance', (tester) async {
      await regenerate(tester, succeed: false);
      expect(find.textContaining('points left'), findsNothing);
    });
  });

  // P2-1 batch 2: the confirm dialogs now come from showConfirmDialog. Each
  // keeps its texts and destructive style; cancelling sends nothing.
  group('confirm dialogs', () {
    /// A group of [versions] (ids 1..n); records DELETEs and regenerates.
    MockClient groupClient(
      int groupId,
      int versions,
      List<http.Request> deletes,
      List<http.Request> regenerates,
    ) {
      return MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'DELETE') {
          deletes.add(request);
          return jsonResponse(envelope(null));
        }
        if (path.endsWith('/regenerate')) {
          regenerates.add(request);
          return jsonResponse(envelope(null));
        }
        if (request.method == 'GET' && path.endsWith('/$groupId')) {
          return jsonResponse(
            envelope({
              'outfits': [
                for (var id = 1; id <= versions; id++)
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
    }

    Future<void> openPage(WidgetTester tester, int groupId) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(groupId: groupId)),
      );
      await tester.pump();
      await tester.pump();
    }

    AppDialog dialog(WidgetTester tester) =>
        tester.widget<AppDialog>(find.byType(AppDialog));

    Future<void> cancel(WidgetTester tester) async {
      await tester.tap(find.byKey(AppDialog.dismissButtonKey));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('Delete Outfit: destructive; Cancel deletes nothing, Delete '
        'deletes the group', (tester) async {
      const groupId = 741;
      final deletes = <http.Request>[];
      await http.runWithClient(() async {
        await openPage(tester, groupId);
        Future<void> openDelete() async {
          await tester.tap(find.byIcon(Icons.more_vert));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.text('Delete Outfit'));
          await tester.pump(const Duration(milliseconds: 500));
        }

        await openDelete();
        expect(dialog(tester).title, 'Delete Outfit');
        expect(
          dialog(tester).body,
          "This will also delete every other outfit generated together with "
          "it. This can't be undone.",
        );
        expect(dialog(tester).primaryLabel, 'Delete');
        expect(dialog(tester).destructive, isTrue);
        await cancel(tester);
        expect(deletes, isEmpty);
        expect(find.byType(OutfitDetailsPage), findsOneWidget);

        await openDelete();
        await tester.tap(find.text('Delete').last);
        await tester.pump();
        await tester.pump();
        expect(deletes.single.url.path, endsWith('/outfit/$groupId'));
      }, () => groupClient(groupId, 1, deletes, []));
    });

    testWidgets('Delete Version: destructive; Cancel keeps every version', (
      tester,
    ) async {
      const groupId = 742;
      final deletes = <http.Request>[];
      await http.runWithClient(() async {
        await openPage(tester, groupId);
        expect(find.text('1 / 3'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Delete Version'));
        await tester.pump(const Duration(milliseconds: 500));

        expect(dialog(tester).title, 'Delete Outfit');
        expect(
          dialog(tester).body,
          'Are you sure you want to delete this version?',
        );
        expect(dialog(tester).primaryLabel, 'Delete');
        expect(dialog(tester).destructive, isTrue);
        await cancel(tester);
        expect(deletes, isEmpty);
        expect(find.text('1 / 3'), findsOneWidget);
      }, () => groupClient(groupId, 3, deletes, []));
    });

    testWidgets('Regenerate: a plain (not destructive) confirm; Cancel '
        'regenerates nothing', (tester) async {
      const groupId = 743;
      final regenerates = <http.Request>[];
      await http.runWithClient(() async {
        await openPage(tester, groupId);
        await tester.tap(find.byIcon(Icons.refresh).first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(dialog(tester).title, 'Regenerate this image?');
        expect(dialog(tester).primaryLabel, 'Regenerate');
        expect(dialog(tester).destructive, isFalse);
        await cancel(tester);
        expect(regenerates, isEmpty);
      }, () => groupClient(groupId, 1, [], regenerates));
    });
  });

  // C1: a regenerate whose session ends before its outcome is known — not a
  // failure, and not "still rendering" for the page that sent it.
  group('regenerate across a session end', () {
    final failed = find.text('Failed to generate outfit');
    final stillRendering = find.textContaining('Still in progress');
    final sessionExpired = find.text('Session Expired');

    Future<void> closeDialogs(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        final buttons = find.byKey(AppDialog.dismissButtonKey);
        if (buttons.evaluate().isEmpty) break;
        await tester.tap(buttons.last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {}
    }

    Future<void> startRegenerate(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.refresh).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Regenerate').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    void expireSession(WidgetTester tester) => unawaited(
      AuthExpiredHandler.handle(tester.element(find.byType(OutfitDetailsPage))),
    );

    testWidgets('the reply landing after the session ended: no failure or '
        '"still rendering" over Session Expired, nothing sent again', (
      tester,
    ) async {
      final reply = Completer<http.Response>();
      var posts = 0;
      await http.runWithClient(
        () async {
          await startRegenerate(tester);
          expect(posts, 1);
          expireSession(tester);
          await tester.pump();
          await tester.pump();
          reply.complete(
            jsonResponse(
              envelope({
                'outfit_id': 1,
                'group_id': 3,
                'result_image_url': 'https://img.example/1b.png',
                'garment_ids': <int>[],
              }),
            ),
          );
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(seconds: 1));
          }

          final shown = {
            'failed': failed.evaluate().length,
            'stillRendering': stillRendering.evaluate().length,
            'sessionExpired': sessionExpired.evaluate().length,
            'posts': posts,
          };
          await closeDialogs(tester);
          expect(shown, {
            'failed': 0,
            'stillRendering': 0,
            'sessionExpired': 1,
            'posts': 1,
          });
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/regenerate')) {
            posts++;
            return reply.future;
          }
          if (isPointsSummaryPath(path)) {
            return jsonResponse(envelope(pointsSummaryJson(balance: 3)));
          }
          return jsonResponse(envelope({'items': []}));
        }),
      );
    });

    testWidgets('the session ending while its status is polled: no delayed '
        '"still rendering" over Session Expired, no new render', (
      tester,
    ) async {
      var posts = 0;
      var checks = 0;
      await http.runWithClient(
        () async {
          await startRegenerate(tester);
          for (var i = 0; i < 2; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          expect(checks, greaterThan(0));
          expireSession(tester);
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(seconds: 1));
          }

          final shown = {
            'failed': failed.evaluate().length,
            'stillRendering': stillRendering.evaluate().length,
            'sessionExpired': sessionExpired.evaluate().length,
            'posts': posts,
          };
          await closeDialogs(tester);
          expect(shown, {
            'failed': 0,
            'stillRendering': 0,
            'sessionExpired': 1,
            'posts': 1,
          });
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/regenerate')) {
            posts++;
            throw TimeoutException('slow');
          }
          if (path.contains('/outfit/generations/')) {
            checks++;
            return jsonResponse(envelope({'status': 'processing'}));
          }
          if (isPointsSummaryPath(path)) {
            return jsonResponse(envelope(pointsSummaryJson(balance: 3)));
          }
          return jsonResponse(envelope({'items': []}));
        }),
      );
    });
  });
}
