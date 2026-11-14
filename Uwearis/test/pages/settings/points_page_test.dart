import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/features/pages/settings/points_activity_page.dart';
import 'package:uwearis/features/pages/settings/points_page.dart';
import 'package:uwearis/data/points.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';
import 'package:uwearis/l10n/points_localization.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/mock_http.dart';
import '../../helpers/points_fixture.dart';
import '../../helpers/text_scale_harness.dart';
import '../../helpers/widget_harness.dart';

const _allCosts = {
  'try_on': 30,
  'garment_analysis': 1,
  'flat_lay': 20,
  'base_model': 22,
  'closet_analysis': 3,
  'outfit_advice': 2,
  'match_look_reference': 1,
  'match_look_match': 1,
  'trip_outfits': 8,
  'trip_packing': 7,
};

Map<String, dynamic> _transaction(
  int id, {
  required int delta,
  required String kind,
  String? action,
}) => {
  'id': id,
  'delta': delta,
  'balance_after': 100 + id,
  'kind': kind,
  'action': action,
  'note': null,
  'created_at': '2026-11-09T14:03:21',
};

/// `GET /points` answers [summary]; `/points/transactions` answers [pages]
/// by page number (missing = empty).
http.Client Function() _client({
  Map<String, dynamic>? summary,
  Map<int, List<Map<String, dynamic>>> pages = const {},
  int total = 0,
  List<int>? requestedPages,
}) {
  final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/points/transactions')) {
      final page = int.parse(request.url.queryParameters['page']!);
      requestedPages?.add(page);
      return jsonResponse(
        envelope({
          'items': pages[page] ?? [],
          'total': total,
          'page': page,
          'size': 20,
        }),
      );
    }
    if (isPointsSummaryPath(path)) {
      return jsonResponse(envelope(summary ?? pointsSummaryJson()));
    }
    return jsonResponse(envelope(null), status: 404);
  });
  return () => client;
}

