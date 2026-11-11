import 'package:shared_preferences/shared_preferences.dart';

import '../../data/points.dart';
import 'debug_log.dart';

/// "You got today's N points", once per Taipei day. The grant itself lands
/// on the day's first request (usually `GET /users/me` at launch), so
/// `POST /points/daily-claim` would almost always report 0 — the app keeps
/// its own record of having said so instead.
class DailyPointsNotice {
  static const _shownDateKey = 'points_daily_notice_date';

  /// True at most once per Taipei day; records it as shown.
  static Future<bool> takeIfDue(PointsSummary summary, {DateTime? now}) async {
    if (!summary.claimedToday || summary.dailyGrant <= 0) return false;
    final today = taipeiDateKey(now ?? DateTime.now());
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_shownDateKey) == today) return false;
      await prefs.setString(_shownDateKey, today);
      return true;
    } catch (e) {
      debugLog('DailyPointsNotice: $e');
      return false;
    }
  }

  /// At sign-out, so the next account gets its own notice.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shownDateKey);
    } catch (e) {
      debugLog('DailyPointsNotice.clear: $e');
    }
  }
}

/// `yyyy-MM-dd` of [now] in Taipei (fixed UTC+8) — the backend's "day".
String taipeiDateKey(DateTime now) {
  final taipei = now.toUtc().add(const Duration(hours: 8));
  final mm = taipei.month.toString().padLeft(2, '0');
  final dd = taipei.day.toString().padLeft(2, '0');
  return '${taipei.year}-$mm-$dd';
}
