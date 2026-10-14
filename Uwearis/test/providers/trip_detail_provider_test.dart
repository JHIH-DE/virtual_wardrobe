import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/trip_detail_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/trip_plan.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _planDay(String date, int optionId, int garmentId) => {
  'date': date,
  'options': [
    {
      'id': optionId,
      'order_index': 0,
      'items': [
        {'garment_id': garmentId, 'name': 'Item $garmentId', 'category': 'top'},
      ],
    },
  ],
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

  /// Serves `GET /plan` from [planDays] and `GET /{id}` from [suitcase],
  /// counting each; [planGate] holds `/plan` open until completed.
  ({MockClient client, int Function() planCalls, int Function() tripCalls})
  mockTrip({
    required List<Map<String, dynamic>> Function() planDays,
    required List<Map<String, dynamic>> Function() suitcase,
    Future<void> Function()? planGate,
  }) {
    var planCalls = 0;
    var tripCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/trip_plans/7/plan')) {
        planCalls++;
        await planGate?.call();
        return jsonResponse(
          envelope({'days': planDays(), 'suitcase_items': []}),
        );
      }
      if (request.url.path.endsWith('/trip_plans/7')) {
        tripCalls++;
        return jsonResponse(envelope({'suitcase_items': suitcase()}));
      }
      return jsonResponse(envelope({}), status: 404);
    });
    return (
      client: client,
      planCalls: () => planCalls,
      tripCalls: () => tripCalls,
    );
  }

  test('build() combines the plan and the suitcase, fetching each once', () {
    final mock = mockTrip(
      planDays: () => [_planDay('2026-11-01', 10, 1)],
      suitcase: () => [
        {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
        {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
      ],
    );
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final detail = await container.read(tripDetailProvider(7).future);

      expect(detail.days.single.optionId, 10);
      expect(detail.suitcase.map((g) => g.name), ['Tee', 'Jeans']);
      expect(detail.suitcaseIds, {1, 2});
      expect(detail.hasTripPlan, isTrue);

      // A second read is served from the cache.
      await container.read(tripDetailProvider(7).future);
      expect(mock.planCalls(), 1);
      expect(mock.tripCalls(), 1);
    }, () => mock.client);
  });

  test('updateDayOutfit replaces the day holding that option, and is a no-op '
      'for an option no day holds', () {
    final mock = mockTrip(
      planDays: () => [
        _planDay('2026-11-01', 10, 1),
        _planDay('2026-11-02', 11, 2),
      ],
      suitcase: () => [],
    );
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(tripDetailProvider(7).future);
      final notifier = container.read(tripDetailProvider(7).notifier);

      notifier.updateDayOutfit(
        11,
        (current) => TripDayOutfit(
          date: current.date,
          optionId: 11,
          garments: current.garments,
          outfitId: 99,
        ),
      );
      final days = container.read(tripDetailProvider(7)).value!.days;
      expect(days[0].outfitId, isNull);
      expect(days[1].outfitId, 99);

      final before = container.read(tripDetailProvider(7)).value;
      notifier.updateDayOutfit(404, (current) => current);
      expect(container.read(tripDetailProvider(7)).value, same(before));
    }, () => mock.client);
  });

  test('suitcase mutations keep ids unique', () {
    final mock = mockTrip(planDays: () => [], suitcase: () => []);
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
    var days = [_planDay('2026-11-01', 10, 1)];
    Completer<void>? gate;
    final mock = mockTrip(
      planDays: () => days,
      suitcase: () => [],
      planGate: () => gate?.future ?? Future.value(),
    );
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(tripDetailProvider(7).future);
      final notifier = container.read(tripDetailProvider(7).notifier);

      gate = Completer<void>();
      final reload = notifier.reloadPlan();
      // While the GET is pending, a local edit lands...
      notifier.updateDayOutfit(
        10,
        (current) => TripDayOutfit(
          date: current.date,
          optionId: 10,
          garments: current.garments,
          isManuallyEdited: true,
        ),
      );
      gate!.complete();
      await reload;

      expect(
        container
            .read(tripDetailProvider(7))
            .value!
            .days
            .single
            .isManuallyEdited,
        isTrue,
        reason: 'the stale reload must not undo the local edit',
      );

      // ...whereas a reload with nothing racing it is applied.
      days = [_planDay('2026-11-01', 10, 1), _planDay('2026-11-02', 11, 2)];
      await notifier.reloadPlan();
      expect(container.read(tripDetailProvider(7)).value!.days, hasLength(2));
    }, () => mock.client);
  });

  test('a failed reload keeps the cached detail and surfaces the error', () {
    var failPlan = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/plan')) {
        if (failPlan) return jsonResponse(envelope(null), status: 500);
        return jsonResponse(
          envelope({
            'days': [_planDay('2026-11-01', 10, 1)],
            'suitcase_items': [],
          }),
        );
      }
      return jsonResponse(envelope({'suitcase_items': []}));
    });
    return http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(tripDetailProvider(7).future);

      failPlan = true;
      await expectLater(
        container.read(tripDetailProvider(7).notifier).reloadPlan(),
        throwsA(anything),
      );
      final state = container.read(tripDetailProvider(7));
      expect(state.hasError, isFalse);
      expect(state.value!.days.single.optionId, 10);
    }, () => client);
  });
}
