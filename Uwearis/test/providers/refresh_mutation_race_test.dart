import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/garment.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _garmentJson(
  int id, {
  String? name,
  bool fav = false,
  String url = '',
}) => {
  'id': id,
  'name': name ?? 'Garment $id',
  'category': 'Top',
  'sub_category': 'Tee',
  'image_url': url,
  'is_favorite': fav,
};

Map<String, dynamic> _groupJson(
  int id, {
  String? name,
  bool fav = false,
  String url = '',
}) => {
  'group_id': id,
  'name': name,
  'cover_outfit_id': null,
  'outfits': [
    {
      'outfit_id': id,
      'group_id': id,
      'group_type': 'general',
      'status': 'completed',
      'garment_ids': <int>[],
      'result_image_url': url,
      'season': <String>[],
      'style': <String>[],
      'is_favorite': fav,
    },
  ],
};

/// A list endpoint whose reply reflects the server's list *when the request
/// arrived* — so a reply to a fetch that started before a mutation
/// committed doesn't contain it. With [hold], replies wait for the test.
class _ListBackend {
  _ListBackend(this.items);

  List<Map<String, dynamic>> items;
  int gets = 0;
  bool hold = false;
  http.Response? failWith;
  final List<Completer<void>> held = [];

  late final MockClient client = MockClient((request) async {
    gets++;
    final snapshot = [
      for (final i in items) {...i},
    ];
    final failure = failWith;
    if (hold) {
      final gate = Completer<void>();
      held.add(gate);
      await gate.future;
    }
    return failure ??
        jsonResponse(
          envelope({
            'items': snapshot,
            'total': snapshot.length,
            'page': 1,
            'size': 100,
          }),
        );
  });

  /// Answers held replies in [order] (indexes into the held list).
  Future<void> release(List<int> order) async {
    final gates = [...held];
    held.clear();
    hold = false;
    for (final i in order) {
      gates[i].complete();
      await _settle();
    }
  }
}

http.Response _serverError() => jsonResponse({
  'success': false,
  'message': 'boom',
  'data': null,
  'error_code': 'SERVICE_UNAVAILABLE',
}, status: 503);

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Garment _garment(int id, {String? name, bool fav = false}) =>
    Garment.fromJson(_garmentJson(id, name: name, fav: fav));

