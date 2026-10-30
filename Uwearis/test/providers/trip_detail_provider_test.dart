import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/trip_detail_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/trip_outfit.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _outfit(int id, List<int> garmentIds) => {
  'id': id,
  'source': 'suggested',
  'garments': [
    for (final g in garmentIds)
      {'garment_id': g, 'name': 'Item $g', 'category': 'top'},
  ],
};

Map<String, dynamic> _collection({
  List<Map<String, dynamic>> outfits = const [],
  List<int> suitcase = const [],
}) => {
  'trip_id': 7,
  'total_days': 5,
  'suggested_outfit_count': {'min': 4, 'max': 6},
  'suitcase_items': [
    for (final g in suitcase)
      {'garment_id': g, 'name': 'Item $g', 'category': 'top'},
  ],
  'outfits': outfits,
  'saved_candidates': [],
};

Garment _garment(int id) => Garment(
  id: id,
  garmentId: id,
  name: 'Item $id',
  category: GarmentCategory.top,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
);

void main() {
  setUp(setUpFakeAuth);

  /// Serves `GET /outfits` from [collection], counting calls; [gate] holds
  /// it open until completed.
  ({MockClient client, int Function() calls}) mockCollection(
    Map<String, dynamic> Function() collection, {
    Future<void> Function()? gate,
  }) {
    var calls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/trip_plans/7/outfits')) {
        calls++;
        await gate?.call();
        return jsonResponse(envelope(collection()));
      }
      return jsonResponse(envelope({}), status: 404);
    });
    return (client: client, calls: () => calls);
  }

  test('build() loads the collection and suitcase in one request', () {
    final mock = mockCollection(
      () => _collection(
        outfits: [
          _outfit(1, [1, 2]),
        ],
        suitcase: [1, 2],
      ),
    );
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final detail = await container.read(tripDetailProvider(7).future);

      expect(detail.outfits.single.id, 1);
      expect(detail.suitcaseIds, {1, 2});
      expect(detail.suggestedMax, 6);

      await container.read(tripDetailProvider(7).future);
      expect(mock.calls(), 1);
    }, () => mock.client);
  });

  test('removing a garment from the suitcase marks the outfit missing '
      'without patching the outfit', () {
    final mock = mockCollection(
      () => _collection(
        outfits: [
          _outfit(1, [1, 2]),
          _outfit(2, [1, 3]),
        ],
        suitcase: [1, 2, 3],
      ),
    );
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(tripDetailProvider(7).future);

      container.read(tripDetailProvider(7).notifier).removeSuitcaseGarment(1);

      final detail = container.read(tripDetailProvider(7)).value!;
      expect(detail.outfits, hasLength(2));
      for (final o in detail.outfits) {
        expect(o.missingGarments(detail.suitcaseIds).map((g) => g.id), [1]);
      }
    }, () => mock.client);
  });

  test('suitcase mutations keep ids unique', () {
    final mock = mockCollection(() => _collection());
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(tripDetailProvider(7).future);
      final notifier = container.read(tripDetailProvider(7).notifier);

      notifier.setSuitcase([_garment(1)]);
      notifier.addSuitcaseGarments([_garment(1), _garment(2)]);
      expect(container.read(tripDetailProvider(7)).value!.suitcaseIds, {1, 2});

      notifier.removeSuitcaseGarment(1);
      expect(container.read(tripDetailProvider(7)).value!.suitcaseIds, {2});
    }, () => mock.client);
  });

  test('a reload that was in flight across a local mutation is dropped, so a '
      'response predating that change cannot overwrite it', () {
    var outfits = [
      _outfit(1, [1, 2]),
    ];
    Completer<void>? gate;
    final mock = mockCollection(
      () => _collection(outfits: outfits),
      gate: () => gate?.future ?? Future.value(),
    );
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(tripDetailProvider(7).future);
      final notifier = container.read(tripDetailProvider(7).notifier);

      gate = Completer<void>();
      final reload = notifier.reloadTripDetail();
      // While the GET is pending, an action's response lands...
      notifier.setCollection(
        TripOutfitCollection.fromJson(
          _collection(
            outfits: [
              _outfit(1, [1, 2]),
              _outfit(2, [3, 4]),
            ],
          ),
        ),
      );
      gate!.complete();
      await reload;

      expect(
        container.read(tripDetailProvider(7)).value!.outfits,
        hasLength(2),
        reason: 'the stale reload must not undo the newer collection',
      );

      // ...whereas a reload with nothing racing it is applied.
      outfits = [];
      await notifier.reloadTripDetail();
      expect(container.read(tripDetailProvider(7)).value!.outfits, isEmpty);
    }, () => mock.client);
  });

  test(
    'a failed reload keeps the cached collection and surfaces the error',
    () {
      var fail = false;
      final client = MockClient((request) async {
        if (fail) return jsonResponse(envelope(null), status: 500);
        return jsonResponse(
          envelope(
            _collection(
              outfits: [
                _outfit(1, [1]),
              ],
            ),
          ),
        );
      });
      return http.runWithClient(() async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(tripDetailProvider(7).future);

        fail = true;
        await expectLater(
          container.read(tripDetailProvider(7).notifier).reloadTripDetail(),
          throwsA(anything),
        );
        final state = container.read(tripDetailProvider(7));
        expect(state.hasError, isFalse);
        expect(state.value!.outfits.single.id, 1);
      }, () => client);
    },
  );
}
