import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/services/outfit_service.dart';
import 'package:uwearis/core/services/pending_try_on_store.dart';
import 'package:uwearis/core/utils/image_cache_bust.dart';
import 'package:uwearis/core/utils/pending_try_on_recovery.dart';
import 'package:uwearis/data/outfit.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

final _now = DateTime(2026, 11, 2, 12);

Map<String, dynamic> _outfit(int id, int groupId) => {
  'outfit_id': id,
  'group_id': groupId,
  'group_type': 'general',
  'status': 'completed',
  'garment_ids': [1, 2],
  'result_image_url': 'https://example.com/$id.jpg',
};

http.Response _statusReply(String status, {Map<String, dynamic>? outfit}) =>
    jsonResponse(
      envelope({
        'idempotency_key': 'k',
        'kind': 'generate',
        'status': status,
        'error_code': status == 'failed' ? 'TRY_ON_GENERATION_EXPIRED' : null,
        'group_id': 100,
        'outfit': outfit,
        'created_at': '2026-11-02T12:00:00',
      }),
    );

http.Response _error(int status, String? code) => jsonResponse({
  'success': false,
  'message': 'x',
  'error_code': code,
  'data': null,
}, status: status);

/// Answers status and group reads; records everything else.
class _Backend {
  _Backend(this.status, {this.trip});

  final Future<http.Response> Function() status;

  /// Answers `GET /trip_plans/{id}/outfits`.
  final Future<http.Response> Function()? trip;
  final groupOutfits = <int, List<Map<String, dynamic>>>{};
  final deleted = <int>[];
  final posts = <String>[];

  late final client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path.contains('/outfit/generations/')) {
      return status();
    }
    if (request.method == 'GET' && path.endsWith('/outfits') && trip != null) {
      return trip!();
    }
    final group = RegExp(r'/outfit/(\d+)$').firstMatch(path);
    if (group != null) {
      final id = int.parse(group.group(1)!);
      if (request.method == 'GET') {
        return jsonResponse(
          envelope({
            'group_id': id,
            'outfits': groupOutfits[id] ?? <Map<String, dynamic>>[],
          }),
        );
      }
      if (request.method == 'DELETE') {
        deleted.add(id);
        return jsonResponse(envelope(null));
      }
    }
    posts.add('${request.method} $path');
    throw StateError('unexpected ${request.method} $path');
  });
}

