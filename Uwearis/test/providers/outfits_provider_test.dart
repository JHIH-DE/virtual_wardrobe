import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/outfit.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _outfit(int id, int groupId, {String imageUrl = ''}) => {
  'outfit_id': id,
  'group_id': groupId,
  'group_type': 'general',
  'status': 'completed',
  'garment_ids': <int>[],
  'result_image_url': imageUrl,
  'season': <String>[],
  'style': <String>[],
  'is_favorite': false,
};

/// A group holding a single outfit.
Map<String, dynamic> _group(int outfitId, int groupId, {String? name}) => {
  'group_id': groupId,
  'name': name,
  'cover_outfit_id': null,
  'outfits': [_outfit(outfitId, groupId)],
};

/// A group of several versions, the first one its cover.
Map<String, dynamic> _multiGroup(int groupId, List<int> outfitIds) => {
  'group_id': groupId,
  'name': null,
  'cover_outfit_id': outfitIds.first,
  'outfits': [for (final id in outfitIds) _outfit(id, groupId)],
};

Future<void> withOutfits(
  List<Map<String, dynamic>> groups,
  Future<void> Function(ProviderContainer container) body, {
  Future<http.Response> Function(http.Request request)? onRequest,
}) {
  final client = MockClient(
    onRequest ?? (_) async => jsonResponse(envelope({'items': groups})),
  );
  return http.runWithClient(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(outfitsProvider.future);
    await body(container);
  }, () => client);
}

void main() {
  setUp(setUpFakeAuth);

  group('groups', () {
    List<int> versionIds(ProviderContainer c, int groupId) => c
        .read(outfitsProvider)
        .value!
        .firstWhere((g) => g.groupId == groupId)
        .versions
        .map((o) => o.id)
        .toList();

    test('build() keeps every version of each group', () {
      return withOutfits(
        [
          _multiGroup(10, [1, 2, 3]),
        ],
        (c) async {
          expect(versionIds(c, 10), [1, 2, 3]);
          final cover = outfitGroupCovers(
            c.read(outfitsProvider).value!,
          ).single;
          expect(cover.id, 1);
        },
      );
    });

    test('removeOutfitVersion keeps the group while versions remain', () {
      return withOutfits(
        [
          _multiGroup(10, [1, 2]),
          _group(3, 20),
        ],
        (c) async {
          final outfits = c.read(outfitsProvider.notifier);
          outfits.removeOutfitVersion(1);
          expect(versionIds(c, 10), [2]);
          // The cover is gone, so the next version stands for the group.
          expect(outfitGroupCovers(c.read(outfitsProvider).value!).first.id, 2);

          outfits.removeOutfitVersion(3);
          expect(c.read(outfitsProvider).value!.map((g) => g.groupId), [10]);
        },
      );
    });

    test('a non-cover version takes favorite and tag edits', () {
      return withOutfits(
        [
          _multiGroup(10, [1, 2]),
        ],
        (c) async {
          final outfits = c.read(outfitsProvider.notifier);
          outfits.updateOutfitFavorite(2, isFavorite: true);
          outfits.updateOutfitTags(
            2,
            style: const ['minimal'],
            suitableTemperature: (
              minC: 15,
              maxC: 21,
              source: OutfitTemperatureSource.manual,
            ),
          );
          final second = c.read(outfitsProvider).value!.single.versions.last;
          expect(second.isFavorite, isTrue);
          expect(second.style, ['minimal']);
          expect(second.suitableTempMinC, 15);
          final first = c.read(outfitsProvider).value!.single.versions.first;
          expect(first.isFavorite, isFalse);
        },
      );
    });
  });

  test('build() flattens groups to their representative outfits', () {
    return withOutfits([_group(1, 10), _group(2, 20)], (c) async {
      expect(
        outfitGroupCovers(c.read(outfitsProvider).value!).map((o) => o.id),
        [1, 2],
      );
    });
  });

  group('optimistic mutations', () {
    test('removeGroup drops the matching group', () {
      return withOutfits([_group(1, 10), _group(2, 20)], (c) async {
        c.read(outfitsProvider.notifier).removeGroup(10);
        expect(
          outfitGroupCovers(c.read(outfitsProvider).value!).map((o) => o.id),
          [2],
        );
      });
    });

    test('updateGroupName matches by groupId, not outfit id', () {
      return withOutfits([_group(1, 10), _group(2, 20)], (c) async {
        c
            .read(outfitsProvider.notifier)
            .updateGroupName(20, name: 'Weekend Look');
        final list = c.read(outfitsProvider).value!;
        expect(list.firstWhere((g) => g.groupId == 20).name, 'Weekend Look');
        expect(list.firstWhere((g) => g.groupId == 10).name, isNull);
      });
    });
  });

  group('isStale / refreshIfNeeded', () {
    test(
      'isStale is true when a result image URL is an expired signed URL',
      () {
        final client = MockClient(
          (_) async => jsonResponse(
            envelope({
              'items': [
                {
                  'group_id': 10,
                  'cover_outfit_id': null,
                  'outfits': [_outfit(1, 10, imageUrl: expiredSignedUrl)],
                },
              ],
            }),
          ),
        );
        return http.runWithClient(() async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          await container.read(outfitsProvider.future);
          expect(container.read(outfitsProvider.notifier).isStale, isTrue);
        }, () => client);
      },
    );

    test('refreshIfNeeded re-fetches an empty list, skips a fresh one', () {
      var requests = 0;
      return withOutfits(
        const [],
        (c) async {
          expect(requests, 1);
          await c.read(outfitsProvider.notifier).refreshIfNeeded();
          expect(requests, 2, reason: 'empty -> refresh');
        },
        onRequest: (_) async {
          requests++;
          return jsonResponse(envelope({'items': const []}));
        },
      );
    });
  });
}
