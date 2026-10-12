import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/outfit.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

class _FakeOutfitsNotifier extends OutfitsNotifier {
  _FakeOutfitsNotifier(this._initial);
  final List<Outfit> _initial;

  @override
  Future<List<Outfit>> build() async => _initial;

  void set(List<Outfit> outfits) => state = AsyncData(outfits);
}

Outfit _outfit(int id) =>
    Outfit(id: id, groupId: id, imageUrl: 'https://example.com/$id.jpg');

Map<String, dynamic> _outfitJson(int id) => {
  'outfit_id': id,
  'group_id': id,
  'group_type': 'general',
  'status': 'completed',
  'result_image_url': 'https://example.com/$id.jpg',
};

/// A stand-in `/daily_outfits` backend: [plan] is today's picked outfit ids
/// (empty = no plan), and [onGenerate] decides each POST's outcome from its
/// `alternatives_per_day` — returning the ids to pick, or null for a 422
/// `INSUFFICIENT_OUTFIT_DATA`.
class _Backend {
  _Backend({this.plan = const [], this.onGenerate});

  List<int> plan;
  List<int>? Function(int alternatives)? onGenerate;
  final generateAlternatives = <int>[];
  var getCount = 0;

  MockClient get client => MockClient((request) async {
    if (request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final alternatives = body['alternatives_per_day'] as int;
      generateAlternatives.add(alternatives);
      final picked = onGenerate?.call(alternatives);
      if (picked == null) {
        return jsonResponse({
          'success': false,
          'message': 'Not enough outfits',
          'data': null,
          'error_code': 'INSUFFICIENT_OUTFIT_DATA',
        }, status: 422);
      }
      plan = picked;
      return jsonResponse(
        envelope({'id': 1, 'outfits': plan.map(_outfitJson).toList()}),
      );
    }
    getCount++;
    return jsonResponse(
      envelope(
        plan.isEmpty ? null : {'outfits': plan.map(_outfitJson).toList()},
      ),
    );
  });
}

Future<void> _withDaily(
  _Backend backend,
  List<Outfit> outfits,
  Future<void> Function(ProviderContainer c, _FakeOutfitsNotifier o) body,
) {
  final fakeOutfits = _FakeOutfitsNotifier(outfits);
  return http.runWithClient(() async {
    final container = ProviderContainer(
      overrides: [outfitsProvider.overrideWith(() => fakeOutfits)],
    );
    addTearDown(container.dispose);
    await container.read(dailyOutfitProvider.future);
    await body(container, fakeOutfits);
  }, () => backend.client);
}

List<int> _ids(ProviderContainer c) =>
    c.read(dailyOutfitProvider).value!.map((o) => o.id).toList();

void main() {
  setUp(setUpFakeAuth);

  test('reads an existing plan without generating', () {
    final backend = _Backend(plan: [1, 2]);
    return _withDaily(backend, [_outfit(1), _outfit(2)], (c, _) async {
      expect(_ids(c), [1, 2]);
      expect(backend.generateAlternatives, isEmpty);
    });
  });

  test('generates a primary plus alternatives when today has no plan', () {
    final backend = _Backend(onGenerate: (_) => [3, 1, 2]);
    final outfits = [_outfit(1), _outfit(2), _outfit(3)];
    return _withDaily(backend, outfits, (c, _) async {
      expect(backend.generateAlternatives, [
        DailyOutfitNotifier.alternativesPerDay,
      ]);
      expect(_ids(c), [3, 1, 2]);
      // The generate response already carries the picked outfits — no
      // second GET to read them back.
      expect(backend.getCount, 1);
    });
  });

  test("settles for a primary alone when today's weather leaves too few "
      'outfits for alternatives', () {
    final backend = _Backend(onGenerate: (n) => n == 0 ? [2] : null);
    return _withDaily(backend, [_outfit(1), _outfit(2)], (c, _) async {
      expect(backend.generateAlternatives, [2, 0]);
      expect(_ids(c), [2]);
    });
  });

  test('skips generating when the user has no outfits yet', () {
    final backend = _Backend(onGenerate: (_) => [1]);
    return _withDaily(backend, const [], (c, _) async {
      expect(_ids(c), isEmpty);
      expect(backend.generateAlternatives, isEmpty);
    });
  });

  test("doesn't retry an INSUFFICIENT_OUTFIT_DATA day until the user's "
      'outfits change', () {
    final backend = _Backend(onGenerate: (_) => null);
    return _withDaily(backend, [_outfit(1)], (c, outfits) async {
      expect(_ids(c), isEmpty);
      expect(backend.generateAlternatives, [2, 0]);

      await c.read(dailyOutfitProvider.notifier).refresh();
      expect(backend.generateAlternatives, [2, 0]);

      backend.onGenerate = (_) => [5];
      outfits.set([_outfit(1), _outfit(5)]);
      await pumpEventQueue();
      expect(backend.generateAlternatives, [2, 0, 2]);
      expect(_ids(c), [5]);
    });
  });

  test('a change to My Outfits re-reads today in place, without a loading '
      'state', () {
    final backend = _Backend(plan: [1, 2]);
    return _withDaily(backend, [_outfit(1), _outfit(2)], (c, outfits) async {
      final states = <AsyncValue<List<Outfit>>>[];
      c.listen(dailyOutfitProvider, (_, next) => states.add(next));

      // Deleting outfit 2 also drops it from today's plan server-side.
      backend.plan = [1];
      outfits.set([_outfit(1)]);
      await pumpEventQueue();

      expect(_ids(c), [1]);
      expect(states.any((s) => s.isLoading), isFalse);
    });
  });
}
