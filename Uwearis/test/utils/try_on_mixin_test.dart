import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/services/outfit_service.dart';
import 'package:uwearis/core/services/pending_try_on_store.dart';
import 'package:uwearis/core/utils/try_on_mixin.dart';
import 'package:uwearis/data/outfit.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

class _Harness extends StatefulWidget {
  const _Harness({super.key});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TryOnMixin {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

Map<String, dynamic> _outfitJson(int outfitId, int groupId) => {
  'outfit_id': outfitId,
  'group_id': groupId,
  'group_type': 'general',
  'status': 'completed',
  'name': null,
  'garment_ids': [1, 2],
  'result_image_url': 'https://example.com/$outfitId.jpg',
  'season': <String>[],
  'style': <String>[],
  'is_favorite': false,
};

http.Response _error(int status, String? code) => jsonResponse({
  'success': false,
  'message': 'x',
  'error_code': code,
  'data': null,
}, status: status);

/// Records every request. [onGenerate] decides each generate's outcome;
/// [onStatus] answers `GET /outfit/generations/{key}` (default: unknown key).
class _FakeBackend {
  _FakeBackend(this.onGenerate, {this.onStatus});

  final Future<http.Response> Function(int call, int groupId) onGenerate;
  Future<http.Response> Function(int call, String key)? onStatus;
  final created = <int>[];
  final deleted = <String>[];
  final generateKeys = <String?>[];
  final generateGroups = <int>[];
  final generateHeaders = <Map<String, String>>[];
  final statusKeys = <String>[];
  final groupReads = <int>[];
  // What GET /outfit/{group_id} lists, per group.
  final groupOutfits = <int, List<Map<String, dynamic>>>{};

  late final client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/outfit')) {
      final id = 100 + created.length;
      created.add(id);
      return jsonResponse(envelope({'group_id': id, 'type': 'general'}));
    }
    if (request.method == 'POST' && path.endsWith('/generate')) {
      final groupId = int.parse(request.url.pathSegments.reversed.elementAt(1));
      generateGroups.add(groupId);
      generateKeys.add(request.headers['Idempotency-Key']);
      generateHeaders.add(request.headers);
      return onGenerate(generateKeys.length, groupId);
    }
    if (request.method == 'GET' && path.contains('/outfit/generations/')) {
      final key = request.url.pathSegments.last;
      statusKeys.add(key);
      final respond = onStatus;
      if (respond == null) return _error(404, 'TRY_ON_GENERATION_NOT_FOUND');
      return respond(statusKeys.length, key);
    }
    final groupRead = RegExp(r'/outfit/(\d+)$').firstMatch(path);
    if (request.method == 'GET' && groupRead != null) {
      final id = int.parse(groupRead.group(1)!);
      groupReads.add(id);
      return jsonResponse(
        envelope({
          'group_id': id,
          'name': null,
          'cover_outfit_id': null,
          'outfits': groupOutfits[id] ?? <Map<String, dynamic>>[],
        }),
      );
    }
    if (request.method == 'DELETE') {
      deleted.add(path.split('/outfit/').last);
      return jsonResponse(envelope(null));
    }
    throw StateError('unexpected ${request.method} $path');
  });
}

http.Response _status(
  String status, {
  Map<String, dynamic>? outfit,
  String? errorCode,
}) => jsonResponse(
  envelope({
    'idempotency_key': 'k',
    'kind': 'generate',
    'status': status,
    'error_code': errorCode,
    'group_id': 100,
    'outfit': outfit,
    'created_at': '2026-11-02T12:00:00',
    'finished_at': null,
  }),
);

