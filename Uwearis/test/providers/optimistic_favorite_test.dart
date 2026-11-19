import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

// The optimistic-favorite protocol callers follow: show the value, PATCH,
// then settle with the requested value (success) or the previous one
// (failure). These cover the orderings a single screen can't produce on its
// own (it allows one PATCH at a time), e.g. two screens or two taps whose
// PATCHes overlap.

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A list endpoint answering with [fav] as it is when a request *arrives*;
/// with [hold], replies wait for [release].
class _Backend {
  _Backend(this.itemJson);

  final Map<String, dynamic> Function(bool fav) itemJson;
  bool fav = false;
  bool hold = false;
  final List<Completer<void>> _held = [];

  Future<void> release() async {
    hold = false;
    for (final gate in [..._held]) {
      gate.complete();
    }
    _held.clear();
    await _settle();
  }

  late final MockClient client = MockClient((_) async {
    final snapshot = jsonDecode(jsonEncode(itemJson(fav)));
    if (hold) {
      final gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
    return jsonResponse(
      envelope({
        'items': [snapshot],
        'total': 1,
        'page': 1,
        'size': 100,
      }),
    );
  });
}

void main() {
  setUp(setUpFakeAuth);

  group('garmentsProvider', () {
    late _Backend backend;
    late ProviderContainer container;

    Future<void> run(Future<void> Function(GarmentsNotifier n) body) {
      backend = _Backend(
        (fav) => {
          'id': 1,
          'name': 'Tee',
          'category': 'Top',
          'sub_category': 'Tee',
          'image_url': '',
          'is_favorite': fav,
        },
      );
      return http.runWithClient(() async {
        container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(garmentsProvider, (_, _) {});
        await container.read(garmentsProvider.future);
        await body(container.read(garmentsProvider.notifier));
      }, () => backend.client);
    }

    bool fav() => container.read(garmentsProvider).value!.single.isFavorite;

    test('favorite → stale refresh answers → PATCH succeeds', () {
      return run((n) async {
        final t = n.updateFavoriteOptimistically(1, isFavorite: true);
        backend.hold = true;
        final refresh = n.refresh();
        await _settle();
        await backend.release(); // stale: false
        await refresh;
        expect(fav(), isFalse, reason: 'the stale reply landed');

        backend.fav = true;
        n.settleFavorite(1, t, isFavorite: true);
        expect(fav(), isTrue);
      });
    });

    test('unfavorite → stale refresh answers → PATCH succeeds', () {
      return run((n) async {
        backend.fav = true;
        await n.refresh();
        final t = n.updateFavoriteOptimistically(1, isFavorite: false);
        backend.hold = true;
        final refresh = n.refresh();
        await _settle();
        await backend.release(); // stale: true
        await refresh;

        n.settleFavorite(1, t, isFavorite: false);
        expect(fav(), isFalse);
      });
    });

    test('PATCH succeeds while the stale refresh is still in flight', () {
      return run((n) async {
        final t = n.updateFavoriteOptimistically(1, isFavorite: true);
        backend.hold = true;
        final refresh = n.refresh();
        await _settle();
        n.settleFavorite(1, t, isFavorite: true); // replayed onto the reply
        await backend.release(); // stale: false
        await refresh;

        expect(fav(), isTrue);
      });
    });

    test('a failed PATCH rolls back', () {
      return run((n) async {
        final t = n.updateFavoriteOptimistically(1, isFavorite: true);
        n.settleFavorite(1, t, isFavorite: false);
        expect(fav(), isFalse);
      });
    });

    test('a failed PATCH settling during a refresh still rolls back', () {
      return run((n) async {
        final t = n.updateFavoriteOptimistically(1, isFavorite: true);
        backend.hold = true;
        final refresh = n.refresh();
        await _settle();
        n.settleFavorite(1, t, isFavorite: false);
        await backend.release();
        await refresh;

        expect(fav(), isFalse);
      });
    });

    test("a rollback doesn't undo a newer write made before it", () {
      return run((n) async {
        final older = n.updateFavoriteOptimistically(1, isFavorite: true);
        n.updateFavorite(1, isFavorite: true); // another screen, confirmed
        n.settleFavorite(1, older, isFavorite: false); // older PATCH failed

        expect(fav(), isTrue);
      });
    });

    test('quick favorite then unfavorite, PATCH replies reversed: ends on '
        'the last tap', () {
      return run((n) async {
        final first = n.updateFavoriteOptimistically(1, isFavorite: true);
        final second = n.updateFavoriteOptimistically(1, isFavorite: false);

        n.settleFavorite(1, second, isFavorite: false); // answers first
        n.settleFavorite(1, first, isFavorite: true); // answers last: stale

        expect(fav(), isFalse);
      });
    });

    test('quick favorite then unfavorite, the later one fails: rolls back '
        "to the earlier tap's value", () {
      return run((n) async {
        final first = n.updateFavoriteOptimistically(1, isFavorite: true);
        final second = n.updateFavoriteOptimistically(1, isFavorite: false);

        n.settleFavorite(1, first, isFavorite: true); // stale, ignored
        n.settleFavorite(1, second, isFavorite: true); // failed: previous

        expect(fav(), isTrue);
      });
    });

    test("a token from before a rebuild (sign-in) settles nothing", () {
      return run((n) async {
        final t = n.updateFavoriteOptimistically(1, isFavorite: true);
        container.invalidate(garmentsProvider);
        await container.read(garmentsProvider.future);

        n.settleFavorite(1, t, isFavorite: true);
        expect(fav(), isFalse);
      });
    });
  });

  group('outfitsProvider', () {
    late _Backend backend;
    late ProviderContainer container;

    Future<void> run(Future<void> Function(OutfitsNotifier n) body) {
      backend = _Backend(
        (fav) => {
          'group_id': 5,
          'name': 'Weekend',
          'cover_outfit_id': 5,
          'outfits': [
            {
              'outfit_id': 5,
              'group_id': 5,
              'group_type': 'general',
              'status': 'completed',
              'garment_ids': <int>[],
              'result_image_url': 'https://img/5',
              'season': <String>[],
              'style': <String>[],
              'is_favorite': fav,
            },
          ],
        },
      );
      return http.runWithClient(() async {
        container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(outfitsProvider, (_, _) {});
        await container.read(outfitsProvider.future);
        await body(container.read(outfitsProvider.notifier));
      }, () => backend.client);
    }

    bool fav() => container.read(outfitsProvider).value!.single.isFavorite;

    test('favorite → stale refresh answers → PATCH succeeds', () {
      return run((n) async {
        final t = n.updateOutfitFavoriteOptimistically(5, isFavorite: true);
        backend.hold = true;
        final refresh = n.refresh();
        await _settle();
        await backend.release();
        await refresh;

        n.settleOutfitFavorite(5, t, isFavorite: true);
        expect(fav(), isTrue);
        expect(
          container.read(outfitsProvider).value!.single.groupName,
          'Weekend',
          reason: 'still a field-level write (F3)',
        );
      });
    });

    test("a rollback doesn't undo a newer confirmed write", () {
      return run((n) async {
        final older = n.updateOutfitFavoriteOptimistically(5, isFavorite: true);
        n.updateOutfitFavorite(5, isFavorite: true); // Outfit Details
        n.settleOutfitFavorite(5, older, isFavorite: false);

        expect(fav(), isTrue);
      });
    });

    test('quick toggles with reversed replies end on the last tap', () {
      return run((n) async {
        final first = n.updateOutfitFavoriteOptimistically(5, isFavorite: true);
        final second = n.updateOutfitFavoriteOptimistically(
          5,
          isFavorite: false,
        );
        n.settleOutfitFavorite(5, second, isFavorite: false);
        n.settleOutfitFavorite(5, first, isFavorite: true);

        expect(fav(), isFalse);
      });
    });
  });
}
