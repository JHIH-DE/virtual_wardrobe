import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/garment_outfits_provider.dart';
import 'package:uwearis/core/services/outfit_service.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

const _garmentId = 7;

/// An in-memory `/outfit` backend: just enough of generate / delete /
/// by-garments / generations to move a garment in and out of outfits.
class _FakeOutfitBackend {
  final List<Map<String, dynamic>> outfits = [];
  int byGarmentsCalls = 0;
  int _nextOutfitId = 100;

  /// When set, the next by-garments reply waits on it (one-shot).
  Completer<void>? holdNextByGarments;

  Map<String, dynamic> outfitJson({
    required int outfitId,
    required int groupId,
    required List<int> garmentIds,
  }) => {
    'outfit_id': outfitId,
    'group_id': groupId,
    'group_type': 'general',
    'status': 'completed',
    'name': null,
    'garment_ids': garmentIds,
    'result_image_url': 'https://example.com/$outfitId.jpg',
    'season': <String>[],
    'style': <String>[],
    'is_favorite': false,
  };

  Map<String, dynamic> addOutfit(int groupId, List<int> garmentIds) {
    final json = outfitJson(
      outfitId: _nextOutfitId++,
      groupId: groupId,
      garmentIds: garmentIds,
    );
    outfits.add(json);
    return json;
  }

  late final MockClient client = MockClient((request) async {
    final segments = request.url.pathSegments;
    final i = segments.indexOf('outfit');
    final rest = segments.sublist(i + 1);

    if (request.method == 'POST' && rest.join('/') == 'by-garments') {
      byGarmentsCalls++;
      final hold = holdNextByGarments;
      holdNextByGarments = null;
      final ids = ((jsonDecode(request.body) as Map)['garment_ids'] as List)
          .cast<int>();
      final snapshot = [
        for (final o in outfits)
          if (ids.every((o['garment_ids'] as List).contains)) o,
      ];
      if (hold != null) await hold.future;
      return jsonResponse(envelope(snapshot));
    }
    if (request.method == 'POST' && rest.length == 2 && rest[1] == 'generate') {
      final ids = ((jsonDecode(request.body) as Map)['garment_ids'] as List)
          .cast<int>();
      return jsonResponse(envelope(addOutfit(int.parse(rest[0]), ids)));
    }
    if (request.method == 'DELETE' && rest.length == 1) {
      final groupId = int.parse(rest[0]);
      outfits.removeWhere((o) => o['group_id'] == groupId);
      return jsonResponse(envelope(null));
    }
    if (request.method == 'DELETE' && rest.length == 2) {
      final outfitId = int.parse(rest[1]);
      outfits.removeWhere((o) => o['outfit_id'] == outfitId);
      return jsonResponse(envelope(null));
    }
    if (request.method == 'PATCH' && rest.length == 2) {
      final outfitId = int.parse(rest[1]);
      final outfit = outfits.firstWhere((o) => o['outfit_id'] == outfitId);
      outfit['is_favorite'] =
          (jsonDecode(request.body) as Map)['is_favorite'] ?? false;
      return jsonResponse(envelope(outfit));
    }
    return http.Response('unexpected ${request.method} ${request.url}', 500);
  });
}

/// Lets the change notification, the invalidation and the re-fetch it
/// triggers all run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(setUpFakeAuth);

  late _FakeOutfitBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = _FakeOutfitBackend();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<int> watchedCount() async {
    await _settle();
    return (await container.read(
      garmentOutfitsProvider(_garmentId).future,
    )).length;
  }

  Future<T> withBackend<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => backend.client);

  test('0 → 1: creating an outfit with the garment updates the count', () {
    return withBackend(() async {
      container.listen(garmentOutfitsProvider(_garmentId), (_, _) {});
      expect(await watchedCount(), 0);

      await OutfitService().generateOutfit(
        garmentIds: [_garmentId, 8],
        groupId: 40,
      );

      expect(await watchedCount(), 1);
    });
  });

  test('1 → 0: deleting the outfit group updates the count', () {
    return withBackend(() async {
      backend.addOutfit(40, [_garmentId, 8]);
      container.listen(garmentOutfitsProvider(_garmentId), (_, _) {});
      expect(await watchedCount(), 1);

      await OutfitService().deleteGroup(40);

      expect(await watchedCount(), 0);
    });
  });

  test('deleting a single version updates the count', () {
    return withBackend(() async {
      final v1 = backend.addOutfit(40, [_garmentId, 8]);
      backend.addOutfit(40, [_garmentId, 9]);
      container.listen(garmentOutfitsProvider(_garmentId), (_, _) {});
      expect(await watchedCount(), 2);

      await OutfitService().deleteOutfit(40, v1['outfit_id'] as int);

      expect(await watchedCount(), 1);
    });
  });

  test('a lost reply recovered by key (the render landed) updates the '
      'count', () {
    return withBackend(() async {
      container.listen(garmentOutfitsProvider(_garmentId), (_, _) {});
      expect(await watchedCount(), 0);

      // The generate reached the backend, but its reply was lost.
      final landed = backend.addOutfit(40, [_garmentId, 8]);
      await http.runWithClient(
        () => OutfitService().getGeneration('key-1'),
        () => MockClient(
          (_) async =>
              jsonResponse(envelope({'status': 'succeeded', 'outfit': landed})),
        ),
      );

      expect(await watchedCount(), 1);
    });
  });

  test('a change while nothing listens costs no request until the count is '
      'read again', () {
    return withBackend(() async {
      expect(await watchedCount(), 0);
      expect(backend.byGarmentsCalls, 1);

      await OutfitService().generateOutfit(
        garmentIds: [_garmentId, 8],
        groupId: 40,
      );
      await _settle();
      expect(backend.byGarmentsCalls, 1);

      expect(await watchedCount(), 1);
      expect(backend.byGarmentsCalls, 2);
    });
  });

  test("a favorite toggle doesn't change which outfits hold the garment, "
      "so it doesn't re-fetch", () {
    return withBackend(() async {
      final outfit = backend.addOutfit(40, [_garmentId, 8]);
      container.listen(garmentOutfitsProvider(_garmentId), (_, _) {});
      expect(await watchedCount(), 1);
      final calls = backend.byGarmentsCalls;

      await OutfitService().updateOutfit(
        40,
        outfit['outfit_id'] as int,
        isFavorite: true,
      );
      await _settle();

      expect(backend.byGarmentsCalls, calls);
    });
  });

  test('a fetch that started before a change never overwrites the newer '
      'result', () {
    return withBackend(() async {
      backend.addOutfit(40, [_garmentId, 8]);
      final hold = Completer<void>();
      backend.holdNextByGarments = hold;
      container.listen(garmentOutfitsProvider(_garmentId), (_, _) {});
      await _settle();

      // The first read (1 outfit) is still in flight when the group goes.
      await OutfitService().deleteGroup(40);
      await _settle();
      hold.complete();
      await _settle();

      expect(
        (await container.read(
          garmentOutfitsProvider(_garmentId).future,
        )).length,
        0,
      );
    });
  });
}
