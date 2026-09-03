import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/data/trip.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _trip(int id, {String name = 'Trip'}) => {
  'id': id,
  'name': '$name $id',
  'legs': [
    {
      'location': 'Tokyo',
      'latitude': 35.68,
      'longitude': 139.69,
      'timezone': 'Asia/Tokyo',
      'start_date': '2027-01-01',
      'end_date': '2027-01-05',
    },
  ],
};

Future<void> withTrips(
  List<Map<String, dynamic>> items,
  Future<void> Function(ProviderContainer container) body, {
  Future<http.Response> Function(http.Request request)? onRequest,
}) {
  final client = MockClient(
    onRequest ?? (_) async => jsonResponse(envelope({'items': items})),
  );
  return http.runWithClient(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(tripsProvider.future);
    await body(container);
  }, () => client);
}

void main() {
  setUp(setUpFakeAuth);

  test('build() parses items into Trips', () {
    return withTrips([_trip(1), _trip(2)], (c) async {
      expect(c.read(tripsProvider).value!.map((t) => t.id), ['1', '2']);
    });
  });

  group('optimistic mutations', () {
    test('addTrip prepends', () {
      return withTrips([_trip(1)], (c) async {
        c.read(tripsProvider.notifier).addTrip(Trip.fromJson(_trip(2)));
        expect(c.read(tripsProvider).value!.map((t) => t.id), ['2', '1']);
      });
    });

    test('removeTrip drops the matching id', () {
      return withTrips([_trip(1), _trip(2), _trip(3)], (c) async {
        c.read(tripsProvider.notifier).removeTrip('2');
        expect(c.read(tripsProvider).value!.map((t) => t.id), ['1', '3']);
      });
    });

    test('updateTrip replaces the entry with the same id', () {
      return withTrips([_trip(1), _trip(2)], (c) async {
        final renamed = Trip.fromJson(_trip(2)).copyWith(name: 'Renamed');
        c.read(tripsProvider.notifier).updateTrip(renamed);
        final list = c.read(tripsProvider).value!;
        expect(list.firstWhere((t) => t.id == '2').name, 'Renamed');
        expect(list.map((t) => t.id), ['1', '2']);
      });
    });
  });

  test('refresh() re-fetches from the server', () {
    var requests = 0;
    return withTrips(
      [_trip(1)],
      (c) async {
        expect(requests, 1);
        await c.read(tripsProvider.notifier).refresh();
        expect(requests, 2);
        expect(c.read(tripsProvider).value!.map((t) => t.id), ['1', '2']);
      },
      onRequest: (_) async {
        requests++;
        return jsonResponse(
          envelope({
            'items': requests == 1 ? [_trip(1)] : [_trip(1), _trip(2)],
          }),
        );
      },
    );
  });
}
