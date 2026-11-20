import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/services/base_service.dart';

import '../helpers/scripted_auth_storage.dart';

// BaseService.sessionGuard: the check a multi-step flow (upload, reanalyze,
// Match a Look reference) runs before each further step.

class _TestService with BaseService {}

Future<void> _signIn(String account) => AuthStorage.startSession(
  accessToken: 'access-$account',
  refreshToken: 'refresh-$account',
);

void main() {
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
  });

  test('passes any number of times within the same session', () async {
    final ensureSession = _TestService().sessionGuard();
    ensureSession();
    // A token refresh doesn't end the session.
    await AuthStorage.saveRefreshedTokens(
      epoch: AuthStorage.sessionEpoch,
      accessToken: 'access-A2',
      refreshToken: 'refresh-A2',
    );
    ensureSession();
    ensureSession();
  });

  test('fails after a sign-out', () async {
    final ensureSession = _TestService().sessionGuard();
    await AuthStorage.clear();
    expect(ensureSession, throwsA(isA<SessionChangedException>()));
  });

  test('fails after A → B', () async {
    final ensureSession = _TestService().sessionGuard();
    await AuthStorage.clear();
    await _signIn('B');
    expect(ensureSession, throwsA(isA<SessionChangedException>()));
  });

  test('stays failed after A → B → A: the same account signing in again '
      'is a new session', () async {
    final ensureSession = _TestService().sessionGuard();
    await AuthStorage.clear();
    await _signIn('B');
    await AuthStorage.clear();
    await _signIn('A');
    expect(ensureSession, throwsA(isA<SessionChangedException>()));
    // A guard made now belongs to the new session.
    _TestService().sessionGuard()();
  });

  test('captures the session when created, not when first checked', () async {
    final ensureSession = _TestService().sessionGuard();
    // startSession bumps the epoch synchronously, before its first await:
    // the guard already sees a new session while the sign-in is storing.
    final signIn = _signIn('B');
    expect(ensureSession, throwsA(isA<SessionChangedException>()));
    await signIn;
    expect(ensureSession, throwsA(isA<SessionChangedException>()));
  });
}
