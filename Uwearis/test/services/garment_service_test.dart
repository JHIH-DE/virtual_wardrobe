import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/data/garment.dart';

import '../helpers/fake_auth.dart';

const _base = 'http://10.0.2.2:8000/api/v1/garments';

http.Response _jsonResponse(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _envelope(Object? data) => {
  'success': true,
  'message': 'ok',
  'data': data,
  'error_code': null,
};

Map<String, dynamic> _garmentJson(int id, {String imageUrl = ''}) => {
  'id': id,
  'garment_id': id,
  'name': 'Garment $id',
  'category': 'Top',
  'sub_category': 'Tee',
  'upload_url': '',
  'object_name': '',
  'image_url': imageUrl,
};

/// A GCS V4 signed URL whose X-Goog-Date/X-Goog-Expires already lapsed
/// (year 2020, 60s expiry) — see isSignedUrlExpired.
const _expiredSignedUrl =
    'https://storage.googleapis.com/x.jpg'
    '?X-Goog-Date=20200101T000000Z&X-Goog-Expires=60';

/// Signed just now with a long expiry — not stale.
String _freshSignedUrl() {
  final now = DateTime.now().toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}'
      'T${two(now.hour)}${two(now.minute)}${two(now.second)}Z';
  return 'https://storage.googleapis.com/x.jpg'
      '?X-Goog-Date=$stamp&X-Goog-Expires=3600';
}

