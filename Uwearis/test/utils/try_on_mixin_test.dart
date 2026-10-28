import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/outfit_service.dart';
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

/// Records every request; [onGenerate] decides each generate's outcome.
class _FakeBackend {
  _FakeBackend(this.onGenerate);

  final Future<http.Response> Function(int call, int groupId) onGenerate;
  final created = <int>[];
  final deleted = <String>[];
  final generateKeys = <String?>[];
  final generateGroups = <int>[];
  List<Map<String, dynamic>> groupOutfits = [];

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
      return onGenerate(generateKeys.length, groupId);
    }
    if (request.method == 'DELETE') {
      deleted.add(path.split('/outfit/').last);
      return jsonResponse(envelope(null));
    }
    if (request.method == 'GET') {
      return jsonResponse(
        envelope({
          'group_id': 0,
          'name': null,
          'cover_outfit_id': null,
          'outfits': groupOutfits,
        }),
      );
    }
    throw StateError('unexpected ${request.method} $path');
  });
}

void main() {
  setUp(() {
    setUpFakeAuth();
    OutfitService().clearGroupCache();
  });

  Future<_HarnessState> pumpHarness(WidgetTester tester) async {
    final key = GlobalKey<_HarnessState>();
    await pumpApp(tester, _Harness(key: key));
    return key.currentState!;
  }

  testWidgets('a retry after a failed generate reuses the draft group and '
      'idempotency key', (tester) async {
    final backend = _FakeBackend(
      (call, groupId) async => call == 1
          ? jsonResponse({'success': false, 'message': 'x'}, status: 500)
          : jsonResponse(envelope(_outfitJson(9, groupId))),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      expect(await state.performTryOn([1, 2]), isNull);
      final outfit = await state.performTryOn([1, 2]);

      expect(outfit?.id, 9);
      expect(backend.created, [100]);
      expect(backend.generateGroups, [100, 100]);
      expect(backend.generateKeys.toSet(), hasLength(1));
      expect(backend.generateKeys.first, isNotNull);
    }, () => backend.client);
  });

  testWidgets('after a timeout, a retry shows the render that landed instead '
      'of generating again', (tester) async {
    final backend = _FakeBackend((call, groupId) async {
      throw TimeoutException('slow');
    });
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      expect(await state.performTryOn([1, 2]), isNull);
      expect(state.tryOnErrorMessage, contains('Create Outfit'));

      backend.groupOutfits = [_outfitJson(9, 100)];
      final Outfit? outfit = await state.performTryOn([1, 2]);

      expect(outfit?.id, 9);
      expect(backend.generateKeys, hasLength(1));
    }, () => backend.client);
  });

  testWidgets('changing the garments after a timeout drops the old draft', (
    tester,
  ) async {
    final backend = _FakeBackend(
      (call, groupId) async => call == 1
          ? throw TimeoutException('slow')
          : jsonResponse(envelope(_outfitJson(9, groupId))),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      await state.performTryOn([1, 2]);
      await state.performTryOn([1, 3]);
      await tester.pump();

      expect(backend.deleted, ['100']);
      expect(backend.generateGroups, [100, 101]);
      expect(backend.generateKeys.toSet(), hasLength(2));
    }, () => backend.client);
  });

  testWidgets('leaving mid-render discards the result once it lands', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final backend = _FakeBackend((call, groupId) => pending.future);
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      final result = state.performTryOn([1, 2]);
      await tester.pump();

      await pumpApp(tester, const SizedBox());
      expect(backend.deleted, isEmpty, reason: 'still rendering');

      pending.complete(jsonResponse(envelope(_outfitJson(9, 100))));
      expect(await result, isNull);
      await tester.pump();
      expect(backend.deleted, ['100']);
    }, () => backend.client);
  });

  testWidgets('leaving after a failure deletes the empty draft', (
    tester,
  ) async {
    final backend = _FakeBackend(
      (call, groupId) async =>
          jsonResponse({'success': false, 'message': 'x'}, status: 500),
    );
    await http.runWithClient(() async {
      final state = await pumpHarness(tester);
      await state.performTryOn([1, 2]);

      await pumpApp(tester, const SizedBox());
      await tester.pump();
      expect(backend.deleted, ['100']);
    }, () => backend.client);
  });
}
