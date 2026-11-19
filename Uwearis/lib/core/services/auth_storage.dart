import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  /// Which sign-in the stored tokens belong to. Bumped synchronously by
  /// [startSession] and [clear], so a request or refresh started under an
  /// earlier session can tell, even after A → B → A, and a token refresh
  /// within one session leaves it alone. In memory only: nothing in flight
  /// survives a restart.
  static int _sessionEpoch = 0;
  static int get sessionEpoch => _sessionEpoch;

  /// Token writes run one at a time, so the access and refresh token are
  /// always replaced as a pair; reads wait for the writes queued before them.
  /// Null when no write is pending.
  static Future<void>? _writes;

  static Future<T> _queueWrite<T>(Future<T> Function() write) {
    final result = (_writes ?? Future<void>.value()).then((_) => write());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_writes, tail)) _writes = null;
    });
    _writes = tail;
    return result;
  }

  static Future<void> _afterPendingWrites() async {
    final pending = _writes;
    if (pending != null) await pending;
  }

  /// A sign-in: the tokens of a new session.
  static Future<void> startSession({
    required String accessToken,
    required String refreshToken,
  }) {
    _sessionEpoch++;
    return _queueWrite(() => _writePair(accessToken, refreshToken));
  }

  /// A token refresh's rotated pair. Writes nothing and returns false when
  /// [epoch] is no longer the current session — a refresh that lands after a
  /// sign-out must not bring that account back or overwrite the next one's.
  static Future<bool> saveRefreshedTokens({
    required int epoch,
    required String accessToken,
    required String refreshToken,
  }) {
    return _queueWrite(() async {
      if (epoch != _sessionEpoch) return false;
      await _writePair(accessToken, refreshToken);
      return true;
    });
  }

  static Future<void> _writePair(
    String accessToken,
    String refreshToken,
  ) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  static Future<String?> getAccessToken() async {
    await _afterPendingWrites();
    return _storage.read(key: _kAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    await _afterPendingWrites();
    return _storage.read(key: _kRefreshToken);
  }

  /// The signed-in backend user id (the access token's `sub`), for crash
  /// reports and support emails. Null when signed out.
  static Future<String?> getUserId() async =>
      userIdFromToken(await getAccessToken());

  static String? userIdFromToken(String? token) {
    final parts = token?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final sub = payload is Map ? payload['sub'] : null;
      return sub?.toString();
    } catch (_) {
      return null;
    }
  }

  /// A sign-out: ends the current session.
  static Future<void> clear() {
    _sessionEpoch++;
    return _queueWrite(
      () => Future.wait([
        _storage.delete(key: _kAccessToken),
        _storage.delete(key: _kRefreshToken),
      ]),
    );
  }
}