void main() {
  // GarmentService is a singleton with an in-memory cache — every test
  // below uses its own garment id so cache entries from earlier tests in
  // this file never leak into a later one's expectations.
  setUp(setUpFakeAuth);

  group('initUpload / completeUpload', () {
    test('initUpload POSTs the content_type and returns upload details', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'upload_url': 'https://up.example.com', 'object_name': 'g/1.jpg'}),
        );
      });

      final result = await http.runWithClient(
        () => GarmentService().initUpload(),
        () => client,
      );

      expect(captured.url.toString(), '$_base/init-upload');
      expect(jsonDecode(captured.body), {'content_type': 'image/jpeg'});
      expect(result.uploadUrl, 'https://up.example.com');
    });

    test('completeUpload sends the garment fields and date-only purchase_date', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_garmentJson(101)));
      });

      final garment = Garment(
        name: 'Navy Blazer',
        category: GarmentCategory.outer,
        subCategory: 'Blazer',
        uploadUrl: '',
        objectName: 'g/101.jpg',
        purchaseDate: DateTime(2025, 3, 14, 9, 30),
      );

      final result = await http.runWithClient(
        () => GarmentService().completeUpload(garment, {'note': 'x'}),
        () => client,
      );

      expect(result.id, 101);
      expect(captured.url.toString(), '$_base/complete');
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['name'], 'Navy Blazer');
      expect(payload['category'], 'Outer');
      expect(payload['object_name'], 'g/101.jpg');
      expect(payload['purchase_date'], '2025-03-14');
      expect(payload['metadata'], {'note': 'x'});
    });
  });

  group('getGarments', () {
    test('GETs the base list and populates the cache for getGarment to reuse', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope([_garmentJson(201), _garmentJson(202)]),
        ),
      );

      final garments = await http.runWithClient(
        () => GarmentService().getGarments(),
        () => client,
      );
      expect(garments, hasLength(2));

      // getGarment(201) should now be served from the cache this populated
      // — a client that always throws proves no network call happens.
      final throwingClient = MockClient((request) async {
        throw StateError('should not hit the network for a cached garment');
      });
      final cached = await http.runWithClient(
        () => GarmentService().getGarment(201),
        () => throwingClient,
      );
      expect(cached.name, 'Garment 201');
    });
  });

  group('getGarment caching', () {
    test('fetches over the network on a cold cache', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return _jsonResponse(_envelope(_garmentJson(301)));
      });

      final garment = await http.runWithClient(
        () => GarmentService().getGarment(301),
        () => client,
      );

      expect(garment.id, 301);
      expect(requestCount, 1);
    });

    test('re-fetches when the cached image URL is a stale signed URL', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        // First response: expired signed URL, so the cache entry it
        // creates should immediately be treated as stale next time.
        // Second response: fresh.
        return _jsonResponse(
          _envelope(
            _garmentJson(
              302,
              imageUrl: requestCount == 1 ? _expiredSignedUrl : _freshSignedUrl(),
            ),
          ),
        );
      });

      await http.runWithClient(
        () => GarmentService().getGarment(302),
        () => client,
      );
      expect(requestCount, 1);

      // Cached entry has an expired signed URL -> must hit the network again.
      await http.runWithClient(
        () => GarmentService().getGarment(302),
        () => client,
      );
      expect(requestCount, 2);

      // Now cached with a fresh URL -> should be served from cache.
      final throwingClient = MockClient((request) async {
        throw StateError('should not hit the network for a fresh cache entry');
      });
      await http.runWithClient(
        () => GarmentService().getGarment(302),
        () => throwingClient,
      );
    });
  });

  group('deleteGarment', () {
    test('treats 200/204/404 all as success', () async {
      for (final status in [200, 204, 404]) {
        final id = 400 + status;
        final client = MockClient(
          (request) async => http.Response('', status),
        );
        await http.runWithClient(
          () => GarmentService().deleteGarment(id),
          () => client,
        );
      }
    });

    test('throws for any other status code', () async {
      final client = MockClient((request) async => http.Response('', 500));
      await expectLater(
        http.runWithClient(
          () => GarmentService().deleteGarment(500),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // Behavior 5: a non-401/404 failure keeps its original shape — a plain
    // Exception the page surfaces as an inline error, never AuthExpiredException.
    test('a 500 throws a plain Exception, not AuthExpiredException', () async {
      final client = MockClient((request) async => http.Response('', 500));
      await expectLater(
        http.runWithClient(
          () => GarmentService().deleteGarment(511),
          () => client,
        ),
        throwsA(allOf(isA<Exception>(), isNot(isA<AuthExpiredException>()))),
      );
    });

    // Behavior 3: a transient 401 that a silent token refresh fixes must
    // resolve invisibly — the retried DELETE succeeds and nothing throws.
    test('recovers when the first 401 is cleared by a token refresh', () async {
      var deleteAttempts = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse(_envelope({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          }));
        }
        deleteAttempts++;
        return http.Response('', deleteAttempts == 1 ? 401 : 200);
      });

      await http.runWithClient(
        () => GarmentService().deleteGarment(601),
        () => client,
      );

      expect(deleteAttempts, 2);
    });

    // Behavior 4: the bug this fix targets. When the post-refresh retry still
    // 401s, deleteGarment must surface AuthExpiredException so the page's
    // `on AuthExpiredException` path (session-expired dialog + redirect) runs,
    // not the generic "delete failed" fallback.
    test('throws AuthExpiredException when the retry after refresh still 401s', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse(_envelope({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          }));
        }
        return http.Response('', 401);
      });

      await expectLater(
        http.runWithClient(
          () => GarmentService().deleteGarment(602),
          () => client,
        ),
        throwsA(isA<AuthExpiredException>()),
      );
    });

    // Behavior 6: a successful delete evicts the garment from the cache so a
    // later getGarment goes back to the network.
    test('a successful delete evicts the garment from the cache', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(604),
        () => MockClient(
          (request) async => _jsonResponse(_envelope(_garmentJson(604))),
        ),
      );

      await http.runWithClient(
        () => GarmentService().deleteGarment(604),
        () => MockClient((request) async => http.Response('', 200)),
      );

      var refetched = 0;
      await http.runWithClient(
        () => GarmentService().getGarment(604),
        () => MockClient((request) async {
          refetched++;
          return _jsonResponse(_envelope(_garmentJson(604)));
        }),
      );
      expect(refetched, 1);
    });

    // Behavior 2: a 404 is treated as an idempotent success — no throw, and
    // the cache is evicted just like a 200.
    test('a 404 is an idempotent success and still evicts the cache', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(606),
        () => MockClient(
          (request) async => _jsonResponse(_envelope(_garmentJson(606))),
        ),
      );

      await http.runWithClient(
        () => GarmentService().deleteGarment(606),
        () => MockClient((request) async => http.Response('', 404)),
      );

      var refetched = 0;
      await http.runWithClient(
        () => GarmentService().getGarment(606),
        () => MockClient((request) async {
          refetched++;
          return _jsonResponse(_envelope(_garmentJson(606)));
        }),
      );
      expect(refetched, 1);
    });

    // Behavior 7: a failed delete must NOT evict the cache entry — the garment
    // still exists on the server, so the cached copy stays valid.
    test('a failed delete leaves the cache entry intact', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(605),
        () => MockClient(
          (request) async => _jsonResponse(_envelope(_garmentJson(605))),
        ),
      );

      await expectLater(
        http.runWithClient(
          () => GarmentService().deleteGarment(605),
          () => MockClient((request) async => http.Response('', 500)),
        ),
        throwsA(isA<Exception>()),
      );

      // A throwing client proves the entry is still served from cache.
      final cached = await http.runWithClient(
        () => GarmentService().getGarment(605),
        () => MockClient((request) async {
          throw StateError('should not hit the network for a cached garment');
        }),
      );
      expect(cached.id, 605);
    });
  });

  group('updateGarment', () {
    test('throws immediately when the garment has no id, without a network call', () async {
      final client = MockClient((request) async {
        throw StateError('should not attempt a request without an id');
      });

      final garment = Garment(
        name: 'No Id',
        category: GarmentCategory.top,
        subCategory: '',
        uploadUrl: '',
        objectName: '',
      );

      await expectLater(
        http.runWithClient(
          () => GarmentService().updateGarment(garment),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('PATCHes /{id} with the garment payload', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_garmentJson(303)));
      });

      final garment = Garment(
        id: 303,
        name: 'Updated Name',
        category: GarmentCategory.top,
        subCategory: '',
        uploadUrl: '',
        objectName: '',
      );

      final result = await http.runWithClient(
        () => GarmentService().updateGarment(garment),
        () => client,
      );

      expect(result.id, 303);
      expect(captured.method, 'PATCH');
      expect(captured.url.toString(), '$_base/303');
    });

    // The PATCH body goes through Garment.toJson; its purchase_date must be
    // date-only so the backend's Pydantic `date` field accepts it (a datetime
    // with a time component 422s). Mirrors completeUpload's date-only test.
    test('sends a date-only purchase_date in the PATCH payload', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_garmentJson(305)));
      });

      final garment = Garment(
        id: 305,
        name: 'Dated',
        category: GarmentCategory.top,
        subCategory: '',
        uploadUrl: '',
        objectName: '',
        purchaseDate: DateTime(2025, 3, 14, 9, 30),
      );

      await http.runWithClient(
        () => GarmentService().updateGarment(garment),
        () => client,
      );

      expect(
        (jsonDecode(captured.body) as Map<String, dynamic>)['purchase_date'],
        '2025-03-14',
      );
    });
  });

  group('setFavorite', () {
    test('PATCHes is_favorite', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => GarmentService().setFavorite(304, isFavorite: true),
        () => client,
      );

      expect(captured.method, 'PATCH');
      expect(captured.url.toString(), '$_base/304');
      expect(jsonDecode(captured.body), {'is_favorite': true});
    });

    // Behavior 1: after a successful toggle, a cached garment must reflect
    // the new favorite state without another network round-trip.
    test('a successful favorite toggle updates the cached garment', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(705),
        () => MockClient(
          (request) async => _jsonResponse(_envelope(_garmentJson(705))),
        ),
      );

      await http.runWithClient(
        () => GarmentService().setFavorite(705, isFavorite: true),
        () => MockClient((request) async => _jsonResponse(_envelope(null))),
      );

      // A throwing client proves getGarment is served from the cache.
      final cached = await http.runWithClient(
        () => GarmentService().getGarment(705),
        () => MockClient((request) async {
          throw StateError('should not hit the network for a cached garment');
        }),
      );
      expect(cached.isFavorite, isTrue);
    });

    // Behavior 2: toggling back off must move the cache to false too (not
    // just latch on the first write).
    test('toggling favorite back off updates the cache to false', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(706),
        () => MockClient(
          (request) async => _jsonResponse(
            _envelope({..._garmentJson(706), 'is_favorite': true}),
          ),
        ),
      );

      await http.runWithClient(
        () => GarmentService().setFavorite(706, isFavorite: false),
        () => MockClient((request) async => _jsonResponse(_envelope(null))),
      );

      final cached = await http.runWithClient(
        () => GarmentService().getGarment(706),
        () => MockClient((request) async {
          throw StateError('should not hit the network for a cached garment');
        }),
      );
      expect(cached.isFavorite, isFalse);
    });

    // Behavior 3: a non-2xx response throws and must not touch the cache.
    test('a failed setFavorite throws and leaves the cache unchanged', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(707),
        () => MockClient(
          (request) async => _jsonResponse(_envelope(_garmentJson(707))),
        ),
      );

      await expectLater(
        http.runWithClient(
          () => GarmentService().setFavorite(707, isFavorite: true),
          () => MockClient((request) async => http.Response('', 500)),
        ),
        throwsA(isA<Exception>()),
      );

      final cached = await http.runWithClient(
        () => GarmentService().getGarment(707),
        () => MockClient((request) async {
          throw StateError('should not hit the network for a cached garment');
        }),
      );
      expect(cached.isFavorite, isFalse);
    });

    // Behavior 4: an unrecoverable 401 (refresh + retry both fail) must
    // surface AuthExpiredException and must not touch the cache.
    test('setFavorite surfaces AuthExpiredException on an unrecoverable 401, cache unchanged', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(708),
        () => MockClient(
          (request) async => _jsonResponse(_envelope(_garmentJson(708))),
        ),
      );

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _jsonResponse(_envelope({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          }));
        }
        return http.Response('', 401);
      });

      await expectLater(
        http.runWithClient(
          () => GarmentService().setFavorite(708, isFavorite: true),
          () => client,
        ),
        throwsA(isA<AuthExpiredException>()),
      );

      final cached = await http.runWithClient(
        () => GarmentService().getGarment(708),
        () => MockClient((request) async {
          throw StateError('should not hit the network for a cached garment');
        }),
      );
      expect(cached.isFavorite, isFalse);
    });

    // Behavior 5a (deterministic): whatever the source of the abort, a
    // TimeoutException out of the request must propagate and leave the
    // cache untouched. A MockClient that throws TimeoutException reproduces
    // exactly what `.timeout(...)` does when it fires (the request future
    // completes with a TimeoutException) with no real wall-clock wait.
    test('a timed-out setFavorite rethrows TimeoutException and leaves the cache unchanged', () async {
      await http.runWithClient(
        () => GarmentService().getGarment(709),
        () => MockClient(
          (request) async => _jsonResponse(_envelope(_garmentJson(709))),
        ),
      );

      await expectLater(
        http.runWithClient(
          () => GarmentService().setFavorite(709, isFavorite: true),
          () => MockClient((request) async {
            throw TimeoutException('simulated slow request');
          }),
        ),
        throwsA(isA<TimeoutException>()),
      );

      final cached = await http.runWithClient(
        () => GarmentService().getGarment(709),
        () => MockClient((request) async {
          throw StateError('should not hit the network for a cached garment');
        }),
      );
      expect(cached.isFavorite, isFalse);
    });
  });

  group('analyzeGarment', () {
    test('sends a multipart request and parses metadata/versatility', () async {
      final tempFile = await _writeTempJpeg();
      addTearDown(() => tempFile.delete());

      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'metadata': {'color': 'navy'},
            'versatility': {
              'score': 80,
              'breakdown': [
                {'category': 'Bottom', 'compatible_count': 3},
              ],
            },
          }),
        );
      });

      final result = await http.runWithClient(
        () => GarmentService().analyzeGarment(tempFile.path),
        () => client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_base/analyze-instant');
      expect(result.metadata, {'color': 'navy'});
      expect(result.versatility?.score, 80);
      expect(result.versatility?.breakdown.single.category, GarmentCategory.bottom);
      expect(result.versatility?.breakdown.single.compatibleCount, 3);
      expect(result.processedImagePath, isNull);
    });
  });

  group('uploadImage', () {
    test('PUTs the file bytes as image/jpeg to the signed url', () async {
      final tempFile = await _writeTempJpeg();
      addTearDown(() => tempFile.delete());

      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      });

      await http.runWithClient(
        () => GarmentService().uploadImage(
          'https://upload.example.com/signed',
          tempFile.path,
        ),
        () => client,
      );

      expect(captured.method, 'PUT');
      expect(captured.url.toString(), 'https://upload.example.com/signed');
      expect(captured.headers['Content-Type'], 'image/jpeg');
      expect(captured.bodyBytes, [0xFF, 0xD8, 0xFF, 0xD9]);
    });

    test('throws with the status code on a non-2xx response', () async {
      final tempFile = await _writeTempJpeg();
      addTearDown(() => tempFile.delete());

      final client = MockClient((_) async => http.Response('denied', 403));

      await expectLater(
        http.runWithClient(
          () => GarmentService().uploadImage('https://x/y', tempFile.path),
          () => client,
        ),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', contains('403')),
        ),
      );
    });
  });
}

Future<File> _writeTempJpeg() async {
  final file = File(
    '${Directory.systemTemp.path}/garment_service_test_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  return file;
}
