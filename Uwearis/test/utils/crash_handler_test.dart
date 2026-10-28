import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/utils/crash_handler.dart';

String _jwt(Object payload) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  group('GlobalErrorHandler.userIdFromToken', () {
    test('returns the sub claim', () {
      expect(GlobalErrorHandler.userIdFromToken(_jwt({'sub': '42'})), '42');
    });

    test('stringifies a numeric sub', () {
      expect(GlobalErrorHandler.userIdFromToken(_jwt({'sub': 7})), '7');
    });

    test('returns null for a missing sub', () {
      expect(GlobalErrorHandler.userIdFromToken(_jwt({'exp': 1})), isNull);
    });

    test('returns null for null, malformed or non-JSON tokens', () {
      expect(GlobalErrorHandler.userIdFromToken(null), isNull);
      expect(GlobalErrorHandler.userIdFromToken('not-a-jwt'), isNull);
      expect(GlobalErrorHandler.userIdFromToken('a.%%%.c'), isNull);
      expect(GlobalErrorHandler.userIdFromToken(_jwt(['sub'])), isNull);
    });
  });

  test('setReportingUser is a no-op before Crashlytics is initialized', () {
    expect(GlobalErrorHandler.setReportingUser('a.b.c'), completes);
    expect(GlobalErrorHandler.setReportingUser(null), completes);
  });
}
