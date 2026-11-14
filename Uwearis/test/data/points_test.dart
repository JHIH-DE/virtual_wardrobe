import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/utils/daily_points_notice.dart';
import 'package:uwearis/data/points.dart';

import '../helpers/points_fixture.dart';

void main() {
  group('PointsSummary.fromJson', () {
    test('parses balance, grant, subscription and costs', () {
      final s = PointsSummary.fromJson(
        pointsSummaryJson(
          balance: 140,
          subscriptionExpiresAt: '2026-12-09T00:00:00+08:00',
          costs: {'try_on': 30, 'future_feature': 4},
        ),
      );
      expect(s.balance, 140);
      expect(s.cap, 30000);
      expect(s.dailyGrant, 15);
      expect(s.claimedToday, isTrue);
      expect(s.nextClaimAt.toUtc(), DateTime.utc(2026, 11, 9, 16));
      expect(s.nextGrant, 15);
      expect(s.subscriptionActive, isTrue);
      expect(s.subscriptionExpiresAt!.toUtc(), DateTime.utc(2026, 12, 8, 16));
      expect(s.costOf(PointsAction.tryOn), 30);
      expect(s.costOf(PointsAction.flatLay), isNull);
      expect(s.costs['future_feature'], 4);
    });

    test('a missing next_grant means no grant tomorrow', () {
      final s = PointsSummary.fromJson(pointsSummaryJson(nextGrant: null));
      expect(s.nextGrant, 0);
    });

    test('a float-valued number still parses', () {
      final s = PointsSummary.fromJson({
        ...pointsSummaryJson(),
        'balance': 12.0,
      });
      expect(s.balance, 12);
    });
  });

  group('PointsTransaction.fromJson', () {
    test('created_at without an offset is Taipei time', () {
      final t = PointsTransaction.fromJson({
        'id': 1,
        'delta': -30,
        'balance_after': 125,
        'kind': 'charge',
        'action': 'try_on',
        'note': null,
        'created_at': '2026-11-09T14:02:58',
      });
      expect(t.createdAt.toUtc(), DateTime.utc(2026, 11, 9, 6, 2, 58));
      expect(t.kind, PointsTransactionKind.charge);
      expect(t.action, PointsAction.tryOn);
    });

    test('unknown kinds and actions don\'t throw', () {
      final t = PointsTransaction.fromJson({
        'id': 2,
        'delta': 5,
        'balance_after': 10,
        'kind': 'bonus',
        'action': 'something_new',
        'created_at': '2026-11-09T14:02:58',
      });
      expect(t.kind, PointsTransactionKind.unknown);
      expect(t.action, isNull);
      expect(t.rawAction, 'something_new');
    });
  });

  test('PointsTransactionPage.hasMore', () {
    PointsTransactionPage page(int p, int total) =>
        PointsTransactionPage(items: const [], total: total, page: p, size: 20);
    expect(page(1, 37).hasMore, isTrue);
    expect(page(2, 37).hasMore, isFalse);
    expect(page(1, 20).hasMore, isFalse);
  });

  test('taipeiDateKey rolls over at 16:00 UTC', () {
    expect(taipeiDateKey(DateTime.utc(2026, 11, 9, 15, 59)), '2026-11-09');
    expect(taipeiDateKey(DateTime.utc(2026, 11, 9, 16)), '2026-11-10');
  });
}
