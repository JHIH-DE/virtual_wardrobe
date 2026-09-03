import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _g(int id, {String imageUrl = ''}) => {
  'id': id,
  'name': 'Garment $id',
  'category': 'Top',
  'sub_category': 'Tee',
  'image_url': imageUrl,
};

/// Runs [body] with garmentsProvider seeded from [items]; [onRequest], if
/// given, replaces the default handler (which always returns [items]) so a
/// test can count / vary responses.
Future<void> withGarments(
  List<Map<String, dynamic>> items,
  Future<void> Function(ProviderContainer container) body, {
  Future<http.Response> Function(http.Request request)? onRequest,
}) {
  final client = MockClient(
    onRequest ?? (_) async => jsonResponse(envelope(items)),
  );
  return http.runWithClient(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(garmentsProvider.future);
    await body(container);
  }, () => client);
}

void main() {
  setUp(setUpFakeAuth);

  group('build()', () {
    test('exposes the fetched list', () {
      return withGarments([_g(1), _g(2)], (c) async {
        expect(c.read(garmentsProvider).value!.map((g) => g.id), [1, 2]);
      });
    });
  });

  group('optimistic mutations', () {
    test('addGarment prepends the new garment', () {
      return withGarments([_g(1)], (c) async {
        c.read(garmentsProvider.notifier).addGarment(Garment.fromJson(_g(2)));
        expect(c.read(garmentsProvider).value!.map((g) => g.id), [2, 1]);
      });
    });

    test('removeGarment drops the matching id, keeps the rest', () {
      return withGarments([_g(1), _g(2), _g(3)], (c) async {
        c.read(garmentsProvider.notifier).removeGarment(2);
        expect(c.read(garmentsProvider).value!.map((g) => g.id), [1, 3]);
      });
    });

    test('updateGarment replaces the entry with the same id', () {
      return withGarments([_g(1), _g(2)], (c) async {
        final renamed = Garment.fromJson(_g(2)).copyWith(name: 'Renamed');
        c.read(garmentsProvider.notifier).updateGarment(renamed);
        final list = c.read(garmentsProvider).value!;
        expect(list.firstWhere((g) => g.id == 2).name, 'Renamed');
        expect(list.map((g) => g.id), [1, 2]);
      });
    });

    test('updateFavorite flips isFavorite only on the target', () {
      return withGarments([_g(1), _g(2)], (c) async {
        c
            .read(garmentsProvider.notifier)
            .updateFavorite(1, isFavorite: true);
        final list = c.read(garmentsProvider).value!;
        expect(list.firstWhere((g) => g.id == 1).isFavorite, isTrue);
        expect(list.firstWhere((g) => g.id == 2).isFavorite, isFalse);
      });
    });

    test('a mutation on an empty list is a no-op, not a crash', () {
      return withGarments([], (c) async {
        c.read(garmentsProvider.notifier).removeGarment(99);
        expect(c.read(garmentsProvider).value, isEmpty);
      });
    });
  });

  group('isStale / refreshIfNeeded', () {
    test('isStale is false for a fresh, non-empty list', () {
      return withGarments([_g(1)], (c) async {
        expect(c.read(garmentsProvider.notifier).isStale, isFalse);
      });
    });

    test('isStale is true when any image URL is an expired signed URL', () {
      return withGarments([_g(1, imageUrl: expiredSignedUrl)], (c) async {
        expect(c.read(garmentsProvider.notifier).isStale, isTrue);
      });
    });

    test('refreshIfNeeded re-fetches when the list is empty', () {
      var requests = 0;
      return withGarments(
        [],
        (c) async {
          expect(requests, 1, reason: 'initial build()');
          await c.read(garmentsProvider.notifier).refreshIfNeeded();
          expect(requests, 2);
        },
        onRequest: (_) async {
          requests++;
          return jsonResponse(envelope(const []));
        },
      );
    });

    test('refreshIfNeeded does nothing for a fresh non-empty list', () {
      var requests = 0;
      return withGarments(
        [_g(1)],
        (c) async {
          expect(requests, 1);
          await c.read(garmentsProvider.notifier).refreshIfNeeded();
          expect(requests, 1, reason: 'not empty, not stale -> skip');
        },
        onRequest: (_) async {
          requests++;
          return jsonResponse(envelope([_g(1)]));
        },
      );
    });
  });
}
