import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/daily_outfit_service.dart';

import '../helpers/fake_auth.dart';

const _base = 'http://10.0.2.2:8000/api/v1/daily_outfits';

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

void main() {
  setUp(setUpFakeAuth);

  group('getDailyOutfit', () {
    test('GETs the target date and parses the outfits list', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'outfits': [
              {
                'outfit_id': 1,
                'group_id': 5,
                'group_type': 'daily',
                'result_image_url': 'https://example.com/1.jpg',
              },
            ],
          }),
        );
      });

      final outfits = await http.runWithClient(
        () => DailyOutfitService().getDailyOutfit('2026-09-02'),
        () => client,
      );

      expect(captured.method, 'GET');
      expect(captured.url.toString(), '$_base/2026-09-02');
      expect(outfits, hasLength(1));
      expect(outfits!.single.groupType, 'daily');
    });

    test('returns null when data is null (no plan for that date yet)', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope(null)),
      );

      final outfits = await http.runWithClient(
        () => DailyOutfitService().getDailyOutfit('2026-09-02'),
        () => client,
      );

      expect(outfits, isNull);
    });

    test('throws when data is present but has no outfits list', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({})),
      );

      await expectLater(
        http.runWithClient(
          () => DailyOutfitService().getDailyOutfit('2026-09-02'),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
