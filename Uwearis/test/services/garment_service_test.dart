import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
            'versatility': {'score': 0.8},
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
      expect(result.versatility, {'score': 0.8});
      expect(result.processedImagePath, isNull);
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