void main() {
  setUp(() {
    setUpFakeAuth();
    SharedPreferences.setMockInitialValues({});
    OutfitService().clearGroupCache();
  });

  Future<_HarnessState> pumpHarness(WidgetTester tester) async {
    final key = GlobalKey<_HarnessState>();
    await pumpApp(tester, _Harness(key: key));
    return key.currentState!;
  }

  /// Advances fake time until [future] completes (status polling waits
  /// between checks).
  Future<T> drive<T>(WidgetTester tester, Future<T> future) async {
    var done = false;
    late T value;
    Object? error;
    future.then(
      (v) {
        value = v;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    for (var i = 0; i < 400 && !done; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(done, isTrue, reason: 'future never completed');
    if (error != null) throw error!;
    return value;
  }

  testWidgets('a definitive failure is retried in the same draft with a new '
      'idempotency key', (tester) async {
    final backend = _FakeBackend(
      (call, groupId) async => call == 1
          ? _error(500, 'LOOK_GENERATION_FAILED')
          : jsonResponse(envelope(_outfitJson(9, groupId))),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      expect(await state.performTryOn([1, 2]), isNull);
      final outfit = await state.performTryOn([1, 2]);

      expect(outfit?.id, 9);
      expect(backend.created, [100]);
      expect(backend.generateGroups, [100, 100]);
      expect(backend.generateKeys.toSet(), hasLength(2));
      expect(backend.statusKeys, isEmpty);
    }, () => backend.client);
  });

  testWidgets('a lost reply is recovered by status, not by rendering again', (
    tester,
  ) async {
    final backend = _FakeBackend(
      (call, groupId) async => throw TimeoutException('slow'),
      onStatus: (call, key) async => call < 3
          ? _status('processing')
          : _status('succeeded', outfit: _outfitJson(9, 100)),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      final outfit = await drive(tester, state.performTryOn([1, 2]));

      expect(outfit?.id, 9);
      expect(backend.generateKeys, hasLength(1));
      expect(backend.statusKeys.toSet(), {backend.generateKeys.single});
      expect(state.tryOnErrorMessage, isNull);
    }, () => backend.client);
  });

  testWidgets(
    'a gateway timeout and "in progress" are both checked by status',
    (tester) async {
      for (final reply in [
        _error(504, null),
        _error(409, 'TRY_ON_GENERATION_IN_PROGRESS'),
      ]) {
        final backend = _FakeBackend(
          (call, groupId) async => reply,
          onStatus: (call, key) async =>
              _status('succeeded', outfit: _outfitJson(9, 100)),
        );
        await http.runWithClient(() async {
          final state = await pumpHarness(tester);
          expect((await drive(tester, state.performTryOn([1, 2])))?.id, 9);
          expect(backend.generateKeys, hasLength(1));
        }, () => backend.client);
      }
    },
  );

  testWidgets('still running when the window closes: the retry reuses the key '
      'and gets the finished render', (tester) async {
    final backend = _FakeBackend(
      (call, groupId) async => call == 1
          ? throw TimeoutException('slow')
          : jsonResponse(envelope(_outfitJson(9, groupId))),
      onStatus: (call, key) async => _status('processing'),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      expect(await drive(tester, state.performTryOn([1, 2])), isNull);
      expect(state.tryOnErrorMessage, contains('Create Outfit'));

      final outfit = await drive(tester, state.performTryOn([1, 2]));
      expect(outfit?.id, 9);
      expect(backend.generateKeys.toSet(), hasLength(1));
      expect(backend.generateGroups, [100, 100]);
    }, () => backend.client);
  });

  testWidgets('a render that failed while unanswered is final: not-counted '
      'message, new key next time', (tester) async {
    final backend = _FakeBackend(
      (call, groupId) async => call == 1
          ? throw TimeoutException('slow')
          : jsonResponse(envelope(_outfitJson(9, groupId))),
      onStatus: (call, key) async =>
          _status('failed', errorCode: 'TRY_ON_GENERATION_EXPIRED'),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      expect(await drive(tester, state.performTryOn([1, 2])), isNull);
      expect(state.tryOnErrorMessage, contains("wasn't counted"));

      await state.performTryOn([1, 2]);
      expect(backend.generateKeys.toSet(), hasLength(2));
    }, () => backend.client);
  });

  testWidgets('a request that never reached the server fails without '
      'waiting', (tester) async {
    final backend = _FakeBackend((call, groupId) async {
      throw http.ClientException('connection reset');
    });
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      expect(await drive(tester, state.performTryOn([1, 2])), isNull);
      expect(backend.statusKeys, hasLength(1));
      expect(state.tryOnErrorMessage, 'Failed to generate outfit');
    }, () => backend.client);
  });

  testWidgets('a backend without the status endpoint (rolled back) leaves the '
      'outcome unknown: draft kept, key kept', (tester) async {
    final backend = _FakeBackend(
      (call, groupId) async => throw TimeoutException('slow'),
      // An older backend routes /outfit/generations/{key} to
      // /{group_id}/{outfit_id} and fails validation.
      onStatus: (call, key) async => _error(422, null),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      expect(await drive(tester, state.performTryOn([1, 2])), isNull);
      expect(backend.statusKeys, hasLength(1));
      expect(state.tryOnErrorMessage, contains("couldn't confirm"));

      await pumpApp(tester, const SizedBox());
      await tester.pump();
      expect(backend.deleted, isEmpty);
    }, () => backend.client);
  });

  testWidgets('leaving mid-render keeps the render and reports it', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final backend = _FakeBackend((call, groupId) => pending.future);
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      Outfit? landed;
      final result = state.performTryOn([
        1,
        2,
      ], onLandedAfterLeave: (o) => landed = o);
      await tester.pump();

      await pumpApp(tester, const SizedBox());
      pending.complete(jsonResponse(envelope(_outfitJson(9, 100))));
      expect(await result, isNull);
      await tester.pump();

      expect(landed?.id, 9);
      expect(backend.deleted, isEmpty);
    }, () => backend.client);
  });

  testWidgets('leaving while the outcome is unknown keeps the draft', (
    tester,
  ) async {
    final backend = _FakeBackend(
      (call, groupId) async => throw TimeoutException('slow'),
      onStatus: (call, key) async => _status('processing'),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      await drive(tester, state.performTryOn([1, 2]));

      await pumpApp(tester, const SizedBox());
      await tester.pump();
      expect(backend.deleted, isEmpty);
    }, () => backend.client);
  });

  testWidgets('leaving after a definitive failure deletes the empty draft', (
    tester,
  ) async {
    final backend = _FakeBackend(
      (call, groupId) async => _error(500, 'LOOK_GENERATION_FAILED'),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      await state.performTryOn([1, 2]);

      await pumpApp(tester, const SizedBox());
      await tester.pump();
      expect(backend.deleted, ['100']);
    }, () => backend.client);
  });

  testWidgets('changing the garments while a render may still land starts a '
      'new draft without deleting the old one', (tester) async {
    final backend = _FakeBackend(
      (call, groupId) async => call == 1
          ? throw TimeoutException('slow')
          : jsonResponse(envelope(_outfitJson(9, groupId))),
      onStatus: (call, key) async => _status('processing'),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      await drive(tester, state.performTryOn([1, 2]));
      await state.performTryOn([1, 3]);
      await tester.pump();

      expect(backend.deleted, isEmpty);
      expect(backend.generateGroups, [100, 101]);
      expect(backend.generateKeys.toSet(), hasLength(2));
    }, () => backend.client);
  });

  group('when the backend can\'t report status (current backend)', () {
    _FakeBackend unreportable({int failFirst = 1}) => _FakeBackend(
      (call, groupId) async => call <= failFirst
          ? throw TimeoutException('slow')
          : jsonResponse(envelope(_outfitJson(9, groupId))),
      onStatus: (call, key) async => _error(422, null),
    );

    testWidgets('a retry shows the render that landed in the draft, without '
        'another request', (tester) async {
      final backend = unreportable();
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        await drive(tester, state.performTryOn([1, 2]));
        backend.groupOutfits[100] = [_outfitJson(9, 100)];

        var asked = false;
        final outfit = await drive(
          tester,
          state.performTryOn([
            1,
            2,
          ], confirmRetryWhileUnknown: () async => asked = true),
        );
        expect(outfit?.id, 9);
        expect(asked, isFalse);
        expect(backend.generateKeys, hasLength(1));
      }, () => backend.client);
    });

    testWidgets('with nothing landed, a retry asks first and sends nothing '
        'when declined', (tester) async {
      final backend = unreportable();
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        await drive(tester, state.performTryOn([1, 2]));

        var asked = 0;
        final declined = await drive(
          tester,
          state.performTryOn(
            [1, 2],
            confirmRetryWhileUnknown: () async {
              asked++;
              return false;
            },
          ),
        );
        expect(declined, isNull);
        expect(asked, 1);
        expect(state.isOutfitLoading, isFalse);
        expect(state.tryOnErrorMessage, isNull);
        expect(backend.generateKeys, hasLength(1));

        // No callback at all is a decline too.
        await drive(tester, state.performTryOn([1, 2]));
        expect(backend.generateKeys, hasLength(1));
      }, () => backend.client);
    });

    testWidgets('a confirmed retry is a new intent in a new draft; the old '
        'draft is kept for its late render', (tester) async {
      final backend = unreportable();
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        await drive(tester, state.performTryOn([1, 2]));
        final outfit = await drive(
          tester,
          state.performTryOn([
            1,
            2,
          ], confirmRetryWhileUnknown: () async => true),
        );
        await tester.pump();

        expect(outfit?.id, 9);
        expect(backend.generateGroups, [100, 101]);
        expect(backend.generateKeys.toSet(), hasLength(2));
        expect(backend.deleted, isEmpty);
      }, () => backend.client);
    });
  });

  group('pending key (relaunch recovery)', () {
    testWidgets('kept while the outcome is unknown, cleared once known', (
      tester,
    ) async {
      final backend = _FakeBackend(
        (call, groupId) async => call == 1
            ? throw TimeoutException('slow')
            : call == 2
            ? jsonResponse(envelope(_outfitJson(9, groupId)))
            : _error(500, 'LOOK_GENERATION_FAILED'),
        onStatus: (call, key) async => _status('processing'),
      );
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        await drive(tester, state.performTryOn([1, 2]));
        final unknown = await PendingTryOnStore.load();
        expect(unknown.map((p) => p.key), [backend.generateKeys.single]);
        expect(unknown.single.draftGroupId, 100);

        await drive(tester, state.performTryOn([1, 2]));
        expect(await PendingTryOnStore.load(), isEmpty);

        await state.performTryOn([1, 3]);
        expect(await PendingTryOnStore.load(), isEmpty);
      }, () => backend.client);
    });

    testWidgets('a version (existing group) is recorded without a draft', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      final backend = _FakeBackend((call, groupId) => pending.future);
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        final result = state.performTryOn([1, 2], groupId: 55);
        await tester.pump();
        final recorded = await PendingTryOnStore.load();
        expect(recorded.single.draftGroupId, isNull);
        expect(PendingTryOnStore.isInFlight(recorded.single.key), isTrue);

        pending.complete(jsonResponse(envelope(_outfitJson(9, 55))));
        await result;
        expect(PendingTryOnStore.isInFlight(recorded.single.key), isFalse);
      }, () => backend.client);
    });
  });

  testWidgets('every generate carries the try-on protocol header', (
    tester,
  ) async {
    final backend = _FakeBackend(
      (call, groupId) async => jsonResponse(envelope(_outfitJson(9, groupId))),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      await state.performTryOn([1, 2]);
      expect(backend.generateHeaders.single['X-Try-On-Protocol'], '2');
    }, () => backend.client);
  });

  group('across a sign-out', () {
    testWidgets('a render landing afterwards reports nothing and stores '
        'nothing', (tester) async {
      final pending = Completer<http.Response>();
      final backend = _FakeBackend((call, groupId) => pending.future);
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        Outfit? landed;
        final result = state.performTryOn([
          1,
          2,
        ], onLandedAfterLeave: (o) => landed = o);
        await tester.pump();
        await pumpApp(tester, const SizedBox());
        await PendingTryOnStore.clear();

        pending.complete(jsonResponse(envelope(_outfitJson(9, 100))));
        await result;
        expect(landed, isNull);
        expect(await PendingTryOnStore.load(), isEmpty);
      }, () => backend.client);
    });

    testWidgets('a failure landing afterwards deletes nothing', (tester) async {
      final pending = Completer<http.Response>();
      final backend = _FakeBackend((call, groupId) => pending.future);
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        final result = state.performTryOn([1, 2]);
        await tester.pump();
        await pumpApp(tester, const SizedBox());
        await PendingTryOnStore.clear();

        pending.complete(_error(500, 'LOOK_GENERATION_FAILED'));
        await result;
        await tester.pump();
        expect(backend.deleted, isEmpty);
      }, () => backend.client);
    });

    testWidgets('polling stops instead of asking with the next account', (
      tester,
    ) async {
      final backend = _FakeBackend(
        (call, groupId) async => throw TimeoutException('slow'),
        onStatus: (call, key) async => _status('processing'),
      );
      await http.runWithClient(() async {
        final state = await pumpHarness(tester);
        final result = state.performTryOn([1, 2]);
        await tester.pump(const Duration(seconds: 4));
        final checksBefore = backend.statusKeys.length;
        expect(checksBefore, greaterThan(0));

        await PendingTryOnStore.clear();
        await drive(tester, result);
        expect(backend.statusKeys.length, lessThanOrEqualTo(checksBefore + 1));
        expect(backend.deleted, isEmpty);
      }, () => backend.client);
    });
  });
}