void main() {
  setUp(() {
    setUpFakeAuth();
    SharedPreferences.setMockInitialValues({});
    OutfitService().clearGroupCache();
  });

  Future<void> remember({
    String key = 'k1',
    int? draft = 100,
    Duration age = const Duration(minutes: 3),
  }) => PendingTryOnStore.add(
    PendingTryOn(key: key, draftGroupId: draft, startedAt: _now.subtract(age)),
    forSession: PendingTryOnStore.session,
  );

  Future<List<String>> keys() async =>
      (await PendingTryOnStore.load()).map((p) => p.key).toList();

  Future<int> recover(_Backend backend) async => (await http.runWithClient(
    () => recoverPendingTryOns(now: _now),
    () => backend.client,
  )).outfitsLanded;

  test('succeeded: reported, then forgotten', () async {
    await remember();
    final backend = _Backend(
      () async => _statusReply('succeeded', outfit: _outfit(9, 100)),
    );
    expect(await recover(backend), 1);
    expect(await keys(), isEmpty);
    expect(backend.deleted, isEmpty);
  });

  test('failed: forgotten and its empty draft deleted', () async {
    await remember();
    final backend = _Backend(() async => _statusReply('failed'));
    expect(await recover(backend), 0);
    expect(await keys(), isEmpty);
    expect(backend.deleted, [100]);
  });

  test('failed but the draft holds an outfit: the draft is kept', () async {
    await remember();
    final backend = _Backend(() async => _statusReply('failed'))
      ..groupOutfits[100] = [_outfit(3, 100)];
    await recover(backend);
    expect(backend.deleted, isEmpty);
  });

  test('still processing: kept', () async {
    await remember();
    expect(await recover(_Backend(() async => _statusReply('processing'))), 0);
    expect(await keys(), ['k1']);
  });

  test('never received: kept while young, then dropped with its empty '
      'draft', () async {
    await remember(key: 'young', age: const Duration(seconds: 30));
    await remember(key: 'old', draft: 200, age: const Duration(minutes: 5));
    final backend = _Backend(
      () async => _error(404, 'TRY_ON_GENERATION_NOT_FOUND'),
    );
    await recover(backend);
    expect(await keys(), ['young']);
    expect(backend.deleted, [200]);
  });

  group('a backend without the status endpoint', () {
    _Backend old() => _Backend(() async => _error(422, null));

    test('reports a render that landed in the draft', () async {
      await remember();
      final backend = old()..groupOutfits[100] = [_outfit(9, 100)];
      expect(await recover(backend), 1);
      expect(await keys(), isEmpty);
    });

    test('keeps an empty draft and the key — nothing deleted', () async {
      await remember();
      final backend = old();
      expect(await recover(backend), 0);
      expect(await keys(), ['k1']);
      expect(backend.deleted, isEmpty);
    });

    test('a 404 without the error code also means "can\'t check"', () async {
      await remember();
      final backend = _Backend(() async => _error(404, null));
      await recover(backend);
      expect(await keys(), ['k1']);
      expect(backend.deleted, isEmpty);
    });
  });

  test('offline: kept, nothing deleted', () async {
    await remember();
    final backend = _Backend(() async => throw const SocketException('down'));
    expect(await recover(backend), 0);
    expect(await keys(), ['k1']);
    expect(backend.deleted, isEmpty);
  });

  test('older than the store\'s limit: dropped without any request', () async {
    await remember(age: const Duration(hours: 1));
    var asked = false;
    final backend = _Backend(() async {
      asked = true;
      return _statusReply('processing');
    });
    await recover(backend);
    expect(asked, isFalse);
    expect(await keys(), isEmpty);
    expect(backend.deleted, isEmpty);
  });

  test('a key this process is still waiting on is left alone', () async {
    await remember();
    PendingTryOnStore.markInFlight('k1');
    addTearDown(() => PendingTryOnStore.unmarkInFlight('k1'));
    var asked = false;
    await recover(
      _Backend(() async {
        asked = true;
        return _statusReply('failed');
      }),
    );
    expect(asked, isFalse);
    expect(await keys(), ['k1']);
  });

  test('never sends a generate, whatever the status', () async {
    for (final reply in [
      () async => _statusReply('failed'),
      () async => _error(422, null),
      () async => _error(503, null),
    ]) {
      await remember();
      final backend = _Backend(reply);
      await recover(backend);
      expect(backend.posts, isEmpty);
    }
  });

  test('cleared at sign-out', () async {
    await remember();
    await PendingTryOnStore.clear();
    expect(await keys(), isEmpty);
  });

  group('across a sign-out', () {
    test('a status reply that lands after it changes nothing', () async {
      for (final reply in ['succeeded', 'failed']) {
        await remember();
        final gate = Completer<http.Response>();
        final backend = _Backend(() => gate.future);
        final result = recover(backend);
        await Future<void>.delayed(Duration.zero);
        await PendingTryOnStore.clear(); // sign-out mid-check
        await remember(); // the next account's own pending entry
        gate.complete(_statusReply(reply, outfit: _outfit(9, 100)));
        expect(await result, 0);
        expect(await keys(), ['k1']);
        expect(backend.deleted, isEmpty);
      }
    });

    test("a write that started before it can't bring entries back", () async {
      final before = PendingTryOnStore.session;
      final write = PendingTryOnStore.add(
        PendingTryOn(key: 'old', draftGroupId: 1, startedAt: _now),
        forSession: before,
      );
      await PendingTryOnStore.clear();
      await write;
      expect(await keys(), isEmpty);

      await PendingTryOnStore.add(
        PendingTryOn(key: 'stale', draftGroupId: 1, startedAt: _now),
        forSession: before,
      );
      expect(await keys(), isEmpty);
    });
  });

  group('a regenerate', () {
    test('that landed refreshes its image', () async {
      await PendingTryOnStore.add(
        PendingTryOn(
          key: 'regen',
          regeneratedOutfitId: 5,
          startedAt: _now.subtract(const Duration(minutes: 3)),
        ),
        forSession: PendingTryOnStore.session,
      );
      final before = ImageCacheBust.versionOf(outfitImageCacheKey(5));
      final backend = _Backend(
        () async => _statusReply('succeeded', outfit: _outfit(5, 3)),
      );
      expect(await recover(backend), 1);
      expect(ImageCacheBust.versionOf(outfitImageCacheKey(5)), before + 1);
      expect(await keys(), isEmpty);
    });

    test('without a status endpoint it waits (no draft to check)', () async {
      await PendingTryOnStore.add(
        PendingTryOn(
          key: 'regen',
          regeneratedOutfitId: 5,
          startedAt: _now.subtract(const Duration(minutes: 3)),
        ),
        forSession: PendingTryOnStore.session,
      );
      expect(await recover(_Backend(() async => _error(422, null))), 0);
      expect(await keys(), ['regen']);
    });
  });

  group('a trip try-on', () {
    Map<String, dynamic> collection({int? outfitId, String? image}) => {
      'outfits': [
        {
          'id': 1,
          'source': 'manual',
          'outfit_id': outfitId,
          'result_image_url': image,
        },
      ],
      'suitcase_items': <Object>[],
    };

    Future<void> rememberTrip() => PendingTryOnStore.add(
      PendingTryOn(
        key: 'trip-1',
        kind: PendingTryOnKind.trip,
        tripId: 7,
        tripOutfitId: 1,
        imageMarker: 'null|',
        startedAt: _now.subtract(const Duration(minutes: 3)),
      ),
      forSession: PendingTryOnStore.session,
    );

    Future<TryOnRecovery> recoverAll(_Backend backend) => http.runWithClient(
      () => recoverPendingTryOns(now: _now),
      () => backend.client,
    );

    test('whose image changed is reported with the trip\'s outfits', () async {
      await rememberTrip();
      final found = await recoverAll(
        _Backend(
          () async => _error(500, null),
          trip: () async => jsonResponse(
            envelope(collection(outfitId: 9, image: 'https://s.example/n.jpg')),
          ),
        ),
      );
      expect(found.trips.keys, [7]);
      expect(found.trips[7]!.outfits.single.outfitId, 9);
      expect(await keys(), isEmpty);
    });

    test('still unchanged is kept; never re-sent', () async {
      await rememberTrip();
      final backend = _Backend(
        () async => _error(500, null),
        trip: () async => jsonResponse(envelope(collection())),
      );
      final found = await recoverAll(backend);
      expect(found.trips, isEmpty);
      expect(await keys(), ['trip-1']);
      expect(backend.posts, isEmpty);
    });

    test('of a deleted trip is dropped', () async {
      await rememberTrip();
      await recoverAll(
        _Backend(
          () async => _error(500, null),
          trip: () async => _error(404, 'TRIP_PLAN_NOT_FOUND'),
        ),
      );
      expect(await keys(), isEmpty);
    });
  });

  test('an entry saved before kinds existed loads as a keyed generate', () {
    final p = PendingTryOn.fromJson({
      'key': 'k',
      'draft_group_id': 100,
      'started_at': '2026-11-02T12:00:00',
    })!;
    expect((p.kind, p.draftGroupId), (PendingTryOnKind.keyed, 100));
  });
}