void main() {
  setUpAll(loadAppFont);
  setUp(setUpFakeAuth);

  testWidgets('shows the balance, the daily grant and every cost', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await pumpApp(tester, const PointsPage());
      await tester.pumpAndSettle();
    }, _client(summary: pointsSummaryJson(balance: 1234, costs: _allCosts)));

    expect(find.text('P 1,234', findRichText: true), findsOneWidget);
    expect(find.textContaining('15 points tomorrow'), findsOneWidget);
    expect(find.textContaining('Uwearis Plus ·'), findsNothing);
    expect(find.text('Points per feature'), findsNothing);

    await tester.tap(find.byTooltip('Points per feature'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Points per feature'), findsOneWidget);
    for (final group in [
      'IMAGES',
      'WARDROBE & STYLING',
      'MATCH A LOOK & TRIPS',
    ]) {
      expect(find.text(group), findsOneWidget);
    }
    // Every feature sits in exactly one group.
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final action in PointsAction.values) {
      expect(find.text(action.localizedLabel(l10n)), findsOneWidget);
    }
    expect(find.text('P 30', findRichText: true), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('IMAGES')).dy,
      lessThan(tester.getTopLeft(find.text('Virtual try-on')).dy),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a group with no priced feature is left out', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await pumpApp(tester, const PointsPage());
      await tester.pumpAndSettle();
    }, _client(summary: pointsSummaryJson(costs: const {'try_on': 30})));

    await tester.tap(find.byTooltip('Points per feature'));
    await tester.pumpAndSettle();
    expect(find.text('IMAGES'), findsOneWidget);
    expect(find.text('WARDROBE & STYLING'), findsNothing);
    expect(find.text('MATCH A LOOK & TRIPS'), findsNothing);
  });

  testWidgets('no costs hides the info button', (tester) async {
    await http.runWithClient(() async {
      await pumpApp(tester, const PointsPage());
      await tester.pumpAndSettle();
    }, _client(summary: pointsSummaryJson(costs: const {})));
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('an active subscription shows its end date', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(
      () async {
        await pumpApp(tester, const PointsPage());
        await tester.pumpAndSettle();
      },
      _client(
        summary: pointsSummaryJson(
          dailyGrant: 75,
          nextGrant: 75,
          subscriptionExpiresAt: '2026-12-09T00:00:00+08:00',
        ),
      ),
    );
    expect(find.textContaining('Uwearis Plus · until'), findsOneWidget);
    expect(find.textContaining('75 points tomorrow'), findsOneWidget);
  });

  for (final (name, daily, next, expected) in [
    (
      'the last grant day says so',
      75,
      0,
      'Today is the last day of daily points',
    ),
    ('no grant today or tomorrow shows no grant line', 0, 0, null),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await http.runWithClient(
        () async {
          await pumpApp(tester, const PointsPage());
          await tester.pumpAndSettle();
        },
        _client(
          summary: pointsSummaryJson(dailyGrant: daily, nextGrant: next),
        ),
      );
      expect(find.textContaining('points tomorrow'), findsNothing);
      expect(
        find.text('Today is the last day of daily points'),
        expected == null ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets('selecting a plan updates the bottom action', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await pumpApp(tester, const PointsPage());
      await tester.pumpAndSettle();

      expect(find.text('Continue · NT\$299'), findsOneWidget);

      await tester.tap(find.text('NT\$999'));
      await tester.pumpAndSettle();
      expect(find.text('Continue · NT\$999'), findsOneWidget);

      await tester.tap(find.text('NT\$199'));
      await tester.pumpAndSettle();
      expect(find.text('Subscribe · NT\$199/mo'), findsOneWidget);
    }, _client());
  });

  group('activity', () {
    testWidgets('lists transactions with their titles and signed amounts', (
      tester,
    ) async {
      await http.runWithClient(
        () async {
          await pumpApp(tester, const PointsActivityPage());
          await tester.pumpAndSettle();
        },
        _client(
          total: 4,
          pages: {
            1: [
              _transaction(4, delta: 30, kind: 'refund', action: 'try_on'),
              _transaction(3, delta: -30, kind: 'charge', action: 'try_on'),
              _transaction(2, delta: 15, kind: 'daily_grant'),
              _transaction(1, delta: -5, kind: 'charge', action: 'new_thing'),
            ],
          },
        ),
      );
      expect(find.text('Refund · Virtual try-on'), findsOneWidget);
      expect(find.text('Virtual try-on'), findsOneWidget);
      expect(find.text('Points granted'), findsOneWidget);
      expect(find.text('AI feature'), findsOneWidget);
      expect(find.text('+30'), findsOneWidget);
      expect(find.text('-30'), findsOneWidget);
      expect(find.text('Balance 104'), findsOneWidget);
    });

    testWidgets('loads the next page near the end of the list', (tester) async {
      final requested = <int>[];
      await http.runWithClient(
        () async {
          await pumpApp(tester, const PointsActivityPage());
          await tester.pumpAndSettle();
          expect(requested, [1]);
          await tester.drag(find.byType(ListView), const Offset(0, -4000));
          await tester.pumpAndSettle();
        },
        _client(
          total: 25,
          requestedPages: requested,
          pages: {
            1: [
              for (var i = 25; i > 5; i--)
                _transaction(i, delta: -1, kind: 'charge', action: 'try_on'),
            ],
            2: [
              for (var i = 5; i > 0; i--)
                _transaction(i, delta: 15, kind: 'daily_grant'),
            ],
          },
        ),
      );
      expect(requested, [1, 2]);
    });

    testWidgets('an empty history says so', (tester) async {
      await http.runWithClient(() async {
        await pumpApp(tester, const PointsActivityPage());
        await tester.pumpAndSettle();
      }, _client());
      expect(find.text('No points activity yet'), findsOneWidget);
    });
  });

  for (final c in layoutCases) {
    testWidgets('lays out without overflow · ${describeCase(c)}', (
      tester,
    ) async {
      applyLayoutCase(tester, c, height: 2400);
      await http.runWithClient(
        () async {
          await pumpApp(tester, const PointsPage());
          await tester.pumpAndSettle();
        },
        _client(
          summary: pointsSummaryJson(
            costs: _allCosts,
            subscriptionExpiresAt: '2026-12-09T00:00:00+08:00',
          ),
        ),
      );
      expect(find.byType(RadioGroup<int>), findsOneWidget);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(
        find.text(
          c.locale.languageCode == 'en' ? 'Points per feature' : '各功能點數',
        ),
        findsOneWidget,
      );
    });
  }
}
