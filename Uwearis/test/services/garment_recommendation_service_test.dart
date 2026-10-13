import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/garment_recommendation_service.dart';
import 'package:uwearis/data/style_type.dart';

import '../helpers/fake_auth.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/outfit/advice';

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

  group('completeOutfit', () {
    test('POSTs style/temperature/garment_ids/exclude_garment_ids and '
        'parses the result', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'outfit_name': 'Sharp Weekday Look',
            'selected_garment_ids': [101, 205, 88],
            'items': [
              {'garment_id': 101, 'role': 'top', 'order': 0, 'reason': 'r'},
            ],
            'styling_tips': null,
            'reasoning': null,
          }),
        );
      });

      final ids = await http.runWithClient(
        () => GarmentRecommendationService().completeOutfit(
          garmentIds: const [101],
          excludeGarmentIds: const [9, 10],
          style: StyleType.smartCasual,
          temperatureC: 22.5,
        ),
        () => client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), _base);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['style'], 'smart_casual');
      expect(body.containsKey('occasion'), isFalse);
      expect(body['temperature_c'], 22.5);
      expect(body['garment_ids'], [101]);
      expect(body['exclude_garment_ids'], [9, 10]);
      expect(ids, [101, 205, 88]);
    });

    test('defaults exclude_garment_ids to an empty list', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'selected_garment_ids': <int>[], 'items': <dynamic>[]}),
        );
      });

      await http.runWithClient(
        () =>
            GarmentRecommendationService().completeOutfit(garmentIds: const []),
        () => client,
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['exclude_garment_ids'], <int>[]);
    });

    test('leaves style out when none is picked (backend infers it)', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'selected_garment_ids': <int>[], 'items': <dynamic>[]}),
        );
      });

      await http.runWithClient(
        () =>
            GarmentRecommendationService().completeOutfit(garmentIds: const []),
        () => client,
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('style'), isFalse);
    });

    test('sends a null temperature_c when the weather is unknown', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({'selected_garment_ids': <int>[], 'items': <dynamic>[]}),
        );
      });

      await http.runWithClient(
        () =>
            GarmentRecommendationService().completeOutfit(garmentIds: const []),
        () => client,
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('temperature_c'), isTrue);
      expect(body['temperature_c'], isNull);
    });

    test('throws when the response is missing selected_garment_ids', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({'items': <dynamic>[]})),
      );

      await expectLater(
        http.runWithClient(
          () => GarmentRecommendationService().completeOutfit(
            garmentIds: const [1],
          ),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // The POST carries a .timeout(); a stalled request must surface a
    // TimeoutException rather than hang the caller forever.
    test('surfaces a TimeoutException from a stalled request', () async {
      await expectLater(
        http.runWithClient(
          () => GarmentRecommendationService().completeOutfit(
            garmentIds: const [1],
          ),
          () => MockClient((request) async {
            throw TimeoutException('simulated slow request');
          }),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