void main() {
  setUp(setUpFakeAuth);

  group('garmentsProvider', () {
    late _ListBackend backend;
    late ProviderContainer container;

    setUp(() {
      backend = _ListBackend([_garmentJson(1), _garmentJson(2)]);
    });

    Future<T> run<T>(Future<T> Function() body) => http.runWithClient(() async {
      container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(garmentsProvider, (_, _) {});
      await container.read(garmentsProvider.future);
      return body();
    }, () => backend.client);

    GarmentsNotifier notifier() => container.read(garmentsProvider.notifier);
    List<Garment> garments() => container.read(garmentsProvider).value!;
    List<int?> ids() => garments().map((g) => g.id).toList();

    /// Starts a refresh whose request reaches the server now, and holds it.
    Future<({Future<void> done})> heldRefresh() async {
      backend.hold = true;
      final refresh = notifier().refresh();
      await _settle();
      return (done: refresh);
    }

    test('a garment added while a refresh is in flight survives it', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        backend.items = [_garmentJson(3), ...backend.items];
        notifier().addGarment(_garment(3));

        await backend.release([0]);
        await refresh;

        expect(ids(), [3, 1, 2]);
        expect(backend.gets, 2, reason: 'no extra request');
      });
    });

    test('an edit made while a refresh is in flight survives it', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        backend.items[0] = _garmentJson(1, name: 'Renamed');
        notifier().updateGarment(_garment(1, name: 'Renamed'));

        await backend.release([0]);
        await refresh;

        expect(garments().first.name, 'Renamed');
      });
    });

    test('a garment removed while a refresh is in flight stays removed', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        backend.items.removeAt(0);
        notifier().removeGarment(1);

        await backend.release([0]);
        await refresh;

        expect(ids(), [2]);
      });
    });

    test('a favorite set while a refresh is in flight survives it', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        notifier().updateFavoriteOptimistically(2, isFavorite: true);

        await backend.release([0]);
        await refresh;

        expect(garments().firstWhere((g) => g.id == 2).isFavorite, isTrue);
      });
    });

    test('an add that the refresh already contains is not duplicated', () {
      return run(() async {
        backend.items = [_garmentJson(3), ...backend.items];
        final refresh = (await heldRefresh()).done; // its reply includes 3
        notifier().addGarment(_garment(3));

        await backend.release([0]);
        await refresh;

        expect(ids(), [3, 1, 2]);
      });
    });

    test('a failed optimistic favorite rolled back during a refresh ends '
        'rolled back', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        notifier().updateFavoriteOptimistically(
          2,
          isFavorite: true,
        ); // optimistic
        notifier().updateFavoriteOptimistically(
          2,
          isFavorite: false,
        ); // request failed

        await backend.release([0]);
        await refresh;

        expect(garments().firstWhere((g) => g.id == 2).isFavorite, isFalse);
      });
    });

    test('an older refresh answering after a newer one does not overwrite '
        'it', () {
      return run(() async {
        backend.hold = true;
        final older = notifier().refresh();
        await _settle();
        backend.items = [_garmentJson(9)];
        final newer = notifier().refresh();
        await _settle();

        await backend.release([1, 0]); // newer first
        await Future.wait([older, newer]);

        expect(ids(), [9]);
        expect(container.read(garmentsProvider).isLoading, isFalse);
      });
    });

    test('refreshes answering in order end on the newest', () {
      return run(() async {
        backend.hold = true;
        final older = notifier().refresh();
        await _settle();
        backend.items = [_garmentJson(9)];
        final newer = notifier().refresh();
        await _settle();

        await backend.release([0, 1]);
        await Future.wait([older, newer]);

        expect(ids(), [9]);
      });
    });

    test('a failed refresh keeps the list, with edits made meanwhile', () {
      return run(() async {
        backend.failWith = _serverError();
        final refresh = (await heldRefresh()).done;
        notifier().updateGarment(_garment(1, name: 'Renamed'));

        await backend.release([0]);
        await refresh;

        final state = container.read(garmentsProvider);
        expect(state.hasError, isTrue, reason: 'error semantics unchanged');
        expect(state.value?.map((g) => g.name), ['Renamed', 'Garment 2']);
      });
    });

    test("after invalidate (next sign-in), the previous build's refresh "
        "can't overwrite the new list", () {
      return run(() async {
        final refresh = (await heldRefresh()).done; // account A's list
        setUpFakeAuth(accessToken: 'account-b');
        backend
          ..items = [_garmentJson(50)]
          ..hold = true;
        container.invalidate(garmentsProvider);
        await _settle();

        final gates = [...backend.held];
        backend
          ..held.clear()
          ..hold = false;
        gates[1].complete(); // B's build
        await _settle();
        expect(ids(), [50]);

        gates[0].complete(); // A's late refresh
        await refresh;
        await _settle();
        expect(ids(), [50]);
      });
    });

    test('a garment added while the first load is in flight survives it', () {
      backend.hold = true;
      return http.runWithClient(() async {
        container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(garmentsProvider, (_, _) {});
        await _settle();

        backend.items = [_garmentJson(3), ...backend.items];
        notifier().addGarment(_garment(3)); // e.g. a shared photo's upload
        await backend.release([0]);
        await container.read(garmentsProvider.future);

        expect(ids(), [3, 1, 2]);
        expect(backend.gets, 1);
      }, () => backend.client);
    });

    test("a mutation from before the switch isn't replayed into the next "
        "account's list", () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        notifier().addGarment(_garment(7)); // account A
        setUpFakeAuth(accessToken: 'account-b');
        backend
          ..items = [_garmentJson(50)]
          ..hold = true;
        container.invalidate(garmentsProvider);
        await _settle();

        await backend.release([1, 0]); // B's build, then A's refresh
        await refresh;

        expect(ids(), [50]);
      });
    });
  });

  group('outfitsProvider', () {
    late _ListBackend backend;
    late ProviderContainer container;

    setUp(() {
      backend = _ListBackend([_groupJson(1), _groupJson(2)]);
    });

    Future<T> run<T>(Future<T> Function() body) => http.runWithClient(() async {
      container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(outfitsProvider, (_, _) {});
      await container.read(outfitsProvider.future);
      return body();
    }, () => backend.client);

    OutfitsNotifier notifier() => container.read(outfitsProvider.notifier);
    List<int> ids() =>
        container.read(outfitsProvider).value!.map((o) => o.id).toList();

    Future<({Future<void> done})> heldRefresh() async {
      backend.hold = true;
      final refresh = notifier().refresh();
      await _settle();
      return (done: refresh);
    }

    test('an outfit deleted while a refresh is in flight stays deleted', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        backend.items.removeAt(0);
        notifier().removeOutfit(1);

        await backend.release([0]);
        await refresh;

        expect(ids(), [2]);
      });
    });

    test('an outfit edit made while a refresh is in flight survives it', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        final current = container.read(outfitsProvider).value!.first;
        notifier().updateOutfitFavorite(current.id, isFavorite: true);

        await backend.release([0]);
        await refresh;

        expect(container.read(outfitsProvider).value!.first.isFavorite, isTrue);
      });
    });

    test('a group rename made while a refresh is in flight survives it', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        notifier().updateGroupName(2, name: 'Weekend');

        await backend.release([0]);
        await refresh;

        expect(
          container.read(outfitsProvider).value!.last.groupName,
          'Weekend',
        );
      });
    });

    test('an older refresh answering after a newer one does not overwrite '
        'it', () {
      return run(() async {
        backend.hold = true;
        final older = notifier().refresh();
        await _settle();
        backend.items = [_groupJson(9)];
        final newer = notifier().refresh();
        await _settle();

        await backend.release([1, 0]);
        await Future.wait([older, newer]);

        expect(ids(), [9]);
      });
    });

    test("after invalidate, the previous build's refresh can't overwrite "
        'the new list', () {
      return run(() async {
        final refresh = (await heldRefresh()).done;
        setUpFakeAuth(accessToken: 'account-b');
        backend
          ..items = [_groupJson(50)]
          ..hold = true;
        container.invalidate(outfitsProvider);
        await _settle();

        await backend.release([1, 0]); // B's build, then A's refresh
        await refresh;

        expect(ids(), [50]);
      });
    });
  });

  // Concurrency audit of ListRefetchGuard (through garmentsProvider /
  // outfitsProvider). Skipped tests state the behaviour that should hold
  // and reproduce a finding; run them with --run-skipped.
  group('ListRefetchGuard audit', () {
    late _ListBackend backend;
    late ProviderContainer container;

    GarmentsNotifier notifier() => container.read(garmentsProvider.notifier);
    AsyncValue<List<Garment>> state() => container.read(garmentsProvider);
    List<int?> ids() => state().value!.map((g) => g.id).toList();

    Future<T> run<T>(Future<T> Function() body) => http.runWithClient(() async {
      container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(garmentsProvider, (_, _) {});
      await container.read(garmentsProvider.future);
      return body();
    }, () => backend.client);

    /// Starts refresh A, then refresh B (B's request sees [bItems]); both
    /// held. [aFails]/[bFails] make that reply a 503.
    Future<({Future<void> a, Future<void> b})> startAB({
      List<Map<String, dynamic>>? bItems,
      bool aFails = false,
      bool bFails = false,
      void Function()? between,
    }) async {
      backend
        ..hold = true
        ..failWith = aFails ? _serverError() : null;
      final a = notifier().refresh();
      await _settle();
      between?.call();
      if (bItems != null) backend.items = bItems;
      backend.failWith = bFails ? _serverError() : null;
      final b = notifier().refresh();
      await _settle();
      backend.failWith = null;
      return (a: a, b: b);
    }

    setUp(() => backend = _ListBackend([_garmentJson(1), _garmentJson(2)]));

    test('1. A succeeds, then B succeeds: ends on B', () {
      return run(() async {
        final r = await startAB(bItems: [_garmentJson(9)]);
        await backend.release([0, 1]);
        await Future.wait([r.a, r.b]);

        expect(ids(), [9]);
        expect(state().hasError, isFalse);
      });
    });

    test('2. A fails, then B succeeds: ends on B with no error', () {
      return run(() async {
        final r = await startAB(bItems: [_garmentJson(9)], aFails: true);
        await backend.release([0, 1]);
        await Future.wait([r.a, r.b]);

        expect(ids(), [9]);
        expect(state().hasError, isFalse);
      });
    });

    test(
      "2b. A's failure while B is still in flight isn't shown as an error",
      () {
        return run(() async {
          await startAB(bItems: [_garmentJson(9)], aFails: true);
          final gates = [...backend.held];
          backend.held.clear();
          gates[0].complete(); // A fails; B is still in flight
          await _settle();

          expect(state().hasError, isFalse);
          expect(state().isLoading, isTrue);
          gates[1].complete();
          await _settle();
        });
      },
    );

    test('3. B succeeds, then A fails: ends on B, the late failure is '
        'dropped', () {
      return run(() async {
        final r = await startAB(bItems: [_garmentJson(9)], aFails: true);
        await backend.release([1, 0]);
        await Future.wait([r.a, r.b]);

        expect(ids(), [9]);
        expect(state().hasError, isFalse);
      });
    });

    test("3b. B fails, then A succeeds: A's list is applied — a failure "
        "doesn't advance the applied order, and A's reply is still newer than "
        'what was shown', () {
      return run(() async {
        final r = await startAB(bItems: [_garmentJson(9)], bFails: true);
        await backend.release([1, 0]);
        await Future.wait([r.a, r.b]);

        expect(state().hasError, isFalse);
        expect(ids(), [1, 2], reason: "A's reply (its server snapshot)");
      });
    });

    for (final order in [
      [0, 1],
      [1, 0],
    ]) {
      test('4. A → mutation → B, answered ${order.join('→')}: the mutation '
          'survives', () {
        return run(() async {
          final r = await startAB(
            between: () {
              backend.items[0] = _garmentJson(1, name: 'Renamed');
              notifier().updateGarment(_garment(1, name: 'Renamed'));
            },
          );
          await backend.release(order);
          await Future.wait([r.a, r.b]);

          expect(state().value!.first.name, 'Renamed');
          expect(backend.gets, 3, reason: 'no extra request');
        });
      });
    }

    test('5. several mutations during one refresh replay in order', () {
      return run(() async {
        backend.hold = true;
        final refresh = notifier().refresh();
        await _settle();
        notifier()
          ..updateGarment(_garment(1, name: 'First'))
          ..updateGarment(_garment(1, name: 'Second'))
          ..addGarment(_garment(3))
          ..removeGarment(3)
          ..removeGarment(2)
          ..addGarment(_garment(2, name: 'Back'))
          ..updateFavoriteOptimistically(1, isFavorite: true)
          ..updateFavoriteOptimistically(1, isFavorite: false);
        final local = state().value!;

        await backend.release([0]);
        await refresh;

        expect(ids(), [2, 1]);
        expect(state().value!.map((g) => g.name), ['Back', 'Second']);
        expect(state().value![1].isFavorite, isFalse);
        expect(
          state().value!.map((g) => (g.id, g.name, g.isFavorite)),
          local.map((g) => (g.id, g.name, g.isFavorite)),
          reason: 'the replayed list matches what was shown locally',
        );
      });
    });

    test("6. an old generation's refresh failing after the rebuild doesn't "
        'error the new state', () {
      return run(() async {
        backend
          ..hold = true
          ..failWith = _serverError();
        final old = notifier().refresh();
        await _settle();
        backend
          ..failWith = null
          ..items = [_garmentJson(50)];
        setUpFakeAuth(accessToken: 'account-b');
        container.invalidate(garmentsProvider);
        await _settle();

        await backend.release([1, 0]);
        await old;

        expect(ids(), [50]);
        expect(state().hasError, isFalse);
      });
    });

    test('6b. an edit in the new generation still replays onto its own '
        "refresh while an old generation's fetch is in flight", () {
      return run(() async {
        backend.hold = true;
        final old = notifier().refresh(); // the old generation's
        await _settle();
        backend.items = [_garmentJson(50)];
        container.invalidate(garmentsProvider);
        await _settle();
        final first = [...backend.held]; // [old refresh, new build]
        backend.held.clear();
        first[1].complete();
        await _settle();

        final fresh = notifier().refresh(); // the new generation's
        await _settle();
        notifier().addGarment(_garment(51));
        final second = [...backend.held];
        backend
          ..held.clear()
          ..hold = false;
        second.single.complete();
        await fresh;
        first[0].complete();
        await old;
        await _settle();

        expect(ids(), [51, 50]);
      });
    });

    test("7. each refresh's own Future (what pull-to-refresh awaits) waits "
        'for its own reply', () {
      return run(() async {
        final r = await startAB(bItems: [_garmentJson(9)]);
        var bDone = false;
        unawaited(r.b.then((_) => bDone = true));
        final gates = [...backend.held];
        backend.held.clear();
        gates[0].complete();
        await r.a;
        await _settle();
        expect(bDone, isFalse);

        gates[1].complete();
        await r.b;
      });
    });

    test("7b. A answering first doesn't end the loading state while B is "
        'still in flight', () {
      return run(() async {
        await startAB(bItems: [_garmentJson(9)]);
        final gates = [...backend.held];
        backend.held.clear();
        gates[0].complete();
        await _settle();

        expect(state().isLoading, isTrue);
        gates[1].complete();
        await _settle();
      });
    });

    test("8. a favorite (a field-level edit) keeps the refresh's re-signed "
        'image URL', () {
      return run(() async {
        // The refresh's reply carries a re-signed URL (not yet the favorite).
        backend
          ..items[0] = _garmentJson(1, url: 'https://new/1')
          ..hold = true;
        final refresh = notifier().refresh();
        await _settle();
        notifier().updateFavoriteOptimistically(1, isFavorite: true);

        await backend.release([0]);
        await refresh;

        final g = state().value!.first;
        expect(g.isFavorite, isTrue);
        expect(g.imageUrl, 'https://new/1');
      });
    });

    test("8b. an outfit edit made from an older copy doesn't revert the "
        "refresh's re-signed image URL", () {
      backend = _ListBackend([_groupJson(1, url: 'https://old/1')]);
      return http.runWithClient(() async {
        container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(outfitsProvider, (_, _) {});
        final shown = (await container.read(outfitsProvider.future)).first;
        final outfits = container.read(outfitsProvider.notifier);

        // The old URL expired, so the page re-fetches...
        backend
          ..items = [_groupJson(1, url: 'https://new/1')]
          ..hold = true;
        final refresh = outfits.refresh();
        await _settle();
        // ...while the user favorites the outfit they're looking at.
        outfits.updateOutfitFavorite(shown.id, isFavorite: true);

        await backend.release([0]);
        await refresh;

        final o = container.read(outfitsProvider).value!.single;
        expect(o.isFavorite, isTrue);
        expect(o.imageUrl, 'https://new/1');
      }, () => backend.client);
    });

    test('an optimistic edit made before the refresh started survives a reply '
        'that predates its request, once its PATCH settles', () {
      return run(() async {
        final token = notifier().updateFavoriteOptimistically(
          2,
          isFavorite: true,
        );
        backend.hold = true;
        final refresh = notifier().refresh(); // PATCH not committed yet
        await _settle();
        backend.items[1] = _garmentJson(2, fav: true); // PATCH commits

        await backend.release([0]);
        await refresh;
        notifier().settleFavorite(2, token, isFavorite: true); // its reply

        expect(state().value![1].isFavorite, isTrue);
      });
    });

    test('A and B both fail: ends in error (nothing left to take over)', () {
      return run(() async {
        final r = await startAB(aFails: true, bFails: true);
        await backend.release([0, 1]);
        await Future.wait([r.a, r.b]);

        expect(state().hasError, isTrue);
        expect(state().isLoading, isFalse);
        expect(ids(), [1, 2], reason: 'the error keeps the last list');
      });
    });

    test("A succeeds, then B fails: B's error stands, carrying A's list", () {
      return run(() async {
        backend.items = [_garmentJson(5)]; // what A reads
        final r = await startAB(bFails: true);
        await backend.release([0, 1]);
        await Future.wait([r.a, r.b]);

        expect(state().hasError, isTrue);
        expect(ids(), [5]);
      });
    });

    test("A answering first while B is in flight: A's list shows, still "
        'loading, and refreshIfNeeded sends nothing more', () {
      return run(() async {
        backend.items = []; // A reads an empty closet
        await startAB(bItems: [_garmentJson(9)]);
        final gates = [...backend.held];
        backend.held.clear();
        gates[0].complete();
        await _settle();

        expect(state().value, isEmpty);
        expect(state().isLoading, isTrue);
        final gets = backend.gets;
        await notifier().refreshIfNeeded(); // an empty list would re-fetch
        expect(backend.gets, gets);

        backend.hold = false;
        gates[1].complete();
        await _settle();
        expect(ids(), [9]);
        expect(state().isLoading, isFalse);
      });
    });

    test('an edit during overlapping refreshes shows in A\'s early list and '
        "survives B's", () {
      return run(() async {
        final r = await startAB(
          // A confirmed favorite: on the server before B's request.
          between: () {
            backend.items[0] = _garmentJson(1, fav: true);
            notifier().updateFavoriteOptimistically(1, isFavorite: true);
          },
        );
        final gates = [...backend.held];
        backend.held.clear();
        gates[0].complete();
        await _settle();
        expect(state().value!.first.isFavorite, isTrue);
        expect(state().isLoading, isTrue);

        backend.hold = false;
        notifier().updateGarment(_garment(2, name: 'Renamed'));
        gates[1].complete();
        await Future.wait([r.a, r.b]);
        expect(
          state().value!.first.isFavorite,
          isTrue,
          reason:
              'B started '
              'after the favorite; the server had it',
        );
        expect(state().value![1].name, 'Renamed');
      });
    });

    test("an old generation's success doesn't end the new generation's "
        'first load', () {
      return run(() async {
        backend.hold = true;
        final old = notifier().refresh();
        await _settle();
        container.invalidate(garmentsProvider);
        await _settle();
        final gates = [...backend.held];
        backend.held.clear();

        gates[0].complete(); // the old refresh lands first
        await old;
        await _settle();
        expect(state().isLoading, isTrue);

        backend.hold = false;
        gates[1].complete();
        await _settle();
        expect(state().isLoading, isFalse);
      });
    });
  });

  group('overlapping refreshes (outfitsProvider)', () {
    late _ListBackend backend;
    late ProviderContainer container;

    AsyncValue<List<Object?>> state() => container.read(outfitsProvider);

    Future<void> run(Future<void> Function(OutfitsNotifier n) body) {
      backend = _ListBackend([_groupJson(1), _groupJson(2)]);
      return http.runWithClient(() async {
        container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(outfitsProvider, (_, _) {});
        await container.read(outfitsProvider.future);
        await body(container.read(outfitsProvider.notifier));
      }, () => backend.client);
    }

    Future<List<Completer<void>>> startAB(
      OutfitsNotifier n, {
      bool aFails = false,
    }) async {
      backend
        ..hold = true
        ..failWith = aFails ? _serverError() : null;
      unawaited(n.refresh());
      await _settle();
      backend
        ..failWith = null
        ..items = [_groupJson(9)];
      unawaited(n.refresh());
      await _settle();
      final gates = [...backend.held];
      backend
        ..held.clear()
        ..hold = false;
      return gates;
    }

    test("A's failure while B is in flight isn't shown", () {
      return run((n) async {
        final gates = await startAB(n, aFails: true);
        gates[0].complete();
        await _settle();
        expect(state().hasError, isFalse);
        expect(state().isLoading, isTrue);

        gates[1].complete();
        await _settle();
        expect(state().value!.length, 1);
        expect(state().hasError, isFalse);
      });
    });

    test("A answering first keeps loading until B's reply", () {
      return run((n) async {
        final gates = await startAB(n);
        gates[0].complete();
        await _settle();
        expect(state().isLoading, isTrue);

        gates[1].complete();
        await _settle();
        expect(state().isLoading, isFalse);
      });
    });
  });
}
