import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

// An edit replayed onto a refresh must only change the fields it set: the
// refresh may carry a re-signed image URL, a new cache key, or group-level
// values (versionCount, groupName) the caller's own copy never had.

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// `/outfit` (group list + PATCH) and `/daily_outfits/{date}`. The group
/// list reply reflects [groups] when its request arrives; with [holdList]
/// it waits for [releaseList].
class _OutfitBackend {
  _OutfitBackend(this.groups);

  List<Map<String, dynamic>> groups;
  bool holdList = false;
  final List<Completer<void>> _held = [];

  /// Today's plan, as `/daily_outfits` returns it: plain outfits, no group
  /// wrapper (so no versionCount / groupName), with the URL it had.
  List<Map<String, dynamic>> plan = [];

  Future<void> releaseList() async {
    holdList = false;
    for (final gate in [..._held]) {
      gate.complete();
    }
    _held.clear();
    await _settle();
  }

  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/daily_outfits/')) {
      return jsonResponse(envelope(plan.isEmpty ? null : {'outfits': plan}));
    }
    if (request.method == 'PATCH') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = int.parse(request.url.pathSegments.last);
      final outfit = plan.firstWhere((o) => o['outfit_id'] == id);
      if (body.containsKey('is_favorite')) {
        outfit['is_favorite'] = body['is_favorite'];
      }
      if (body.containsKey('season')) outfit['season'] = body['season'];
      if (body.containsKey('style')) outfit['style'] = body['style'];
      return jsonResponse(envelope({...outfit}));
    }
    final snapshot = jsonDecode(jsonEncode(groups));
    if (holdList) {
      final gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
    return jsonResponse(
      envelope({'items': snapshot, 'total': groups.length, 'page': 1}),
    );
  });
}

Map<String, dynamic> _outfitJson(
  int id, {
  String url = 'https://old/1',
  String? cacheKey = 'key-old',
  bool fav = false,
}) => {
  'outfit_id': id,
  'group_id': id,
  'group_type': 'general',
  'status': 'completed',
  'garment_ids': <int>[],
  'result_image_url': url,
  'result_image_cache_key': cacheKey,
  'season': <String>[],
  'style': <String>[],
  'is_favorite': fav,
};

/// A group with three versions; [id] is its cover.
Map<String, dynamic> _groupJson(
  int id, {
  String url = 'https://old/1',
  String? cacheKey = 'key-old',
  String name = 'Weekend',
}) => {
  'group_id': id,
  'name': name,
  'cover_outfit_id': id,
  'outfits': [
    _outfitJson(id, url: url, cacheKey: cacheKey),
    _outfitJson(id + 100),
    _outfitJson(id + 200),
  ],
};

