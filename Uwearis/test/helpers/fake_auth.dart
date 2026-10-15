import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Seeds secure storage with a fake access token so
/// `BaseService.getSafeToken()` succeeds in tests.
void setUpFakeAuth({
  String accessToken = 'fake-access-token',
  String refreshToken = 'fake-refresh-token',
}) {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': accessToken,
    'refresh_token': refreshToken,
  });
}
