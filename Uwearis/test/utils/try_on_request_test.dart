import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/outfit_service.dart';
import 'package:uwearis/core/services/pending_try_on_store.dart';
import 'package:uwearis/core/services/trip_service.dart';
import 'package:uwearis/core/utils/try_on_request.dart';
import 'package:uwearis/data/trip_outfit.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _outfitJson(int id) => {
  'outfit_id': id,
  'group_id': 3,
  'group_type': 'general',
  'status': 'completed',
  'garment_ids': [1, 2],
  'result_image_url': 'https://img.example/$id.jpg',
};

Map<String, dynamic> _tripOutfitJson({int? outfitId, String? image}) => {
  'id': 1,
  'source': 'manual',
  'outfit_id': outfitId,
  'image_outfit_id': outfitId,
  'result_image_url': image,
  'garments': <Object>[],
};

Map<String, dynamic> _collection({int? outfitId, String? image}) => {
  'outfits': [_tripOutfitJson(outfitId: outfitId, image: image)],
  'suitcase_items': <Object>[],
};

http.Response _error(int status, String? code) => jsonResponse({
  'success': false,
  'message': 'x',
  'error_code': code,
  'data': null,
}, status: status);

/// Advances fake time until [future] completes (polling waits between
/// checks).
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
  for (var i = 0; i < 600 && !done; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  expect(done, isTrue, reason: 'never completed');
  if (error != null) throw error!;
  return value;
}

void main() {
  setUp(() {
    setUpFakeAuth();
    SharedPreferences.setMockInitialValues({});
    OutfitService().clearGroupCache();
  });

  Future<List<PendingTryOn>> pending() => PendingTryOnStore.load();

  group('sendKeyedTryOn (regenerate)', () {
    Future<Object?> regenerate(
      WidgetTester tester,
      MockClient client, {
      String key = 'key-0001',
    }) {
      return http.runWithClient(() async {
        try {
          return await drive(
            tester,
            sendKeyedTryOn(
              key: key,
              session: PendingTryOnStore.session,
              regeneratedOutfitId: 5,
              send: () =>
                  OutfitService().regenerateOutfit(3, 5, idempotencyKey: key),
            ),
          );
        } catch (e) {
          return e;
        }
      }, () => client);
    }

    testWidgets('a lost reply is recovered by status, not by sending again', (
      tester,
    ) async {
      var posts = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          throw TimeoutException('slow');
        }
        return jsonResponse(
          envelope({'status': 'succeeded', 'outfit': _outfitJson(5)}),
        );
      });
      final result = await regenerate(tester, client);
      expect((result as dynamic).id, 5);
      expect(posts, 1);
      expect(await pending(), isEmpty);
    });

    testWidgets('no status endpoint: unknown, and the key is kept with its '
        'target', (tester) async {
      final client = MockClient((request) async {
        if (request.method == 'POST') throw TimeoutException('slow');
        return _error(422, null);
      });
      final result = await regenerate(tester, client);
      expect(result, isA<TryOnStillRunning>());
      expect((result as TryOnStillRunning).statusUnavailable, isTrue);
      final kept = (await pending()).single;
      expect(
        (kept.key, kept.kind, kept.regeneratedOutfitId),
        ('key-0001', PendingTryOnKind.keyed, 5),
      );
    });

    testWidgets('a definitive failure is rethrown and forgotten', (
      tester,
    ) async {
      final client = MockClient(
        (_) async => _error(500, 'LOOK_GENERATION_FAILED'),
      );
      final result = await regenerate(tester, client);
      expect((result as ApiException).errorCode, 'LOOK_GENERATION_FAILED');
      expect(await pending(), isEmpty);
    });
  });

  group('trip try-on', () {
    TripOutfit before({int? outfitId, String? image}) =>
        TripOutfit.fromJson(_tripOutfitJson(outfitId: outfitId, image: image));

    test('the image marker follows the stored object, not the signature', () {
      final a = before(outfitId: 9, image: 'https://s.example/a.jpg?sig=1');
      final b = before(outfitId: 9, image: 'https://s.example/a.jpg?sig=2');
      final c = before(outfitId: 9, image: 'https://s.example/b.jpg?sig=1');
      expect(tripOutfitImageMarker(a), tripOutfitImageMarker(b));
      expect(tripOutfitImageMarker(a), isNot(tripOutfitImageMarker(c)));
    });

    Future<Object?> tryOn(
      WidgetTester tester,
      MockClient client,
      TripOutfit outfit,
    ) {
      return http.runWithClient(() async {
        try {
          return await drive(
            tester,
            sendTripTryOn(
              tripId: 7,
              before: outfit,
              session: PendingTryOnStore.session,
              send: () => TripService().tryOnTripOutfit(7, tripOutfitId: 1),
            ),
          );
        } catch (e) {
          return e;
        }
      }, () => client);
    }

    testWidgets('a lost reply is recovered from the trip once its image '
        'changes', (tester) async {
      var posts = 0;
      var reads = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          return _error(504, null);
        }
        reads++;
        return jsonResponse(
          envelope(
            reads < 3
                ? _collection()
                : _collection(outfitId: 9, image: 'https://s.example/n.jpg'),
          ),
        );
      });
      final result = await tryOn(tester, client, before());
      expect(result, isA<TripOutfitCollection>());
      expect(posts, 1);
      expect(await pending(), isEmpty);
    });

    testWidgets('still unchanged at the end: unknown, recorded for relaunch', (
      tester,
    ) async {
      final client = MockClient((request) async {
        if (request.method == 'POST') throw TimeoutException('slow');
        return jsonResponse(envelope(_collection()));
      });
      final result = await tryOn(tester, client, before());
      expect(result, isA<TryOnStillRunning>());
      final kept = (await pending()).single;
      expect(kept.kind, PendingTryOnKind.trip);
      expect((kept.tripId, kept.tripOutfitId), (7, 1));
      expect(kept.imageMarker, tripOutfitImageMarker(before()));
    });

    testWidgets('a definitive failure is rethrown and forgotten', (
      tester,
    ) async {
      final client = MockClient(
        (_) async => _error(422, 'TRIP_OUTFIT_INCOMPLETE'),
      );
      final result = await tryOn(tester, client, before());
      expect((result as ApiException).errorCode, 'TRIP_OUTFIT_INCOMPLETE');
      expect(await pending(), isEmpty);
    });
  });
}
