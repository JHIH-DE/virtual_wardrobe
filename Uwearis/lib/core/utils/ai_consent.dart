import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_storage.dart';

/// Whether the signed-in user agreed to their photos and details going to
/// the third-party AI service (App Review 5.1.2(i)). Kept on the device per
/// user id until the backend stores it. Bump [_version] when the disclosure
/// changes materially (e.g. `AppConfig.aiProviderName`), so everyone is
/// asked again.
class AiConsent {
  static const _version = 1;

  /// Non-null skips storage; test/flutter_test_config.dart sets it true so
  /// AI flows run past the prompt unless a test opts back in with null.
  @visibleForTesting
  static bool? debugGrantedOverride;

  static Future<String> _key() async =>
      'ai_consent_v${_version}_${await AuthStorage.getUserId() ?? 'unknown'}';

  static Future<bool> isGranted() async {
    if (debugGrantedOverride != null) return debugGrantedOverride!;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(await _key()) != null;
  }

  static Future<void> grant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      await _key(),
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
