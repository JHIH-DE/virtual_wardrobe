import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/features/pages/common/location_picker_page.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../../helpers/widget_harness.dart';

/// Open-Meteo's geocoding search: answers [name] with one place of that
/// name. With [hold], replies wait for [answer] (by query), so tests pick
/// the order searches finish in. [statusFor] overrides a query's status.
class _Geocoder {
  bool hold = false;
  final Map<String, Completer<void>> _held = {};
  final Map<String, int> statusFor = {};
  final List<String> queries = [];

  void answer(String name) => _held.remove(name)!.complete();

  late final MockClient client = MockClient((request) async {
    final name = request.url.queryParameters['name']!;
    queries.add(name);
    if (hold) {
      final gate = Completer<void>();
      _held[name] = gate;
      await gate.future;
    }
    final status = statusFor[name] ?? 200;
    if (status != 200) {
      return http.Response(
        jsonEncode({'error': true, 'reason': 'upstream'}),
        status,
      );
    }
    return http.Response(
      jsonEncode({
        'results': [
          {
            'id': name.hashCode,
            'name': name,
            'country': 'Japan',
            'latitude': 35.0,
            'longitude': 139.0,
            'timezone': 'Asia/Tokyo',
            'population': 100,
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

void main() {
  late _Geocoder geocoder;

  setUp(() => geocoder = _Geocoder());

  Future<void> open(WidgetTester tester) =>
      pumpApp(tester, const LocationPickerPage());

  testWidgets('a search lists its places', (tester) async {
    await http.runWithClient(() async {
      await open(tester);
      await _search(tester, 'Tokyo');
      await tester.pumpAndSettle();

      expect(find.text('Tokyo, Japan'), findsOneWidget);
    }, () => geocoder.client);
  });

  testWidgets("an older search answering after a newer one doesn't replace "
      "the newer one's places", (tester) async {
    await http.runWithClient(() async {
      geocoder.hold = true;
      await open(tester);
      await _search(tester, 'Tokyo');
      await _search(tester, 'Osaka');

      geocoder.answer('Osaka');
      await tester.pump();
      await tester.pump();
      expect(find.text('Osaka, Japan'), findsOneWidget);

      geocoder.answer('Tokyo'); // the older one lands last
      await tester.pump();
      await tester.pump();
      expect(find.text('Osaka, Japan'), findsOneWidget);
      expect(find.text('Tokyo, Japan'), findsNothing);
    }, () => geocoder.client);
  });

  testWidgets("an older search finishing first doesn't hide the spinner of "
      'the newer one still running', (tester) async {
    await http.runWithClient(() async {
      geocoder.hold = true;
      await open(tester);
      await _search(tester, 'Tokyo');
      await _search(tester, 'Osaka');

      geocoder.answer('Tokyo');
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Tokyo, Japan'), findsNothing);

      geocoder.answer('Osaka');
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }, () => geocoder.client);
  });

  testWidgets('a search that fails with an HTTP error shows the existing '
      'search-failed dialog, not an empty list', (tester) async {
    await http.runWithClient(() async {
      geocoder.statusFor['Tokyo'] = 503;
      await open(tester);
      await _search(tester, 'Tokyo');
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(LocationPickerPage)),
      );
      expect(find.text(l10n.locationSearchFailed), findsOneWidget);
    }, () => geocoder.client);
  });

  testWidgets("one failing spelling variant doesn't hide the others' places", (
    tester,
  ) async {
    await http.runWithClient(() async {
      geocoder.statusFor['台北'] = 503; // its 台北市 / 臺北 variants still answer
      await open(tester);
      await _search(tester, '台北');
      await tester.pumpAndSettle();

      expect(find.text('台北市, Japan'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LocationPickerPage)),
      );
      expect(find.text(l10n.locationSearchFailed), findsNothing);
    }, () => geocoder.client);
  });

  testWidgets('closing the page mid-search: no error, and no dialog once '
      'the reply lands', (tester) async {
    await http.runWithClient(() async {
      geocoder
        ..hold = true
        ..statusFor['Tokyo'] = 503;
      await open(tester);
      await _search(tester, 'Tokyo');

      await tester.pumpWidget(const SizedBox()); // the page is gone
      geocoder.answer('Tokyo');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }, () => geocoder.client);
  });

  testWidgets('the search field controller is disposed with the page', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await open(tester);
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;

      await tester.pumpWidget(const SizedBox());

      expect(() => controller.addListener(() {}), throwsFlutterError);
    }, () => geocoder.client);
  });

  testWidgets('picking a place returns it', (tester) async {
    await http.runWithClient(() async {
      LocationResult? picked;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await Navigator.push<LocationResult>(
                context,
                MaterialPageRoute(builder: (_) => const LocationPickerPage()),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _search(tester, 'Tokyo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tokyo, Japan'));
      await tester.pumpAndSettle();

      expect(picked?.name, 'Tokyo, Japan');
      expect(picked?.timezone, 'Asia/Tokyo');
    }, () => geocoder.client);
  });
}