void main() {
  setUp(setUpFakeAuth);

  group('outfitsProvider', () {
    late _OutfitBackend backend;
    late ProviderContainer container;

    Outfit shown() => container.read(outfitsProvider).value!.single;

    Future<void> run(Future<void> Function() body) {
      backend = _OutfitBackend([_groupJson(1)])..plan = [_outfitJson(1)];
      return http.runWithClient(() async {
        container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(outfitsProvider, (_, _) {});
        container.listen(dailyOutfitProvider, (_, _) {});
        await container.read(outfitsProvider.future);
        await container.read(dailyOutfitProvider.future);
        await body();
      }, () => backend.client);
    }

    /// A refresh whose reply carries a re-signed URL and a new cache key.
    Future<({Future<void> done})> resignedRefresh() async {
      backend
        ..groups = [_groupJson(1, url: 'https://new/1', cacheKey: 'key-new')]
        ..holdList = true;
      final refresh = container.read(outfitsProvider.notifier).refresh();
      await _settle();
      return (done: refresh);
    }

    test("a favorite from Home's daily card keeps the refresh's new URL, "
        'cache key and the group-level fields', () {
      return run(() async {
        final refresh = (await resignedRefresh()).done;
        await container
            .read(dailyOutfitProvider.notifier)
            .toggleOutfitFavorite(
              container.read(dailyOutfitProvider).value!.single,
            );

        await backend.releaseList();
        await refresh;

        final o = shown();
        expect(o.isFavorite, isTrue);
        expect(o.imageUrl, 'https://new/1');
        expect(o.resultImageCacheKey, 'key-new');
        expect(o.versionCount, 3);
        expect(o.groupName, 'Weekend');
        expect(o.coverOutfitId, 1);
      });
    });

    test("a tag edit keeps the refresh's new cache key and URL", () {
      return run(() async {
        final refresh = (await resignedRefresh()).done;
        await container
            .read(dailyOutfitProvider.notifier)
            .updateOutfitTags(
              container.read(dailyOutfitProvider).value!.single,
              seasons: ['Summer'],
              style: ['Casual'],
            );

        await backend.releaseList();
        await refresh;

        final o = shown();
        expect(o.seasons, ['Summer']);
        expect(o.style, ['Casual']);
        expect(o.resultImageCacheKey, 'key-new');
        expect(o.imageUrl, 'https://new/1');
        expect(o.versionCount, 3);
      });
    });

    test("without any refresh, an edit from another screen's copy doesn't "
        "reset the representative's group-level fields", () {
      return run(() async {
        await container
            .read(dailyOutfitProvider.notifier)
            .toggleOutfitFavorite(
              container.read(dailyOutfitProvider).value!.single,
            );
        await _settle();

        final o = shown();
        expect(o.isFavorite, isTrue);
        expect(o.versionCount, 3, reason: "Style Taste's total uses it");
        expect(o.groupName, 'Weekend');
        expect(o.coverOutfitId, 1);
      });
    });

    test('different fields edited in order during one refresh all land, '
        'over the fresh URL', () {
      return run(() async {
        final refresh = (await resignedRefresh()).done;
        final daily = container.read(dailyOutfitProvider.notifier);
        Outfit today() => container.read(dailyOutfitProvider).value!.single;

        await daily.toggleOutfitFavorite(today()); // on
        await daily.updateOutfitTags(
          today(),
          seasons: ['Winter'],
          style: ['Formal'],
        );
        container
            .read(outfitsProvider.notifier)
            .updateGroupName(1, name: 'Office');
        await daily.toggleOutfitFavorite(today()); // off

        await backend.releaseList();
        await refresh;

        final o = shown();
        expect(o.isFavorite, isFalse);
        expect(o.seasons, ['Winter']);
        expect(o.style, ['Formal']);
        expect(o.groupName, 'Office');
        expect(o.imageUrl, 'https://new/1');
        expect(o.resultImageCacheKey, 'key-new');
      });
    });
  });

  group('garmentsProvider', () {
    late List<Map<String, dynamic>> items;
    late bool hold;
    late List<Completer<void>> held;
    late ProviderContainer container;

    Map<String, dynamic> garmentJson({
      String url = 'https://old/g',
      String? cacheKey = 'g-old',
      String? brand = 'Uniqlo',
      String name = 'Tee',
      bool fav = false,
    }) => {
      'id': 1,
      'name': name,
      'category': 'Top',
      'sub_category': 'Tee',
      'image_url': url,
      'image_cache_key': cacheKey,
      'brand': brand,
      'is_favorite': fav,
    };

    Future<void> run(Future<void> Function() body) {
      items = [garmentJson()];
      hold = false;
      held = [];
      final client = MockClient((_) async {
        final snapshot = jsonDecode(jsonEncode(items));
        if (hold) {
          final gate = Completer<void>();
          held.add(gate);
          await gate.future;
        }
        return jsonResponse(
          envelope({'items': snapshot, 'total': 1, 'page': 1, 'size': 100}),
        );
      });
      return http.runWithClient(() async {
        container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(garmentsProvider, (_, _) {});
        await container.read(garmentsProvider.future);
        await body();
      }, () => client);
    }

    GarmentsNotifier notifier() => container.read(garmentsProvider.notifier);
    Garment shown() => container.read(garmentsProvider).value!.single;

    Future<({Future<void> done})> resignedRefresh() async {
      items = [garmentJson(url: 'https://new/g', cacheKey: 'g-new')];
      hold = true;
      final refresh = notifier().refresh();
      await _settle();
      return (done: refresh);
    }

    Future<void> release() async {
      hold = false;
      for (final gate in held) {
        gate.complete();
      }
      await _settle();
    }

    test("a favorite keeps the refresh's new URL and cache key", () {
      return run(() async {
        final refresh = (await resignedRefresh()).done;
        notifier().updateFavoriteOptimistically(1, isFavorite: true);

        await release();
        await refresh;

        final g = shown();
        expect(g.isFavorite, isTrue);
        expect(g.imageUrl, 'https://new/g');
        expect(g.imageCacheKey, 'g-new');
      });
    });

    test('an edit that clears a nullable field (brand) stays cleared over '
        'a refresh that still has the old value', () {
      return run(() async {
        final refresh =
            (await resignedRefresh()).done; // its reply: brand Uniqlo
        // Garment Details' PATCH response: brand cleared.
        notifier().updateGarment(
          Garment.fromJson(
            garmentJson(
              url: 'https://patch/g',
              cacheKey: 'g-patch',
              brand: null,
            ),
          ),
        );

        await release();
        await refresh;

        expect(shown().brand, isNull);
      });
    });

    test('a favorite then a full edit replay in order', () {
      return run(() async {
        final refresh = (await resignedRefresh()).done;
        notifier().updateFavoriteOptimistically(1, isFavorite: true);
        notifier().updateGarment(
          Garment.fromJson(
            garmentJson(
              name: 'Renamed',
              fav: true,
              url: 'https://patch/g',
              cacheKey: 'g-patch',
            ),
          ),
        );

        await release();
        await refresh;

        final g = shown();
        expect(g.name, 'Renamed');
        expect(g.isFavorite, isTrue);
        expect(g.imageCacheKey, 'g-patch', reason: 'a server response');
      });
    });
  });
}
