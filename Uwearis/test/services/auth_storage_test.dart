import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/services/auth_storage.dart';

String _jwt(Object payload) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  group('AuthStorage.userIdFromToken', () {
    test('returns the sub claim', () {
      expect(AuthStorage.userIdFromToken(_jwt({'sub': '42'})), '42');
    });

    test('stringifies a numeric sub', () {
      expect(AuthStorage.userIdFromToken(_jwt({'sub': 7})), '7');
    });

    test('returns null for a missing sub', () {
      expect(AuthStorage.userIdFromToken(_jwt({'exp': 1})), isNull);
    });

    test('returns null for null, malformed or non-JSON tokens', () {
      expect(AuthStorage.userIdFromToken(null), isNull);
      expect(AuthStorage.userIdFromToken('not-a-jwt'), isNull);
      expect(AuthStorage.userIdFromToken('a.%%%.c'), isNull);
      expect(AuthStorage.userIdFromToken(_jwt(['sub'])), isNull);
    });
  });
}
