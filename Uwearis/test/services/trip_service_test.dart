import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/trip_service.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/trip_outfit.dart';

import '../helpers/fake_auth.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/trip_plans';

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

    // A JSON encoder can serialize the new id as a float (9.0).
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

  Map<String, dynamic> collection({List<Map<String, dynamic>>? outfits}) => {
    'trip_id': 9,
    'total_days': 3,
    'suggested_outfit_count': {'min': 3, 'max': 3},
    'suitcase_items': [
      {'garment_id': 1, 'name': 'Tee', 'category': 'Top'},
    ],
    'outfits':
        outfits ??
        [
          {
            'id': 5,
            'source': 'saved_outfit',
            'source_outfit_id': 40,
            'garments': [
              {'garment_id': 1, 'category': 'Top'},
            ],
          },
        ],
    'saved_candidates': [],
  };

  /// Captures the one request and answers with [collection].
  Future<(http.Request, T)> capture<T>(
    Future<T> Function() call, {
    Map<String, dynamic>? body,
  }) async {
    late http.Request captured;
    final result = await http.runWithClient(
      call,
      () => MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(body ?? collection()));
      }),
    );
    return (captured, result);
  }

  group('trip outfit collection', () {
    test(
      'getTripOutfits GETs /{id}/outfits and parses the collection',
      () async {
        final (req, c) = await capture(() => TripService().getTripOutfits(9));
        expect(req.method, 'GET');
        expect(req.url.toString(), '$_base/9/outfits');
        expect(c.outfits.single.sourceOutfitId, 40);
        expect(c.suitcaseIds, {1});
      },
    );

    test('addTripOutfitFromSaved POSTs the version id', () async {
      final (req, c) = await capture(
        () => TripService().addTripOutfitFromSaved(9, outfitId: 40),
      );
      expect(req.method, 'POST');
      expect(req.url.toString(), '$_base/9/outfits/from-saved');
      expect(jsonDecode(req.body), {'outfit_id': 40});
      expect(c.outfits, hasLength(1));
    });

    test('createTripOutfit POSTs garment_ids', () async {
      final (req, _) = await capture(
        () => TripService().createTripOutfit(9, garmentIds: [1, 2, 3]),
      );
      expect(req.method, 'POST');
      expect(req.url.toString(), '$_base/9/outfits');
      expect(jsonDecode(req.body), {
        'garment_ids': [1, 2, 3],
      });
    });

    test('updateTripOutfit PATCHes only the fields passed', () async {
      final (pinReq, _) = await capture(
        () =>
            TripService().updateTripOutfit(9, tripOutfitId: 5, isPinned: true),
      );
      expect(pinReq.method, 'PATCH');
      expect(pinReq.url.toString(), '$_base/9/outfits/5');
      expect(jsonDecode(pinReq.body), {'is_pinned': true});

      final (editReq, _) = await capture(
        () => TripService().updateTripOutfit(
          9,
          tripOutfitId: 5,
          garmentIds: [1, 2],
        ),
      );
      expect(jsonDecode(editReq.body), {
        'garment_ids': [1, 2],
      });
    });

    test('removeTripOutfit DELETEs the trip outfit path', () async {
      final (req, _) = await capture(
        () => TripService().removeTripOutfit(9, tripOutfitId: 5),
      );
      expect(req.method, 'DELETE');
      expect(req.url.toString(), '$_base/9/outfits/5');
    });

    test('generateTripOutfits sends the mode and reads the counts', () async {
      final (req, result) = await capture(
        () => TripService().generateTripOutfits(
          9,
          mode: TripOutfitGenerateMode.refresh,
        ),
        body: {...collection(), 'generated_count': 2, 'replaced_count': 2},
      );
      expect(req.method, 'POST');
      expect(req.url.toString(), '$_base/9/outfits/generate');
      expect(jsonDecode(req.body), {'mode': 'refresh'});
      expect(result.generatedCount, 2);
      expect(result.replacedCount, 2);
    });

    // Throwing TimeoutException from the MockClient stands in for .timeout()
    // firing.
    test('surfaces a TimeoutException from a stalled generation', () async {
      await expectLater(
        http.runWithClient(
          () => TripService().generateTripOutfits(
            9,
            mode: TripOutfitGenerateMode.plan,
          ),
          () => MockClient((request) async {
            throw TimeoutException('simulated slow generation');
          }),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('tryOnTripOutfit POSTs the try-on path', () async {
      final (req, _) = await capture(
        () => TripService().tryOnTripOutfit(9, tripOutfitId: 5),
      );
      expect(req.method, 'POST');
      expect(req.url.toString(), '$_base/9/outfits/5/try-on');
    });

    test('an error envelope surfaces as ApiException with its code', () async {
      await expectLater(
        http.runWithClient(
          () => TripService().addTripOutfitFromSaved(9, outfitId: 40),
          () => MockClient(
            (request) async => _jsonResponse({
              'success': false,
              'message': 'dup',
              'data': null,
              'error_code': 'TRIP_OUTFIT_ALREADY_ADDED',
            }, status: 409),
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'TRIP_OUTFIT_ALREADY_ADDED',
          ),
        ),
      );
    });
  });

  group('suitcase items', () {
    test(
      'addSuitcaseItems POSTs garment_ids and returns the suitcase',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return _jsonResponse(
            _envelope({
              'suitcase_items': [
                {'garment_id': 55, 'name': 'Tee', 'category': 'Top'},
                {'garment_id': 56, 'name': 'Jeans', 'category': 'Bottom'},
              ],
            }),
          );
        });

        final suitcase = await http.runWithClient(
          () => TripService().addSuitcaseItems(9, garmentIds: [55, 56]),
          () => client,
        );

        expect(captured.method, 'POST');
        expect(captured.url.toString(), '$_base/9/suitcase-items');
        expect(jsonDecode(captured.body), {
          'garment_ids': [55, 56],
        });
        expect(suitcase.map((g) => g.id), [55, 56]);
        expect(suitcase.first.category, GarmentCategory.top);
      },
    );

    test('removeSuitcaseItem DELETEs the garment-specific path', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'affected_options': []}));
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
}
