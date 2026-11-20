import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_log.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  /// Persisted flag, set before anything that can leave the keychain with a
  /// mixed pair or an already-rotated refresh token — a refresh call, a
  /// token pair write, a sign-out's deletes — and removed once that finished
  /// cleanly. A launch that finds it set never uses the stored tokens: the
  /// in-memory [_untrustedEpoch] is gone by then. Holds no token or user
  /// data. A separate store from the keychain, so the order of the two
  /// writes, not a transaction, is what makes this safe.
  static const _kUntrustedMarker = 'auth_tokens_untrusted';

  /// Which sign-in the stored tokens belong to. Bumped synchronously by
  /// [startSession] and [clear], so a request or refresh started under an
  /// earlier session can tell, even after A → B → A, and a token refresh
  /// within one session leaves it alone. In memory only: nothing in flight
  /// survives a restart.
  static int _sessionEpoch = 0;
  static int get sessionEpoch => _sessionEpoch;

  /// The session found on disk at launch, before any sign-in or sign-out.
  static const _launchEpoch = 0;

  /// A session whose stored tokens can't be trusted: its token pair or its
  /// sign-out's deletes failed, or the launch found [_kUntrustedMarker], so
  /// the keychain may hold a mixed pair or a refresh token the backend has
  /// already rotated — and resending a rotated one makes the backend revoke
  /// every session of that user. Reads return null for it, whatever is left
  /// on disk. Bound to its epoch, so the next sign-in starts trusted.
  static int? _untrustedEpoch;
  static bool get _untrusted => _untrustedEpoch == _sessionEpoch;

  /// Token writes run one at a time, so the access and refresh token are
  /// always replaced as a pair; reads wait for the writes queued before them.
  /// Null when no write is pending.
  static Future<void>? _writes;

  /// The launch's marker check: ahead of every read and queued write. Once
  /// done, only [_launchChecked] is consulted, so nothing awaits a future of
  /// a zone that may be gone (each widget test runs in its own).
  static Future<void>? _launchCheck;
  static bool _launchChecked = false;

  /// Forgets everything held in memory, as a relaunch would; what is on
  /// disk stays.
  @visibleForTesting
  static void debugSimulateRestart() {
    _sessionEpoch = 0;
    _untrustedEpoch = null;
    _writes = null;
    _launchCheck = null;
    _launchChecked = false;
  }

  /// Trusts the tokens a test seeded into the keychain as they are: forgets
  /// an earlier test's distrusted session and skips the launch check, so
  /// its leftover marker can't sign this test out. Session epochs carry on.
  @visibleForTesting
  static void debugTrustStoredTokens() {
    _untrustedEpoch = null;
    _launchChecked = true;
  }

  /// Null when there is nothing to wait for.
  static Future<void>? _pending() {
    if (_writes != null) return _writes;
    if (_launchChecked) return null;
    final running = _launchCheck;
    if (running != null) return running;
    late final Future<void> check;
    check = _checkMarkerAtLaunch().whenComplete(() {
      if (identical(_launchCheck, check)) _launchChecked = true;
    });
    return _launchCheck = check;
  }

  static Future<T> _queueWrite<T>(Future<T> Function() write) {
    final result = (_pending() ?? Future<void>.value()).then((_) => write());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_writes, tail)) _writes = null;
    });
    _writes = tail;
    return result;
  }

  /// Runs before anything else this process does with the keychain, so it
  /// can't delete a sign-in made since. Never throws. An unreadable marker
  /// distrusts the tokens for this launch but leaves them, for a launch that
  /// can tell.
  static Future<void> _checkMarkerAtLaunch() async {
    bool marked;
    try {
      final prefs = await SharedPreferences.getInstance();
      marked = prefs.getBool(_kUntrustedMarker) ?? false;
    } catch (e) {
      debugLog(
        'AuthStorage: reading the token marker failed (${e.runtimeType})',
      );
      _untrustedEpoch = _launchEpoch;
      return;
    }
    if (!marked) return;
    debugLog('AuthStorage: stored tokens were left unfinished; signing out');
    _untrustedEpoch = _launchEpoch;
    if (await _deleteTokens()) await _unmark();
  }

  /// Throws when the marker can't be stored.
  static Future<void> _mark() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_kUntrustedMarker, true)) {
      throw Exception('AuthStorage: token marker not stored');
    }
  }

  /// Best effort: a marker left behind only signs the next launch out.
  static Future<void> _unmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUntrustedMarker);
    } catch (e) {
      debugLog(
        'AuthStorage: clearing the token marker failed (${e.runtimeType})',
      );
    }
  }

  /// A sign-in: the tokens of a new session. Throws, storing nothing, when
  /// the marker can't be set first; that session is then over.
  static Future<void> startSession({
    required String accessToken,
    required String refreshToken,
  }) {
    final epoch = ++_sessionEpoch;
    return _queueWrite(() async {
      try {
        await _mark();
      } catch (e) {
        debugLog('AuthStorage: sign-in not stored (${e.runtimeType})');
        if (epoch == _sessionEpoch) _untrustedEpoch = epoch;
        rethrow;
      }
      await _writePair(epoch, accessToken, refreshToken);
    });
  }

  /// The refresh token for [epoch]'s `/auth/refresh`, once the marker is
  /// set: from the moment it is sent, the stored one may be spent. Null when
  /// [epoch] has ended or has no usable token. Throws when the marker can't
  /// be set — then it must not be sent; the session itself is still fine.
  static Future<String?> refreshTokenForRotation(int epoch) {
    return _queueWrite(() async {
      if (epoch != _sessionEpoch || _untrusted) return null;
      final token = await _storage.read(key: _kRefreshToken);
      if (token == null) return null;
      await _mark();
      return token;
    });
  }

  /// Ends [epoch]'s use of the stored tokens at once, in this process: reads
  /// return null and [refreshTokenForRotation] gives nothing more to send.
  /// For a refresh that may have spent the token without the app storing the
  /// new pair; the marker [refreshTokenForRotation] set keeps the next launch
  /// from using them too. Returns false, changing nothing, when [epoch] has
  /// already ended — the session now current is not this one's to end.
  static bool distrustSession(int epoch) {
    if (epoch != _sessionEpoch) return false;
    _untrustedEpoch = epoch;
    return true;
  }

  /// A token refresh's rotated pair. Writes nothing and returns false when
  /// [epoch] is no longer the current session — a refresh that lands after a
  /// sign-out must not bring that account back or overwrite the next one's.
  /// Throws when the pair can't be stored; that session is then over.
  static Future<bool> saveRefreshedTokens({
    required int epoch,
    required String accessToken,
    required String refreshToken,
  }) {
    return _queueWrite(() async {
      if (epoch != _sessionEpoch) return false;
      await _writePair(epoch, accessToken, refreshToken);
      return true;
    });
  }

  /// Refresh token first: if only it lands, the expired access token left
  /// beside it still recovers through a normal refresh. On any failure the
  /// session stops being usable, both keys are deleted, best effort, and the
  /// marker stays.
  static Future<void> _writePair(
    int epoch,
    String accessToken,
    String refreshToken,
  ) async {
    try {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
      await _storage.write(key: _kAccessToken, value: accessToken);
    } catch (e) {
      debugLog('AuthStorage: token pair write failed (${e.runtimeType})');
      // Another session since: its own queued writes replace these keys.
      if (epoch == _sessionEpoch) {
        _untrustedEpoch = epoch;
        await _deleteTokens();
      }
      rethrow;
    }
    await _unmark();
  }

  /// Deletes both keys, each attempted even if the other fails. False when
  /// either delete failed.
  static Future<bool> _deleteTokens() async {
    var deleted = true;
    for (final key in const [_kAccessToken, _kRefreshToken]) {
      try {
        await _storage.delete(key: key);
      } catch (e) {
        deleted = false;
        debugLog('AuthStorage: deleting $key failed (${e.runtimeType})');
      }
    }
    return deleted;
  }

  static Future<String?> getAccessToken() => _read(_kAccessToken);

  static Future<String?> getRefreshToken() => _read(_kRefreshToken);

  static Future<String?> _read(String key) async {
    final pending = _pending();
    if (pending != null) await pending;
    if (_untrusted) return null;
    final value = await _storage.read(key: key);
    return _untrusted ? null : value;
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

  /// A sign-out: ends the current session. Never throws: if the keychain
  /// refuses the deletes, this process still treats the session as signed
  /// out, and so does the next launch, through the marker — unless that
  /// can't be stored either.
  static Future<void> clear() {
    final epoch = ++_sessionEpoch;
    return _queueWrite(() async {
      try {
        await _mark();
      } catch (e) {
        debugLog('AuthStorage: sign-out marker failed (${e.runtimeType})');
      }
      if (await _deleteTokens()) {
        await _unmark();
      } else if (epoch == _sessionEpoch) {
        _untrustedEpoch = epoch;
      }
    });
  }
}
