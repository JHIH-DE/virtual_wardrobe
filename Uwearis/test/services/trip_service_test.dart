import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/trip_service.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';

import '../helpers/fake_auth.dart';

const _base = 'http://10.0.2.2:8000/api/v1/trip_plans';

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

TripLeg _leg() => TripLeg(
  location: LocationResult(
    name: 'Tokyo',
    latitude: 35.68,
    longitude: 139.69,
    timezone: 'Asia/Tokyo',
  ),
  dateRange: DateTimeRange(
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 3),
  ),
);

void main() {
  setUp(setUpFakeAuth);

  group('createTrip', () {
    test('POSTs name/legs/activity and returns the new id', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'id': 9}));
      });

      final id = await http.runWithClient(
        () => TripService().createTrip(
          name: 'Japan Trip',
          legs: [_leg()],
          activities: ['outdoor'],
        ),
        () => client,
      );

      expect(id, 9);
      expect(captured.method, 'POST');
      expect(captured.url.toString(), _base);
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['name'], 'Japan Trip');
      expect(payload['activity'], ['outdoor']);
      expect((payload['legs'] as List), hasLength(1));
      expect(payload.containsKey('days'), isFalse);
    });

    test('includes days only when explicitly passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'id': 1}));
      });

      await http.runWithClient(
        () => TripService().createTrip(
          name: 'Trip',
          legs: [_leg()],
          activities: const [],
          days: [
            {'date': '2026-10-01', 'activity': 'outdoor'},
          ],
        ),
        () => client,
      );

      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['days'], [
        {'date': '2026-10-01', 'activity': 'outdoor'},
      ]);
    });

    test('throws when the response has no id', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({})),
      );
      await expectLater(
        http.runWithClient(
          () => TripService().createTrip(
            name: 'Trip',
            legs: [_leg()],
            activities: const [],
          ),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // A JSON encoder can serialize the new id as a float (9.0); parse it via
    // num rather than rejecting anything that isn't exactly an int.
    test('accepts an id returned as a float', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({'id': 9.0})),
      );

      final id = await http.runWithClient(
        () => TripService().createTrip(
          name: 'Trip',
          legs: [_leg()],
          activities: const [],
        ),
        () => client,
      );

      expect(id, 9);
    });
  });

  group('updateTrip', () {
    test('only sends the fields that were actually passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => TripService().updateTrip(9, name: 'Renamed Trip'),
        () => client,
      );

      expect(captured.method, 'PATCH');
      expect(captured.url.toString(), '$_base/9');
      expect(jsonDecode(captured.body), {'name': 'Renamed Trip'});
    });
  });

  group('getTrips', () {
    test('GETs the base url and parses items into Trips', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'items': [
              {
                'id': 1,
                'name': 'Trip A',
                'legs': [
                  {
                    'location': 'Tokyo',
                    'latitude': 35.68,
                    'longitude': 139.69,
                    'timezone': 'Asia/Tokyo',
                    'start_date': '2026-10-01',
                    'end_date': '2026-10-03',
                  },
                ],
              },
            ],
          }),
        );
      });

      final trips = await http.runWithClient(
        () => TripService().getTrips(),
        () => client,
      );

      expect(captured.url.toString(), _base);
      expect(trips, hasLength(1));
      expect(trips.single.name, 'Trip A');
    });
  });

  group('getTrip / getTripPlan', () {
    test('getTrip GETs /{id} and returns the raw data map', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'id': 9, 'days': []}));
      });

      final data = await http.runWithClient(
        () => TripService().getTrip(9),
        () => client,
      );

      expect(captured.url.toString(), '$_base/9');
      expect(data['id'], 9);
    });

    test('getTrip returns the nested days payload unchanged', () async {
      final days = [
        {
          'id': 1,
          'date': '2026-10-01',
          'group_id': 42,
          'outfits': [
            {
              'outfit_id': 7,
              'option_type': 'ai',
              'result_image_url': 'https://signed.example/x.jpg',
            },
          ],
        },
      ];
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({'id': 9, 'days': days})),
      );

      final data = await http.runWithClient(
        () => TripService().getTrip(9),
        () => client,
      );

      expect(data['days'], days);
    });

    test('getTripPlan GETs /{id}/plan and parses a typed TripPlan', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'suitcase_items': [
              {'garment_id': 5},
            ],
            'days': [
              {
                'date': '2026-10-01',
                'options': [
                  {
                    'id': 3,
                    'order_index': 0,
                    'outfit_id': 71,
                    'items': [
                      {'garment_id': 5, 'name': 'Tee', 'category': 'Top'},
                    ],
                  },
                ],
              },
            ],
          }),
        );
      });

      final plan = await http.runWithClient(
        () => TripService().getTripPlan(9),
        () => client,
      );

      expect(captured.url.toString(), '$_base/9/plan');
      expect(plan.suitcaseIds, {5});
      expect(plan.days.single.optionId, 3);
      expect(plan.days.single.outfitId, 71);
    });
  });

  group('generateTripPlan', () {
    test('omits days/alternatives_per_day when not passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'id': 9}));
      });

      await http.runWithClient(
        () => TripService().generateTripPlan(9),
        () => client,
      );

      expect(captured.url.toString(), '$_base/9/generate');
      expect(jsonDecode(captured.body), {});
    });

    test('includes days and alternatives_per_day when passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'id': 9}));
      });

      await http.runWithClient(
        () => TripService().generateTripPlan(
          9,
          days: [
            {'date': '2026-10-01'},
          ],
          alternativesPerDay: 3,
        ),
        () => client,
      );

      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['days'], [
        {'date': '2026-10-01'},
      ]);
      expect(payload['alternatives_per_day'], 3);
    });

    // The generate POST carries a .timeout(); a stalled request must surface a
    // TimeoutException rather than hang the caller. (A MockClient throwing
    // TimeoutException reproduces what .timeout() does when it fires.)
    test('surfaces a TimeoutException from a stalled generation', () async {
      await expectLater(
        http.runWithClient(
          () => TripService().generateTripPlan(9),
          () => MockClient((request) async {
            throw TimeoutException('simulated slow generation');
          }),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('suitcase items', () {
    test('addSuitcaseItem POSTs garment_id', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => TripService().addSuitcaseItem(9, garmentId: 55),
        () => client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_base/9/suitcase-items');
      expect(jsonDecode(captured.body), {'garment_id': 55});
    });

    test('removeSuitcaseItem DELETEs the garment-specific path', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => TripService().removeSuitcaseItem(9, garmentId: 55),
        () => client,
      );

      expect(captured.method, 'DELETE');
      expect(captured.url.toString(), '$_base/9/suitcase-items/55');
    });
  });

  group('deleteTrip', () {
    test('DELETEs /{id}', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(() => TripService().deleteTrip(9), () => client);

      expect(captured.method, 'DELETE');
      expect(captured.url.toString(), '$_base/9');
    });
  });

  group('packing analysis', () {
    test(
      'analyzeTrip POSTs to packing-analysis and parses the analysis',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return _jsonResponse(
            _envelope({
              'overall_advice': 'Pack light.',
              'categories': [
                {
                  'category': 'Top',
                  'recommended_quantity': 3,
                  'suggested_garment_ids': [7, 8],
                  'reasoning': ['line one', 'line two'],
                },
                {'category': 'Shoes', 'recommended_quantity': 2},
              ],
            }),
          );
        });

        final analysis = await http.runWithClient(
          () => TripService().analyzeTrip(9),
          () => client,
        );

        expect(captured.method, 'POST');
        expect(captured.url.toString(), '$_base/9/packing-analysis');
        expect(analysis.overallAdvice, 'Pack light.');
        expect(analysis.recommendedTotal, 5);
        final top = analysis.forCategory(GarmentCategory.top)!;
        expect(top.recommendedQuantity, 3);
        expect(top.suggestedGarmentIds, {7, 8});
        expect(top.reasoning, 'line one\nline two');
      },
    );

    test('getTripSuggestion GETs the same packing-analysis path', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'overall_advice': 'Pack light.'}));
      });

      final analysis = await http.runWithClient(
        () => TripService().getTripSuggestion(9),
        () => client,
      );

      expect(captured.method, 'GET');
      expect(captured.url.toString(), '$_base/9/packing-analysis');
      expect(analysis.categories, isEmpty);
      expect(analysis.recommendedTotal, 0);
    });
  });

  group('option outfit rendering', () {
    test('generateOptionOutfit POSTs and parses the render result', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'outfit_id': 3,
            'result_image_url': 'https://img/3.png',
          }),
        );
      });

      final render = await http.runWithClient(
        () => TripService().generateOptionOutfit(9, optionId: 42),
        () => client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_base/9/options/42/outfit');
      expect(render.outfitId, 3);
      expect(render.resultImageUrl, 'https://img/3.png');
    });

    test('regenerateOptionOutfit omits background_id when null', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'outfit_id': 3}));
      });

      await http.runWithClient(
        () => TripService().regenerateOptionOutfit(9, optionId: 42),
        () => client,
      );

      expect(captured.url.toString(), '$_base/9/options/42/outfit/regenerate');
      expect(jsonDecode(captured.body), {});
    });

    test('regenerateOptionOutfit includes background_id when passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'outfit_id': 3}));
      });

      await http.runWithClient(
        () => TripService().regenerateOptionOutfit(
          9,
          optionId: 42,
          backgroundId: 7,
        ),
        () => client,
      );

      expect(jsonDecode(captured.body), {'background_id': 7});
    });

    test('updateOptionItems PATCHes garment_ids and returns the new garments', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'option_id': 42,
            'items': [
              {'garment_id': 1, 'name': 'Tee', 'category': 'Top'},
              {'garment_id': 2, 'name': 'Jeans', 'category': 'Bottom'},
            ],
          }),
        );
      });

      final garments = await http.runWithClient(
        () => TripService().updateOptionItems(
          9,
          optionId: 42,
          garmentIds: [1, 2],
        ),
        () => client,
      );

      expect(captured.method, 'PATCH');
      expect(captured.url.toString(), '$_base/9/options/42/items');
      expect(jsonDecode(captured.body), {
        'garment_ids': [1, 2],
      });
      expect(garments.map((g) => g.id), [1, 2]);
      expect(garments.first.category, GarmentCategory.top);
    });
  });
}
