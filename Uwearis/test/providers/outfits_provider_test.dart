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

/// One OutfitGroup wrapper holding a single outfit — [getAllOutfits] flattens
/// each group to its representative, so `id == outfitId` and `groupId` come
/// straight through.
Map<String, dynamic> _group(int outfitId, int groupId, {String? name}) => {
  'group_id': groupId,
  'name': name,
  'cover_outfit_id': null,
  'outfits': [_outfit(outfitId, groupId)],
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

  test('build() flattens groups to their representative outfits', () {
    return withOutfits([_group(1, 10), _group(2, 20)], (c) async {
      expect(c.read(outfitsProvider).value!.map((o) => o.id), [1, 2]);
    });
  });

  group('optimistic mutations', () {
    test('addOutfit prepends', () {
      return withOutfits([_group(1, 10)], (c) async {
        c
            .read(outfitsProvider.notifier)
            .addOutfit(Outfit.fromJson(_outfit(2, 20)));
        expect(c.read(outfitsProvider).value!.map((o) => o.id), [2, 1]);
      });
    });

    test('removeOutfit drops the matching id', () {
      return withOutfits([_group(1, 10), _group(2, 20)], (c) async {
        c.read(outfitsProvider.notifier).removeOutfit(1);
        expect(c.read(outfitsProvider).value!.map((o) => o.id), [2]);
      });
    });

    test('updateGroupName matches by groupId, not outfit id', () {
      return withOutfits([_group(1, 10), _group(2, 20)], (c) async {
        c
            .read(outfitsProvider.notifier)
            .updateGroupName(20, name: 'Weekend Look');
        final list = c.read(outfitsProvider).value!;
        expect(list.firstWhere((o) => o.groupId == 20).groupName, 'Weekend Look');
        expect(list.firstWhere((o) => o.groupId == 10).groupName, isNull);
      });
    });
  });

  group('isStale / refreshIfNeeded', () {
    test('isStale is true when a result image URL is an expired signed URL', () {
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
    });

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
