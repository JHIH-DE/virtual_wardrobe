import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/daily_outfit_service.dart';

import '../helpers/fake_auth.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/daily_outfits';

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
                'group_type': 'general',
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
      expect(outfits!.single.id, 1);
    });

    test(
      'returns null when data is null (no plan for that date yet)',
      () async {
        final client = MockClient(
          (request) async => _jsonResponse(_envelope(null)),
        );

        final outfits = await http.runWithClient(
          () => DailyOutfitService().getDailyOutfit('2026-09-02'),
          () => client,
        );

        expect(outfits, isNull);
      },
    );

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

    // testWidgets for its fake clock, so the 15s timeouts elapse instantly.
    testWidgets('times out a stalled request after one retry', (tester) async {
      var calls = 0;
      Object? error;
      http.runWithClient(
        () => DailyOutfitService()
            .getDailyOutfit('2026-09-02')
            .then<void>((_) {}, onError: (Object e) => error = e),
        () => MockClient((request) {
          calls++;
          return Completer<http.Response>().future;
        }),
      );

      await tester.pump(const Duration(seconds: 15));
      expect(calls, 1);
      expect(error, isNull);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 15));
      expect(calls, 2);
      expect(error, isA<TimeoutException>());
    });
  });

  group('generate', () {
    test(
      'POSTs the date and alternatives without the removed default_occasion',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return _jsonResponse(
            _envelope({
              'id': 169,
              'date': '2026-10-17',
              'occasion': 'casual_daily',
              'options': [
                {'id': 362, 'option_type': 'primary', 'outfit_id': 148},
                {'id': 363, 'option_type': 'alternative', 'outfit_id': 62},
              ],
              'outfits': [
                {'outfit_id': 148, 'group_id': 78, 'group_type': 'general'},
                {'outfit_id': 62, 'group_id': 30, 'group_type': 'general'},
              ],
            }),
          );
        });

        final outfits = await http.runWithClient(
          () => DailyOutfitService().generate(
            date: DateTime(2026, 10, 17),
            alternativesPerDay: 1,
          ),
          () => client,
        );

        expect(captured.method, 'POST');
        expect(captured.url.toString(), '$_base/generate');
        expect(jsonDecode(captured.body), {
          'date': '2026-10-17',
          'alternatives_per_day': 1,
        });
        expect(outfits.map((o) => o.id), [148, 62]);
      },
    );

    test('surfaces INSUFFICIENT_OUTFIT_DATA as an ApiException', () async {
      final client = MockClient(
        (request) async => _jsonResponse({
          'success': false,
          'message': 'Not enough outfits',
          'data': null,
          'error_code': 'INSUFFICIENT_OUTFIT_DATA',
        }, status: 422),
      );

      await expectLater(
        http.runWithClient(
          () => DailyOutfitService().generate(date: DateTime(2026, 10, 17)),
          () => client,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'INSUFFICIENT_OUTFIT_DATA',
          ),
        ),
      );
    });
  });
}
