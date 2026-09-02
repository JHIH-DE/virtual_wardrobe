import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Seeds [AuthStorage] (backed by flutter_secure_storage) with a fake access
/// token, using the plugin's own official test hook — so `BaseService
/// .getSafeToken()` succeeds in a plain `flutter_test` VM run without a real
/// secure-storage platform channel or a logged-in session. Call this in a
/// service test's `setUp()`.
void setUpFakeAuth({
  String accessToken = 'fake-access-token',
  String refreshToken = 'fake-refresh-token',
}) {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': accessToken,
    'refresh_token': refreshToken,
  });
}
