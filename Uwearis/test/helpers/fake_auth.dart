import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uwearis/core/services/auth_storage.dart';

/// Seeds secure storage with a fake token pair so `BaseService.withAuth`
/// finds a signed-in session in tests, and has [AuthStorage] trust it: an earlier test's failed refresh may have distrusted the
/// session this process holds.
void setUpFakeAuth({
  String accessToken = 'fake-access-token',
  String refreshToken = 'fake-refresh-token',
}) {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': accessToken,
    'refresh_token': refreshToken,
  });
  AuthStorage.debugTrustStoredTokens();
}
